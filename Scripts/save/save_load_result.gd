## SavePipeline.load() 的结果；EMPTY 表示该槽没有可用数据。
class_name SaveLoadResult
extends RefCounted

enum Status {
	LOADED,
	EMPTY,
}

var status: Status = Status.EMPTY
var data: Dictionary = {}
var write_back: bool = false
var keep_backup: bool = false
var read_only: bool = false


func _init(
		p_status: Status,
		p_data: Dictionary = {},
		p_write_back: bool = false,
		p_keep_backup: bool = false,
		p_read_only: bool = false,
) -> void:
	status = p_status
	data = p_data
	write_back = p_write_back
	keep_backup = p_keep_backup
	read_only = p_read_only


static func empty() -> SaveLoadResult:
	return SaveLoadResult.new(Status.EMPTY)


static func loaded(
		p_data: Dictionary,
		p_write_back: bool,
		p_keep_backup: bool,
		p_read_only: bool,
) -> SaveLoadResult:
	return SaveLoadResult.new(Status.LOADED, p_data, p_write_back, p_keep_backup, p_read_only)
