extends Node

signal slot_list_changed
signal slot_loaded(slot: int)
signal slot_saved(slot: int)
signal active_slot_changed(slot: int)

var _storage: SaveStorage = DiskSaveStorage.new()
var _pipeline: SavePipeline
var _scheduler := SaveScheduler.new()
var _containers := ContainerSaveParticipant.new()
var _collection := CollectionSaveParticipant.new()
var _map_board := MapBoardSaveParticipant.new()
var _participants: Array[SaveParticipant] = []

var _loading: bool = false
var _active_slot: int = -1
var _player_data: Dictionary = {}
var _play_time_sec: float = 0.0
var _slot_summaries: Array[Dictionary] = []
var _keep_backup_next_save: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_participants.append(_containers)
	_participants.append(_collection)
	_participants.append(_map_board)
	_pipeline = SavePipeline.new(_storage, _participants)
	_connect_signals()
	refresh_slot_summaries()
	await get_tree().process_frame
	if get_tree().current_scene == null:
		_enter_read_only("没有主场景（工具模式）", false)
		return
	var missing := _containers.missing_containers()
	if not missing.is_empty():
		_enter_read_only("容器未注册：%s" % ", ".join(PackedStringArray(missing)), true)


func _process(delta: float) -> void:
	if _active_slot < 0:
		return
	_play_time_sec += delta
	if _loading or _pipeline.is_read_only():
		return
	if _scheduler.tick(delta):
		save_now()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST and what != NOTIFICATION_APPLICATION_PAUSED:
		return
	if _active_slot >= 0:
		save_now()


func save_now() -> bool:
	if _active_slot < 0:
		return false
	_scheduler.begin_save()
	if _loading or _pipeline.is_read_only():
		return false
	if not _containers.containers_ready():
		push_error("存档：容器尚未注册，不能写档")
		return false
	var keep_backup := _keep_backup_next_save
	var ok := _pipeline.save(_active_slot, _play_time_sec, _player_data, keep_backup)
	if ok:
		_keep_backup_next_save = false
		_scheduler.on_saved()
		slot_saved.emit(_active_slot)
		refresh_slot_summaries()
	return ok


func load_slot(slot: int) -> bool:
	if _loading or not SaveStorage.is_valid_slot(slot):
		return false
	if not _containers.containers_ready():
		push_error("存档：容器尚未注册，不能读档")
		return false
	if GBIS.has_moving_item():
		push_warning("存档：正在拖拽物品，先放下再读档")
		return false

	var result := _pipeline.load(slot)
	if result.status == SaveLoadResult.Status.EMPTY:
		return false

	_keep_backup_next_save = result.keep_backup
	var write_back := _apply_data(result.data, true, slot, result.read_only) or result.write_back
	if write_back and not result.read_only:
		save_now()
	slot_loaded.emit(slot)
	return true


func create_new_game(slot: int, player_data: Dictionary) -> bool:
	if _loading or not SaveStorage.is_valid_slot(slot):
		return false
	if not _containers.containers_ready():
		push_error("存档：容器尚未注册，不能创建新档")
		return false
	if GBIS.has_moving_item():
		push_warning("存档：正在拖拽物品，先放下再创建新档")
		return false
	refresh_slot_summaries()
	if is_slot_occupied(slot):
		return false
	if _pipeline.has_save(slot):
		push_warning("存档：槽 %d 文件不可读，按空槽覆盖" % (slot + 1))
	_keep_backup_next_save = false
	var document := _pipeline.create(slot, player_data)
	if document.is_empty():
		return false
	_apply_data(document, false, slot, false, player_data)
	slot_saved.emit(slot)
	slot_loaded.emit(slot)
	return true


func collect_save_data() -> Dictionary:
	return _pipeline.collect(_play_time_sec, _player_data)


func get_slot_summaries() -> Array[Dictionary]:
	if _slot_summaries.is_empty():
		refresh_slot_summaries()
	var result: Array[Dictionary] = []
	for summary in _slot_summaries:
		result.append(summary.duplicate(true))
	return result


func get_slot_summary(slot: int) -> Dictionary:
	if not SaveStorage.is_valid_slot(slot):
		return {}
	if _slot_summaries.is_empty():
		refresh_slot_summaries()
	return _slot_summaries[slot].duplicate(true)


