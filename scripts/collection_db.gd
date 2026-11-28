extends Node

signal entry_unlocked(kind: int, id: StringName)
signal state_reloaded

const STARTUP_TIMING: GDScript = preload("res://scripts/debug/startup_timing.gd")

var unlock_all_for_testing: bool = false

var _seen: Dictionary = {}


func _ready() -> void:
	STARTUP_TIMING.mark("主场景加载编译与前置 autoload 完成")
	_reset_seen()
	GBIS.sig_inv_item_added.connect(_on_inv_item_added)
	GBIS.sig_inv_refresh.connect(_scan_owned_souls)
	@warning_ignore("missing_await")
	_scan_owned_souls_after_ready()


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
	var changed := _unlock_kind(ContentKind.Kind.MONSTER, ModLoader.get_monster_ids())
	changed = _unlock_kind(ContentKind.Kind.SOUL, ModLoader.get_soul_ids()) or changed
	return _unlock_kind(ContentKind.Kind.VESSEL, ModLoader.get_vessel_ids()) or changed


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


func _unlock_kind(kind: int, ids: Array[StringName]) -> bool:
	var changed := false
	for id: StringName in ids:
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
