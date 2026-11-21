class_name FakeSaveParticipant
extends SaveParticipant

const DEFAULT_KEY: String = "fake"

var key: String = DEFAULT_KEY
var value: Variant = null
var apply_write_back: bool = false
var finish_write_back: bool = false
var collect_count: int = 0
var apply_count: int = 0
var finish_count: int = 0
var last_document: Dictionary = {}
var last_has_disk_data: bool = false


func _init(p_key: String = DEFAULT_KEY, p_value: Variant = null) -> void:
	key = p_key
	value = p_value


func collect_into(document: Dictionary) -> void:
	collect_count += 1
	if value is Dictionary:
		document[key] = (value as Dictionary).duplicate(true)
	elif value is Array:
		document[key] = (value as Array).duplicate(true)
	else:
		document[key] = value


func apply_from(document: Dictionary, has_disk_data: bool) -> bool:
	apply_count += 1
	last_document = document.duplicate(true)
	last_has_disk_data = has_disk_data
	return apply_write_back


func finish_load() -> bool:
	finish_count += 1
	return finish_write_back
