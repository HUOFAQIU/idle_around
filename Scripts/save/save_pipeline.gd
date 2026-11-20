## 存档管线：文档收集、版本/主备策略与 participant 顺序。
##
## 不认识 autoload、UI 和磁盘；storage 决定数据落点（磁盘或内存），
## 这样整条读写策略可以在没有真实存档、没有启动链的情况下验证。
class_name SavePipeline
extends RefCounted

var _storage: SaveStorage
var _participants: Array[SaveParticipant] = []


func _init(storage: SaveStorage, participants: Array[SaveParticipant] = []) -> void:
	_storage = storage
	for participant in participants:
		_participants.append(participant)


## 当前内存状态的存档文档（不写盘）
func collect(play_time_sec: float, player_data: Dictionary = {}) -> Dictionary:
	var document := SaveDocument.build(play_time_sec, player_data)
	for participant in _participants:
		participant.collect_into(document)
	return document


## 把文档应用到各 participant；返回是否有 participant 报告需要回写
func apply(document: Dictionary, has_disk_data: bool) -> bool:
	var write_back := false
	for participant in _participants:
		if participant.apply_from(document, has_disk_data):
			write_back = true
	for participant in _participants:
		if participant.finish_load():
			write_back = true
	return write_back


## 写档；返回 false 表示槽位非法或底层写入失败
func save(
		slot: int,
		play_time_sec: float,
		player_data: Dictionary = {},
		keep_backup: bool = false,
) -> bool:
	if not SaveStorage.is_valid_slot(slot):
		return false
	return _storage.write(slot, collect(play_time_sec, player_data), keep_backup)


## 新建档并写盘；成功返回写下的文档，失败返回空字典
func create(slot: int, player_data: Dictionary) -> Dictionary:
	if not SaveStorage.is_valid_slot(slot):
		return {}
	var document := SaveDocument.build(0.0, player_data)
	if not _storage.write(slot, document):
		return {}
	return document


## 读槽：主文件不可用时回退备份，按版本决定迁移或只读
func load(slot: int) -> SaveLoadResult:
	if not SaveStorage.is_valid_slot(slot):
		return SaveLoadResult.empty()
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
		return SaveLoadResult.empty()
	var version := SaveDocument.version_of(data)
	if version <= 0:
		push_warning("存档：槽 %d 缺少版本号" % (slot + 1))
		return SaveLoadResult.empty()
	var read_only := false
	if version > SaveDocument.VERSION:
		push_warning("存档：版本 %d 高于当前 %d，只读不覆盖" % [version, SaveDocument.VERSION])
		read_only = true
	elif version != SaveDocument.VERSION:
		data = SaveDocument.migrate(data, version)
		write_back = true
	return SaveLoadResult.loaded(data, write_back, keep_backup, read_only)


func delete(slot: int) -> bool:
	return _storage.delete(slot)


func has_save(slot: int) -> bool:
	return _storage.has_save(slot)


func path(slot: int) -> String:
	return _storage.path(slot)


func set_read_only(on: bool) -> void:
	_storage.set_read_only(on)


func is_read_only() -> bool:
	return _storage.is_read_only()


## 六个槽的摘要：slot / occupied / player / saved_at / play_time
func summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in SaveStorage.SLOT_COUNT:
		result.append(_make_summary(slot, _read_slot_data(slot)))
	return result


func _read_slot_data(slot: int) -> Dictionary:
	var data := _storage.read_primary(slot)
	if data.is_empty():
		data = _storage.read_backup(slot)
	if SaveDocument.version_of(data) <= 0:
		return {}
	return data


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
