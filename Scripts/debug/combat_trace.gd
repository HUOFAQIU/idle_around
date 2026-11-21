class_name CombatTrace extends RefCounted

static var _next_id: int = 1

var id: int = 0
var parent_id: int = 0
var root_id: int = 0
var cause: String = ""
var created_msec: int = 0


func _init(p_cause: String = "", parent: CombatTrace = null) -> void:
	id = _next_id
	_next_id += 1
	cause = p_cause
	created_msec = Time.get_ticks_msec()
	if parent != null:
		parent_id = parent.id
		root_id = parent.root_id
	else:
		root_id = id


func child(p_cause: String) -> CombatTrace:
	return CombatTrace.new(p_cause, self)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"parent_id": parent_id,
		"root_id": root_id,
		"cause": cause,
	}
