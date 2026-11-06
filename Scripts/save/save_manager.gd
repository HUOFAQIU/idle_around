extends Node
## 存档管理（Autoload：SaveManager）。
##
## 单槽 JSON 存档，路径 `user://saves/slot_0.json`。
## 只保存玩家进度：容器里的物品 + 见闻；战斗运行期状态和静态资源数据不存。
## 写入采用临时文件 + 备份轮换；启动等一帧（容器注册完）后自动读档。

const SAVE_DIR: String = "user://saves"
const SAVE_FILE: String = "slot_0.json"
const SAVE_PATH: String = SAVE_DIR + "/" + SAVE_FILE
const BACKUP_FILE: String = SAVE_FILE + ".bak"
const TEMP_FILE: String = SAVE_FILE + ".tmp"
const TEMP_PATH: String = SAVE_DIR + "/" + TEMP_FILE
const BACKUP_PATH: String = SAVE_DIR + "/" + BACKUP_FILE
const SAVE_VERSION: int = 1
## 普通物品变化后延迟写盘，避免战斗掉落逐次写文件
const DEBOUNCE_SECONDS: float = 2.0
## 没有变化时也定期写一次，刷新 saved_at / play_time
const HEARTBEAT_SECONDS: float = 30.0

var _dirty: bool = false
var _urgent: bool = false
var _loading: bool = false
var _since_save: float = 0.0
var _play_time_sec: float = 0.0
## 从备份恢复后的第一次写盘不要覆盖那份备份
var _keep_backup_next_save: bool = false
## 读到未来版本的存档时只读，避免旧客户端覆盖新数据
var _read_only: bool = false
## 因 mod 缺失/容器满而暂时放不进世界的物品记录；写档时原样保留
var _orphaned_records: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_signals()
	# 仓库页由 Warehouse autoload 预注册，其余容器由 InventoryView._ready() 注册；等一帧再读档
	await get_tree().process_frame
	# --script/工具模式没有主场景，装备槽等容器不会注册；
	# 这时读档会跳过找不到的容器，若随后自动写档会丢物品，所以直接不读也不写。
	if get_tree().current_scene == null:
		_read_only = true
		set_process(false)
		return
	load_game()


func _process(delta: float) -> void:
	_play_time_sec += delta
	if _loading or _read_only:
		return
	_since_save += delta
	if _dirty and (_urgent or _since_save >= DEBOUNCE_SECONDS):
		save_now()
	elif _since_save >= HEARTBEAT_SECONDS:
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()


#region 公共接口
## 立即写档；失败时保留脏标记，下个去抖周期重试
func save_now() -> bool:
	_since_save = 0.0
	_urgent = false
	if _loading or _read_only:
		return false
	if not _containers_ready():
		push_error("存档：容器尚未注册，不能写档")
		return false
	var keep_backup := _keep_backup_next_save
	var ok := _write_save_file(collect_save_data(), keep_backup)
	if ok:
		_keep_backup_next_save = false
		_dirty = false
	return ok


## 从磁盘读档并重建容器；返回是否成功
func load_game() -> bool:
	if _loading:
		return false
	if not _containers_ready():
		push_error("存档：容器尚未注册，不能读档")
		return false
	if GBIS.has_moving_item():
		push_warning("存档：正在拖拽物品，先放下再读档")
		return false

	_keep_backup_next_save = false
	var data := _read_save_file(SAVE_PATH)
	var write_back := false
	if data.is_empty():
		data = _read_save_file(BACKUP_PATH)
		if not data.is_empty():
			push_warning("存档：主文件不可用，已回退到备份")
			write_back = true
			_keep_backup_next_save = true
	var has_disk_data := not data.is_empty()
	_read_only = false
	if has_disk_data:
		var version := int(data.get("version", 0))
		if version > SAVE_VERSION:
			push_warning("存档：版本 %d 高于当前 %d，只读不覆盖" % [version, SAVE_VERSION])
			_read_only = true
		elif version != SAVE_VERSION:
			data = _migrate(data, version)
			write_back = true
	else:
		data = _empty_save_data()
		write_back = true

	_loading = true
	_dirty = false
	_urgent = false
	_orphaned_records = _read_orphaned_records(data)
	var restore_count := _orphaned_records.size()
	_clear_containers()
	_apply_containers(data)
	var collection_data: Variant = data.get("collection")
	if has_disk_data and collection_data is Dictionary:
		CollectionDB.apply_save_data(collection_data)
	elif CollectionDB.load_legacy_state():
		push_warning("存档：已从旧 collection.cfg 迁移见闻记录")
		write_back = true
	else:
		CollectionDB.apply_save_data({})
	_restore_orphaned_records(restore_count)
	_play_time_sec = float(data.get("play_time_sec", 0.0))
	_loading = false
	_since_save = 0.0
	# 一次性让所有 InventoryView 重建，避免逐件信号
	GBIS.sig_inv_refresh.emit()
	if write_back:
		save_now()
	return true


