## 测试用内存 adapter：与 DiskSaveStorage 同接口，不落盘。
class_name MemorySaveStorage
extends SaveStorage

var _primary: Dictionary = {}
var _backup: Dictionary = {}


## 预置槽内容，用于构造「只有备份可用」「版本过高」等场景
func seed(slot: int, primary: Dictionary, backup: Dictionary = {}) -> void:
	if not SaveStorage.is_valid_slot(slot):
		return
	_primary[slot] = primary.duplicate(true)
	if backup.is_empty():
		_backup.erase(slot)
	else:
		_backup[slot] = backup.duplicate(true)


func read_primary(slot: int) -> Dictionary:
	if not _primary.has(slot):
		return {}
	return (_primary[slot] as Dictionary).duplicate(true)


func read_backup(slot: int) -> Dictionary:
	if not _backup.has(slot):
		return {}
	return (_backup[slot] as Dictionary).duplicate(true)


func write(slot: int, data: Dictionary, keep_backup: bool = false) -> bool:
	if not SaveStorage.is_valid_slot(slot):
		return false
	if not keep_backup and _primary.has(slot):
		_backup[slot] = (_primary[slot] as Dictionary).duplicate(true)
	_primary[slot] = data.duplicate(true)
	return true


func delete(slot: int) -> bool:
	if not SaveStorage.is_valid_slot(slot):
		return false
	_primary.erase(slot)
	_backup.erase(slot)
	return true


func has_save(slot: int) -> bool:
	return _primary.has(slot) or _backup.has(slot)


func path(slot: int) -> String:
	return "memory://slot_%d.json" % slot
