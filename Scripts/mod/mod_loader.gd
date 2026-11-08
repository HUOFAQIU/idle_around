extends Node
## Mod 加载器（Autoload：ModLoader）。
##
## 在 _init() 里完成发现、校验、排序、PCK 挂载和内容加载；之后提供查询，以及写启用状态/加载顺序的配置接口。
## 必须排在 CollectionDB 之前启动，否则 mod 内容赶不上内容目录构建。
##
## 内置 mod 目录：
##   res://base_mods/<mod_id>/mod.json
##   res://base_mods/<mod_id>/...       # 官方内容包只支持 loose 目录
##
## 第三方 mod 目录：
##   user://mods/<mod_id>/mod.json
##   user://mods/<mod_id>/content.pck   # 可选；没有则按 loose 目录加载
##
## mod.json 里的内容路径可以是相对路径，也可以是 res://mods/<mod_id>/...；
## loose 模式会自动把 res://mods/<mod_id>/... 映射到 user://mods/<mod_id>/...。

## 随游戏发布的内置 mod 目录；只会出现官方内容包
const BUILTIN_MODS_DIR: String = "res://base_mods"
const MODS_DIR: String = "user://mods"
const CONFIG_PATH: String = "user://mods.cfg"
const MANIFEST_FILE: String = "mod.json"
const PACK_FILE: String = "content.pck"
const GAME_VERSION_SETTING: String = "application/config/version"
## 用 preload 而不是全局类名，保证 --script 无头模式也能解析
const CONTENT_NAMING: GDScript = preload("res://Scripts/mod/content_naming.gd")

var _mods: Array[ModInfo] = []
## 按依赖/加载顺序排好、本次真正要加载的 mod
var _sorted_enabled: Array[ModInfo] = []
## 用户指定的基础加载顺序；运行期不改
var _order: Array[StringName] = []
var _order_index: Dictionary[StringName, int] = {}
## 本次实际加载顺序的索引，-1 表示没加载
var _load_index: Dictionary[StringName, int] = {}
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
## 同一个效果可能被多颗魂灵引用，只校验一次
var _validated_effect_ids: Dictionary = {}
var _config := ConfigFile.new()
var _game_version: String = ""


func _init() -> void:
	_game_version = String(ProjectSettings.get_setting(GAME_VERSION_SETTING, "0.0.0"))
	_load_config()
	_load_order()
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


## 本次实际加载顺序（只含已启用且未被阻止的 mod）
func get_load_order() -> Array[StringName]:
	var result: Array[StringName] = []
	for mod in _sorted_enabled:
		result.append(mod.id)
	return result


## 用户指定的基础加载顺序；内置 mod 固定在最前，未列出的追加在末尾
func get_order_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for mod in _mods:
		if mod.is_builtin():
			result.append(mod.id)
	for mod_id in _order:
		if _mods_by_id.has(mod_id) and not result.has(mod_id):
			result.append(mod_id)
	for mod in _mods:
		if not result.has(mod.id):
			result.append(mod.id)
	return result


## 写入基础加载顺序；内置 mod 始终排在最前，运行期不重排，重启后生效
func set_mod_order(ids: Array[StringName]) -> bool:
	var normalized: Array[StringName] = []
	for mod in _mods:
		if mod.is_builtin():
			normalized.append(mod.id)
	for mod_id in ids:
		if _mods_by_id.has(mod_id) and not normalized.has(mod_id):
			normalized.append(mod_id)
	for mod in _mods:
		if not normalized.has(mod.id):
			normalized.append(mod.id)
	_order = normalized
	_rebuild_order_index()
	var packed := PackedStringArray()
	for mod_id in _order:
		packed.append(String(mod_id))
	_config.set_value("order", "list", packed)
	var err := _config.save(CONFIG_PATH)
	if err != OK:
		push_warning("ModLoader: 写入 %s 失败（%d）" % [CONFIG_PATH, err])
		return false
	push_warning("ModLoader: 加载顺序已保存，重启后生效")
	return true


## 供内容合并阶段补充诊断（例如技能 ID 冲突）；会立即写 warning
func report_warning(message: String) -> void:
	_errors.append(message)
	push_warning("ModLoader: " + message)


