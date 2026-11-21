class_name SaveScheduler extends RefCounted

const DEBOUNCE_SECONDS: float = 2.0
const HEARTBEAT_SECONDS: float = 30.0

var _dirty: bool = false
var _urgent: bool = false
var _since_save: float = 0.0


func mark_dirty(urgent: bool = false) -> void:
	_dirty = true
	_urgent = _urgent or urgent


func tick(delta: float, can_save: bool = true) -> bool:
	if not can_save:
		return false
	_since_save += delta
	if _dirty and (_urgent or _since_save >= DEBOUNCE_SECONDS):
		return true
	return _since_save >= HEARTBEAT_SECONDS


func begin_save() -> void:
	_since_save = 0.0
	_urgent = false


func on_saved() -> void:
	_dirty = false


func reset() -> void:
	_dirty = false
	_urgent = false
	_since_save = 0.0
