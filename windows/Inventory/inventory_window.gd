class_name InventoryWindow
extends BaseWindow

const WAREHOUSE_SCRIPT: GDScript = preload("res://scripts/warehouse.gd")
const PAGE_BUTTON_SIZE: Vector2 = Vector2(30, 26)

@onready var inventory_view: InventoryView = $InventoryView
@onready var page_bar: HBoxContainer = $PageBar

var _page_buttons: Array[Button] = []
var _page_group: ButtonGroup = ButtonGroup.new()
var _current_page: int = 0


func _ready() -> void:
	super()
	title = "仓库窗口"

	_build_page_bar()
	set_page(0)


func get_page() -> int:
	return _current_page


func set_page(page: int) -> void:
	page = clampi(page, 0, Warehouse.PAGE_COUNT - 1)
	_current_page = page
	for index in _page_buttons.size():
		_page_buttons[index].set_pressed_no_signal(index == page)
	var container_name: String = WAREHOUSE_SCRIPT.page_name(page)
	if inventory_view.container_name != container_name:
		inventory_view.change_data_source(container_name)


func _build_page_bar() -> void:
	page_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_group.allow_unpress = false
	for page in Warehouse.PAGE_COUNT:
		var button := Button.new()
		button.text = str(page + 1)
		button.custom_minimum_size = PAGE_BUTTON_SIZE
		button.toggle_mode = true
		button.button_group = _page_group
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(set_page.bind(page))
		page_bar.add_child(button)
		_apply_selected_style(button)
		_page_buttons.append(button)


func _apply_selected_style(button: Button) -> void:
	var pressed_style := button.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	if pressed_style == null:
		pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = GameColors.to_color(GameColors.ACCENT)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("hover_pressed", pressed_style)
	var text_color := GameColors.to_color(GameColors.ACCENT_TEXT)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_hover_pressed_color", text_color)
