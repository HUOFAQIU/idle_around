class_name CubePlacement
extends Node
## 把立方体锚定在屏幕坐标上，并按视口高度换算世界缩放，
## 使面 02 的屏幕投影保持约 TARGET_FACE_PX 像素。
##
## 位置以「立方体中心的屏幕像素坐标」持久化；拖动圆点只改这个坐标，
## 世界位置和缩放每帧由本节点重算。

## 屏幕中心变化；穿透区域等外部消费者据此刷新
signal screen_center_changed

const TARGET_FACE_PX : float = 300.0
## 面片 QuadMesh 的边长，和 face_3d.tscn 保持一致
const FACE_WORLD_SIZE : float = 1.9
## 面片相对立方体中心的距离，用于按面片深度修正缩放
const FACE_OFFSET : float = 1.005
## 默认朝向时靠近相机的面（01 或 02）的世界法线
const NEAR_FACE_NORMAL := Vector3(0, 0, 1)

var _camera : Camera3D
var _floating : FloatingMotion
var _screen_center := Vector2.ZERO
var _depth : float = 5.9
var _has_saved_position : bool = false


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
	_has_saved_position = CubeSettings.has_position()
	_refresh_center()
	@warning_ignore("missing_await")
	_refresh_center_after_frame()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _process(_delta : float) -> void:
	_apply()


## 立即按当前视口应用一次；主场景装配时调，避免首帧停在场景默认位置
func apply_now() -> void:
	_apply()


func get_screen_center() -> Vector2:
	return _screen_center


func set_screen_center(value : Vector2) -> void:
	_set_screen_center(value)


func save_position() -> void:
	CubeSettings.save_position(_screen_center)
	_has_saved_position = true


## 等一帧让全屏/DPI 后的视口尺寸稳定，再重算默认位或夹取已保存位置
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
	# 子视口由 SubViewportContainer 拉伸到主视口，布局稳定前先跳过一帧
	if _camera.get_viewport().get_visible_rect().size.y < 2.0:
		return
	_floating.scale = Vector3.ONE * _compute_scale(viewport_size)
	_floating.set_base_position(_camera.project_position(_screen_center, _depth))


## 靠近相机的面按面片深度解出精确缩放，让面片投影保持约 300px
func _compute_scale(viewport_size : Vector2) -> float:
	var half_fov := deg_to_rad(_camera.fov * 0.5)
	var k := TARGET_FACE_PX * 2.0 * tan(half_fov) / viewport_size.y
	return k * _depth / (FACE_WORLD_SIZE + FACE_OFFSET * k)


func _camera_plane_depth() -> float:
	var forward := -_camera.global_basis.z.normalized()
	var depth := (Vector3.ZERO - _camera.global_position).dot(forward)
	return depth if depth > 0.1 else 5.9


func _refresh_center() -> void:
	var target := CubeSettings.load_position() if _has_saved_position else _default_center()
	_set_screen_center(target)


func _set_screen_center(value : Vector2) -> void:
	var clamped := _clamp_center(value)
	if clamped.is_equal_approx(_screen_center):
		return
	_screen_center = clamped
	screen_center_changed.emit()


## 默认位置以「近端面的中心」为准：近端面在透视下会向外偏，
## 直接放立方体中心会让面片被屏幕边缘裁掉，这里反算立方体中心。
func _default_center() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := float(GameGlobal.WINDOWPOSOFFSET)
	var half := TARGET_FACE_PX * 0.5
	var face_target := Vector2(
			margin + half,
			viewport_size.y - margin - half,
	)
	if _camera == null:
		return face_target

	var face_distance := FACE_OFFSET * _compute_scale(viewport_size)
	var forward := -_camera.global_basis.z.normalized()
	var face_depth := _depth + NEAR_FACE_NORMAL.dot(forward) * face_distance
	var face_world := _camera.project_position(face_target, face_depth)
	var center_world := face_world - NEAR_FACE_NORMAL * face_distance
	return _camera.unproject_position(center_world)


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
