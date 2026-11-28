extends Node

const PACK_FILE: String = "content.pck"
const GAME_VERSION_SETTING: String = "application/config/version"
const CONTENT_NAMING: GDScript = preload("res://scripts/mod/content_naming.gd")
const CONTENT_KIND_SPEC: GDScript = preload("res://scripts/mod/content_kind_spec.gd")
const MOD_PATHS: GDScript = preload("res://scripts/mod/mod_paths.gd")
const MOD_VALIDATOR: GDScript = preload("res://scripts/mod/mod_content_validator.gd")
const STARTUP_TIMING: GDScript = preload("res://scripts/debug/startup_timing.gd")

var _mods: Array[ModInfo] = []
var _sorted_enabled: Array[ModInfo] = []
var _order: Array[StringName] = []
var _order_index: Dictionary[StringName, int] = {}
var _load_index: Dictionary[StringName, int] = {}
var _mods_by_id: Dictionary[StringName, ModInfo] = {}
var _soul_entries: Array[ModContentEntry] = []
var _monster_entries: Array[ModContentEntry] = []
var _vessel_entries: Array[ModContentEntry] = []
var _cue_entries: Array[ModContentEntry] = []
var _map_entries: Array[ModContentEntry] = []
var _item_entries: Array[ModContentEntry] = []
var _soul_ids: Dictionary[StringName, bool] = {}
var _monster_ids: Dictionary[StringName, bool] = {}
var _vessel_ids: Dictionary[StringName, bool] = {}
var _cue_tags: Dictionary[StringName, bool] = {}
var _map_ids: Dictionary[StringName, bool] = {}
var _item_ids: Dictionary[StringName, bool] = {}
var _content_paths: Dictionary[String, StringName] = {}
var _errors: Array[String] = []
var _warnings: Array[String] = []
var _validator: ModContentValidator
var _config := ConfigFile.new()
var _game_version: String = ""


func _init() -> void:
	STARTUP_TIMING.mark("首个 autoload")
	_validator = MOD_VALIDATOR.new(_mod_error, _content_root)
	_game_version = String(ProjectSettings.get_setting(GAME_VERSION_SETTING, "0.0.0"))
	_load_config()
	_load_order()
	_discover_mods()
	_resolve_dependencies()
	_sort_mods()
	_mount_and_load()
	for message in _errors:
		push_warning("ModLoader: " + message)
	for message in _warnings:
		push_warning("ModLoader: " + message)
	STARTUP_TIMING.mark("mod 加载完成")


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


func get_vessel_entries() -> Array[ModContentEntry]:
	var result: Array[ModContentEntry] = []
	result.assign(_vessel_entries)
	return result


func get_cue_entries() -> Array[ModContentEntry]:
	var result: Array[ModContentEntry] = []
	result.assign(_cue_entries)
	return result


func get_map_entries() -> Array[ModContentEntry]:
	var result: Array[ModContentEntry] = []
	result.assign(_map_entries)
	return result


func get_item_entries() -> Array[ModContentEntry]:
	var result: Array[ModContentEntry] = []
	result.assign(_item_entries)
	return result


func get_errors() -> Array[String]:
	return _errors.duplicate()


func get_warnings() -> Array[String]:
	return _warnings.duplicate()


func get_load_order() -> Array[StringName]:
	var result: Array[StringName] = []
	for mod in _sorted_enabled:
		result.append(mod.id)
	return result


func get_user_order() -> Array[StringName]:
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
	var err := _config.save(MOD_PATHS.CONFIG_PATH)
	if err != OK:
		push_warning("ModLoader: 写入 %s 失败（%d）" % [MOD_PATHS.CONFIG_PATH, err])
		return false
	push_warning("ModLoader: 加载顺序已保存，重启后生效")
	return true


func report_warning(message: String) -> void:
	_warnings.append(message)
	push_warning("ModLoader: " + message)


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
			"vessels": mod.vessel_count,
			"cues": mod.cue_count,
			"errors": mod.errors.duplicate(),
			"warnings": mod.warnings.duplicate(),
		})
	return result


func is_mod_enabled(mod_id: StringName) -> bool:
	var mod: ModInfo = _mods_by_id.get(mod_id)
	return mod != null and mod.enabled


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
	var err := _config.save(MOD_PATHS.CONFIG_PATH)
	if err != OK:
		push_warning("ModLoader: 写入 %s 失败（%d）" % [MOD_PATHS.CONFIG_PATH, err])
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


