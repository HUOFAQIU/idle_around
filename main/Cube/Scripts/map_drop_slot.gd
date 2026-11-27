class_name MapDropSlot
extends Control

signal clicked

const ITEM_BASE_SIZE: int = 32
const SLOT_BG: Color = Color(0.043, 0.067, 0.098, 0.85)
const DEFAULT_ACCENT: Color = Color("#4fb8ff")

var _pending: MapItemData
var _accent_color: Color = DEFAULT_ACCENT
var _hovering: bool = false
var _item_view: ItemView

@onready var _panel: Panel = $Panel
@onready var _hint: Label = $Hint


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_center_item_view)
	_apply_styles()
	_update_visual()


func set_accent(color: Color) -> void:
	_accent_color = color
	_apply_styles()


func set_pending(item: MapItemData) -> void:
	if _pending == item:
		return
	_pending = item
	_update_visual()
	if item == null:
		_hide_tooltip()


func get_pending() -> MapItemData:
	return _pending


func activate() -> void:
	clicked.emit()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(GBIS.input_click):
		clicked.emit()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovering = true
		_apply_styles()
		_show_tooltip()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovering = false
		_apply_styles()
		_hide_tooltip()


func _apply_styles() -> void:
	if _panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_BG
	style.border_color = _with_alpha(_accent_color, 0.82 if _hovering else 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("panel", style)


func _update_visual() -> void:
	if _hint == null:
		return
	if _pending == null:
		_hint.visible = true
		_hint.text = "放地图"
		if _item_view != null:
			_item_view.queue_free()
			_item_view = null
		return
	_hint.visible = false
	if _item_view == null:
		_item_view = ItemView.new(_pending, ITEM_BASE_SIZE)
		_item_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_item_view)
		_center_item_view()
	else:
		_item_view.data = _pending
		_item_view.recalculate_size()
		_center_item_view()


func _center_item_view() -> void:
	if _item_view == null or not is_instance_valid(_item_view):
		return
	_item_view.position = (size - _item_view.size) * 0.5


func _show_tooltip() -> void:
	if _pending == null or TooltipWindow.instance == null:
		return
	TooltipWindow.instance.show_tip(
		self,
		TooltipWindow.Layer.ITEM,
		_pending.tooltip_title(),
		MapTooltip.build(_pending, TooltipText.Format.PLAIN),
	)


func _hide_tooltip() -> void:
	if TooltipWindow.instance != null:
		TooltipWindow.instance.hide_tip(self)


static func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = alpha
	return result


func _exit_tree() -> void:
	_hide_tooltip()
