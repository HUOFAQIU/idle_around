class_name FaceContent
extends Control

const FACE_NUMBER_FONT: Font = preload(
		"res://Main/Cube/Resources/UI/font_cjk_bold.tres")
const FACE_NUMBER_HEIGHT_RATIO := 0.8
const FACE_NUMBER_ALPHA := 0.16

@warning_ignore("unused_signal")
signal identify_requested

## 面号水印插入到该节点之后：在底色之上、内容之下
@export var backdrop_path: NodePath = ^"Background"

var _face_number_label: Label


func setup(index: int, _display_name: String, accent: Color) -> void:
	_apply_face_number(index, accent)


func content_id() -> StringName:
	return &"face_content"


func face_number_text() -> String:
	return _face_number_label.text if _face_number_label != null else ""


func _apply_face_number(index: int, accent: Color) -> void:
	var label := _ensure_face_number_label()
	if label == null:
		return
	label.text = "%02d" % (index + 1)
	var color := accent
	color.a = FACE_NUMBER_ALPHA
	label.add_theme_color_override("font_color", color)


func _ensure_face_number_label() -> Label:
	if _face_number_label != null:
		return _face_number_label
	var backdrop := get_node_or_null(backdrop_path)
	if backdrop == null or backdrop.get_parent() == null:
		return null
	var parent := backdrop.get_parent()
	var label := Label.new()
	label.name = "FaceNumberLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FACE_NUMBER_FONT)
	label.add_theme_font_size_override(
			"font_size", maxi(1, roundi(size.y * FACE_NUMBER_HEIGHT_RATIO)))
	parent.add_child(label)
	parent.move_child(label, backdrop.get_index() + 1)
	_face_number_label = label
	return label
