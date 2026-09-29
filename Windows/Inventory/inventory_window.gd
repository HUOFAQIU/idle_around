extends BaseWindow

## 普通页数（后面还会多 1 页临时页）
const PAGE_COUNT : int = 5
## 临时页按钮上的字，用红色标出来
const TEMP_BUTTON_TEXT : String = "临"
const COLOR_TEMP_BUTTON := Color(0.90, 0.32, 0.32)

@onready var pagination: HBoxContainer = $MarginContainer/VBoxContainer/Pagination
@onready var grid: InventoryGrid = $MarginContainer/VBoxContainer/Grid

var _page_buttons : Array[Button] = []


func _ready() -> void:
	super()
	title = "仓库窗口"

	# 铺满窗口的一层：手上拖着的东西鼠标走到哪儿都看得见（不然只有网格那一块会摆它）。
	# 装备只能在仓库里挪位置，所以这一层也是唯一要看装备的
	var overlay := DragOverlay.new()
	overlay.allow_equipment = true
	add_child(overlay)

	grid.set_page_count(PAGE_COUNT)
	_build_pagination()
	grid.page_changed.connect(_on_page_changed)
	grid.inventory_changed.connect(_refresh_temp_button)
	grid.item_right_clicked.connect(_on_item_right_clicked)
	_fill_demo_page()

	var panel := _equipment_panel()
	if panel:
		panel.equipment_removed.connect(_on_equipment_removed)


# 左上方分页：每页一个按钮，点哪个翻到哪页；最后一页是临时页，红的
func _build_pagination() -> void:
	var group := ButtonGroup.new()
	for i in grid.page_count():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(28, 28)
		if grid.is_temp_page(i):
			button.text = TEMP_BUTTON_TEXT
			button.tooltip_text = "临时页：换装换下来的东西堆在这儿，只能取不能存"
			button.add_theme_color_override("font_color", COLOR_TEMP_BUTTON)
		else:
			button.text = str(i + 1)
		button.pressed.connect(_on_page_button_pressed.bind(i))
		pagination.add_child(button)
		_page_buttons.append(button)
	_update_page_buttons(grid.page)
	_refresh_temp_button()


func _on_page_button_pressed(p_page: int) -> void:
	grid.set_page(p_page)


func _on_page_changed(p_page: int) -> void:
	_update_page_buttons(p_page)


func _update_page_buttons(p_page: int) -> void:
	if p_page >= 0 and p_page < _page_buttons.size():
		_page_buttons[p_page].button_pressed = true


# 临时页空着就把那个红按钮藏起来；正站在临时页上又空了就退回第一页
func _refresh_temp_button() -> void:
	var index := grid.temp_page_index()
	var empty := grid.temp_page_is_empty()
	_page_buttons[index].visible = not empty
	if empty and grid.page == index:
		grid.set_page(0)


# ---------------------------------------------------------------- 换装

# 右键仓库里的装备 = 换上它。只有在装备窗口开着的时候才管用。
func _on_item_right_clicked(item: InventoryItem) -> void:
	if not (item is Equipment):
		return
	var panel := _equipment_panel()
	if panel == null or not panel.is_visible_in_tree():
		return

	# 先把装备从仓库里拿走，再装到对应部位上
	# （原来那件会被顶下来，走 equipment_removed 信号进临时页）
	grid.remove_item(item)
	panel.equip(item)


# 从装备窗口里出来的那件（换下来的、右键卸下来的）连同它身上的魂灵一起丢进临时页
func _on_equipment_removed(equipment: Equipment) -> void:
	grid.add_to_temp_page(equipment)
	for soul in equipment.souls:
		grid.add_to_temp_page(soul)
	equipment.souls.clear()


func _equipment_panel() -> EquipmentPanel:
	return get_tree().get_first_node_in_group("equipment_panel")


# ---------------------------------------------------------------- 演示数据

# 第一页摆一点东西出来看：六个部位各一件，外加几颗散着的魂灵
# （装备掉落还没做，在掉落系统出来之前先这么放着）
func _fill_demo_page() -> void:
	# 武器：弓，身上装着一颗弓手（中 2 格宽）+ 一颗石肤（大 3 格宽），挨着排
	var bow := _equipment(Equipment.Part.WEAPON, InventoryItem.Size.MEDIUM, Vector2i(1, 1), "弓")
	bow.place_soul(_make_soul("弓手", InventoryItem.Size.MEDIUM), Vector2i(0, 0))

	_equipment(Equipment.Part.HEAD, InventoryItem.Size.MEDIUM, Vector2i(4, 1), "皮帽")
	# 身体：锁子甲上挂一颗小的（1 格宽），想放哪一列就放哪一列
	var armor := _equipment(Equipment.Part.BODY, InventoryItem.Size.LARGE, Vector2i(7, 1), "锁子甲")
	armor.place_soul(_make_soul("疾风", InventoryItem.Size.SMALL), Vector2i(4, 0))
	_equipment(Equipment.Part.FOOT, InventoryItem.Size.MEDIUM, Vector2i(11, 1), "软靴")
	_equipment(Equipment.Part.NECK, InventoryItem.Size.SMALL, Vector2i(1, 4), "护身符")
	_equipment(Equipment.Part.RING, InventoryItem.Size.SMALL, Vector2i(4, 4), "铜戒")

	# 散着的魂灵，三档各一颗，等着被拖到装备上
	_soul(Vector2i(1, 7), "剑士", InventoryItem.Size.SMALL)
	_soul(Vector2i(4, 7), "狼魂", InventoryItem.Size.MEDIUM)
	_soul(Vector2i(7, 7), "巨力", InventoryItem.Size.LARGE)


func _equipment(part: Equipment.Part, size: InventoryItem.Size, cell: Vector2i, item_name: String) -> Equipment:
	var equipment := Equipment.new(part, size, cell)
	equipment.name = item_name
	grid.add_item(equipment, 0)
	return equipment


## 散在仓库里的魂灵
func _soul(cell: Vector2i, soul_name: String, size: InventoryItem.Size) -> Soul:
	var soul := _make_soul(soul_name, size)
	soul.cell = cell
	grid.add_item(soul, 0)
	return soul


## 只造一颗魂灵，不进仓库（装在装备上的走 place_soul()）
func _make_soul(soul_name: String, size: InventoryItem.Size) -> Soul:
	return Soul.new(Vector2i.ZERO, soul_name, size)
