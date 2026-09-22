extends Control

## E2E：仓库 / 装备窗口最近改的四条行为
##   跑法：godot --path . res://Tests/e2e_warehouse.tscn
##   产物：Tests/shots/*.png + Tests/shots/report.txt
##
## 从真实入口 control.tscn 起，点的是真按钮、送的是真鼠标事件；
## 判定只看**用户看得见的东西**（东西落在哪一格、窗口开没开、临时页按钮出没出现、截图像不像）。
## 测试里需要「找到要操作的那件东西」时才去看 grid.pages（这是为了拿到操作对象，不是断言内部状态）。

const CELL : int = InventoryItem.CELL_SIZE

var kit := E2EKit.new("warehouse")
var app : Control
var inv : Window
var equip : Window
var grid : InventoryGrid
var panel : EquipmentPanel


func _ready() -> void:
	app = load("res://control.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame

	await _step_open_warehouse()
	await _step_drag_past_right_edge()
	await _step_drag_out_of_window()
	await _step_unequip_to_temp_page()
	await _step_soul_drag_leaves_no_ghost()

	kit.finish("仓库/装备窗口 E2E")
	get_tree().quit()


# ---------------------------------------------------------------- 步骤

func _step_open_warehouse() -> void:
	kit.note("步骤 1：点主界面的「仓库」按钮（走真实按钮的回调）")
	(app.get_node("GridContainer/Button3") as Button).pressed.emit()
	await get_tree().process_frame
	inv = app.get_node("InventoryWindow")
	grid = inv.get_node("MarginContainer/VBoxContainer/Grid")
	kit.check("仓库窗口打开了", inv.visible, true)
	kit.check("第一页有 6 件装备 + 3 颗散魂灵", _page_items().size(), 9)
	await kit.shot(inv, "01_仓库打开", "第一页：六个部位各一件、三颗散着的魂灵")


func _step_drag_past_right_edge() -> void:
	var armor := _find_part(Equipment.Part.BODY)
	kit.note("步骤 2：按住锁子甲往右拖过头（超出第 25 列），松手 —— 应该落在还放得下的最靠右那列")
	await kit.put_cursor_at(inv, _grid_point(armor.cell))
	await kit.press(inv)
	# 拖 17 格：已经越过「整件收边」的阈值，但光标还在窗口里
	# （拖更远等于把光标推出窗口，装备一出去这次拖动就作废了，那是另一条规则、另一步测）
	await kit.shift_cursor_in(inv, Vector2(17 * CELL, 0))
	kit.check("光标还在仓库窗口里", Rect2i(inv.position, inv.size).has_point(DisplayServer.mouse_get_position()), true)
	await kit.shot(inv, "02_拖过头", "锁子甲贴在网格最右边，落点框也是绿的（收边后的位置）")
	await kit.release(inv)
	kit.check("锁子甲落在最靠右那列 (22, 1)", armor.cell, Vector2i(22, 1))


func _step_drag_out_of_window() -> void:
	var armor := _find_part(Equipment.Part.BODY)
	kit.note("步骤 3：再按住它、往左拖 12 格，然后把窗口挪开让鼠标出窗口 —— 这次拖动该作废、东西回原位")
	await kit.put_cursor_at(inv, _grid_point(armor.cell))
	await kit.press(inv)
	await kit.shift_cursor_in(inv, Vector2(-12 * CELL, 0))
	# 窗口挪到屏幕外：鼠标就不在仓库窗口里了
	inv.position += Vector2i(400, 400)
	await get_tree().process_frame
	await get_tree().process_frame
	kit.check("东西回到原位 (22, 1)", armor.cell, Vector2i(22, 1))
	kit.check("还躺在仓库里（没被谁拿走）", _page_items().has(armor), true)
	await kit.release(inv)
	await kit.put_cursor_at(inv, Vector2(200, 200))
	await kit.shot(inv, "03_拖出窗口作废", "锁子甲还在最右边那一列，没有被拖出去")


func _step_unequip_to_temp_page() -> void:
	kit.note("步骤 4：开装备窗口 → 右键仓库里的弓（换上）→ 右键装备槽（卸下）→ 临时页按钮该冒出来")
	(app.get_node("GridContainer/Button2") as Button).pressed.emit()
	await get_tree().process_frame
	equip = app.get_node("EquipmentWindow")
	panel = equip.get_node("Panel")
	kit.check("装备窗口打开了", equip.visible, true)

	var temp_button : Button = inv.get_node("MarginContainer/VBoxContainer/Pagination").get_child(
		inv.get_node("MarginContainer/VBoxContainer/Pagination").get_child_count() - 1)
	kit.check("临时页按钮一开始是藏着的", temp_button.visible, false)

	var bow := _find_part(Equipment.Part.WEAPON)
	await kit.put_cursor_at(inv, _grid_point(bow.cell))
	await kit.deliver_click(inv, true, MOUSE_BUTTON_RIGHT)
	await kit.deliver_click(inv, false, MOUSE_BUTTON_RIGHT)
	await kit.shot(inv, "04_右键换装后", "仓库里少了一件（弓被换到装备窗口）")

	var slot : SlotCell = _row(Equipment.Part.WEAPON)
	await kit.put_cursor_at(equip, (slot.get_node("HBoxContainer/EquipmentTextureRect") as Control).get_global_rect().get_center())
	await kit.shot(equip, "05_卸下前", "武器那一行装着弓，槽里有东西")
	await kit.deliver_click(equip, true, MOUSE_BUTTON_RIGHT)
	await kit.deliver_click(equip, false, MOUSE_BUTTON_RIGHT)
	await get_tree().process_frame
	await kit.shot(equip, "06_卸下后", "武器槽空了；仓库那边临时页按钮应该亮出来")
	kit.check("临时页按钮冒出来了", temp_button.visible, true)
	await kit.shot(inv, "07_临时页按钮", "仓库左上角多了一个红色的「临」")


func _step_soul_drag_leaves_no_ghost() -> void:
	kit.note("步骤 5：拖一颗魂灵到装备窗口，落在一条空行上（放不下）—— 松手后装备窗口必须跟拖之前一模一样")
	# 冷却线每帧都在动，先定住，好做逐像素比较
	for item in _page_items():
		if item is Soul:
			(item as Soul).interval = 1000000.0
			(item as Soul).cd_progress = 0.0
	await get_tree().process_frame

	var soul := _first_loose_soul()
	var before := await kit.grab(equip)

	await kit.put_cursor_at(inv, _grid_point(soul.cell))
	await kit.press(inv)
	# 把装备窗口挪到光标底下：光标就从仓库跑到装备窗口的某一空行上了
	var head : SlotCell = _row(Equipment.Part.HEAD)
	await kit.put_cursor_at(equip, head.get_global_rect().get_center())
	await get_tree().process_frame
	var during := await kit.grab(equip)
	kit.check("拖着的时候装备窗口上多了东西", during.get_data() != before.get_data(), true)
	await kit.shot(equip, "08_拖动中", "空行上浮着那颗魂灵（跟着光标），但这一行没有装备，放不下")

	await kit.release(equip)
	await get_tree().process_frame
	await get_tree().process_frame
	var after := await kit.grab(equip)
	kit.check("松手之后装备窗口跟没拖过一样（没留残影）", after.get_data() == before.get_data(), true)
	await kit.shot(equip, "09_松手后", "那颗魂灵不见了，空行恢复原样")


# ---------------------------------------------------------------- 小工具

func _page_items() -> Array:
	return grid.pages[0]


func _find_part(part: Equipment.Part) -> Equipment:
	for item in _page_items():
		if item is Equipment and (item as Equipment).part == part:
			return item
	return null


func _first_loose_soul() -> Soul:
	for item in _page_items():
		if item is Soul:
			return item
	return null


func _row(part: Equipment.Part) -> SlotCell:
	for child in panel.get_children():
		if child is SlotCell and (child as SlotCell).part == part:
			return child
	return null


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL) + Vector2(CELL / 2.0, CELL / 2.0)


## 格子坐标 → 窗口坐标（网格在窗口里还隔着边距和分页栏，得加上它自己的位置）
func _grid_point(cell: Vector2i) -> Vector2:
	return Vector2(grid.global_position) + _cell_center(cell)
