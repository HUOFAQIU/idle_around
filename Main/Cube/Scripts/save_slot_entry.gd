class_name SaveSlotEntry
extends Control
## 01 面单个存档位：主按钮 + 右上角删除按钮。
##
## 删除是两段式：第一次点 × 变成「确认」，再点一次才发 delete_requested；
## 点主按钮、新游戏或其它槽的删除按钮会取消确认。活动槽不显示删除按钮。

signal slot_requested
signal delete_requested
## 第一次点 × 进入确认态；父级用它取消其它槽的确认
signal delete_confirmation_started

const DELETE_HEIGHT: float = 20.0
const DELETE_MARGIN: float = 3.0
const DELETE_WIDTH: float = 20.0
const DELETE_CONFIRM_WIDTH: float = 44.0
const DELETE_TEXT: String = "×"
const DELETE_CONFIRM_TEXT: String = "确认"

var _slot: int = 0
var _occupied: bool = false
var _active: bool = false
var _confirming: bool = false
var _slot_name_color: Color
var _character_name_color: Color
var _active_text_color: Color
var _accent_normal: StyleBoxFlat
var _accent_hover: StyleBoxFlat
var _accent_pressed: StyleBoxFlat

@onready var _main_button: Button = $MainButton
@onready var _slot_name: Label = $MainButton/Layout/SlotName
@onready var _character_name: Label = $MainButton/Layout/CharacterName
@onready var _delete_button: Button = $DeleteButton


func _ready() -> void:
	_main_button.pressed.connect(_on_main_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_slot_name_color = _slot_name.get_theme_color("font_color")
	_character_name_color = _character_name.get_theme_color("font_color")
	_active_text_color = GameColors.to_color(GameColors.ACCENT_TEXT)
	_accent_normal = _make_accent_style(&"normal")
	_accent_hover = _make_accent_style(&"hover")
	_accent_pressed = _make_accent_style(&"pressed")
	_apply_delete_style()
	_update_delete_button_rect()
	set_slot(0, false, "", false)


## 更新槽位显示；active 为当前正在玩的槽，不显示删除按钮并加绿底
func set_slot(slot: int, occupied: bool, character_name: String, active: bool) -> void:
	var was_active := _active
	_slot = slot
	_occupied = occupied
	_active = active
	_slot_name.text = "存档 %d" % (slot + 1) if occupied else "空"
	_character_name.visible = occupied
	_character_name.text = character_name
	_main_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if occupied
		else Control.MOUSE_FILTER_IGNORE
	)
	_delete_button.visible = occupied and not active
	_refresh_delete_tooltip()
	if not occupied or active:
		set_confirming(false)
	if was_active != active:
		_apply_active_visual(active)


## 测试/调试：模拟点击主按钮；空槽返回 false
func activate() -> bool:
	if not _occupied:
		return false
	_main_button.pressed.emit()
	return true


## 测试/调试：模拟点击删除按钮；空槽和活动槽返回 false
func activate_delete() -> bool:
	if not _occupied or _active:
		return false
	_delete_button.pressed.emit()
	return true


## 当前槽是否处于删除确认态
func is_confirming() -> bool:
	return _confirming


## 进入/退出二次确认；退出时把按钮恢复成 ×
func set_confirming(confirming: bool) -> void:
	if _confirming == confirming:
		return
	_confirming = confirming
	_delete_button.text = DELETE_CONFIRM_TEXT if confirming else DELETE_TEXT
	_refresh_delete_tooltip()
	_update_delete_button_rect()


func _on_main_pressed() -> void:
	set_confirming(false)
	slot_requested.emit()


func _on_delete_pressed() -> void:
	if not _occupied or _active:
		return
	if not _confirming:
		set_confirming(true)
		delete_confirmation_started.emit()
		return
	set_confirming(false)
	delete_requested.emit()


## 活动槽用置顶按钮同款绿底 + 深色文字；切走时恢复主题样式
func _apply_active_visual(active: bool) -> void:
	if active:
		_main_button.add_theme_stylebox_override("normal", _accent_normal)
		_main_button.add_theme_stylebox_override("hover", _accent_hover)
		_main_button.add_theme_stylebox_override("pressed", _accent_pressed)
		_slot_name.add_theme_color_override("font_color", _active_text_color)
		_character_name.add_theme_color_override("font_color", _active_text_color)
		return
	_main_button.remove_theme_stylebox_override("normal")
	_main_button.remove_theme_stylebox_override("hover")
	_main_button.remove_theme_stylebox_override("pressed")
	_slot_name.add_theme_color_override("font_color", _slot_name_color)
	_character_name.add_theme_color_override("font_color", _character_name_color)


func _make_accent_style(state: StringName) -> StyleBoxFlat:
	var base := _main_button.get_theme_stylebox(state)
	var style: StyleBoxFlat = null
	if base != null:
		style = base.duplicate() as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
	style.bg_color = GameColors.to_color(GameColors.ACCENT)
	return style


func _refresh_delete_tooltip() -> void:
	_delete_button.tooltip_text = (
		"再次点击删除存档 %d" % (_slot + 1)
		if _confirming
		else "删除存档 %d" % (_slot + 1)
	)


func _update_delete_button_rect() -> void:
	var width := DELETE_CONFIRM_WIDTH if _confirming else DELETE_WIDTH
	_delete_button.offset_left = -DELETE_MARGIN - width
	_delete_button.offset_top = DELETE_MARGIN
	_delete_button.offset_right = -DELETE_MARGIN
	_delete_button.offset_bottom = DELETE_MARGIN + DELETE_HEIGHT


func _apply_delete_style() -> void:
	var danger := GameColors.to_color(GameColors.DANGER)
	_delete_button.add_theme_stylebox_override("normal", _make_style(danger))
	_delete_button.add_theme_stylebox_override("hover", _make_style(danger.lightened(0.14)))
	_delete_button.add_theme_stylebox_override("pressed", _make_style(danger.darkened(0.16)))
	_delete_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text_color := GameColors.to_color(GameColors.TEXT_PRIMARY)
	_delete_button.add_theme_color_override("font_color", text_color)
	_delete_button.add_theme_color_override("font_hover_color", text_color)
	_delete_button.add_theme_color_override("font_pressed_color", text_color)
	_delete_button.add_theme_font_size_override("font_size", 13)


func _make_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(DELETE_HEIGHT * 0.5)
	style.corner_radius_top_right = int(DELETE_HEIGHT * 0.5)
	style.corner_radius_bottom_left = int(DELETE_HEIGHT * 0.5)
	style.corner_radius_bottom_right = int(DELETE_HEIGHT * 0.5)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style