## JSON 友好的概况，供 TestAPI 和 ModWindow 使用
func get_mod_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mod in _mods:
		result.append({
			"id": String(mod.id),
			"name": mod.name,
			"version": mod.version,
			"author": mod.author,
			"description": mod.description,
			"enabled": mod.enabled,
			"blocked": mod.blocked,
			"loaded": mod.loaded,
			"mounted": mod.mounted,
			"load_index": _load_index.get(mod.id, -1),
			"source": _source_name(mod.source),
			"builtin": mod.is_builtin(),
			"locked": mod.is_builtin(),
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
	if mod.is_builtin():
		push_warning("ModLoader: 内置 mod %s 不能禁用" % mod_id)
		return false
	mod.enabled = enabled
	_config.set_value("mods", String(mod_id), enabled)
	var err := _config.save(CONFIG_PATH)
	if err != OK:
		push_warning("ModLoader: 写入 %s 失败（%d）" % [CONFIG_PATH, err])
		return false
	push_warning("ModLoader: mod %s 的启用状态已保存，重启后生效" % mod_id)
	return true


func _source_name(source: ModInfo.Source) -> String:
	match source:
		ModInfo.Source.BUILTIN:
			return "builtin"
		ModInfo.Source.WORKSHOP:
			return "workshop"
		_:
			return "local"
#endregion


#region 发现与排序
func _load_config() -> void:
	var err := _config.load(CONFIG_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		_record_error("读取 %s 失败（%d）" % [CONFIG_PATH, err])


func _load_order() -> void:
	var raw: Variant = _config.get_value("order", "list", PackedStringArray())
	if not raw is PackedStringArray and not raw is Array:
		return
	for value in raw:
		var mod_id := StringName(String(value))
		if not mod_id.is_empty() and not _order.has(mod_id):
			_order.append(mod_id)
	_rebuild_order_index()


func _rebuild_order_index() -> void:
	_order_index.clear()
	for index in _order.size():
		_order_index[_order[index]] = index


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
	_discover_mod_root(BUILTIN_MODS_DIR, ModInfo.Source.BUILTIN)
	if _ensure_mods_dir():
		_discover_mod_root(MODS_DIR, ModInfo.Source.LOCAL)
	_mods.sort_custom(_sort_by_user_order)


func _discover_mod_root(root: String, source: ModInfo.Source) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		_record_error("无法打开 %s" % root)
		return
	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while not folder_name.is_empty():
		if not folder_name.begins_with(".") and dir.current_is_dir():
			_discover_mod_folder(root.path_join(folder_name), source)
		folder_name = dir.get_next()
	dir.list_dir_end()


## 内置优先；其余按用户顺序，没在配置里的 mod 按 id 排在后面
func _sort_by_user_order(a: ModInfo, b: ModInfo) -> bool:
	var a_builtin := a.is_builtin()
	var b_builtin := b.is_builtin()
	if a_builtin != b_builtin:
		return a_builtin
	var a_index: int = _order_index.get(a.id, 0x7fffffff)
	var b_index: int = _order_index.get(b.id, 0x7fffffff)
	if a_index == b_index:
		return String(a.id) < String(b.id)
	return a_index < b_index


func _discover_mod_folder(folder: String, source: ModInfo.Source) -> void:
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
	if source != ModInfo.Source.BUILTIN:
		if manifest.content_namespace == "global":
			_record_error("%s: 只有内置 mod 可以使用 content_namespace=global" % manifest.id)
			return
		if not manifest.content_root.is_empty():
			_record_error("%s: 只有内置 mod 可以使用 content_root" % manifest.id)
			return

	var mod := ModInfo.new()
	mod.id = manifest.id
	mod.name = manifest.name
	mod.version = manifest.version
	mod.author = manifest.author
	mod.description = manifest.description
	mod.source = source
	mod.root_path = folder
	mod.manifest_path = manifest_path
	mod.manifest = manifest
	mod.enabled = true if source == ModInfo.Source.BUILTIN else _is_enabled(manifest.id)

	var pack_path := folder.path_join(PACK_FILE)
	if FileAccess.file_exists(pack_path):
		if source == ModInfo.Source.BUILTIN:
			_record_error("%s: 内置 mod 不支持 content.pck，请使用 loose 目录" % manifest.id)
			return
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
	_load_index.clear()
	for index in sorted.size():
		_load_index[sorted[index].id] = index


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
## 两段式：先挂载全部 PCK，再统一加载内容。
## 这样后挂载的 mod 覆盖 res:// 路径时，先加载的内置内容不会被资源缓存绕过。
func _mount_and_load() -> void:
	_mount_all()
	_load_all_content()


func _mount_all() -> void:
	for mod in _sorted_enabled:
		if mod.pack_path.is_empty():
			mod.loaded = true
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


func _load_all_content() -> void:
	for mod in _sorted_enabled:
		if mod.loaded:
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

	if not _validate_content_id(mod, kind, raw_id):
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
			_normalize_skill_id(mod, soul)
			_validate_soul_vocabulary(mod, soul)
			_validate_soul_tags(mod, soul)
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
			_validate_monster_config(mod, monster)
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


## 校验内容 ID / Cue 标签的前缀、字符集和类型后缀；返回 false 表示该条目不加载
func _validate_content_id(mod: ModInfo, kind: ModContentEntry.Kind, raw_id: String) -> bool:
	var global_namespace := mod.manifest.content_namespace == "global"
	if kind == ModContentEntry.Kind.CUE:
		var cue_prefix := _cue_tag_prefix(mod)
		if not global_namespace and (not raw_id.begins_with(cue_prefix) or raw_id.length() == cue_prefix.length()):
			_mod_error(mod, "cue 标签必须使用 %s 前缀：%s" % [cue_prefix, raw_id])
			return false
		if not CONTENT_NAMING.is_valid_tag(raw_id):
			_mod_error(mod, "cue 标签不是合法 GAS 标签：%s" % raw_id)
			return false
		return true

	if not global_namespace and not raw_id.begins_with(String(mod.id) + ":"):
		_mod_error(mod, "内容 ID 必须以 %s: 开头：%s" % [mod.id, raw_id])
		return false
	var local_id: String = CONTENT_NAMING.local_id_of(StringName(raw_id), mod.id)
	if not CONTENT_NAMING.is_valid_local_id(local_id):
		_mod_error(mod, "内容 ID 不合法（小写 snake_case）：%s" % raw_id)
		return false
	if kind == ModContentEntry.Kind.SOUL and not CONTENT_NAMING.is_soul_local_id(local_id):
		_mod_error(mod, "魂灵 ID 应以 %s 结尾：%s" % [CONTENT_NAMING.SOUL_SUFFIX, raw_id])
		return false
	if kind == ModContentEntry.Kind.MONSTER and not CONTENT_NAMING.is_monster_local_id(local_id, global_namespace):
		_mod_error(mod, "怪物 ID 应以 %s 结尾：%s" % [CONTENT_NAMING.MONSTER_SUFFIX, raw_id])
		return false
	return true


## 技能 ID 存的是 ability_tag 后缀：为空时按 content_id 派生，非空时校验格式与命名空间
func _normalize_skill_id(mod: ModInfo, soul: SoulData) -> void:
	var skill := soul.skill
	if skill == null:
		return
	var owns_skill := not skill.resource_path.is_empty() and skill.resource_path.begins_with(_content_root(mod))
	if not owns_skill:
		_validate_external_skill_id(mod, skill)
		return

	var global_namespace := mod.manifest.content_namespace == "global"
	if skill.id.is_empty():
		skill.id = CONTENT_NAMING.skill_suffix(mod.id, soul.content_id, global_namespace)
		return
	if not CONTENT_NAMING.is_valid_tag(skill.id):
		_mod_error(mod, "技能 id 不是合法 GAS 标签：%s" % skill.id)
		return
	if not CONTENT_NAMING.is_skill_suffix_allowed(skill.id, mod.id, global_namespace):
		_mod_error(mod, "技能 id 必须使用 %s%s. 前缀：%s" % [
			CONTENT_NAMING.MOD_TAG_PREFIX,
			CONTENT_NAMING.to_pascal(String(mod.id)),
			skill.id,
		])
		return
	if global_namespace:
		var expected: String = CONTENT_NAMING.skill_suffix(mod.id, soul.content_id, true)
		if skill.id != expected:
			_mod_error(mod, "core 技能 id 应与魂灵 ID 对应，应为 %s：%s" % [expected, skill.id])


## mod 引用外部技能资源时只校验格式，不要求本 mod 命名空间
func _validate_external_skill_id(mod: ModInfo, skill: SkillDefinition) -> void:
	if skill.id.is_empty():
		_mod_error(mod, "外部技能资源缺少 id：%s" % skill.resource_path)
	elif not CONTENT_NAMING.is_valid_tag(skill.id):
		_mod_error(mod, "技能 id 不是合法 GAS 标签：%s" % skill.id)


## 魂灵类型/标签使用固定前缀；拼错会让筛选和触发规则静默失效
func _validate_soul_vocabulary(mod: ModInfo, soul: SoulData) -> void:
	for type in soul.types:
		if not _is_soul_type(type):
			_mod_error(mod, "魂灵 %s 的类型应为 Soul.types.<PascalName>：%s" % [soul.content_id, type])
	for tag in soul.tags:
		if not _is_soul_tag(tag):
			_mod_error(mod, "魂灵 %s 的标签应为 Soul.tags.<PascalName>：%s" % [soul.content_id, tag])
	for trigger in soul.triggers:
		if trigger == null:
			continue
		for type in trigger.required_soul_types:
			if not _is_soul_type(type):
				_mod_error(mod, "魂灵 %s 的触发条件类型应为 Soul.types.<PascalName>：%s" % [soul.content_id, type])


## 稀有怪必须同时退出常规池，并且有可实例化的战斗场景
func _validate_monster_config(mod: ModInfo, monster: MonsterData) -> void:
	if not monster.is_rare:
		return
	if monster.spawn_weight > 0.0:
		_mod_error(mod, "怪物 %s 标记为 is_rare，spawn_weight 应为 0" % monster.content_id)
	if monster.battle_scene == null:
		_mod_error(mod, "稀有怪 %s 缺少 battle_scene" % monster.content_id)


func _is_soul_type(value: StringName) -> bool:
	var text := String(value)
	return text.begins_with("Soul.types.") and CONTENT_NAMING.is_valid_tag(text.trim_prefix("Soul.types."))


func _is_soul_tag(value: StringName) -> bool:
	var text := String(value)
	return text.begins_with("Soul.tags.") and CONTENT_NAMING.is_valid_tag(text.trim_prefix("Soul.tags."))


## 技能/触发器/效果里的标签引用：只校验格式和必要的命名空间，注册检查在 ModCueRegistrar
func _validate_soul_tags(mod: ModInfo, soul: SoulData) -> void:
	var skill := soul.skill
	if skill != null:
		_validate_tag(mod, skill.hit_cue_tag, "Cue.", "魂灵 %s 的 hit_cue_tag" % soul.content_id)
		for tag in skill.cast_require_all_tags:
			_validate_tag(mod, tag, "", "魂灵 %s 的 cast_require_all_tags" % soul.content_id)
		for tag in skill.cast_block_tags:
			_validate_tag(mod, tag, "", "魂灵 %s 的 cast_block_tags" % soul.content_id)
		_validate_effects(mod, skill.effects, soul.content_id)
		_validate_effects(mod, skill.self_effects, soul.content_id)
	if soul is PassiveSoulData:
		_validate_effects(mod, (soul as PassiveSoulData).passive_effects, soul.content_id)
	for trigger in soul.triggers:
		if trigger == null:
			continue
		_validate_tag(mod, trigger.event_tag, "Event.", "魂灵 %s 的 trigger.event_tag" % soul.content_id)
		_validate_effects(mod, trigger.effects, soul.content_id)


func _validate_effects(mod: ModInfo, effects: Array[GameplayEffect], owner: StringName) -> void:
	for effect in effects:
		if effect != null:
			_validate_effect_tags(mod, effect, owner)


func _validate_effect_tags(mod: ModInfo, effect: GameplayEffect, owner: StringName) -> void:
	var effect_id := effect.get_instance_id()
	if _validated_effect_ids.has(effect_id):
		return
	_validated_effect_ids[effect_id] = true

	for tag in effect.granted_tags:
		_validate_tag(mod, tag, "", "效果 %s 的 granted_tags" % owner)
	for tag in effect.remove_effects_with_tags:
		_validate_tag(mod, tag, "", "效果 %s 的 remove_effects_with_tags" % owner)
	for tag in effect.application_cue_tags:
		_validate_tag(mod, tag, "Cue.", "效果 %s 的 application_cue_tags" % owner)
	for tag in effect.persistent_cue_tags:
		_validate_tag(mod, tag, "Cue.", "效果 %s 的 persistent_cue_tags" % owner)
	for tag in effect.periodic_cue_tags:
		_validate_tag(mod, tag, "Cue.", "效果 %s 的 periodic_cue_tags" % owner)
	for tag in effect.removal_cue_tags:
		_validate_tag(mod, tag, "Cue.", "效果 %s 的 removal_cue_tags" % owner)
	for tag in effect.event_tags:
		_validate_tag(mod, tag, "Event.", "效果 %s 的 event_tags" % owner)

	for execution in effect.executions:
		if execution is SoulDamageExecution:
			for type in (execution as SoulDamageExecution).matching_soul_types:
				if not _is_soul_type(type):
					_mod_error(mod, "效果 %s 的 matching_soul_types 应为 Soul.types.<PascalName>：%s" % [owner, type])
	for overflow in effect.overflow_effects:
		if overflow != null:
			_validate_effect_tags(mod, overflow, owner)


func _validate_tag(mod: ModInfo, tag: StringName, required_prefix: String, context: String) -> void:
	if tag.is_empty():
		return
	var text := String(tag)
	if not CONTENT_NAMING.is_valid_tag(text):
		_mod_error(mod, "%s 不是合法 GAS 标签：%s" % [context, text])
		return
	if not required_prefix.is_empty() and not text.begins_with(required_prefix):
		_mod_error(mod, "%s 应以 %s 开头：%s" % [context, required_prefix, text])


func _validate_overrides(mod: ModInfo) -> void:
	for raw_path in mod.manifest.overrides:
		var path := raw_path.simplify_path()
		if not path.begins_with("res://"):
			_mod_error(mod, "override 必须是 res:// 路径：%s" % raw_path)
			continue
		var migrated := _migrated_override_path(path)
		if not migrated.is_empty():
			_mod_error(mod, "override 路径已迁移到 %s，请重新打包：%s" % [migrated, path])
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
	if path.begins_with("res://base_mods/") and path.ends_with("/mod.json"):
		return true
	return false


## 官方内容物理迁移前的旧路径；返回对应的新路径，没有迁移时返回空串
func _migrated_override_path(path: String) -> String:
	if path.begins_with("res://game/content/Souls/"):
		return "res://base_mods/core/souls/" + path.trim_prefix("res://game/content/Souls/")
	if path.begins_with("res://game/content/Monster/"):
		return "res://base_mods/core/monsters/" + path.trim_prefix("res://game/content/Monster/")
	if path.begins_with("res://game/content/effects/"):
		return "res://base_mods/core/effects/" + path.trim_prefix("res://game/content/effects/")
	if path.begins_with("res://game/content/cues/"):
		return "res://base_mods/core/cues/" + path.trim_prefix("res://game/content/cues/")
	if path.begins_with("res://game/battle/cues/") and path.ends_with(".tscn"):
		return "res://base_mods/core/cues/" + path.trim_prefix("res://game/battle/cues/")
	return ""


## Cue 标签命名空间：mod id（snake_case）转 PascalCase，例如 example_souls → Cue.Mod.ExampleSouls.
func _cue_tag_prefix(mod: ModInfo) -> String:
	return "Cue.Mod.%s." % CONTENT_NAMING.to_pascal(String(mod.id))


func _content_root(mod: ModInfo) -> String:
	if mod.is_builtin():
		if not mod.manifest.content_root.is_empty():
			return mod.manifest.content_root
		return "res://base_mods/%s/" % mod.id
	if mod.pack_path.is_empty():
		return "user://mods/%s/" % mod.id
	return "res://mods/%s/" % mod.id


func _canonical_content_prefix(mod: ModInfo) -> String:
	if mod.is_builtin():
		return "res://base_mods/%s/" % mod.id
	return "res://mods/%s/" % mod.id


func _resolve_content_path(mod: ModInfo, raw_path: String) -> String:
	var canonical := _canonical_content_prefix(mod)
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