func first_empty_slot() -> int:
	if _slot_summaries.is_empty():
		refresh_slot_summaries()
	for summary in _slot_summaries:
		if not bool(summary["occupied"]):
			return int(summary["slot"])
	return -1


func is_slot_occupied(slot: int) -> bool:
	if not SaveStorage.is_valid_slot(slot):
		return false
	if _slot_summaries.is_empty():
		refresh_slot_summaries()
	return bool(_slot_summaries[slot]["occupied"])


func has_any_save() -> bool:
	if _slot_summaries.is_empty():
		refresh_slot_summaries()
	for summary in _slot_summaries:
		if bool(summary["occupied"]):
			return true
	return false


func get_active_slot() -> int:
	return _active_slot


func get_player_data() -> Dictionary:
	return _player_data.duplicate(true)


func get_orphaned_records() -> Array[Dictionary]:
	return _containers.get_orphaned_records()


func get_save_status() -> Dictionary:
	return {
		"ready": _containers.containers_ready(),
		"read_only": _pipeline.is_read_only(),
		"missing_containers": _containers.missing_containers(),
		"active_slot": _active_slot,
	}


func get_save_path(slot: int) -> String:
	return _pipeline.path(slot)


func delete_slot(slot: int) -> bool:
	if not SaveStorage.is_valid_slot(slot):
		return false
	var ok := _pipeline.delete(slot)
	if not ok:
		return false
	if slot == _active_slot:
		_active_slot = -1
		_player_data = {}
		_play_time_sec = 0.0
		_keep_backup_next_save = false
		_scheduler.reset()
		_pipeline.set_read_only(false)
		active_slot_changed.emit(-1)
	refresh_slot_summaries()
	return true


func mark_dirty(urgent: bool = false) -> void:
	if _active_slot < 0 or _loading or _pipeline.is_read_only():
		return
	_scheduler.mark_dirty(urgent)


func refresh_slot_summaries() -> void:
	_slot_summaries = _pipeline.summaries()
	slot_list_changed.emit()


func _apply_data(
		data: Dictionary,
		has_disk_data: bool,
		slot: int,
		read_only: bool,
		player_override: Dictionary = {},
) -> bool:
	_loading = true
	_scheduler.reset()
	_pipeline.set_read_only(read_only)
	SoulRuntimeDB.clear()
	var write_back := _pipeline.apply(data, has_disk_data)
	_play_time_sec = float(data.get(SaveDocument.KEY_PLAY_TIME, 0.0))
	_player_data = (
		player_override.duplicate(true)
		if not player_override.is_empty()
		else SaveDocument.player_of(data)
	)
	_active_slot = slot
	_loading = false
	GBIS.sig_inv_refresh.emit()
	active_slot_changed.emit(slot)
	refresh_slot_summaries()
	return write_back


func _enter_read_only(reason: String, report_error: bool) -> void:
	_pipeline.set_read_only(true)
	set_process(false)
	if report_error:
		push_error("存档：%s；本次不读档也不写档" % reason)


func _connect_signals() -> void:
	GBIS.sig_inv_item_added.connect(_on_inv_item_added)
	GBIS.sig_inv_item_removed.connect(_on_inv_item_removed)
	GBIS.sig_inv_item_updated.connect(_on_inv_item_updated)
	GBIS.sig_inv_refresh.connect(_on_inv_refresh)
	CollectionDB.entry_unlocked.connect(_on_collection_unlocked)
	MapBoard.board_changed.connect(_on_map_board_changed)


func _on_inv_item_added(_inv_name: String, _item_data: ItemData, _grids: Array[Vector2i]) -> void:
	mark_dirty()


func _on_inv_item_removed(_inv_name: String, _item_data: ItemData) -> void:
	mark_dirty()


func _on_inv_item_updated(_inv_name: String, _grid_id: Vector2i) -> void:
	mark_dirty()


func _on_inv_refresh() -> void:
	mark_dirty()


func _on_collection_unlocked(_kind: int, _id: StringName) -> void:
	mark_dirty(true)


func _on_map_board_changed() -> void:
	mark_dirty()
