class_name Face3D
extends Node3D
## 立方体的一个面：把 SubViewport 中的 2D 内容贴到面片上，
## 并把 CubeRig 计算出的指针事件转发给该 SubViewport。
##
## 普通 FaceUI 面沿用「按下即转发、拖动超阈值取消」的交互；
## ui_capture 面（01 存档位 / 02 主菜单 / 04 角色选择 / 05 地图板）按控件优先分流：
## 指针下有可交互控件时整个按下-拖动-松开周期都交给内容，不参与立方体旋转。

signal face_identified(face_index: int, face_name: String, accent_color: Color)

const OFFSCREEN_POINTER := Vector2(-96.0, -96.0)

@export var face_index: int = 0
@export var face_name: String = "正面"
@export var accent_color: Color = Color("#4fb8ff")
## 面内容优先接收鼠标：用于承载存档位/主菜单/角色选择等可交互 UI 的面
@export var ui_capture: bool = false
## 该面承载的 2D 内容场景，实例化到 Viewport 下；所有面共用同一个 Face3D 模板
@export var content_scene: PackedScene
## 子视口尺寸；普通面 512，存档/主菜单/角色选择/地图板用 300 与屏幕投影 1:1
@export var viewport_size: Vector2i = Vector2i(512, 512)

var _content_size: Vector2 = Vector2(1.9, 1.9)
var _content: FaceContent
var _locked: bool = false
var _pointer_inside: bool = false
var _pointer_down: bool = false
var _last_pointer_position := Vector2.ZERO

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _viewport: SubViewport = $Viewport
@onready var _lock_overlay: Control = get_node_or_null(
		"Viewport/LockOverlay") as Control


func _ready() -> void:
	_viewport.size = viewport_size
	if content_scene != null:
		_viewport.add_child(content_scene.instantiate())
	# 锁图必须在内容之后绘制，实例化内容后把它移到最上层
	if _lock_overlay != null:
		_viewport.move_child(_lock_overlay, _viewport.get_child_count() - 1)
		_lock_overlay.visible = _locked

	var quad := _mesh.mesh as QuadMesh
	if quad != null:
		_content_size = Vector2(
				maxf(quad.size.x, 0.001),
				maxf(quad.size.y, 0.001),
		)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_mesh.material_override = material

	_content = _find_content()
	if _content != null:
		_content.setup(face_index, face_name, accent_color)
		_content.identify_requested.connect(_on_identify_requested)


## 面锁定：内容压暗并显示锁图，所有指针事件不再转发
func set_locked(locked: bool) -> void:
	if _locked == locked:
		return
	_locked = locked
	if _lock_overlay != null:
		_lock_overlay.visible = locked
	if locked:
		cancel_interaction()
		leave()


func is_locked() -> bool:
	return _locked


func get_content() -> FaceContent:
	return _content


## 指针悬停在面上；只转发落在内容区内的位置
func hover_at(world_position: Vector3) -> void:
	if _locked:
		return
	var viewport_position := _to_viewport_position(world_position)
	if not _is_inside_content(viewport_position):
		leave()
		return
	if not _pointer_inside:
		_enter_pointer(viewport_position)
	_push_motion_at(viewport_position)


## 普通面按下：立即转发左键按下，后续拖动由 CubeRig 决定是否取消
func press_at(world_position: Vector3) -> void:
	if _locked:
		return
	var viewport_position := _to_viewport_position(world_position)
	if not _pointer_inside:
		_enter_pointer(viewport_position)
	_push_motion_at(viewport_position)
	_pointer_down = true
	_push_button(viewport_position, true)


func release_at(world_position: Vector3) -> void:
	if _locked:
		return
	var viewport_position := _to_viewport_position(world_position)
	if not _pointer_inside:
		_enter_pointer(viewport_position)
	_push_motion_at(viewport_position)
	_push_button(viewport_position, false)
	_pointer_down = false


## 世界点是否落在本面的可见内容区（不含方形侧面的留白边）
func has_content_point(world_position: Vector3) -> bool:
	if _locked:
		return false
	return _is_inside_content(_to_viewport_position(world_position))


