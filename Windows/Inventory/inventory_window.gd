class_name InventoryWindow
extends BaseWindow

## 页码按钮尺寸
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

	GBIS.sig_item_focused.connect(
		func (item_data: ItemData, container_name: String):
			# 只有魂灵有正文；其他物品保持原来的单行标题提示
			var body := ""
			if item_data is SoulData:
				body = SoulTooltip.build(item_data as SoulData, true)
			TooltipWindow.instance.show_tip(self, TooltipWindow.Layer.ITEM, item_data.item_name, body)
	)
	GBIS.sig_item_focus_lost.connect(
		func (item_data: ItemData):
			TooltipWindow.instance.hide_tip(self)
	)


## 当前页（0 起）
func get_page() -> int:
	return _current_page


## 切到指定页（0 起）；越界自动夹到有效范围
func set_page(page: int) -> void:
	page = clampi(page, 0, Warehouse.PAGE_COUNT - 1)
	_current_page = page
	for index in _page_buttons.size():
		_page_buttons[index].set_pressed_no_signal(index == page)
	var container_name := Warehouse.page_name(page)
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


## 当前页按钮用 ACCENT 底色 + 深色文字，和顶部状态栏的开关一致
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
