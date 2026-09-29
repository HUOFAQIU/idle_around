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
	await _step_tooltip()
	await _step_hover_highlight_hidden_behind_items()

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
	kit.check("锁子甲落在最靠右那列 (23, 1)", armor.cell, Vector2i(23, 1))


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
	kit.check("东西回到原位 (23, 1)", armor.cell, Vector2i(23, 1))
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
	await kit.put_cursor_at(equip, (slot.get_node("HBoxContainer/EquipmentSlot") as Control).get_global_rect().get_center())
	await kit.shot(equip, "05_卸下前", "武器那一行装着弓，槽里有东西")
	await kit.deliver_click(equip, true, MOUSE_BUTTON_RIGHT)
	await kit.deliver_click(equip, false, MOUSE_BUTTON_RIGHT)
	await get_tree().process_frame
	await kit.shot(equip, "06_卸下后", "武器槽空了；仓库那边临时页按钮应该亮出来")
	kit.check("临时页按钮冒出来了", temp_button.visible, true)
	await kit.shot(inv, "07_临时页按钮", "仓库左上角多了一个红色的「临」")


func _step_soul_drag_leaves_no_ghost() -> void:
	kit.note("步骤 5：拖一颗魂灵到装备窗口，落在一条空行上（放不下）—— 松手后装备窗口必须跟拖之前一模一样")
	# 冷却线每帧都在动，先定住，好做逐像素比较：
	# 把扫描线的周期拉到极长（等于不推进），身上的进度再归零
	for row in panel.get_children():
		if row is SlotCell:
			var slot := row as SlotCell
			slot.cooldown_seconds = 1000000.0
			if slot.equipment:
				for soul in slot.equipment.souls:
					soul.cd_progress = 0.0
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


func _step_tooltip() -> void:
	kit.note("步骤 6：hover 提示框 —— 装备弹装备那个（名字 + 魂灵区），魂灵弹魂灵那个（名字 + 冷却 + 技能说明）")
	# 提示框是鼠标移动事件驱动 `_update_hover()` 弹出来的。
	# 这个测试台造不出能送进子窗口的移动事件（按下 / 松开能送，移动送进去没人收），
	# 所以直接调网格自己的 hover 处理函数——走的还是真实那条路（找物品 → 挑提示框 → 填内容 → 摆位），
	# 只是触发的人从鼠标换成了测试。**指针悬停本身没被这条步骤覆盖**。
	# 用身体那件（锁子甲）：它还在仓库第一页上，身上挂着「疾风」，提示框里看得见魂灵。
	# 弓这会儿已经被换到装备窗口、又卸进临时页了，第一页上找不着
	var armor := _find_part(Equipment.Part.BODY)
	var soul := _first_loose_soul()
	var equip_tip := _tooltip(EquipmentTooltip)
	var soul_tip := _tooltip(SoulTooltip)

	grid._update_hover(_cell_center(armor.cell) + Vector2(16, 16))
	await get_tree().process_frame
	kit.check("悬停装备后装备提示框浮出来了", equip_tip.visible, true)
	kit.check("提示框里是这件装备的名字", equip_tip.get_node("BG/VBoxContainer/NameLabel").text, armor.name)
	kit.check("魂灵那个没跟着浮出来", soul_tip.visible, false)
	print("   装备提示框尺寸=", equip_tip.size)
	await kit.shot(inv, "10_提示框_装备", "锁子甲的提示框：名字在上，底下一整片魂灵区（疾风按自己的位置摆着）")

	grid._update_hover(_cell_center(soul.cell) + Vector2(8, 16))
	await get_tree().process_frame
	kit.check("悬停魂灵后魂灵提示框浮出来了", soul_tip.visible, true)
	kit.check("提示框里是魂灵的名字", soul_tip.get_node("BG/VBoxContainer/NameLabel").text, soul.name)
	kit.check("装备那个收起来了", equip_tip.visible, false)
	# 魂灵提示框就是 soul_tooltip.tscn 那个场景的样子（名字 + 冷却 + 技能说明），
	# 只有名字是这颗魂灵的；冷却 / 技能那两块还是场景里的占位文字
	kit.check("冷却是场景里那块（照场景显示）", soul_tip.get_node("BG/VBoxContainer/SkillPanel").visible, true)
	print("   魂灵提示框尺寸=", soul_tip.size)
	kit.check("框按场景的版面撑开（名字那行 + 64 高的技能块）", soul_tip.size.y > 64.0, true)
	await kit.shot(inv, "11_提示框_魂灵", "魂灵的提示框：上面名字，下面冷却秒数和技能说明（后两样还是占位文字）")

	# 挪到空白处：提示框该收起来，别留在屏幕上
	grid._update_hover(_cell_center(Vector2i(20, 20)))
	await get_tree().process_frame
	kit.check("移到空处两个提示框都收起来了", equip_tip.visible or soul_tip.visible, false)
	await kit.shot(inv, "12_提示框收起", "提示框没了，只剩鼠标底下那个空格子的 hover 框")


