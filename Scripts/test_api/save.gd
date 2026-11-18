extends RefCounted
## TestAPI 存档与开局域。
##
## 对外入口仍是 res://Scripts/test_api.gd 的 TestAPI。

static func save_now() -> bool:
	return SaveManager.save_now()


static func load_save_slot(slot: int) -> bool:
	return GameFlow.request_load_slot(slot)


static func load_save_slot_raw(slot: int) -> bool:
	return SaveManager.load_slot(slot)


static func new_game(character_id: StringName = &"small_coal_lamp") -> bool:
	GameFlow.request_new_game()
	if GameFlow.get_state() != GameFlow.State.CHARACTER_SELECT:
		return false
	return GameFlow.create_new_game(character_id)


static func delete_save_slot(slot: int) -> bool:
	return SaveManager.delete_slot(slot)


static func has_save() -> bool:
	return SaveManager.has_any_save()


static func get_save_slots() -> Array[Dictionary]:
	return GameFlow.get_slot_summaries()


static func get_active_slot() -> int:
	return SaveManager.get_active_slot()


static func get_game_flow_state() -> Dictionary:
	return GameFlow.get_state_snapshot()


static func get_save_path(slot: int) -> String:
	return SaveManager.get_save_path(slot)


static func get_save_status() -> Dictionary:
	return SaveManager.get_save_status()


static func dump_save() -> Dictionary:
	return SaveManager.collect_save_data()
