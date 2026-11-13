class_name ControlDrag
extends RefCounted
## 通用 Control 拖动：把 handle 上的左键拖动映射成 target.position 的位移。
##
## 用 process_frame 轮询鼠标，不依赖 handle 的 motion 事件：鼠标快速拖出
## 控件边缘时也能继续。target 必须不在 Container 的布局管理下，否则
## position 会被父容器覆盖。

signal drag_started
signal drag_ended

var _target : Control
var _handle : Control
var _bounds : Control
var _dragging : bool = false
var _start_mouse : Vector2 = Vector2.ZERO
var _start_position : Vector2 = Vector2.ZERO


## bounds 是可用区域，与 target 同一坐标系；为空时用主视口矩形。
func bind(target : Control, handle : Control, bounds : Control = null) -> void:
	if _dragging:
		_stop_drag()
	if _target != null and is_instance_valid(_target) and _target.tree_exiting.is_connected(_stop_drag):
		_target.tree_exiting.disconnect(_stop_drag)
	if _handle != null and is_instance_valid(_handle) and _handle.gui_input.is_connected(_on_handle_gui_input):
		_handle.gui_input.disconnect(_on_handle_gui_input)
	_target = target
	_handle = handle
	_bounds = bounds
	if _target != null:
		_target.tree_exiting.connect(_stop_drag)
	if _handle != null:
		_handle.gui_input.connect(_on_handle_gui_input)


func is_dragging() -> bool:
	return _dragging


func _on_handle_gui_input(event : InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_button.pressed:
		_start_drag()
		if _dragging:
			_handle.accept_event()
	elif _dragging:
		_stop_drag()


func _start_drag() -> void:
	if _dragging or _target == null or not _target.is_visible_in_tree():
		return
	_dragging = true
	_start_mouse = _target.get_global_mouse_position()
	_start_position = _target.position
	if not _target.get_tree().process_frame.is_connected(_update_drag):
		_target.get_tree().process_frame.connect(_update_drag)
	drag_started.emit()


func _update_drag() -> void:
	if not _dragging:
		_stop_drag()
		return
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		_stop_drag()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_drag()
		return
	var delta := _target.get_global_mouse_position() - _start_mouse
	_target.position = _clamp_position(_start_position + delta)


func _stop_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	if _target != null and is_instance_valid(_target):
		var tree := _target.get_tree()
		if tree != null and tree.process_frame.is_connected(_update_drag):
			tree.process_frame.disconnect(_update_drag)
	drag_ended.emit()


func _clamp_position(target_position : Vector2) -> Vector2:
	var area := _target.get_viewport_rect().size
	if _bounds != null and is_instance_valid(_bounds):
		area = _bounds.size
	return UiBounds.clamp_position(target_position, _target.size, area)
