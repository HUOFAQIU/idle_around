extends Node
## Mod 加载器（Autoload：ModLoader）。
##
## 在 _init() 里完成发现、校验、排序和 PCK 挂载；之后只提供只读查询。
## 必须排在 CollectionDB 之前启动，否则 mod 内容赶不上内容目录构建。
##
## 正式 mod 目录：
##   user://mods/<mod_id>/mod.json
##   user://mods/<mod_id>/content.pck   # 可选；没有则按 loose 目录加载
##
## mod.json 里的内容路径可以是相对路径，也可以是 res://mods/<mod_id>/...；
## loose 模式会自动把 res://mods/<mod_id>/... 映射到 user://mods/<mod_id>/...。

const MODS_DIR: String = "user://mods"
const CONFIG_PATH: String = "user://mods.cfg"
const MANIFEST_FILE: String = "mod.json"
const PACK_FILE: String = "content.pck"
const GAME_VERSION_SETTING: String = "application/config/version"

var _mods: Array[ModInfo] = []
## 按依赖/加载顺序排好、本次真正要加载的 mod
var _sorted_enabled: Array[ModInfo] = []
var _mods_by_id: Dictionary[StringName, ModInfo] = {}
var _soul_entries: Array[ModContentEntry] = []
var _monster_entries: Array[ModContentEntry] = []
var _cue_entries: Array[ModContentEntry] = []
var _soul_ids: Dictionary[StringName, bool] = {}
var _monster_ids: Dictionary[StringName, bool] = {}
var _cue_tags: Dictionary[StringName, bool] = {}
## override 路径 -> 声明它的 mod
var _overrides: Dictionary[String, StringName] = {}
var _errors: Array[String] = []
var _config := ConfigFile.new()
var _game_version: String = ""


func _init() -> void:
	_game_version = String(ProjectSettings.get_setting(GAME_VERSION_SETTING, "0.0.0"))
	_load_config()
	_discover_mods()
	_resolve_dependencies()
	_sort_mods()
	_mount_and_load()
	for message in _errors:
		push_warning("ModLoader: " + message)


#region 查询
func get_mods() -> Array[ModInfo]:
	var result: Array[ModInfo] = []
	result.assign(_mods)
	return result


func get_mod(mod_id: StringName) -> ModInfo:
	return _mods_by_id.get(mod_id)


func get_soul_entries() -> Array[ModContentEntry]:
	var result: Array[ModContentEntry] = []
	result.assign(_soul_entries)
	return result


func get_monster_entries() -> Array[ModContentEntry]:
	var result: Array[ModContentEntry] = []
	result.assign(_monster_entries)
	return result


func get_cue_entries() -> Array[ModContentEntry]:
	var result: Array[ModContentEntry] = []
	result.assign(_cue_entries)
	return result


func get_errors() -> Array[String]:
	return _errors.duplicate()


## 供内容合并阶段补充诊断（例如技能 ID 冲突）；会立即写 warning
func report_warning(message: String) -> void:
	_errors.append(message)
	push_warning("ModLoader: " + message)


## JSON 友好的概况，供 TestAPI 和未来的 mod 窗口使用
func get_mod_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mod in _mods:
		result.append({
			"id": String(mod.id),
			"name": mod.name,
			"version": mod.version,
			"author": mod.author,
			"enabled": mod.enabled,
			"blocked": mod.blocked,
			"loaded": mod.loaded,
			"mounted": mod.mounted,
			"source": "local",
			"souls": mod.soul_count,
			"monsters": mod.monster_count,
			"cues": mod.cue_count,
			"errors": mod.errors.duplicate(),
		})
	return result


func is_mod_enabled(mod_id: StringName) -> bool:
	var mod: ModInfo = _mods_by_id.get(mod_id)
	return mod != null and mod.enabled


