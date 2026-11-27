class_name WindowPassthrough
extends Node

const REGION_PADDING: float = 28.0
const UI_REGION_PADDING: float = 8.0
const SHRINK_HOLD_FRAMES: int = 3

static var instance: WindowPassthrough

@export var cube_placement_path: NodePath = ^"../CubePlacement"
@export var hud_path: NodePath = ^"../HUD"
@export var panel_manager_path: NodePath = ^"../GameUI/GameControl/PanelManager"
@export var tooltip_path: NodePath = ^"../GameUI/GameControl/TooltipLayer/TooltipWindow"
@export var item_window_path: NodePath = ^"../GameUI/GameControl/DragLayer/ItemWindow"

var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		if enabled:
			_dirty = true
			return
		_clear_region()

var _window: Window
var _cube_orientation: CubeOrientation
var _camera: Camera3D
var _cube_placement: CubePlacement
var _hud: CubeHud
var _drag_handle: CubeDragHandle
var _panel_manager: PanelManager
var _tooltip: Control
var _item_window: Control
var _locked: bool = false
var _dirty: bool = true
var _last_polygon := PackedVector2Array()
var _last_rects: Array[Rect2] = []
var _last_ui_rects: Array[Rect2] = []
var _last_viewport_size := Vector2i.ZERO
var _last_window_size := Vector2i.ZERO
var _last_cube_viewport_size := Vector2i.ZERO
var _held_region := PackedVector2Array()
var _held_frames: int = 0


func _ready() -> void:
	instance = self
	_window = get_window()
	_cube_orientation = CubeScenePaths.resolve(
			self, CubeScenePaths.ORIENTATION) as CubeOrientation
	_camera = CubeScenePaths.resolve(self, CubeScenePaths.CAMERA) as Camera3D
	_cube_placement = get_node_or_null(cube_placement_path) as CubePlacement
	_hud = get_node_or_null(hud_path) as CubeHud
	_drag_handle = CubeScenePaths.resolve(
			self, CubeScenePaths.DRAG_HANDLE) as CubeDragHandle
	_panel_manager = get_node_or_null(panel_manager_path) as PanelManager
	_tooltip = get_node_or_null(tooltip_path) as Control
	_item_window = get_node_or_null(item_window_path) as Control

	if _window != null:
		_window.mouse_passthrough = false
	if _hud != null:
		_hud.overlay_regions_changed.connect(_on_overlay_regions_changed)
	else:
		push_warning("WindowPassthrough 找不到 HUD，点击穿透区域将只包含立方体。")
	if _cube_orientation == null:
		push_warning("WindowPassthrough 找不到立方体朝向节点。")
	if _camera == null:
		push_warning("WindowPassthrough 找不到立方体相机，穿透区域将只包含 UI。")
	if _cube_placement != null:
		_cube_placement.screen_center_changed.connect(_on_overlay_regions_changed)
	else:
		push_warning("WindowPassthrough 找不到 CubePlacement，程序化移动立方体时穿透区域不会刷新。")
	if _panel_manager == null:
		push_warning("WindowPassthrough 找不到 PanelManager，游戏窗口不会加入穿透区域。")

	_refresh_region()


func _process(_delta: float) -> void:
	if not enabled:
		return
	if _window == null:
		return

	_flush_held_region()

	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	var window_size := _window.size
	if viewport_size != _last_viewport_size or window_size != _last_window_size:
		_last_viewport_size = viewport_size
		_last_window_size = window_size
		_dirty = true

	var cube_viewport_size := _cube_viewport_size()
	if cube_viewport_size != _last_cube_viewport_size:
		_last_cube_viewport_size = cube_viewport_size
		_dirty = true

	var tooltip_visible := _tooltip != null and _tooltip.is_visible_in_tree()
	if _locked:
		if _mouse_buttons_down():
			return
		if _cube_orientation != null and _cube_orientation.is_rotating():
			return
		if tooltip_visible:
			return
		_locked = false
		_dirty = true

	if tooltip_visible:
		_lock_full_region()
		return

	if _cube_orientation != null and _cube_orientation.is_rotating():
		_lock_full_region()
		return

	var ui_rects := _collect_ui_rects()
	if ui_rects != _last_ui_rects:
		_last_ui_rects = ui_rects
		_dirty = true

	if not _dirty:
		return
	_dirty = false
	_refresh_region()


func _input(event: InputEvent) -> void:
	if not enabled or _window == null:
		return
	if event is not InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed:
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT \
			and mouse_button.button_index != MOUSE_BUTTON_RIGHT:
		return
	_lock_full_region()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		return
	_locked = false
	_dirty = true


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if _window == null:
		return
	_window.mouse_passthrough = false
	_window.mouse_passthrough_polygon = PackedVector2Array()


