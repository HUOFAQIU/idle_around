extends RefCounted
## TestAPI 调试 / 遥测域。
##
## 对外入口仍是 res://Scripts/test_api.gd 的 TestAPI。

const COMMON: GDScript = preload("res://Scripts/test_api/common.gd")

static func get_debug_events(category : String = "", limit : int = 200) -> Array:
	var filter : Dictionary = {}
	if not category.is_empty():
		filter["category"] = category
	return CombatTelemetry.query(filter, limit)


static func get_debug_stats() -> Dictionary:
	return CombatTelemetry.get_stats()


static func get_debug_snapshot() -> Dictionary:
	return CombatSnapshot.build(CombatTelemetry.current_battle)


static func get_soul_runtime(soul_name : String, target : String = "player") -> Dictionary:
	var unit: BattleUnit = COMMON.find_unit(target)
	if unit == null:
		return {}
	for runtime in unit.loadout:
		if runtime != null and runtime.display_name() == soul_name:
			return CombatSnapshot.soul_runtime(runtime)
	return {}


static func get_trigger_state(soul_name : String, target : String = "player") -> Array:
	var unit: BattleUnit = COMMON.find_unit(target)
	if unit == null:
		return []
	var result : Array = []
	for trigger in CombatSnapshot.triggers(unit):
		if String(trigger.get("source", "")) == soul_name:
			result.append(trigger)
	return result


static func clear_debug_events() -> void:
	CombatTelemetry.clear()


static func export_debug_log(path : String = "user://debug/test.jsonl") -> String:
	return CombatTelemetry.export_jsonl(path)


static func set_debug_recording(enabled : bool) -> void:
	CombatTelemetry.set_enabled(enabled)


static func watch_unit_for_debug(target : String = "player") -> bool:
	var unit: BattleUnit = COMMON.find_unit(target)
	if unit == null:
		return false
	CombatTelemetry.watch_unit(unit)
	return true