## 当前内存状态的存档快照（不写盘）
func collect_save_data() -> Dictionary:
	var containers := {}
	for inv_name in GBIS.inventory_names:
		var container := ContainerRepository.instance.get_container(inv_name)
		if container == null:
			continue
		var records := SaveCodec.encode_container(container)
		if not records.is_empty():
			containers[inv_name] = records
	var detached: Array = []
	if GBIS.has_moving_item():
		var record := SaveCodec.encode_item(GBIS.moving_item_service.moving_item)
		if not record.is_empty():
			detached.append(record)
	var data := {
		"version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"play_time_sec": _play_time_sec,
		"containers": containers,
		"detached": detached,
		"collection": CollectionDB.to_save_data(),
	}
	if not _orphaned_records.is_empty():
		var orphaned: Array = []
		for entry in _orphaned_records:
			orphaned.append(entry.duplicate(true))
		data["orphaned"] = orphaned
	return data


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


## 当前存档里因 mod 缺失/放不下而保留的原始记录
func get_orphaned_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _orphaned_records:
		result.append(entry.duplicate(true))
	return result


func get_save_path() -> String:
	return SAVE_PATH


## 只删除磁盘文件，不改变当前内存状态
func delete_save() -> bool:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return true
	var ok := true
	for file_name in [SAVE_FILE, BACKUP_FILE, TEMP_FILE]:
		if dir.file_exists(file_name) and dir.remove(file_name) != OK:
			ok = false
	return ok


## 外部系统（见闻、未来的 progression）在状态变化时调用
func mark_dirty(urgent: bool = false) -> void:
	if _loading or _read_only:
		return
	_dirty = true
	_urgent = _urgent or urgent
#endregion


#region 内部：容器
func _containers_ready() -> bool:
	return not GBIS.inventory_names.is_empty()


func _clear_containers() -> void:
	for inv_name in GBIS.inventory_names:
		var container := ContainerRepository.instance.get_container(inv_name)
		if container != null:
			container.clear()


func _apply_containers(data: Dictionary) -> void:
	var containers_data: Variant = data.get("containers", {})
	if containers_data is Dictionary:
		for key in containers_data:
			var container_name := String(key)
			var container := ContainerRepository.instance.get_container(container_name)
			if container == null:
				push_warning("存档：容器不存在 %s，已跳过" % container_name)
				continue
			var records: Variant = containers_data[key]
			if not records is Array:
				push_warning("存档：%s 的数据格式不对" % container_name)
				continue
			_apply_container(container, records)
	var detached: Variant = data.get("detached", [])
	if detached is Array:
		for record in detached:
			if not record is Dictionary:
				continue
			var record_data := record as Dictionary
			var item := SaveCodec.decode_item(record_data)
			if item == null:
				_orphaned_records.append(_make_orphaned_entry("", record_data))
				continue
			if not Warehouse.add_item(item):
				_orphaned_records.append(_make_orphaned_entry("", record_data))
				push_warning("存档：拖拽中的物品无法放回仓库，已保留到 orphaned")


func _apply_container(container: ContainerData, records: Array) -> void:
	records.sort_custom(SaveCodec.sort_records)
	for record in records:
		if not record is Dictionary:
			continue
		var record_data := record as Dictionary
		var item := SaveCodec.decode_item(record_data)
		if item == null:
			_orphaned_records.append(_make_orphaned_entry(container.container_name, record_data))
			continue
		var anchor := SaveCodec.anchor_from_record(record_data)
		if not container.try_add_to_grid(item, anchor).is_empty():
			continue
		if not container.add_item(item).is_empty():
			push_warning("存档：%s 的「%s」无法放回原格 %s，已放到第一个空位" % [container.container_name, item.item_name, anchor])
			continue
		if Warehouse.add_item(item):
			push_warning("存档：%s 的「%s」放不下，已转入仓库" % [container.container_name, item.item_name])
			continue
		_orphaned_records.append(_make_orphaned_entry(container.container_name, record_data))
		push_warning("存档：物品无处安放，已保留到 orphaned：%s" % item.item_name)


