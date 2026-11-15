class_name FaceUI
extends FaceContent
## 单个立方体面的 2D 界面：展示面名，按钮被点击后发出识别请求。

const FACE_COUNT := 6
const BUTTON_BASE_COLOR := Color("#0b1119")
const MUTED_TEXT_COLOR := Color(0.55, 0.63, 0.73, 1.0)

@export var face_index: int = 0
@export var face_name: String = "正面"
@export var accent_color: Color = Color("#4fb8ff")

var _backdrop_material: ShaderMaterial
var _feedback_tween: Tween

@onready var _backdrop: ColorRect = $Backdrop
@onready var _frame: Panel = $Frame
@onready var _index_label: Label = $ContentMargin/Layout/Header/IndexLabel
@onready var _state_label: Label = $ContentMargin/Layout/Header/StateLabel
@onready var _header_rule: ColorRect = $ContentMargin/Layout/HeaderRule
@onready var _face_button: Button = $ContentMargin/Layout/FaceButton
@onready var _hint_label: Label = $ContentMargin/Layout/HintLabel
@onready var _accent_line: ColorRect = $ContentMargin/Layout/Footer/AccentLine
@onready var _footer_label: Label = $ContentMargin/Layout/Footer/FooterLabel
@onready var _footer_index_label: Label = $ContentMargin/Layout/Footer/FooterIndexLabel


func _ready() -> void:
	_face_button.pressed.connect(_on_face_button_pressed)
	_apply_visuals()


func setup(index: int, display_name: String, accent: Color) -> void:
	face_index = index
	face_name = display_name
	accent_color = accent
	if is_node_ready():
		_apply_visuals()


func content_id() -> StringName:
	return &"face_ui"


func _apply_visuals() -> void:
	_index_label.text = "面 %02d" % (face_index + 1)
	_face_button.text = face_name
	_footer_index_label.text = "%02d / %02d" % [face_index + 1, FACE_COUNT]

	_index_label.add_theme_color_override("font_color", accent_color)
	_state_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	_hint_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	_footer_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	_footer_index_label.add_theme_color_override("font_color", _with_alpha(accent_color, 0.72))

	_accent_line.color = accent_color
	_header_rule.color = _with_alpha(accent_color, 0.22)

	_apply_frame_style()
	_apply_button_styles()
	_apply_backdrop_accent()


func _apply_frame_style() -> void:
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color.TRANSPARENT
	frame_style.border_color = _with_alpha(accent_color, 0.24)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(30)
	_frame.add_theme_stylebox_override("panel", frame_style)


func _apply_button_styles() -> void:
	_face_button.add_theme_stylebox_override("normal", _create_button_style(0.08, 0.38))
	_face_button.add_theme_stylebox_override("hover", _create_button_style(0.16, 0.82))
	_face_button.add_theme_stylebox_override("pressed", _create_button_style(0.28, 1.0))


func _apply_backdrop_accent() -> void:
	var source_material := _backdrop.material as ShaderMaterial
	if source_material == null:
		return
	if _backdrop_material == null:
		_backdrop_material = source_material.duplicate() as ShaderMaterial
		_backdrop.material = _backdrop_material
	_backdrop_material.set_shader_parameter("accent_color", accent_color)


func _create_button_style(fill_ratio: float, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BUTTON_BASE_COLOR.lerp(accent_color, fill_ratio)
	style.border_color = _with_alpha(accent_color, border_alpha)
	style.set_border_width_all(2)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(18.0)
	return style


func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = alpha
	return result


func _on_face_button_pressed() -> void:
	_play_click_feedback()
	identify_requested.emit()


func _play_click_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_face_button.pivot_offset = _face_button.size * 0.5
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(_face_button, "scale", Vector2(0.965, 0.965), 0.06)
	_feedback_tween.tween_property(_face_button, "scale", Vector2.ONE, 0.16)