func is_locked() -> bool:
	return _locked


func get_hit_rects() -> Array[Rect2]:
	return _last_rects.duplicate()


func get_polygon_points() -> PackedVector2Array:
	if _window == null:
		return PackedVector2Array()
	return _window.mouse_passthrough_polygon


func _on_overlay_regions_changed() -> void:
	_dirty = true


func _collect_ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var area := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if _panel_manager != null:
		for rect in _panel_manager.get_visible_panel_rects():
			_append_clipped(rects, rect, area)
	if _tooltip != null and _tooltip.is_visible_in_tree():
		_append_clipped(rects, _tooltip.get_global_rect(), area)
	if _item_window != null and _item_window.is_visible_in_tree():
		_append_clipped(rects, _item_window.get_global_rect(), area)
	return rects


func _append_clipped(rects: Array[Rect2], rect: Rect2, area: Rect2) -> void:
	var clipped := rect.intersection(area)
	if clipped.size.x > 0.0 and clipped.size.y > 0.0:
		rects.append(clipped)


func _lock_full_region() -> void:
	if _locked or _window == null:
		return
	_locked = true
	_cancel_held_region()
	_apply_polygon(UiRegion.full_window(Vector2(_window.size)))


func _mouse_buttons_down() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _refresh_region() -> void:
	if _window == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := Vector2(_window.size)
	if viewport_size.x < 2.0 or viewport_size.y < 2.0:
		return
	if window_size.x < 2.0 or window_size.y < 2.0:
		return

	var base_polygon := PackedVector2Array()
	if _camera != null and _cube_orientation != null \
			and _cube_viewport_size().y >= 2:
		base_polygon = _project_cube_hull(_camera)

	_last_ui_rects = _collect_ui_rects()
	_last_rects.clear()
	_last_rects.append_array(_last_ui_rects)
	if _hud != null:
		_last_rects.append_array(_hud.get_overlay_rects())
	if _drag_handle != null:
		_last_rects.append_array(_drag_handle.get_overlay_rects())

	var region := UiRegion.build(
			base_polygon,
			_last_rects,
			REGION_PADDING,
			Rect2(Vector2.ZERO, viewport_size),
			UI_REGION_PADDING,
	)
	if region.size() < 3:
		region = UiRegion.minimal_region()

	if not window_size.is_equal_approx(viewport_size):
		region = _scale_region(region, window_size / viewport_size)

	if _should_hold_shrink(region):
		if region != _held_region:
			_held_region = region
			_held_frames = SHRINK_HOLD_FRAMES
		return
	_cancel_held_region()
	_apply_polygon(region)


func _should_hold_shrink(region: PackedVector2Array) -> bool:
	if region.size() < 3 or _last_polygon.size() < 3:
		return false
	var region_area := _polygon_area(region)
	if region_area >= _polygon_area(_last_polygon) - 1.0:
		return false
	var overlap_area := 0.0
	for piece in Geometry2D.intersect_polygons(_last_polygon, region):
		overlap_area += _polygon_area(piece)
	return overlap_area >= region_area - 1.0


func _flush_held_region() -> void:
	if _held_region.is_empty():
		return
	_held_frames -= 1
	if _held_frames > 0:
		return
	var region := _held_region
	_cancel_held_region()
	_apply_polygon(region)


func _cancel_held_region() -> void:
	_held_region = PackedVector2Array()
	_held_frames = 0


func _polygon_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in polygon.size():
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		area += current.x * next.y - next.x * current.y
	return absf(area) * 0.5


func _project_cube_hull(camera: Camera3D) -> PackedVector2Array:
	return CubeProjection.project_hull(camera, _cube_orientation)


func _cube_viewport_size() -> Vector2i:
	if _camera == null:
		return Vector2i.ZERO
	return Vector2i(_camera.get_viewport().get_visible_rect().size)


func _scale_region(polygon: PackedVector2Array, scale: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in polygon:
		result.append(point * scale)
	return result


func _apply_polygon(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3 or polygon == _last_polygon:
		return
	_last_polygon = polygon
	_window.mouse_passthrough_polygon = polygon


func _clear_region() -> void:
	_last_polygon = PackedVector2Array()
	_last_rects.clear()
	_cancel_held_region()
	if _window == null:
		return
	_window.mouse_passthrough = false
	_window.mouse_passthrough_polygon = PackedVector2Array()