## 构造一条保留记录；container 为空表示原本在鼠标上
func _make_orphaned_entry(container_name: String, record: Dictionary) -> Dictionary:
	return {
		"container": container_name,
		"record": record.duplicate(true),
	}


func _read_orphaned_records(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = data.get("orphaned", [])
	if not raw is Array:
		return result
	for entry in raw:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


## 读档末尾再试一次存档里带回来的保留物品；本次新产生的保留记录不重复尝试
func _restore_orphaned_records(restore_count: int) -> void:
	var remaining: Array[Dictionary] = []
	var index := 0
	for entry in _orphaned_records:
		if index >= restore_count:
			remaining.append(entry)
			index += 1
			continue
		index += 1
		var record: Variant = entry.get("record", {})
		if not record is Dictionary:
			remaining.append(entry)
			continue
		var record_data := record as Dictionary
		var item := SaveCodec.decode_item(record_data)
		if item == null:
			remaining.append(entry)
			continue
		var container_name := String(entry.get("container", ""))
		if _try_restore_item(item, record_data, container_name):
			continue
		remaining.append(entry)
	_orphaned_records = remaining


func _try_restore_item(item: ItemData, record: Dictionary, container_name: String) -> bool:
	if not container_name.is_empty():
		var container := ContainerRepository.instance.get_container(container_name)
		if container != null:
			var anchor := SaveCodec.anchor_from_record(record)
			if not container.try_add_to_grid(item, anchor).is_empty():
				return true
			if not container.add_item(item).is_empty():
				push_warning("存档：缺失内容「%s」已恢复到 %s 的空位" % [item.item_name, container_name])
				return true
	if Warehouse.add_item(item):
		push_warning("存档：缺失内容「%s」已放回仓库" % item.item_name)
		return true
	return false
#endregion


#region 内部：信号
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


#region 内部：文件
func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("存档：无法读取 %s（%s）" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("存档：%s JSON 解析失败" % path)
		return {}
	var data := parsed as Dictionary
	if int(data.get("version", 0)) <= 0:
		push_warning("存档：%s 缺少版本号" % path)
		return {}
	return data


func _write_save_file(data: Dictionary, keep_backup: bool = false) -> bool:
	if not _ensure_save_dir():
		return false
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("存档：无法写入临时文件 %s（%s）" % [TEMP_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		push_warning("存档：无法打开目录 %s" % SAVE_DIR)
		return false
	if dir.file_exists(SAVE_FILE):
		if keep_backup:
			# 主文件已经损坏；只替换主文件，保留刚恢复用的好备份
			var remove_err := dir.remove(SAVE_FILE)
			if remove_err != OK:
				push_warning("存档：无法移除损坏的主存档（%s）" % error_string(remove_err))
				dir.remove(TEMP_FILE)
				return false
		else:
			if dir.file_exists(BACKUP_FILE):
				dir.remove(BACKUP_FILE)
			var rotate_err := dir.rename(SAVE_FILE, BACKUP_FILE)
			if rotate_err != OK:
				push_warning("存档：无法轮换旧存档（%s）" % error_string(rotate_err))
				dir.remove(TEMP_FILE)
				return false
	var rename_err := dir.rename(TEMP_FILE, SAVE_FILE)
	if rename_err != OK:
		push_warning("存档：无法写入正式存档（%s）" % error_string(rename_err))
		if not keep_backup and dir.file_exists(BACKUP_FILE):
			dir.rename(BACKUP_FILE, SAVE_FILE)
		return false
	return true


func _ensure_save_dir() -> bool:
	var absolute := ProjectSettings.globalize_path(SAVE_DIR)
	if DirAccess.dir_exists_absolute(absolute):
		return true
	var err := DirAccess.make_dir_recursive_absolute(absolute)
	if err != OK:
		push_warning("存档：无法创建目录 %s（%s）" % [SAVE_DIR, error_string(err)])
		return false
	return true


func _empty_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"play_time_sec": 0.0,
		"containers": {},
		"detached": [],
		"collection": {"souls": [], "monsters": []},
	}


func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version <= 0:
		push_warning("存档：旧格式没有版本号，按当前版本读取")
	# 目前只有 v1；以后在这里按版本逐级迁移
	data["version"] = SAVE_VERSION
	return data
#endregion
