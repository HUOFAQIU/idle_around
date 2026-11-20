extends RefCounted
## TestAPI 存档与开局域。
##
## 对外入口仍是 res://Scripts/test_api.gd 的 TestAPI。
## 自检用 preload 拿测试 adapter，避免额外依赖全局类缓存。

const MEMORY_SAVE_STORAGE: GDScript = preload("res://Scripts/save/testing/memory_save_storage.gd")
const FAKE_SAVE_PARTICIPANT: GDScript = preload("res://Scripts/save/testing/fake_save_participant.gd")
const SAVE_PIPELINE: GDScript = preload("res://Scripts/save/save_pipeline.gd")
const SAVE_LOAD_RESULT: GDScript = preload("res://Scripts/save/save_load_result.gd")


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


## 用内存 storage + fake participant 验证存档管线；不碰真实存档
static func check_save_pipeline() -> Dictionary:
	var storage: MemorySaveStorage = MEMORY_SAVE_STORAGE.new()
	var participant: FakeSaveParticipant = FAKE_SAVE_PARTICIPANT.new(
			"fake_section", {"amount": 7})
	var participants: Array[SaveParticipant] = [participant]
	var pipeline: SavePipeline = SAVE_PIPELINE.new(storage, participants)
	var checks: Array[Dictionary] = []

	var write_ok: bool = pipeline.save(0, 12.5, {"character_id": &"test", "display_name": "测试"})
	var saved: Dictionary = storage.read_primary(0)
	var saved_section: Dictionary = saved.get("fake_section", {})
	_check(checks, "写档", write_ok
			and int(saved.get(SaveDocument.KEY_VERSION, 0)) == SaveDocument.VERSION
			and int(saved_section.get("amount", 0)) == 7
			and participant.collect_count == 1,
			{"version": saved.get(SaveDocument.KEY_VERSION, 0)})

	var result: SaveLoadResult = pipeline.load(0)
	var applied: bool = pipeline.apply(result.data, true)
	var applied_section: Dictionary = participant.last_document.get("fake_section", {})
	_check(checks, "读档与 apply",
			result.status == SAVE_LOAD_RESULT.Status.LOADED
				and participant.apply_count == 1
				and participant.finish_count == 1
				and participant.last_has_disk_data
				and int(applied_section.get("amount", 0)) == 7
				and not applied,
			{"status": result.status})

	participant.finish_write_back = true
	var finish_write_back: bool = pipeline.apply(result.data, true)
	participant.finish_write_back = false
	_check(checks, "finish_load 回写",
			finish_write_back and participant.finish_count == 2)

	storage.seed(1, {}, SaveDocument.build(3.0, {"character_id": &"bak"}))
	var backup_result: SaveLoadResult = pipeline.load(1)
	_check(checks, "备份回退",
			backup_result.status == SAVE_LOAD_RESULT.Status.LOADED
				and backup_result.write_back
				and backup_result.keep_backup
				and not backup_result.read_only)

	var future := SaveDocument.build(0.0, {})
	future[SaveDocument.KEY_VERSION] = SaveDocument.VERSION + 1
	storage.seed(2, future)
	var future_result: SaveLoadResult = pipeline.load(2)
	_check(checks, "版本过高只读",
			future_result.status == SAVE_LOAD_RESULT.Status.LOADED
				and future_result.read_only
				and not future_result.write_back)

	storage.seed(3, {SaveDocument.KEY_VERSION: 1, SaveDocument.KEY_PLAY_TIME: 4.0})
	var migrated: SaveLoadResult = pipeline.load(3)
	var migrated_player: Dictionary = migrated.data.get(SaveDocument.KEY_PLAYER, {})
	_check(checks, "v1 迁移",
			migrated.status == SAVE_LOAD_RESULT.Status.LOADED
				and migrated.write_back
				and int(migrated.data.get(SaveDocument.KEY_VERSION, 0)) == SaveDocument.VERSION
				and not migrated_player.is_empty())

	var slot_flags := ""
	for summary in pipeline.summaries():
		slot_flags += "1" if bool(summary["occupied"]) else "0"
	_check(checks, "槽位摘要", slot_flags == "111100", slot_flags)

	var passed := true
	for check in checks:
		if not bool(check["passed"]):
			passed = false
	return {"ok": passed, "checks": checks}


static func _check(
		checks: Array[Dictionary],
		name: String,
		passed: bool,
		detail: Variant = "",
) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
