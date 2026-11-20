## 存档槽的存储接口：磁盘与内存两种 adapter 共用的 seam。
##
## 只负责按槽读/写/删，不解释业务 section，也不校验版本；
## 版本、备份回退和 participant 顺序属于 SavePipeline。
class_name SaveStorage
extends RefCounted

const SLOT_COUNT: int = 6

var _read_only: bool = false


static func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


## 主文件内容；不存在或不可解析时返回空字典
func read_primary(_slot: int) -> Dictionary:
	return {}


## 备份文件内容；不存在或不可解析时返回空字典
func read_backup(_slot: int) -> Dictionary:
	return {}


## 写入主文件；keep_backup 为 true 时不轮换刚恢复用的备份
func write(_slot: int, _data: Dictionary, _keep_backup: bool = false) -> bool:
	return false


## 删除该槽的主文件与备份
func delete(_slot: int) -> bool:
	return false


func has_save(_slot: int) -> bool:
	return false


## 该槽主文件的可读路径；内存 adapter 返回 memory:// 形式
func path(_slot: int) -> String:
	return ""


func set_read_only(on: bool) -> void:
	_read_only = on


func is_read_only() -> bool:
	return _read_only