## 写入启用状态；当前运行期不会卸载/重载，重启后生效
func set_mod_enabled(mod_id: StringName, enabled: bool) -> bool:
	var mod: ModInfo = _mods_by_id.get(mod_id)
	if mod == null:
		push_warning("ModLoader: 未知 mod %s" % mod_id)
		return false
	mod.enabled = enabled
	_config.set_value("mods", String(mod_id), enabled)
	var err := _config.save(CONFIG_PATH)
	if err != OK:
		push_warning("ModLoader: 写入 %s 失败（%d）" % [CONFIG_PATH, err])
		return false
	push_warning("ModLoader: mod %s 的启用状态已保存，重启后生效" % mod_id)
	return true
#endregion


#region 发现与排序
func _load_config() -> void:
	var err := _config.load(CONFIG_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		_record_error("读取 %s 失败（%d）" % [CONFIG_PATH, err])


func _is_enabled(mod_id: StringName) -> bool:
	return bool(_config.get_value("mods", String(mod_id), true))


func _ensure_mods_dir() -> bool:
	var global_path := ProjectSettings.globalize_path(MODS_DIR)
	if DirAccess.dir_exists_absolute(global_path):
		return true
	var err := DirAccess.make_dir_recursive_absolute(global_path)
	if err != OK:
		_record_error("创建 %s 失败（%d）" % [MODS_DIR, err])
		return false
	return true


func _discover_mods() -> void:
	if not _ensure_mods_dir():
		return
	var dir := DirAccess.open(MODS_DIR)
	if dir == null:
		_record_error("无法打开 %s" % MODS_DIR)
		return
	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while not folder_name.is_empty():
		if not folder_name.begins_with(".") and dir.current_is_dir():
			_discover_mod_folder(MODS_DIR.path_join(folder_name))
		folder_name = dir.get_next()
	dir.list_dir_end()
	_mods.sort_custom(_sort_by_id)


func _sort_by_id(a: ModInfo, b: ModInfo) -> bool:
	return String(a.id) < String(b.id)


func _discover_mod_folder(folder: String) -> void:
	var manifest_path := folder.path_join(MANIFEST_FILE)
	if not FileAccess.file_exists(manifest_path):
		return
	var manifest := ModManifest.new()
	if not manifest.load_from_file(manifest_path):
		for message in manifest.errors:
			_record_error("%s/%s: %s" % [folder, MANIFEST_FILE, message])
		return
	if _mods_by_id.has(manifest.id):
		_record_error("mod id 重复：%s（%s）" % [manifest.id, folder])
		return
	if not ModManifest.version_in_range(_game_version, manifest.game_version_min, manifest.game_version_max):
		_record_error("%s 与游戏版本 %s 不兼容（要求 %s ~ %s）" % [
			manifest.id,
			_game_version,
			manifest.game_version_min,
			manifest.game_version_max,
		])
		return

	var mod := ModInfo.new()
	mod.id = manifest.id
	mod.name = manifest.name
	mod.version = manifest.version
	mod.author = manifest.author
	mod.description = manifest.description
	mod.source = ModInfo.Source.LOCAL
	mod.root_path = folder
	mod.manifest_path = manifest_path
	mod.manifest = manifest
	mod.enabled = _is_enabled(manifest.id)

	var pack_path := folder.path_join(PACK_FILE)
	if FileAccess.file_exists(pack_path):
		mod.pack_path = pack_path

	_mods.append(mod)
	_mods_by_id[mod.id] = mod


func _resolve_dependencies() -> void:
	var changed := true
	while changed:
		changed = false
		for mod in _mods:
			if not mod.enabled or mod.blocked:
				continue
			for dependency in mod.manifest.dependencies:
				var target: ModInfo = _mods_by_id.get(dependency)
				if target == null:
					mod.blocked = true
					_mod_error(mod, "缺少依赖 mod：%s" % dependency)
					changed = true
					break
				if not target.enabled or target.blocked:
					mod.blocked = true
					_mod_error(mod, "依赖 mod 未启用：%s" % dependency)
					changed = true
					break


func _sort_mods() -> void:
	var sorted: Array[ModInfo] = []
	var states: Dictionary[StringName, int] = {}
	for mod in _mods:
		if mod.enabled and not mod.blocked:
			_visit_mod(mod, states, sorted)
	_sorted_enabled = sorted


func _visit_mod(mod: ModInfo, states: Dictionary[StringName, int], sorted: Array[ModInfo]) -> void:
	var state: int = states.get(mod.id, 0)
	if state == 2:
		return
	if state == 1:
		_mod_error(mod, "加载顺序存在循环依赖")
		return
	states[mod.id] = 1
	for dependency in mod.manifest.dependencies:
		var target: ModInfo = _mods_by_id.get(dependency)
		if target != null and target.enabled and not target.blocked:
			_visit_mod(target, states, sorted)
	for after_id in mod.manifest.load_after:
		var target: ModInfo = _mods_by_id.get(after_id)
		if target != null and target.enabled and not target.blocked:
			_visit_mod(target, states, sorted)
	states[mod.id] = 2
	sorted.append(mod)
#endregion


#region 挂载与内容
func _mount_and_load() -> void:
	for mod in _sorted_enabled:
		if mod.pack_path.is_empty():
			mod.loaded = true
			_load_mod_content(mod)
			continue
		if not FileAccess.file_exists(mod.pack_path):
			_mod_error(mod, "找不到 %s" % mod.pack_path)
			continue
		var absolute_path := ProjectSettings.globalize_path(mod.pack_path)
		if not ProjectSettings.load_resource_pack(absolute_path, true):
			_mod_error(mod, "PCK 挂载失败：%s" % mod.pack_path)
			continue
		mod.mounted = true
		mod.loaded = true
		_load_mod_content(mod)


func _load_mod_content(mod: ModInfo) -> void:
	_load_content_kind(mod, "souls", ModContentEntry.Kind.SOUL)
	_load_content_kind(mod, "monsters", ModContentEntry.Kind.MONSTER)
	_load_content_kind(mod, "cues", ModContentEntry.Kind.CUE)
	_validate_overrides(mod)


func _load_content_kind(mod: ModInfo, key: String, kind: ModContentEntry.Kind) -> void:
	var raw_entries: Variant = mod.manifest.content.get(key, [])
	if not raw_entries is Array:
		_mod_error(mod, "content.%s 必须是数组" % key)
		return
	for raw_entry in raw_entries:
		if not raw_entry is Dictionary:
			_mod_error(mod, "content.%s 条目必须是对象" % key)
			continue
		_load_content_entry(mod, key, kind, raw_entry as Dictionary)


func _load_content_entry(
	mod: ModInfo,
	key: String,
	kind: ModContentEntry.Kind,
	raw_entry: Dictionary
) -> void:
	var raw_id := String(raw_entry.get("id", raw_entry.get("tag", "")))
	var raw_path := String(raw_entry.get("path", raw_entry.get("scene", "")))
	if raw_id.is_empty() or raw_path.is_empty():
		_mod_error(mod, "content.%s 条目缺少 id/tag 或 path" % key)
		return

	if kind == ModContentEntry.Kind.CUE:
		if not raw_id.begins_with("Cue.Mod."):
			_mod_error(mod, "cue 标签必须以 Cue.Mod. 开头：%s" % raw_id)
			return
	elif not raw_id.begins_with(String(mod.id) + ":"):
		_mod_error(mod, "内容 ID 必须以 %s: 开头：%s" % [mod.id, raw_id])
		return

	var path := _resolve_content_path(mod, raw_path).simplify_path()
	if not path.begins_with(_content_root(mod)):
		_mod_error(mod, "内容路径越界：%s" % path)
		return
	if not ResourceLoader.exists(path):
		_mod_error(mod, "内容不存在：%s" % path)
		return
	var resource := ResourceLoader.load(path)
	if resource == null:
		_mod_error(mod, "内容加载失败：%s" % path)
		return

	var content_id := StringName(raw_id)
	match kind:
		ModContentEntry.Kind.SOUL:
			if not resource is SoulData:
				_mod_error(mod, "魂灵资源类型不对：%s" % path)
				return
			if _soul_ids.has(content_id):
				_mod_error(mod, "魂灵 ID 重复：%s" % content_id)
				return
			var soul := resource as SoulData
			soul.content_id = content_id
			_warn_skill_id(mod, soul)
			_soul_ids[content_id] = true
			_soul_entries.append(_make_entry(kind, mod, content_id, path, resource))
			mod.soul_count += 1
		ModContentEntry.Kind.MONSTER:
			if not resource is MonsterData:
				_mod_error(mod, "怪物资源类型不对：%s" % path)
				return
			if _monster_ids.has(content_id):
				_mod_error(mod, "怪物 ID 重复：%s" % content_id)
				return
			var monster := resource as MonsterData
			monster.content_id = content_id
			_monster_ids[content_id] = true
			_monster_entries.append(_make_entry(kind, mod, content_id, path, resource))
			mod.monster_count += 1
		ModContentEntry.Kind.CUE:
			if not resource is PackedScene:
				_mod_error(mod, "Cue 资源不是 PackedScene：%s" % path)
				return
			if _cue_tags.has(content_id):
				_mod_error(mod, "Cue 标签重复：%s" % content_id)
				return
			_cue_tags[content_id] = true
			_cue_entries.append(_make_entry(kind, mod, content_id, path, resource))
			mod.cue_count += 1


func _make_entry(
	kind: ModContentEntry.Kind,
	mod: ModInfo,
	content_id: StringName,
	path: String,
	resource: Resource
) -> ModContentEntry:
	var entry := ModContentEntry.new()
	entry.kind = kind
	entry.mod_id = mod.id
	entry.content_id = content_id
	entry.path = path
	entry.resource = resource
	return entry


func _warn_skill_id(mod: ModInfo, soul: SoulData) -> void:
	if soul.skill == null or soul.skill.id.is_empty():
		return
	var skill_path := soul.skill.resource_path
	var is_mod_skill := skill_path.begins_with("res://mods/") or skill_path.begins_with("user://mods/")
	if is_mod_skill and not soul.skill.id.begins_with(String(mod.id) + "_"):
		_mod_error(mod, "技能 id 未加 mod 前缀：%s" % soul.skill.id)


func _validate_overrides(mod: ModInfo) -> void:
	for raw_path in mod.manifest.overrides:
		var path := raw_path.simplify_path()
		if not path.begins_with("res://"):
			_mod_error(mod, "override 必须是 res:// 路径：%s" % raw_path)
			continue
		if _is_protected_override(path):
			_mod_error(mod, "不允许覆盖受保护路径：%s" % path)
			continue
		if not ResourceLoader.exists(path):
			_mod_error(mod, "override 目标不存在：%s" % path)
			continue
		if _overrides.has(path) and _overrides[path] != mod.id:
			_mod_error(mod, "override 路径已被 %s 覆盖：%s" % [_overrides[path], path])
		_overrides[path] = mod.id


func _is_protected_override(path: String) -> bool:
	if path == "res://project.godot":
		return true
	if path.begins_with("res://.godot/"):
		return true
	if path.begins_with("res://Scripts/mod/"):
		return true
	if path.begins_with("res://game/content/Collection/") and path.ends_with("_registry.tres"):
		return true
	return false


func _content_root(mod: ModInfo) -> String:
	if mod.pack_path.is_empty():
		return "user://mods/%s/" % mod.id
	return "res://mods/%s/" % mod.id


func _resolve_content_path(mod: ModInfo, raw_path: String) -> String:
	var canonical := "res://mods/%s/" % mod.id
	var root := _content_root(mod)
	if raw_path.begins_with(canonical):
		return root + raw_path.trim_prefix(canonical)
	if raw_path.begins_with("res://") or raw_path.begins_with("user://"):
		return raw_path
	return root.path_join(raw_path)
#endregion


#region 错误
func _record_error(message: String) -> void:
	_errors.append(message)


func _mod_error(mod: ModInfo, message: String) -> void:
	var text := "%s: %s" % [mod.id, message]
	mod.errors.append(text)
	_errors.append(text)
#endregion
