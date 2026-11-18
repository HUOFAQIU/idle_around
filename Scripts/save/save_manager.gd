extends Node
## 存档管理（Autoload：SaveManager）。
##
## 六槽 JSON 存档门面：顶层文档见 SaveDocument，文件读写见 SaveStorage，
## 去抖/心跳见 SaveScheduler，容器与见闻各是一个 SaveParticipant。
## 只保存玩家进度：容器里的物品、见闻和角色身份；战斗运行期状态和静态资源数据不存。
## 启动只扫描槽位摘要，不自动读档；没有活动槽时不累计时长、不写盘。

signal slot_list_changed
signal slot_loaded(slot: int)
signal slot_saved(slot: int)
signal active_slot_changed(slot: int)

const SLOT_COUNT: int = SaveStorage.SLOT_COUNT

var _storage := SaveStorage.new()
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
## 从备份恢复后的第一次写盘不要覆盖那份备份
var _keep_backup_next_save: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_participants.append(_containers)
	_participants.append(_collection)
	_participants.append(_map_board)
	_connect_signals()
	refresh_slot_summaries()
	# 仓库页由 Warehouse autoload 预注册，魂器网格由 CharacterWindow 里的 InventoryView._ready() 注册；
	# 等一帧确认容器齐全，但不自动读档。
	await get_tree().process_frame
	# --script/工具模式没有主场景，容器不会注册；不读也不写，避免写档时丢掉未恢复的容器。
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
	if _loading or _storage.is_read_only():
		return
	if _scheduler.tick(delta):
		save_now()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST and what != NOTIFICATION_APPLICATION_PAUSED:
		return
	if _active_slot >= 0:
		save_now()


#region 公共接口
## 立即写当前槽；没有活动槽、只读或容器未注册时返回 false
func save_now() -> bool:
	if _active_slot < 0:
		return false
	_scheduler.begin_save()
	if _loading or _storage.is_read_only():
		return false
	if not _containers.containers_ready():
		push_error("存档：容器尚未注册，不能写档")
		return false
	var keep_backup := _keep_backup_next_save
	var ok := _storage.write(_active_slot, collect_save_data(), keep_backup)
	if ok:
		_keep_backup_next_save = false
		_scheduler.on_saved()
		slot_saved.emit(_active_slot)
		refresh_slot_summaries()
	return ok


## 读取指定槽并重建容器；空槽返回 false，不创建新档
func load_slot(slot: int) -> bool:
	if _loading or not SaveStorage.is_valid_slot(slot):
		return false
	if not _containers.containers_ready():
		push_error("存档：容器尚未注册，不能读档")
		return false
	if GBIS.has_moving_item():
		push_warning("存档：正在拖拽物品，先放下再读档")
		return false

	var data := _storage.read_primary(slot)
	var write_back := false
	var keep_backup := false
	if data.is_empty():
		data = _storage.read_backup(slot)
		if not data.is_empty():
			push_warning("存档：槽 %d 主文件不可用，已回退到备份" % (slot + 1))
			write_back = true
			keep_backup = true
	if data.is_empty():
		return false

	var version := SaveDocument.version_of(data)
	var read_only := false
	if version > SaveDocument.VERSION:
		push_warning("存档：版本 %d 高于当前 %d，只读不覆盖" % [version, SaveDocument.VERSION])
		read_only = true
	elif version != SaveDocument.VERSION:
		data = SaveDocument.migrate(data, version)
		write_back = true

	_keep_backup_next_save = keep_backup
	write_back = _apply_data(data, true, slot, read_only) or write_back
	if write_back and not read_only:
		save_now()
	slot_loaded.emit(slot)
	return true


## 在指定空槽创建新档并设为活动槽；player_data = {character_id, display_name}
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
	# 文件存在但解析失败：按空槽处理；写盘会把旧主文件轮换成 .bak
	if _storage.has_save(slot):
		push_warning("存档：槽 %d 文件不可读，按空槽覆盖" % (slot + 1))
	_keep_backup_next_save = false
	# 先写盘成功，再清空内存并切换活动槽；写失败时旧会话保持原样
	var document := SaveDocument.build(0.0, player_data)
	if not _storage.write(slot, document):
		return false
	_apply_data(document, false, slot, false, player_data)
	slot_saved.emit(slot)
	slot_loaded.emit(slot)
	return true


