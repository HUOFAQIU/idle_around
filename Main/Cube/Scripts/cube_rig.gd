class_name CubeRig
extends Node3D
## 立方体交互入口：处理鼠标射线、拖拽与点击分流，
## 并把指针事件转发给对应的面内 UI。
##
## 普通面沿用「按住可拖拽旋转、松手点击面内按钮」的分流；ui_capture 面
## （面 02 主菜单）按控件优先：指针下有可交互控件时，整个按下-拖动-松开
## 周期都交给面内容，不进入旋转。

signal face_identified(face_index: int, face_name: String, accent_color: Color)

const DRAG_THRESHOLD_PX := 7.0
const RAY_LENGTH := 50.0
const FACE_COLLISION_MASK := 1

@export var drag_handle_path: NodePath = ^"../DragHandle/Dot"

var _hover_face: Face3D
var _pressed_face: Face3D
var _ui_face: Face3D
var _press_position := Vector2.ZERO
var _dragging: bool = false
var _moving_handle: bool = false
var _move_start_center := Vector2.ZERO
var _placement: CubePlacement

@onready var _orientation: CubeOrientation = $OrientationPivot
@onready var _drag_handle: CubeDragHandle = get_node_or_null(
		drag_handle_path) as CubeDragHandle


func _ready() -> void:
	_orientation.settled.connect(_on_orientation_settled)

	for child in _orientation.get_children():
		if child is Face3D:
			child.face_identified.connect(_on_face_identified)

	if _drag_handle == null:
		push_warning("CubeRig 找不到拖动圆点，圆点拖动不可用。")