func _load_config() -> void:
	var err := _config.load(MOD_PATHS.CONFIG_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		_record_error("读取 %s 失败（%d）" % [MOD_PATHS.CONFIG_PATH, err])


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
	var global_path := ProjectSettings.globalize_path(MOD_PATHS.USER_MODS_DIR)
	if DirAccess.dir_exists_absolute(global_path):
		return true
	var err := DirAccess.make_dir_recursive_absolute(global_path)
	if err != OK:
		_record_error("创建 %s 失败（%d）" % [MOD_PATHS.USER_MODS_DIR, err])
		return false
	return true


func _discover_mods() -> void:
	_discover_mod_root(MOD_PATHS.BUILTIN_MODS_DIR, ModInfo.Source.BUILTIN)
	if _ensure_mods_dir():
		_discover_mod_root(MOD_PATHS.USER_MODS_DIR, ModInfo.Source.LOCAL)
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
	var manifest_path := folder.path_join(MOD_PATHS.MANIFEST_FILE)
	if not FileAccess.file_exists(manifest_path):
		return
	var manifest := ModManifest.new()
	if not manifest.load_from_file(manifest_path):
		for message in manifest.errors:
			_record_error("%s/%s: %s" % [folder, MOD_PATHS.MANIFEST_FILE, message])
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
	for message in manifest.warnings:
		var warning := "%s: %s" % [manifest.id, message]
		mod.warnings.append(warning)
		_warnings.append(warning)

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
	var known: Dictionary = {}
	for spec in CONTENT_KIND_SPEC.all():
		known[String(spec.get("key", ""))] = true
		_load_content_kind(mod, spec)
	for key in mod.manifest.content.keys():
		if not known.has(String(key)):
			push_warning("ModLoader: %s: 未知 content 段 %s" % [mod.id, key])
	_validator.validate_overrides(mod)


func _load_content_kind(mod: ModInfo, spec: Dictionary) -> void:
	var key := String(spec.get("key", ""))
	var raw_entries: Variant = mod.manifest.content.get(key, [])
	if not raw_entries is Array:
		_mod_error(mod, "content.%s 必须是数组" % key)
		return
	for raw_entry in raw_entries:
		if not raw_entry is Dictionary:
			_mod_error(mod, "content.%s 条目必须是对象" % key)
			continue
		_load_content_entry(mod, spec, raw_entry as Dictionary)


func _load_content_entry(mod: ModInfo, spec: Dictionary, raw_entry: Dictionary) -> void:
	var key := String(spec.get("key", ""))
	var id_field := String(spec.get("id_field", "id"))
	var path_field := String(spec.get("path_field", "path"))
	var raw_id := String(raw_entry.get(id_field, ""))
	var raw_path := String(raw_entry.get(path_field, ""))
	if raw_id.is_empty() or raw_path.is_empty():
		_mod_error(mod, "content.%s 条目缺少 %s / %s" % [key, id_field, path_field])
		return

	if not _validator.validate_content_id(mod, spec, raw_id):
		return

	var path := _resolve_content_path(mod, raw_path).simplify_path()
	if not path.begins_with(_content_root(mod)):
		_mod_error(mod, "内容路径越界：%s" % path)
		return
	if not ResourceLoader.exists(path):
		_mod_error(mod, "内容不存在：%s" % path)
		return
	if _content_paths.has(path):
		_mod_error(mod, "内容路径重复登记：%s（已用于 %s）" % [path, _content_paths[path]])
		return
	var resource := ResourceLoader.load(path)
	if resource == null:
		_mod_error(mod, "内容加载失败：%s" % path)
		return

	var content_id := StringName(raw_id)
	var kind := int(spec.get("kind", ContentKind.Kind.SOUL))
	match kind:
		ContentKind.Kind.SOUL:
			if not resource is SoulData:
				_mod_error(mod, "魂灵资源类型不对：%s" % path)
				return
			if _soul_ids.has(content_id):
				_mod_error(mod, "魂灵 ID 重复：%s" % content_id)
				return
			var soul := resource as SoulData
			soul.content_id = content_id
			var errors_before := _errors.size()
			_validator.normalize_skill_id(mod, soul)
			_validator.validate_soul_vocabulary(mod, soul)
			_validator.validate_soul_tags(mod, soul)
			_validator.validate_skill_steps(mod, soul)
			if _errors.size() > errors_before:
				return
			_soul_ids[content_id] = true
			_content_paths[path] = content_id
			_soul_entries.append(_make_entry(kind, mod, content_id, path, resource))
			mod.soul_count += 1
		ContentKind.Kind.MONSTER:
			if not resource is MonsterData:
				_mod_error(mod, "怪物资源类型不对：%s" % path)
				return
			if _monster_ids.has(content_id):
				_mod_error(mod, "怪物 ID 重复：%s" % content_id)
				return
			var monster := resource as MonsterData
			monster.content_id = content_id
			var errors_before := _errors.size()
			_validator.validate_monster_config(mod, monster)
			if _errors.size() > errors_before:
				return
			_monster_ids[content_id] = true
			_content_paths[path] = content_id
			_monster_entries.append(_make_entry(kind, mod, content_id, path, resource))
			mod.monster_count += 1
		ContentKind.Kind.VESSEL:
			if not resource is SoulVesselData:
				_mod_error(mod, "魂器资源类型不对：%s" % path)
				return
			if _vessel_ids.has(content_id):
				_mod_error(mod, "魂器 ID 重复：%s" % content_id)
				return
			var vessel := resource as SoulVesselData
			vessel.content_id = content_id
			var errors_before := _errors.size()
			_validator.validate_vessel_config(mod, vessel)
			if _errors.size() > errors_before:
				return
			_vessel_ids[content_id] = true
			_content_paths[path] = content_id
			_vessel_entries.append(_make_entry(kind, mod, content_id, path, resource))
			mod.vessel_count += 1
		ContentKind.Kind.CUE:
			if not resource is PackedScene:
				_mod_error(mod, "Cue 资源不是 PackedScene：%s" % path)
				return
			if _cue_tags.has(content_id):
				_mod_error(mod, "Cue 标签重复：%s" % content_id)
				return
			_cue_tags[content_id] = true
			_content_paths[path] = content_id
			_cue_entries.append(_make_entry(kind, mod, content_id, path, resource))
			mod.cue_count += 1
		ContentKind.Kind.MAP:
			if not resource is MapData:
				_mod_error(mod, "地图资源类型不对：%s" % path)
				return
			if _map_ids.has(content_id):
				_mod_error(mod, "地图 ID 重复：%s" % content_id)
				return
			var map_data := resource as MapData
			map_data.content_id = content_id
			_map_ids[content_id] = true
			_content_paths[path] = content_id
			_map_entries.append(_make_entry(kind, mod, content_id, path, resource))
			mod.map_count += 1
		ContentKind.Kind.ITEM:
			if not resource is ItemData:
				_mod_error(mod, "物品资源类型不对：%s" % path)
				return
			if _item_ids.has(content_id):
				_mod_error(mod, "物品 ID 重复：%s" % content_id)
				return
			var item_data := resource as ItemData
			item_data.content_id = content_id
			_item_ids[content_id] = true
			_content_paths[path] = content_id
			_item_entries.append(_make_entry(kind, mod, content_id, path, resource))
			mod.item_count += 1


func _make_entry(
	kind: int,
	mod: ModInfo,
	content_id: StringName,
	path: String,
	resource: Resource
) -> ModContentEntry:
	var entry := ModContentEntry.new()
	entry.kind = kind as ContentKind.Kind
	entry.mod_id = mod.id
	entry.content_id = content_id
	entry.path = path
	entry.resource = resource
	return entry


func _content_root(mod: ModInfo) -> String:
	if mod.is_builtin():
		if not mod.manifest.content_root.is_empty():
			return mod.manifest.content_root
		return MOD_PATHS.builtin_mod_dir(mod.id)
	if mod.pack_path.is_empty():
		return MOD_PATHS.user_mod_dir(mod.id)
	return MOD_PATHS.res_mod_dir(mod.id)


func _canonical_content_prefix(mod: ModInfo) -> String:
	if mod.is_builtin():
		return MOD_PATHS.builtin_mod_dir(mod.id)
	return MOD_PATHS.res_mod_dir(mod.id)


func _resolve_content_path(mod: ModInfo, raw_path: String) -> String:
	var canonical := _canonical_content_prefix(mod)
	var root := _content_root(mod)
	if raw_path.begins_with(canonical):
		return root + raw_path.trim_prefix(canonical)
	if raw_path.begins_with("res://") or raw_path.begins_with("user://"):
		return raw_path
	return root.path_join(raw_path)


func _record_error(message: String) -> void:
	_errors.append(message)


func _mod_error(mod: ModInfo, message: String) -> void:
	var text := "%s: %s" % [mod.id, message]
	mod.errors.append(text)
	_errors.append(text)