## ui_capture 面：指针下是否有可交互控件（会先同步一次鼠标位置）
func ui_hit_at(world_position: Vector3) -> bool:
	if _locked or not ui_capture or _content == null:
		return false
	var viewport_position := _to_viewport_position(world_position)
	if not _is_inside_content(viewport_position):
		return false
	if not _pointer_inside:
		_enter_pointer(viewport_position)
	_push_motion_at(viewport_position)
	return _viewport.gui_get_hovered_control() != null


## ui_capture 面：转发完整的鼠标按键事件（保留右键/滚轮/修饰键）
func forward_mouse_button(
		event: InputEventMouseButton,
		world_position: Vector3,
) -> void:
	if _locked:
		return
	var viewport_position := _to_viewport_position(world_position)
	if not _pointer_inside:
		_enter_pointer(viewport_position)
	_push_motion_at(viewport_position)
	_push_mouse_button_event(event, viewport_position)
	if event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_down = event.pressed


## ui_capture 面：转发鼠标移动；拖动捕获期间允许坐标越出内容区
func forward_mouse_motion(
		event: InputEventMouseMotion,
		world_position: Vector3,
) -> void:
	if _locked:
		return
	var viewport_position := _to_viewport_position(world_position)
	if not _pointer_inside:
		_enter_pointer(viewport_position)
	_push_mouse_motion_event(event, viewport_position)


func cancel_interaction() -> void:
	if _pointer_down:
		_push_motion_at(OFFSCREEN_POINTER)
		_push_button(OFFSCREEN_POINTER, false)
		_pointer_down = false
	if _pointer_inside:
		_viewport.notify_mouse_exited()
		_pointer_inside = false


func leave() -> void:
	if _pointer_down:
		cancel_interaction()
		return
	if not _pointer_inside:
		return
	# 先把鼠标移出内容区，让子视口内的 hover/Tooltip 及时清理
	_push_motion_at(OFFSCREEN_POINTER)
	_viewport.notify_mouse_exited()
	_pointer_inside = false


func _find_content() -> FaceContent:
	for child in _viewport.get_children():
		if child is FaceContent:
			return child as FaceContent
	return null


func _enter_pointer(viewport_position: Vector2) -> void:
	_pointer_inside = true
	_last_pointer_position = viewport_position
	_viewport.notify_mouse_entered()


func _push_motion_at(viewport_position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = viewport_position
	event.global_position = viewport_position
	event.relative = viewport_position - _last_pointer_position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if _pointer_down else 0
	_viewport.push_input(event, true)
	_last_pointer_position = viewport_position


func _push_button(viewport_position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = viewport_position
	event.global_position = viewport_position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_viewport.push_input(event, true)


func _push_mouse_motion_event(
		event: InputEventMouseMotion,
		viewport_position: Vector2,
) -> void:
	var forwarded := event.duplicate() as InputEventMouseMotion
	forwarded.position = viewport_position
	forwarded.global_position = viewport_position
	forwarded.relative = viewport_position - _last_pointer_position
	_viewport.push_input(forwarded, true)
	_last_pointer_position = viewport_position


func _push_mouse_button_event(
		event: InputEventMouseButton,
		viewport_position: Vector2,
) -> void:
	var forwarded := event.duplicate() as InputEventMouseButton
	forwarded.position = viewport_position
	forwarded.global_position = viewport_position
	_viewport.push_input(forwarded, true)


func _to_viewport_position(world_position: Vector3) -> Vector2:
	var local_position := to_local(world_position)
	var normalized_position := Vector2(
			local_position.x / _content_size.x + 0.5,
			0.5 - local_position.y / _content_size.y,
	)
	return normalized_position * Vector2(_viewport.size)


func _is_inside_content(viewport_position: Vector2) -> bool:
	var content_pixel_size := Vector2(_viewport.size)
	return (
		viewport_position.x >= 0.0
		and viewport_position.y >= 0.0
		and viewport_position.x < content_pixel_size.x
		and viewport_position.y < content_pixel_size.y
	)


func _on_identify_requested() -> void:
	face_identified.emit(face_index, face_name, accent_color)
