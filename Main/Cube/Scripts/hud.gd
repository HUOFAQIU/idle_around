class_name CubeHud
extends CanvasLayer
## 屏幕上的「面识别」反馈条。

signal overlay_regions_changed

var _toast_tween: Tween

@onready var _toast: PanelContainer = $Root/ToastAnchor/Toast
@onready var _toast_dot: Label = $Root/ToastAnchor/Toast/Content/Dot
@onready var _toast_message: Label = $Root/ToastAnchor/Toast/Content/Message


func _ready() -> void:
	_toast.hide()
	_toast.modulate.a = 0.0


func show_face_identified(face_name: String, accent_color: Color) -> void:
	_toast_message.text = "这是：%s" % face_name
	_toast_dot.add_theme_color_override("font_color", accent_color)
	_apply_toast_accent(accent_color)

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast.show()
	overlay_regions_changed.emit()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.45)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_hide_toast)


func get_overlay_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if _toast.visible:
		rects.append(_toast.get_global_rect())
	return rects


func _hide_toast() -> void:
	_toast.hide()
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
