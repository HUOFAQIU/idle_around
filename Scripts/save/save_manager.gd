extends Node
## 存档管理（Autoload：SaveManager）。
##
## 单槽 JSON 存档门面：顶层文档见 SaveDocument，文件读写见 SaveStorage，
## 去抖/心跳见 SaveScheduler，容器与见闻各是一个 SaveParticipant。
## 只保存玩家进度：容器里的物品 + 见闻；战斗运行期状态和静态资源数据不存。
## 写入采用临时文件 + 备份轮换；启动等一帧（容器注册完）后自动读档。

const SAVE_VERSION: int = SaveDocument.VERSION

var _storage := SaveStorage.new()
var _scheduler := SaveScheduler.new()
var _containers := ContainerSaveParticipant.new()
var _collection := CollectionSaveParticipant.new()
var _participants: Array[SaveParticipant] = []

var _loading: bool = false
var _play_time_sec: float = 0.0
## 从备份恢复后的第一次写盘不要覆盖那份备份
var _keep_backup_next_save: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_participants.append(_containers)
	_participants.append(_collection)
	_connect_signals()
	# 仓库页由 Warehouse autoload 预注册，魂器槽由 CharacterWindow 里的 InventoryView._ready() 注册；等一帧再读档
	await get_tree().process_frame
	# --script/工具模式没有主场景，容器不会注册；不读也不写，避免写档时丢掉未恢复的容器。
	if get_tree().current_scene == null:
		_enter_read_only("没有主场景（工具模式）", false)
		return
	var missing := _containers.missing_containers()
	if not missing.is_empty():
		_enter_read_only("容器未注册：%s" % ", ".join(PackedStringArray(missing)), true)
		return
	load_game()


func _process(delta: float) -> void:
	_play_time_sec += delta
	if _loading or _storage.is_read_only():
		return
	if _scheduler.tick(delta):
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()


#region 公共接口
## 立即写档；失败时保留脏标记，下个去抖周期重试
func save_now() -> bool:
	_scheduler.begin_save()
	if _loading or _storage.is_read_only():
		return false
	if not _containers.containers_ready():
		push_error("存档：容器尚未注册，不能写档")
		return false
	var keep_backup := _keep_backup_next_save
	var ok := _storage.write(collect_save_data(), keep_backup)
	if ok:
		_keep_backup_next_save = false
		_scheduler.on_saved()
	return ok


## 从磁盘读档并重建容器；返回是否成功
func load_game() -> bool:
	if _loading:
		return false
	if not _containers.containers_ready():
		push_error("存档：容器尚未注册，不能读档")
		return false
	if GBIS.has_moving_item():
		push_warning("存档：正在拖拽物品，先放下再读档")
		return false

	_keep_backup_next_save = false
	var data := _storage.read_primary()
	var write_back := false
	if data.is_empty():
		data = _storage.read_backup()
		if not data.is_empty():
			push_warning("存档：主文件不可用，已回退到备份")
			write_back = true
			_keep_backup_next_save = true
	var has_disk_data := not data.is_empty()
	_storage.set_read_only(false)
	if has_disk_data:
		var version := SaveDocument.version_of(data)
		if version > SaveDocument.VERSION:
			push_warning("存档：版本 %d 高于当前 %d，只读不覆盖" % [version, SaveDocument.VERSION])
			_storage.set_read_only(true, "存档版本过高")
		elif version != SaveDocument.VERSION:
			data = SaveDocument.migrate(data, version)
			write_back = true
	else:
		data = SaveDocument.empty()
		write_back = true

	_loading = true
	_scheduler.reset()
	for participant in _participants:
		if participant.apply_from(data, has_disk_data):
			write_back = true
	for participant in _participants:
		if participant.finish_load():
			write_back = true
	_play_time_sec = float(data.get(SaveDocument.KEY_PLAY_TIME, 0.0))
	_loading = false
	# 一次性让所有 InventoryView 重建，避免逐件信号
	GBIS.sig_inv_refresh.emit()
	if write_back:
		save_now()
	return true


## 当前内存状态的存档快照（不写盘）
func collect_save_data() -> Dictionary:
	var document := SaveDocument.build(_play_time_sec)
	for participant in _participants:
		participant.collect_into(document)
	return document


func has_save() -> bool:
	return _storage.has_save()


## 当前存档里因 mod 缺失/放不下而保留的原始记录
func get_orphaned_records() -> Array[Dictionary]:
	return _containers.get_orphaned_records()


## 读档/写档是否可用；missing_containers 非空时只读
func get_save_status() -> Dictionary:
	return {
		"ready": _containers.containers_ready(),
		"read_only": _storage.is_read_only(),
		"missing_containers": _containers.missing_containers(),
	}


func get_save_path() -> String:
	return _storage.path()


## 只删除磁盘文件，不改变当前内存状态
func delete_save() -> bool:
	return _storage.delete()


## 外部系统（见闻、未来的 progression）在状态变化时调用
func mark_dirty(urgent: bool = false) -> void:
	if _loading or _storage.is_read_only():
		return
	_scheduler.mark_dirty(urgent)
#endregion


#region 内部
## 进入只读：不读档也不写档，避免容器不齐时覆盖存档
func _enter_read_only(reason: String, report_error: bool) -> void:
	_storage.set_read_only(true, reason)
	set_process(false)
	if report_error:
		push_error("存档：%s；本次不读档也不写档" % reason)


func _connect_signals() -> void:
	GBIS.sig_inv_item_added.connect(_on_inv_item_added)
	GBIS.sig_inv_item_removed.connect(_on_inv_item_removed)
	GBIS.sig_inv_item_updated.connect(_on_inv_item_updated)
	GBIS.sig_inv_refresh.connect(_on_inv_refresh)
	CollectionDB.entry_unlocked.connect(_on_collection_unlocked)


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
#endregion
