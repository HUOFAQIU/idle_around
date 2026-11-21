class_name CubeHud
extends CanvasLayer

signal overlay_regions_changed

const NEAR_CUBE_OFFSET: float = 14.0
const BOTTOM_MARGIN: float = 38.0
const SCREEN_MARGIN: float = 8.0

var _near_cube: bool = false
var _toast_tween: Tween
var _placement: CubePlacement

@onready var _toast: PanelContainer = $Root/ToastAnchor/Toast
@onready var _toast_dot: Label = $Root/ToastAnchor/Toast/Content/Dot
@onready var _toast_message: Label = $Root/ToastAnchor/Toast/Content/Message


func _ready() -> void:
	_toast.hide()
	_toast.modulate.a = 0.0
	_placement = CubeScenePaths.resolve(
			self, CubeScenePaths.PLACEMENT) as CubePlacement
	if _placement != null:
		_placement.screen_center_changed.connect(_on_cube_screen_center_changed)


func show_face_identified(face_name: String, accent_color: Color) -> void:
	_show_toast("这是：%s" % face_name, accent_color, false)


func show_near_cube(text: String, accent_color: Color = Color.TRANSPARENT) -> void:
	var accent := accent_color
	if accent.a <= 0.0:
		accent = GameColors.to_color(GameColors.WARNING)
	_show_toast(text, accent, true)


func get_overlay_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if _toast.visible:
		rects.append(_toast.get_global_rect())
	return rects


func _show_toast(text: String, accent_color: Color, near_cube: bool) -> void:
	_toast_message.text = text
	_toast_dot.add_theme_color_override("font_color", accent_color)
	_apply_toast_accent(accent_color)
	_near_cube = near_cube

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast.show()
	_layout_toast()
	overlay_regions_changed.emit()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.45)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_hide_toast)


func _layout_toast() -> void:
	_toast.reset_size()
	var toast_size := _toast.get_combined_minimum_size()
	if toast_size.x <= 0.0:
		return
	_toast.size = toast_size
	var viewport_size := get_viewport().get_visible_rect().size
	var target := Vector2.ZERO
	if _near_cube and _placement != null:
		var center := _placement.get_screen_center()
		target.x = center.x - toast_size.x * 0.5
		target.y = center.y - CubePlacement.TARGET_FACE_PX * 0.5 \
				- toast_size.y - NEAR_CUBE_OFFSET
	else:
		target.x = (viewport_size.x - toast_size.x) * 0.5
		target.y = viewport_size.y - BOTTOM_MARGIN - toast_size.y
	target.x = clampf(
			target.x, SCREEN_MARGIN, viewport_size.x - toast_size.x - SCREEN_MARGIN)
	target.y = clampf(
			target.y, SCREEN_MARGIN, viewport_size.y - toast_size.y - SCREEN_MARGIN)
	_toast.position = target


func _on_cube_screen_center_changed() -> void:
	if not _near_cube or not _toast.visible:
		return
	_layout_toast()
	overlay_regions_changed.emit()


func _hide_toast() -> void:
	_toast.hide()
	_near_cube = false
	overlay_regions_changed.emit()


func _apply_toast_accent(accent_color: Color) -> void:
	var panel := _toast.get_theme_stylebox("panel")
	if panel == null:
		return
	var style := panel.duplicate() as StyleBoxFlat
	if style == null:
		return
	var border_color := accent_color
	border_color.a = 0.5
	style.border_color = border_color
	style.border_width_left = 3
	_toast.add_theme_stylebox_override("panel", style)
