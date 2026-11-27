extends Node

signal entry_unlocked(kind: int, id: StringName)
signal state_reloaded

const STARTUP_TIMING: GDScript = preload("res://scripts/debug/startup_timing.gd")

var unlock_all_for_testing: bool = false

var _souls: Dictionary[StringName, SoulData] = {}
var _monsters: Dictionary[StringName, MonsterData] = {}
var _vessels: Dictionary[StringName, SoulVesselData] = {}
var _seen: Dictionary = {}


func _ready() -> void:
	STARTUP_TIMING.mark("主场景加载编译与前置 autoload 完成")
	_reset_seen()
	_load_catalog()
	GBIS.sig_inv_item_added.connect(_on_inv_item_added)
	GBIS.sig_inv_refresh.connect(_scan_owned_souls)
	@warning_ignore("missing_await")
	_scan_owned_souls_after_ready()


func get_soul_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_souls.keys())
	return ids


func get_monster_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_monsters.keys())
	return ids


func get_soul(id: StringName) -> SoulData:
	return _souls.get(id)


func get_monster(id: StringName) -> MonsterData:
	return _monsters.get(id)


func get_vessel_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_vessels.keys())
	return ids


func get_vessel(id: StringName) -> SoulVesselData:
	return _vessels.get(id)


func is_seen(kind: int, id: StringName) -> bool:
	if unlock_all_for_testing:
		return true
	var seen: Dictionary = _seen.get(kind, {})
	return seen.has(id)


func set_unlock_all_for_testing(enabled: bool) -> void:
	unlock_all_for_testing = enabled


func get_seen_ids(kind: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	var seen: Dictionary = _seen.get(kind, {})
	ids.assign(seen.keys())
	return ids


func mark_soul_seen(soul: SoulData) -> void:
	if soul == null:
		return
	var id: StringName = soul.content_id
	if id.is_empty():
		push_warning("见闻：魂灵没有 content_id「%s」" % soul.item_name)
		return
	_mark_seen(ContentKind.Kind.SOUL, id)


func mark_vessel_seen(vessel: SoulVesselData) -> void:
	if vessel == null:
		return
	var id: StringName = vessel.content_id
	if id.is_empty():
		push_warning("见闻：魂器没有 content_id「%s」" % vessel.item_name)
		return
	_mark_seen(ContentKind.Kind.VESSEL, id)


func mark_monster_seen(monster: MonsterData) -> void:
	if monster == null:
		return
	var id: StringName = monster.content_id
	if id.is_empty():
		push_warning("见闻：怪物没有 content_id「%s」" % monster.display_name)
		return
	_mark_seen(ContentKind.Kind.MONSTER, id)


func unlock_all() -> bool:
	var changed := _unlock_kind(ContentKind.Kind.MONSTER, _monsters)
	changed = _unlock_kind(ContentKind.Kind.SOUL, _souls) or changed
	return _unlock_kind(ContentKind.Kind.VESSEL, _vessels) or changed


func to_save_data() -> Dictionary:
	return {
		"monsters": _seen_ids(ContentKind.Kind.MONSTER),
		"souls": _seen_ids(ContentKind.Kind.SOUL),
		"vessels": _seen_ids(ContentKind.Kind.VESSEL),
	}


func apply_save_data(data: Dictionary) -> void:
	_reset_seen()
	var monsters: Variant = data.get("monsters", [])
	if monsters is Array:
		for id in monsters:
			_seen[ContentKind.Kind.MONSTER][StringName(String(id))] = true
	var souls: Variant = data.get("souls", [])
	if souls is Array:
		for id in souls:
			_seen[ContentKind.Kind.SOUL][StringName(String(id))] = true
	var vessels: Variant = data.get("vessels", [])
	if vessels is Array:
		for id in vessels:
			_seen[ContentKind.Kind.VESSEL][StringName(String(id))] = true
	state_reloaded.emit()


func _reset_seen() -> void:
	_seen = {
		ContentKind.Kind.MONSTER: {},
		ContentKind.Kind.SOUL: {},
		ContentKind.Kind.VESSEL: {},
	}


func _load_catalog() -> void:
	for entry in ModLoader.get_soul_entries():
		var soul := entry.resource as SoulData
		if soul == null:
			push_warning("见闻：魂灵加载失败 %s" % entry.content_id)
			continue
		soul.content_id = entry.content_id
		_register_soul(entry.content_id, soul)

	for entry in ModLoader.get_monster_entries():
		var monster := entry.resource as MonsterData
		if monster == null:
			push_warning("见闻：怪物加载失败 %s" % entry.content_id)
			continue
		monster.content_id = entry.content_id
		_monsters[entry.content_id] = monster

	for entry in ModLoader.get_vessel_entries():
		var vessel := entry.resource as SoulVesselData
		if vessel == null:
			push_warning("见闻：魂器加载失败 %s" % entry.content_id)
			continue
		vessel.content_id = entry.content_id
		_vessels[entry.content_id] = vessel

	if _souls.is_empty() or _monsters.is_empty():
		push_warning("见闻：内容目录为空，检查内置 core mod 是否加载成功")
	_warn_duplicate_skill_ids()


func _register_soul(id: StringName, soul: SoulData) -> void:
	if _souls.has(id):
		push_warning("见闻：魂灵 ID 重复，已跳过 %s" % id)
		return
	_souls[id] = soul


func _warn_duplicate_skill_ids() -> void:
	var skill_sources: Dictionary[StringName, String] = {}
	for soul: SoulData in _souls.values():
		if soul == null or soul.skill == null or soul.skill.id.is_empty():
			continue
		var skill_id := StringName(soul.skill.id)
		var source: String = soul.skill.resource_path
		if source.is_empty():
			source = str(soul.skill.get_instance_id())
		if skill_sources.has(skill_id) and skill_sources[skill_id] != source:
			ModLoader.report_warning("技能 ID 重复「%s」（%s / %s）" % [
				skill_id,
				skill_sources[skill_id],
				source,
			])
			continue
		skill_sources[skill_id] = source


func _unlock_kind(kind: int, catalog: Dictionary) -> bool:
	var changed := false
	for id: StringName in catalog:
		if _seen.get(kind, {}).has(id):
			continue
		_mark_seen(kind, id)
		changed = true
	return changed


func _mark_seen(kind: int, id: StringName) -> void:
	if not _seen.has(kind):
		_seen[kind] = {}
	var seen: Dictionary = _seen[kind]
	if seen.has(id):
		return
	seen[id] = true
	entry_unlocked.emit(kind, id)


func _on_inv_item_added(_inv_name: String, item_data: ItemData, _grids: Array[Vector2i]) -> void:
	_scan_owned_item(item_data)


func _scan_owned_souls_after_ready() -> void:
	await get_tree().process_frame
	_scan_owned_souls()


func _scan_owned_souls() -> void:
	for inv_name in GBIS.inventory_names:
		var container := ContainerRepository.instance.get_container(inv_name)
		if container == null:
			continue
		for item in container.items:
			_scan_owned_item(item)


func _scan_owned_item(item: ItemData) -> void:
	if item is SoulData:
		mark_soul_seen(item as SoulData)
	elif item is SoulVesselData:
		var vessel := item as SoulVesselData
		mark_vessel_seen(vessel)
		for inner in vessel.ensure_contents().items:
			_scan_owned_item(inner)


func _seen_ids(kind: int) -> Array[String]:
	var ids: Array[String] = []
	var seen: Dictionary = _seen.get(kind, {})
	for id: StringName in seen:
		ids.append(String(id))
	ids.sort()
	return ids
