class_name SaveParticipant extends RefCounted


func collect_into(_document: Dictionary) -> void:
	pass


func apply_from(_document: Dictionary, _has_disk_data: bool) -> bool:
	return false


func finish_load() -> bool:
	return false
