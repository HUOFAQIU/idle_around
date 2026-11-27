class_name SaveStorage
extends RefCounted

const SLOT_COUNT: int = 6

var _read_only: bool = false


static func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


func read_primary(_slot: int) -> Dictionary:
	return {}


func read_backup(_slot: int) -> Dictionary:
	return {}


func write(_slot: int, _data: Dictionary, _keep_backup: bool = false) -> bool:
	return false


func delete(_slot: int) -> bool:
	return false


func has_save(_slot: int) -> bool:
	return false


func path(_slot: int) -> String:
	return ""


func set_read_only(on: bool) -> void:
	_read_only = on


func is_read_only() -> bool:
	return _read_only