func _step_hover_highlight_hidden_behind_items() -> void:
	kit.note("步骤 7：hover 高亮该被东西挡住 —— 悬停东西时它身上不该被画上白框，空格子上才看得见")
	var soul := _first_loose_soul()

	# 底图：把 hover 清掉（跟鼠标移出网格一个效果），拍一张干净的
	grid._update_hover(Vector2(-1, -1))
	await _turn_off_tooltip()
	var clean := await kit.grab(inv)

	# 悬停位置就用这一格的正中：高亮画的是**指针底下那一格**，多点一点就落到下一格去了。
	# 魂灵占 2×2 格，所以悬停它左上那格时，白框的右边和下边都落在魂灵自己身上——那正是要验的地方
	var body := Rect2i(Vector2i(grid.global_position) + soul.cell * CELL, soul.cells() * CELL)
	grid._update_hover(_cell_center(soul.cell))
	await _turn_off_tooltip()
	kit.check("悬停魂灵：魂灵那块跟没悬停时逐像素一样（高亮被它挡住了）",
		_same_region(clean, await kit.grab(inv), body), true)
	await kit.shot(inv, "13_悬停魂灵_高亮被挡住", "魂灵那块干干净净，白框没有压在它上面")

	# 反过来也要成立：空格子上没东西挡，高亮得照样看得见
	var empty := Vector2i(20, 20)
	grid._update_hover(_cell_center(empty))
	await _turn_off_tooltip()
	var cell_rect := Rect2i(Vector2i(grid.global_position) + empty * CELL, Vector2i(CELL, CELL))
	kit.check("悬停空格子：那块跟没悬停时不一样（高亮还看得见）",
		_same_region(clean, await kit.grab(inv), cell_rect), false)
	await kit.shot(inv, "14_悬停空格_高亮看得见", "空格子上白框照旧——没东西挡它")


## 比像素前把提示框请走：它每帧在 `_process` 里跟着**真光标**走
## （`tip.place_near(get_local_mouse_position(), ...)`），而这条场景没在动真光标，
## 它会停在别处，混进比较里就分不清哪块是高亮画的了。注意只藏框，`_hover_cell` 保持不动
func _turn_off_tooltip() -> void:
	grid._hide_tips()
	await get_tree().process_frame


## 两张图里同一块矩形是不是逐像素一样
func _same_region(a: Image, b: Image, rect: Rect2i) -> bool:
	for y in range(rect.position.y, mini(rect.end.y, mini(a.get_height(), b.get_height()))):
		for x in range(rect.position.x, mini(rect.end.x, mini(a.get_width(), b.get_width()))):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				return false
	return true


# ---------------------------------------------------------------- 小工具

func _page_items() -> Array:
	return grid.pages[0]


## 仓库上挂着的提示框（浮没浮出来是用户直接看得见的东西）。
## 传类：`_tooltip(EquipmentTooltip)` / `_tooltip(SoulTooltip)`
func _tooltip(kind: Variant) -> Control:
	for child in grid.get_children():
		if is_instance_of(child, kind):
			return child
	return null


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