## 当前内存状态的存档快照（不写盘）
func collect_save_data() -> Dictionary:
	var document := SaveDocument.build(_play_time_sec, _player_data)
	for participant in _participants:
		participant.collect_into(document)
	return document


## 六个槽的摘要：slot / occupied / player / saved_at / play_time
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


## 第一个空槽；全部占满返回 -1
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


## 当前存档里因 mod 缺失/放不下而保留的原始记录
func get_orphaned_records() -> Array[Dictionary]:
	return _containers.get_orphaned_records()


## 读档/写档是否可用；missing_containers 非空时只读
func get_save_status() -> Dictionary:
	return {
		"ready": _containers.containers_ready(),
		"read_only": _storage.is_read_only(),
		"missing_containers": _containers.missing_containers(),
		"active_slot": _active_slot,
	}


func get_save_path(slot: int) -> String:
	return _storage.path(slot)


## 删除磁盘文件；删的是活动槽时停止计时、清掉只读态并断开活动槽
func delete_slot(slot: int) -> bool:
	if not SaveStorage.is_valid_slot(slot):
		return false
	var ok := _storage.delete(slot)
	if not ok:
		return false
	if slot == _active_slot:
		_active_slot = -1
		_player_data = {}
		_play_time_sec = 0.0
		_keep_backup_next_save = false
		_scheduler.reset()
		_storage.set_read_only(false)
		active_slot_changed.emit(-1)
	refresh_slot_summaries()
	return true


## 外部系统（见闻、未来的 progression）在状态变化时调用
func mark_dirty(urgent: bool = false) -> void:
	if _active_slot < 0 or _loading or _storage.is_read_only():
		return
	_scheduler.mark_dirty(urgent)


## 重新扫描六个槽的摘要；槽位列表 UI 监听 slot_list_changed
func refresh_slot_summaries() -> void:
	var summaries: Array[Dictionary] = []
	for slot in SLOT_COUNT:
		var data := _storage.read_primary(slot)
		if data.is_empty():
			data = _storage.read_backup(slot)
		summaries.append(_make_summary(slot, data))
	_slot_summaries = summaries
	slot_list_changed.emit()
#endregion


#region 内部
## 应用一份文档到内存；返回 participant 是否报告需要回写
func _apply_data(
		data: Dictionary,
		has_disk_data: bool,
		slot: int,
		read_only: bool,
		player_override: Dictionary = {},
) -> bool:
	_loading = true
	_scheduler.reset()
	_storage.set_read_only(read_only)
	SoulRuntimeDB.clear()
	var write_back := false
	for participant in _participants:
		if participant.apply_from(data, has_disk_data):
			write_back = true
	for participant in _participants:
		if participant.finish_load():
			write_back = true
	_play_time_sec = float(data.get(SaveDocument.KEY_PLAY_TIME, 0.0))
	_player_data = (
		player_override.duplicate(true)
		if not player_override.is_empty()
		else SaveDocument.player_of(data)
	)
	_active_slot = slot
	_loading = false
	# 一次性让所有 InventoryView 重建，避免逐件信号
	GBIS.sig_inv_refresh.emit()
	active_slot_changed.emit(slot)
	refresh_slot_summaries()
	return write_back


func _make_summary(slot: int, data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {
			"slot": slot,
			"occupied": false,
			"player": {},
			"saved_at": 0,
			"play_time": 0.0,
		}
	return {
		"slot": slot,
		"occupied": true,
		"player": SaveDocument.player_of(data),
		"saved_at": int(data.get(SaveDocument.KEY_SAVED_AT, 0)),
		"play_time": float(data.get(SaveDocument.KEY_PLAY_TIME, 0.0)),
	}


## 进入只读：不读档也不写档，避免容器不齐时覆盖存档
func _enter_read_only(reason: String, report_error: bool) -> void:
	_storage.set_read_only(true)
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


## 见闻解锁不可再生，立即写盘
func _on_collection_unlocked(_kind: int, _id: StringName) -> void:
	mark_dirty(true)


func _on_map_board_changed() -> void:
	mark_dirty()
#endregion
