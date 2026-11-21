@tool
extends Control
class_name RefreshableView

var _dirty: bool = true
var _refresh_queued: bool = false


func mark_dirty() -> void:
	_dirty = true
	if not is_visible_in_tree() or _refresh_queued:
		return
	_refresh_queued = true
	_refresh_if_dirty.call_deferred()


func refresh() -> void:
	_dirty = false


func _on_shown_without_refresh() -> void:
	pass


func _sync_after_show() -> void:
	await get_tree().process_frame
	if not is_visible_in_tree():
		return
	if _dirty:
		refresh()
	else:
		_on_shown_without_refresh()


func _refresh_if_dirty() -> void:
	_refresh_queued = false
	if _dirty and is_visible_in_tree():
		refresh()
