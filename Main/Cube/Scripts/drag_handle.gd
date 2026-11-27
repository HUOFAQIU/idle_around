class_name CubeDragHandle
extends Node2D

const CORE_RADIUS := 6.0
const HIT_RADIUS := 16.0
const HOVER_SCALE := 1.22
const ACTIVE_SCALE := 1.32
const CORE_COLOR := Color(0.82, 0.96, 1.0, 0.96)
const SCREEN_GAP := 40.0
const SCREEN_MARGIN := 32.0

@export var anchor_path: NodePath = ^"../.."

var _anchor: Node3D
var _hovered: bool = false
var _active: bool = false


func _ready() -> void:
	_anchor = get_node_or_null(anchor_path) as Node3D
	if _anchor == null:
		push_warning("CubeDragHandle 找不到锚点节点，圆点位置将固定在原点。")


func _process(_delta: float) -> void:
	position = get_screen_position()


func get_screen_position() -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _anchor == null:
		return Vector2.ZERO
	var half_height := _anchor.global_transform.basis.get_scale().y
	var top_world := (
			_anchor.global_position
			+ camera.global_basis.y.normalized() * half_height
	)
	var top_screen := camera.unproject_position(top_world)
	return _clamp_screen(Vector2(top_screen.x, top_screen.y - SCREEN_GAP))


func is_screen_point_inside(screen_position: Vector2) -> bool:
	return screen_position.distance_to(get_screen_position()) <= HIT_RADIUS


func set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	queue_redraw()


func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	queue_redraw()


func get_overlay_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var radius := HIT_RADIUS + 2.0
	var center := get_screen_position()
	rects.append(Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
	return rects


func _clamp_screen(screen_position: Vector2) -> Vector2:
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= SCREEN_MARGIN * 2.0 or viewport_size.y <= SCREEN_MARGIN * 2.0:
		return screen_position
	var margin := Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
	return screen_position.clamp(margin, viewport_size - margin)


func _draw() -> void:
	var scale_factor := ACTIVE_SCALE if _active else (HOVER_SCALE if _hovered else 1.0)
	draw_circle(Vector2.ZERO, CORE_RADIUS * scale_factor, CORE_COLOR, true, -1.0, true)
