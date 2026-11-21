class_name CubeInputSurface
extends Control

static var instance: CubeInputSurface

var _cube_viewport: SubViewport
var _camera: Camera3D
var _orientation: CubeOrientation
var _drag_handle: CubeDragHandle
var _rig: CubeRig


func _ready() -> void:
	instance = self
	_cube_viewport = CubeScenePaths.resolve(
			self, CubeScenePaths.VIEWPORT) as SubViewport
	if _cube_viewport == null:
		push_warning("CubeInputSurface 找不到立方体子视口，输入代理不会生效。")
		return

	_camera = CubeScenePaths.resolve(self, CubeScenePaths.CAMERA) as Camera3D
	_orientation = CubeScenePaths.resolve(
			self, CubeScenePaths.ORIENTATION) as CubeOrientation
	_rig = CubeScenePaths.resolve(self, CubeScenePaths.RIG) as CubeRig
	_drag_handle = CubeScenePaths.resolve(
			self, CubeScenePaths.DRAG_HANDLE) as CubeDragHandle
	if _camera == null or _orientation == null:
		push_warning("CubeInputSurface 缺少相机或朝向节点，命中区域只剩拖动圆点。")

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _has_point(point: Vector2) -> bool:
	if _drag_handle != null and _drag_handle.is_screen_point_inside(point):
		return true
	var hull := CubeProjection.project_hull(_camera, _orientation)
	return Geometry2D.is_point_in_polygon(point, hull)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouse or _cube_viewport == null:
		return
	_cube_viewport.push_input(event)
	accept_event()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_MOUSE_EXIT \
			and what != NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		return
	if _rig != null:
		_rig.cancel_window_interaction()


func contains_screen_point(screen_position: Vector2) -> bool:
	var local_position := (
			get_global_transform_with_canvas().affine_inverse() * screen_position
	)
	return _has_point(local_position)


func is_ready() -> bool:
	return _cube_viewport != null and _camera != null \
			and _orientation != null and _rig != null and _drag_handle != null


func get_hull_points() -> PackedVector2Array:
	return CubeProjection.project_hull(_camera, _orientation)


func _on_mouse_entered() -> void:
	if _cube_viewport != null:
		_cube_viewport.notify_mouse_entered()


func _on_mouse_exited() -> void:
	if _cube_viewport != null:
		_cube_viewport.notify_mouse_exited()
	if _rig != null:
		_rig.pointer_left()
