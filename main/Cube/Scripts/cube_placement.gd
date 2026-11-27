class_name CubePlacement
extends Node

signal screen_center_changed

const TARGET_FACE_PX : float = 300.0
const FACE_WORLD_SIZE : float = 1.9
const FACE_OFFSET : float = 1.005

var _camera : Camera3D
var _floating : FloatingMotion
var _screen_center := Vector2.ZERO
var _depth : float = 5.9
var _has_custom_center : bool = false


func _ready() -> void:
	_camera = CubeScenePaths.resolve(self, CubeScenePaths.CAMERA) as Camera3D
	_floating = CubeScenePaths.resolve(
			self, CubeScenePaths.CUBE) as FloatingMotion
	if _camera == null:
		push_warning("CubePlacement 找不到相机，立方体无法定位。")
	else:
		_depth = _camera_plane_depth()
	if _floating == null:
		push_warning("CubePlacement 找不到立方体节点，位置和缩放不会生效。")
	_refresh_center()
	@warning_ignore("missing_await")
	_refresh_center_after_frame()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _process(_delta : float) -> void:
	_apply()


func apply_now() -> void:
	_apply()


func get_screen_center() -> Vector2:
	return _screen_center


func set_screen_center(value : Vector2) -> void:
	_has_custom_center = true
	_set_screen_center(value)


func _refresh_center_after_frame() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		_refresh_center()


func _apply() -> void:
	if _camera == null or _floating == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y < 2.0:
		return
	if _camera.get_viewport().get_visible_rect().size.y < 2.0:
		return
	_floating.scale = Vector3.ONE * _compute_scale(viewport_size)
	_floating.set_base_position(_camera.project_position(_screen_center, _depth))


func _compute_scale(viewport_size : Vector2) -> float:
	var half_fov := deg_to_rad(_camera.fov * 0.5)
	var k := TARGET_FACE_PX * 2.0 * tan(half_fov) / viewport_size.y
	return k * _depth / (FACE_WORLD_SIZE + FACE_OFFSET * k)


func _camera_plane_depth() -> float:
	var forward := -_camera.global_basis.z.normalized()
	var depth := (Vector3.ZERO - _camera.global_position).dot(forward)
	return depth if depth > 0.1 else 5.9


func _refresh_center() -> void:
	var target := _screen_center if _has_custom_center else _default_center()
	_set_screen_center(target)


func _set_screen_center(value : Vector2) -> void:
	var clamped := _clamp_center(value)
	if clamped.is_equal_approx(_screen_center):
		return
	_screen_center = clamped
	screen_center_changed.emit()


func _default_center() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5


func _clamp_center(value : Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var half := TARGET_FACE_PX * 0.5 + float(GameGlobal.WINDOWPOSOFFSET)
	var min_point := Vector2(half, half)
	var max_point := viewport_size - min_point
	if max_point.x < min_point.x:
		min_point.x = viewport_size.x * 0.5
		max_point.x = min_point.x
	if max_point.y < min_point.y:
		min_point.y = viewport_size.y * 0.5
		max_point.y = min_point.y
	return value.clamp(min_point, max_point)


func _on_viewport_size_changed() -> void:
	_refresh_center()
