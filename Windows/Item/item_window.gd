class_name ItemWindow
extends Control


static var instance : ItemWindow

var _grab_offset : Vector2 = Vector2.ZERO
var _view : ItemView
var _last_size : Vector2i = Vector2i.ZERO


func _ready() -> void:
	instance = self
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hold(view: ItemView, grab_offset_cells: Vector2i, base_size: int) -> void:
	clear()
	_view = view
	add_child(view)
	_set_mouse_ignore(view)
	view.position = Vector2.ZERO
	_grab_offset = Vector2(
		base_size * grab_offset_cells.x + base_size / 2.0,
		base_size * grab_offset_cells.y + base_size / 2.0
	)
	_sync_size()
	visible = true
	_reposition()


func clear() -> void:
	for child in get_children():
		child.queue_free()
	_view = null
	_last_size = Vector2i.ZERO
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	_sync_size()
	_reposition()


func _sync_size() -> void:
	if _view == null or not is_instance_valid(_view):
		return
	var want := Vector2i(_view.size)
	if want != _last_size and want.x > 0 and want.y > 0:
		_last_size = want
		size = Vector2(want)


func _reposition() -> void:
	position = get_viewport().get_mouse_position() - _grab_offset


func _set_mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore(child)
