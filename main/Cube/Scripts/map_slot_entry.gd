class_name MapSlotEntry
extends Control

signal pressed
signal eject_requested

const EJECT_HEIGHT: float = 16.0
const EJECT_MARGIN: float = 2.0
const EJECT_WIDTH: float = 16.0
const BUTTON_BASE_COLOR: Color = Color("#0b1119")
const DEFAULT_ACCENT: Color = Color("#4fb8ff")

var _item: MapItemData
var _accent_color: Color = DEFAULT_ACCENT
var _appear_tween: Tween

@onready var _main_button: Button = $MainButton
@onready var _name_label: Label = $MainButton/Layout/MapName
@onready var _eject_button: Button = $EjectButton


func _ready() -> void:
	_main_button.pressed.connect(_on_main_pressed)
	_eject_button.pressed.connect(_on_eject_pressed)
	_main_button.mouse_entered.connect(_on_mouse_entered)
	_main_button.mouse_exited.connect(_on_mouse_exited)
	_update_eject_rect()
	_apply_styles()
	set_map(null)


func set_accent(color: Color) -> void:
	_accent_color = color
	_apply_styles()


func set_map(item: MapItemData) -> void:
	_item = item
	var occupied := item != null
	_main_button.disabled = not occupied
	_main_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP if occupied else Control.MOUSE_FILTER_IGNORE
	)
	_name_label.text = item.item_name if occupied else ""
	_eject_button.visible = occupied
	if not occupied:
		_hide_tooltip()


func get_map() -> MapItemData:
	return _item


func activate() -> bool:
	if _item == null:
		return false
	_main_button.pressed.emit()
	return true


func activate_eject() -> bool:
	if _item == null:
		return false
	_eject_button.pressed.emit()
	return true


func play_appear() -> void:
	if _appear_tween != null and _appear_tween.is_valid():
		_appear_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2(0.82, 0.82)
	modulate.a = 0.35
	_appear_tween = create_tween()
	_appear_tween.set_parallel(true)
	_appear_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_appear_tween.tween_property(self, "scale", Vector2.ONE, 0.22)
	_appear_tween.tween_property(self, "modulate:a", 1.0, 0.18)


func _apply_styles() -> void:
	_main_button.add_theme_stylebox_override("normal", _make_style(0.08, 0.34))
	_main_button.add_theme_stylebox_override("hover", _make_style(0.16, 0.82))
	_main_button.add_theme_stylebox_override("pressed", _make_style(0.26, 1.0))
	_main_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_eject_button.add_theme_stylebox_override(
		"normal", _make_round_style(_accent_color.darkened(0.25))
	)
	_eject_button.add_theme_stylebox_override(
		"hover", _make_round_style(_accent_color)
	)
	_eject_button.add_theme_stylebox_override(
		"pressed", _make_round_style(_accent_color.darkened(0.15))
	)
	_eject_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text_color := GameColors.to_color(GameColors.TEXT_PRIMARY)
	_eject_button.add_theme_color_override("font_color", text_color)
	_eject_button.add_theme_color_override("font_hover_color", text_color)
	_eject_button.add_theme_color_override("font_pressed_color", text_color)
	_eject_button.add_theme_font_size_override("font_size", 11)


func _make_style(fill_ratio: float, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BUTTON_BASE_COLOR.lerp(_accent_color, fill_ratio)
	style.border_color = _with_alpha(_accent_color, border_alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8.0)
	return style


func _make_round_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(EJECT_HEIGHT * 0.5))
	style.set_content_margin_all(0.0)
	return style


static func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = alpha
	return result


func _update_eject_rect() -> void:
	_eject_button.offset_left = -EJECT_MARGIN - EJECT_WIDTH
	_eject_button.offset_top = EJECT_MARGIN
	_eject_button.offset_right = -EJECT_MARGIN
	_eject_button.offset_bottom = EJECT_MARGIN + EJECT_HEIGHT


func _on_main_pressed() -> void:
	pressed.emit()


func _on_eject_pressed() -> void:
	eject_requested.emit()


func _on_mouse_entered() -> void:
	if _item == null or TooltipWindow.instance == null:
		return
	TooltipWindow.instance.show_tip(
		self,
		TooltipWindow.Layer.ITEM,
		_item.tooltip_title(),
		MapTooltip.build(_item, TooltipText.Format.PLAIN),
	)


func _on_mouse_exited() -> void:
	_hide_tooltip()


func _hide_tooltip() -> void:
	if TooltipWindow.instance != null:
		TooltipWindow.instance.hide_tip(self)


func _exit_tree() -> void:
	_hide_tooltip()