## 兜底：面内 UI 捕获期间如果 release 被主视口 GUI 吃掉，下一帧主动取消
func _process(_delta: float) -> void:
	if _ui_face != null and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_cancel_ui_capture()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_handle_primary_pressed(mouse_button)
			else:
				_handle_primary_released(mouse_button)
		else:
			_handle_auxiliary_button(mouse_button)
		return

	if not event is InputEventMouseMotion:
		return
	var mouse_motion := event as InputEventMouseMotion

	if _ui_face != null:
		if (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_cancel_ui_capture()
			return
		_ui_face.forward_mouse_motion(
				mouse_motion,
				_world_on_face(_ui_face, mouse_motion.position),
		)
		get_viewport().set_input_as_handled()
		return

	if _moving_handle:
		if (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_finish_handle_drag()
			_update_hover(mouse_motion.position)
		else:
			_move_handle_to(mouse_motion.position)
			get_viewport().set_input_as_handled()
	elif _dragging:
		if (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_finish_drag()
		else:
			_orientation.drag_by(mouse_motion.relative)
			get_viewport().set_input_as_handled()
	elif _pressed_face != null:
		_handle_pressed_motion(mouse_motion)
		get_viewport().set_input_as_handled()
	else:
		_update_hover(mouse_motion.position)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_MOUSE_EXIT and what != NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		return
	if _ui_face != null:
		_ui_face.cancel_interaction()
		_ui_face = null
		_clear_hover()
		return
	if _moving_handle:
		_finish_handle_drag()
		_clear_hover()
		return
	if _dragging:
		_finish_drag()
		return
	if _pressed_face != null:
		_pressed_face.cancel_interaction()
		_pressed_face = null
	_clear_hover()


## 主场景装配：屏幕锚定和位置持久化统一交给 CubePlacement
func setup_placement(placement : CubePlacement) -> void:
	_placement = placement


func _handle_primary_pressed(event: InputEventMouseButton) -> void:
	if _pressed_face != null or _ui_face != null or _dragging or _moving_handle:
		return

	if _try_begin_handle_drag(event.position):
		return
	if _drag_handle != null:
		_drag_handle.set_hovered(false)

	var hit := _raycast_at(event.position)
	if hit.is_empty():
		return

	var face: Face3D = hit["face"]
	_orientation.stop_rotation()

	if face.ui_capture and face.ui_hit_at(hit["position"]):
		if _hover_face != null and _hover_face != face:
			_hover_face.leave()
		_hover_face = face
		_ui_face = face
		face.forward_mouse_button(event, hit["position"])
		get_viewport().set_input_as_handled()
		return

	if _hover_face != null and _hover_face != face:
		_hover_face.leave()
	_hover_face = face
	_pressed_face = face
	_press_position = event.position
	face.press_at(hit["position"])
	get_viewport().set_input_as_handled()


func _handle_primary_released(event: InputEventMouseButton) -> void:
	if _ui_face != null:
		var face := _ui_face
		_ui_face = null
		var world_position := _world_on_face(face, event.position)
		face.forward_mouse_button(event, world_position)
		if face.has_content_point(world_position):
			_hover_face = face
		else:
			face.leave()
			_hover_face = null
		get_viewport().set_input_as_handled()
		return

	if _moving_handle:
		_finish_handle_drag()
		_update_hover(event.position)
		get_viewport().set_input_as_handled()
		return

	if _dragging:
		_finish_drag()
		get_viewport().set_input_as_handled()
		return

	if _pressed_face == null:
		return

	var face := _pressed_face
	_pressed_face = null
	var hit := _raycast_at(event.position)
	var is_click: bool = not hit.is_empty() and hit["face"] == face
	is_click = is_click and event.position.distance_to(_press_position) <= DRAG_THRESHOLD_PX

	if is_click:
		face.release_at(hit["position"])
		_hover_face = face
	else:
		face.cancel_interaction()
		_hover_face = null
		_update_hover(event.position)

	get_viewport().set_input_as_handled()


## 右键/滚轮等非左键事件：ui_capture 面内容区内直接转发
func _handle_auxiliary_button(event: InputEventMouseButton) -> void:
	var hit := _raycast_at(event.position)
	if hit.is_empty():
		return

	var face: Face3D = hit["face"]
	if not face.ui_capture or not face.has_content_point(hit["position"]):
		return

	face.forward_mouse_button(event, hit["position"])
	get_viewport().set_input_as_handled()


func _handle_pressed_motion(event: InputEventMouseMotion) -> void:
	if _pressed_face == null:
		return

	if event.position.distance_to(_press_position) > DRAG_THRESHOLD_PX:
		_begin_drag(event.position)
		return

	var hit := _raycast_at(event.position)
	if not hit.is_empty() and hit["face"] == _pressed_face:
		_pressed_face.hover_at(hit["position"])
		return

	_pressed_face.cancel_interaction()
	_pressed_face = null
	_hover_face = null
	_update_hover(event.position)


func _begin_drag(current_position: Vector2) -> void:
	var face := _pressed_face
	_pressed_face = null
	_hover_face = null
	face.cancel_interaction()

	_dragging = true
	_orientation.begin_drag()

	var initial_relative := current_position - _press_position
	if not initial_relative.is_zero_approx():
		_orientation.drag_by(initial_relative)


func _try_begin_handle_drag(screen_position: Vector2) -> bool:
	if _drag_handle == null or _placement == null:
		return false
	if not _drag_handle.is_screen_point_inside(screen_position):
		return false

	# 圆点被夹到屏幕边缘时可能盖住面 02，菜单控件优先
	var hit := _raycast_at(screen_position)
	if not hit.is_empty():
		var face := hit["face"] as Face3D
		if face.ui_capture and face.has_content_point(hit["position"]):
			return false

	_orientation.stop_rotation()
	_clear_hover()
	_pressed_face = null
	_dragging = false
	_moving_handle = true
	_press_position = screen_position
	_move_start_center = _placement.get_screen_center()
	_drag_handle.set_active(true)
	get_viewport().set_input_as_handled()
	return true


func _move_handle_to(screen_position: Vector2) -> void:
	if _placement == null:
		return
	_placement.set_screen_center(
			_move_start_center + screen_position - _press_position
	)


func _finish_handle_drag() -> void:
	if not _moving_handle:
		return
	_moving_handle = false
	if _drag_handle != null:
		_drag_handle.set_active(false)
	if _placement != null:
		_placement.save_position()


func _finish_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	_clear_hover()
	_orientation.end_drag()


func _update_hover(screen_position: Vector2) -> void:
	if _orientation.is_rotating():
		_clear_hover()
		return

	if _drag_handle != null and _drag_handle.is_screen_point_inside(screen_position):
		_clear_face_hover()
		_drag_handle.set_hovered(true)
		return
	if _drag_handle != null:
		_drag_handle.set_hovered(false)

	var hit := _raycast_at(screen_position)
	if hit.is_empty():
		_clear_face_hover()
		return

	var face: Face3D = hit["face"]
	if face != _hover_face:
		_clear_face_hover()
		_hover_face = face
	face.hover_at(hit["position"])


func _cancel_ui_capture() -> void:
	if _ui_face == null:
		return
	var face := _ui_face
	_ui_face = null
	face.cancel_interaction()
	_clear_face_hover()
	_update_hover(get_viewport().get_mouse_position())


func _clear_hover() -> void:
	if _drag_handle != null:
		_drag_handle.set_hovered(false)
	_clear_face_hover()


func _clear_face_hover() -> void:
	if _hover_face == null:
		return
	_hover_face.leave()
	_hover_face = null


func _raycast_at(screen_position: Vector2) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, FACE_COLLISION_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}

	var area := result["collider"] as Area3D
	if area == null:
		return {}

	var face := area.get_parent() as Face3D
	if face == null:
		return {}

	return {
		"face": face,
		"position": result["position"],
	}


## 捕获期间鼠标可能离开面片，按面所在平面换算世界点
func _world_on_face(face: Face3D, screen_position: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return face.global_position

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_normal := camera.project_ray_normal(screen_position)
	var face_normal := face.global_transform.basis.z.normalized()
	var plane := Plane(face_normal, face.global_position.dot(face_normal))
	var intersection: Variant = plane.intersects_ray(ray_origin, ray_normal)
	if intersection == null:
		return face.global_position
	return intersection as Vector3


func _on_orientation_settled() -> void:
	if _dragging or _moving_handle or _pressed_face != null or _ui_face != null:
		return
	_update_hover(get_viewport().get_mouse_position())


func _on_face_identified(
		face_index: int,
		face_name: String,
		accent_color: Color,
) -> void:
	face_identified.emit(face_index, face_name, accent_color)
