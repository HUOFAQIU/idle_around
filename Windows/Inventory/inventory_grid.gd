class_name InventoryGrid
extends Control

## 每格的像素边长（跟装备面板共用同一格）
const CELL_SIZE : int = InventoryItem.CELL_SIZE
## 每页的格数：宽 × 高（格子 16 → 32 之后减半，一页还是 800×800 像素）
const PAGE_CELLS : Vector2i = Vector2i(25, 25)

const COLOR_BG := Color(0.10, 0.11, 0.14)
const COLOR_LINE := Color(0.21, 0.23, 0.28)
const COLOR_HOVER := Color(1.0, 1.0, 1.0, 0.35)
## 拖动时落点框：放得下 / 放不下
const COLOR_DROP_OK := Color(0.45, 0.95, 0.55, 0.9)
const COLOR_DROP_BAD := Color(0.95, 0.35, 0.35, 0.9)
## 色块上的装备名字号（色块本身怎么画见 `Scripts/item_draw.gd`）
## 格子变大，字也跟着大一点（14 像素时最小的 1×2 也写得下两个字）
const NAME_FONT_SIZE : int = 14

## 详情面板的颜色
const COLOR_PANEL_BG := Color(0.13, 0.14, 0.18, 0.97)
const COLOR_PANEL_BORDER := Color(0.45, 0.48, 0.58)
const COLOR_SOUL_EMPTY := Color(0.20, 0.21, 0.26)
## 详情面板里魂灵区的格线
const COLOR_SOUL_LINE := Color(0.45, 0.48, 0.58, 0.30)
## 详情里的魂灵区是缩略图，一格画 16 像素（免得提示框比仓库还大）
const DETAIL_SOUL_CELL : int = 16
## 详情面板跟鼠标隔开多少像素
const DETAIL_GAP : float = 18.0

## 翻页时发出，参数是新页码（从 0 开始）
signal page_changed(page: int)
## 右键点了某件东西（窗口拿去判断能不能换上装备）
signal item_right_clicked(item: InventoryItem)
## 页里的东西有增减，窗口拿去刷新临时页那个红按钮
signal inventory_changed

## 当前页码，从 0 开始
var page : int = 0
## 每页一个数组，里面是 InventoryItem；下标就是页码
var pages : Array = []

var _hover_cell : Vector2i = Vector2i(-1, -1)

## 手上拖着的物品，没在拖就是 null（拖动期间它不在 pages 里）
var _dragging : InventoryItem = null
## 抓在物品内部的哪个位置，拖动时物品才不会跳到鼠标左上角
var _drag_offset : Vector2 = Vector2.ZERO
## 拖动开始时物品所在的格，放不下就送回这里
var _drag_from : Vector2i = Vector2i.ZERO
## 拖动中的鼠标位置（本控件局部坐标）
var _drag_pos : Vector2 = Vector2.ZERO

## 鼠标指到装备时浮出来的详情面板
var _detail_panel : PanelContainer
var _detail_name : Label
var _detail_damage : Label
## 物理伤害那一行和它下面的分隔线，没伤害的装备（比如护甲）整行藏起来
var _detail_damage_divider : ColorRect
## 详情面板里那片迷你魂灵区，画的是 _detail_equipment 身上的魂灵
var _soul_area : Control
var _detail_equipment : Equipment = null


func _ready() -> void:
	custom_minimum_size = Vector2(PAGE_CELLS * CELL_SIZE)
	mouse_exited.connect(_on_mouse_exited)
	# 别人拖着的东西在我这儿画过一帧，松手了得擦掉
	GameGlobal.drag_ended.connect(queue_redraw)
	_build_detail_panel()
	# 别人往我这儿拖东西（比如装备面板拖出来的魂灵）时能找到我
	add_to_group("drop_target")


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_LEFT:
			_start_drag(button.position)
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_right_click(button.position)
		return

	var motion := event as InputEventMouseMotion
	if motion and _dragging == null:
		_update_hover(motion.position)


# 详情面板跟着鼠标走；拖动期间每帧跟住鼠标，松开左键就放下
# （在网格外松开也算，所以在这里收尾）
func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return

	var mouse := get_local_mouse_position()
	if _detail_panel.visible:
		_place_detail_panel(mouse)

	# 别人正拖着东西：鼠标在我这个窗口里就得跟着重画，不然看不到手上拿着什么
	if GameGlobal.dragged_item and _mouse_in_window():
		queue_redraw()

	if _dragging == null:
		return
	_drag_pos = mouse
	queue_redraw()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_drag()
		return

	# 装备不许拖出仓库窗口（只能在仓库里挪位置），鼠标一出去这次拖动作废
	# 魂灵不在此列：它还得拖到装备窗口去
	if _dragging is Equipment and not _mouse_in_window():
		_cancel_drag()


func _draw() -> void:
	var grid_size := Vector2(PAGE_CELLS * CELL_SIZE)

	# 底板铺满整个控件，再画格子线（+0.5 让 1 像素的线落在像素中心，不会糊）
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	for x in PAGE_CELLS.x + 1:
		var px := float(x * CELL_SIZE) + 0.5
		draw_line(Vector2(px, 0.0), Vector2(px, grid_size.y), COLOR_LINE)
	for y in PAGE_CELLS.y + 1:
		var py := float(y * CELL_SIZE) + 0.5
		draw_line(Vector2(0.0, py), Vector2(grid_size.x, py), COLOR_LINE)

	# 物品：色块 + 一圈深色描边 + 名字
	for item in get_page_items():
		ItemDraw.block(self, _item_rect(item), item, NAME_FONT_SIZE)

	if _dragging and _mouse_in_window():
		# 手上的物品跟着鼠标走（鼠标出了这个窗口就不画了：那是 DragGhost 的活儿，
		# 不然会同时看到「跟手的一个」和「停在窗口边的那个」）
		var cells := _dragging.cells()
		ItemDraw.block(self, _block_rect(_drag_pos - _drag_offset, cells), _dragging, NAME_FONT_SIZE)
		# 会落在哪：放得下画绿框，放不下画红框（画在色块上面，免得被挡住）
		# 框画的就是收边之后的落点，所以看到框在哪就是落在哪
		var target := _drag_cell(_dragging)
		var fits := can_place(Rect2i(target, cells), page)
		draw_rect(_cell_rect(target, cells), COLOR_DROP_OK if fits else COLOR_DROP_BAD, false, 2.0)
	elif GameGlobal.dragged_item and _mouse_in_window():
		# 别人拖着的东西路过我这儿：画在指针上（谁在鼠标底下谁负责画）
		var foreign := GameGlobal.dragged_item
		var block_size := Vector2(foreign.cells() * CELL_SIZE)
		ItemDraw.block(self, Rect2(get_local_mouse_position() - GameGlobal.dragged_offset, block_size), foreign, NAME_FONT_SIZE)
	elif _hover_cell.x >= 0:
		# 鼠标指着的格子
		draw_rect(_cell_rect(_hover_cell), COLOR_HOVER, false, 1.0)



# ---------------------------------------------------------------- 详情面板

# 鼠标指到装备时浮出来的小面板：名字 / 物理伤害 / 魂灵槽（2×2）
func _build_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.z_index = 10
	# 不拦鼠标，否则面板跟到指针底下就把 hover 顶掉了
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_detail_panel.add_theme_stylebox_override("panel", style)
	add_child(_detail_panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	_detail_panel.add_child(box)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 16)
	box.add_child(_detail_name)
	box.add_child(_make_divider())

	_detail_damage = Label.new()
	_detail_damage.add_theme_font_size_override("font_size", 13)
	box.add_child(_detail_damage)
	_detail_damage_divider = _make_divider()
	box.add_child(_detail_damage_divider)

	# 魂灵区：一排 10 格的原样缩略图（自己画，不走子节点）
	_soul_area = Control.new()
	_soul_area.custom_minimum_size = Vector2(Equipment.SOUL_AREA * DETAIL_SOUL_CELL)
	# 靠左、别跟着面板拉宽
	_soul_area.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_soul_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_soul_area.draw.connect(_draw_soul_area)
	box.add_child(_soul_area)


func _make_divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = COLOR_PANEL_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


# 鼠标底下有装备就显示详情，没有就藏起来
func _update_detail(local_pos: Vector2) -> void:
	var item : InventoryItem = null
	if _hover_cell.x >= 0 and _dragging == null:
		item = item_at(_hover_cell)
	if item == null:
		_detail_panel.visible = false
		return

	_detail_name.text = item.name if not item.name.is_empty() else "？？"
	# 护甲这类没有伤害的东西，物理伤害整行不显示
	var has_damage := item.damage.y > 0
	_detail_damage.visible = has_damage
	_detail_damage_divider.visible = has_damage
	if has_damage:
		_detail_damage.text = "物理伤害：%d-%d" % [item.damage.x, item.damage.y]

	# 魂灵区：把整片区域连着魂灵一起画出来；魂灵自己身上没有区，整块不显示
	_detail_equipment = item as Equipment
	_soul_area.visible = _detail_equipment != null
	_soul_area.queue_redraw()

	_detail_panel.visible = true
	_place_detail_panel(local_pos)


# 详情里的迷你魂灵区：一排 10 格，魂灵按自己的大小摆在各自的格子上
func _draw_soul_area() -> void:
	var equipment := _detail_equipment
	if equipment == null:
		return

	var area := Rect2(Vector2.ZERO, Vector2(Equipment.SOUL_AREA * DETAIL_SOUL_CELL))
	_soul_area.draw_rect(area, COLOR_SOUL_EMPTY)
	for col in Equipment.SOUL_AREA.x + 1:
		var px := float(col * DETAIL_SOUL_CELL) + 0.5
		_soul_area.draw_line(Vector2(px, area.position.y), Vector2(px, area.end.y), COLOR_SOUL_LINE)
	_soul_area.draw_rect(area, COLOR_PANEL_BORDER, false, 1.0)

	for soul in equipment.souls:
		var rect := Rect2(Vector2(soul.cell * DETAIL_SOUL_CELL), Vector2(soul.cells() * DETAIL_SOUL_CELL)).grow(-1.0)
		ItemDraw.block(_soul_area, rect, soul, NAME_FONT_SIZE)


# 面板放在鼠标旁边，贴近网格边缘时自动翻到另一侧
func _place_detail_panel(local_pos: Vector2) -> void:
	var panel_size := _detail_panel.get_combined_minimum_size()

	var pos := local_pos + Vector2(DETAIL_GAP, DETAIL_GAP)
	if pos.x + panel_size.x > size.x:
		pos.x = local_pos.x - DETAIL_GAP - panel_size.x
	if pos.y + panel_size.y > size.y:
		pos.y = local_pos.y - DETAIL_GAP - panel_size.y

	pos.x = clampf(pos.x, 0.0, maxf(0.0, size.x - panel_size.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, size.y - panel_size.y))
	_detail_panel.position = pos


## 设置普通页数；后面会多出 1 页临时页，专门堆换装换下来的东西
func set_page_count(count: int) -> void:
	pages.resize(count + 1)
	for i in pages.size():
		if pages[i] == null:
			pages[i] = []
	page = clampi(page, 0, maxi(pages.size() - 1, 0))
	queue_redraw()


## 临时页是最后一页
func temp_page_index() -> int:
	return pages.size() - 1


func is_temp_page(p_page: int) -> bool:
	return p_page == temp_page_index()


## 临时页空着的时候，窗口会把那个红按钮藏起来
func temp_page_is_empty() -> bool:
	return _page_items(temp_page_index()).is_empty()


## 把东西塞进临时页，从左上往右下找第一块放得下的地方
## （换装换下来的旧装备和旧魂灵走这儿，不受「临时页只能取不能存」那条限制）
func add_to_temp_page(item: InventoryItem) -> bool:
	var spot := _find_free_spot(item.cells(), temp_page_index())
	if spot.x < 0:
		return false
	item.cell = spot
	_page_items(temp_page_index()).append(item)
	if is_temp_page(page):
		queue_redraw()
	inventory_changed.emit()
	return true


# 从左上往右下扫，找第一块放得下 cells 的地方，找不到返回 (-1, -1)
func _find_free_spot(cells: Vector2i, p_page: int) -> Vector2i:
	for y in PAGE_CELLS.y:
		for x in PAGE_CELLS.x:
			if _can_place_raw(Rect2i(Vector2i(x, y), cells), p_page):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func page_count() -> int:
	return pages.size()


## 翻到指定页，超出范围会被夹到最近的一页
func set_page(p_page: int) -> void:
	var target := clampi(p_page, 0, maxi(page_count() - 1, 0))
	if target == page:
		return
	page = target
	_hover_cell = Vector2i(-1, -1)
	_detail_panel.visible = false
	queue_redraw()
	page_changed.emit(page)


## 把物品放进指定页；越界或和已有物品重叠就不放，返回是否放成功
func add_item(item: InventoryItem, p_page: int) -> bool:
	if not can_place(item.cell_rect(), p_page):
		return false
	_page_items(p_page).append(item)
	if p_page == page:
		queue_redraw()
	return true


## 把东西从它所在的页里摘掉（右键换装时用）
func remove_item(item: InventoryItem) -> void:
	for p_page in pages.size():
		var items := _page_items(p_page)
		if items.has(item):
			items.erase(item)
			if p_page == page:
				queue_redraw()
			inventory_changed.emit()
			return


## 这块区域放得下吗：在本页范围内、不和已有物品重叠，而且临时页只能取不能存
func can_place(cell_rect: Rect2i, p_page: int) -> bool:
	if is_temp_page(p_page):
		return false
	return _can_place_raw(cell_rect, p_page)


## 不管「临时页不能存」那条的版本，临时页自己往里塞东西时用
func _can_place_raw(cell_rect: Rect2i, p_page: int) -> bool:
	if p_page < 0 or p_page >= pages.size():
		return false
	if cell_rect.position.x < 0 or cell_rect.position.y < 0:
		return false
	if cell_rect.end.x > PAGE_CELLS.x or cell_rect.end.y > PAGE_CELLS.y:
		return false
	for item in _page_items(p_page):
		if item.cell_rect().intersects(cell_rect):
			return false
	return true


## 这一格上的物品，没有就返回 null
func item_at(cell: Vector2i) -> InventoryItem:
	for item in get_page_items():
		if item.cell_rect().has_point(cell):
			return item
	return null


## 当前页的物品
func get_page_items() -> Array:
	return _page_items(page)


func _page_items(p_page: int) -> Array:
	if p_page < 0 or p_page >= pages.size():
		return []
	return pages[p_page]


## 格子区域，可以一次框多格
func _cell_rect(cell: Vector2i, cells: Vector2i = Vector2i.ONE) -> Rect2:
	return Rect2(Vector2(cell * CELL_SIZE), Vector2(cells * CELL_SIZE))


func _item_rect(item: InventoryItem) -> Rect2:
	return _block_rect(Vector2(item.cell * CELL_SIZE), item.cells())


## 放在某个像素位置上的色块，四周各缩进 1 像素，让底下的格线露出来
func _block_rect(pos: Vector2, cells: Vector2i) -> Rect2:
	return Rect2(pos + Vector2.ONE, Vector2(cells * CELL_SIZE) - Vector2.ONE * 2.0)


## 在物品上按下左键就开始拖：把它从页里摘下来拿在手上
func _start_drag(local_pos: Vector2) -> void:
	# 一次只拖一件：手上有东西就不再接新的一次按下，不然前一件会被顶掉、从页里丢掉
	if _dragging != null:
		return
	var cell := _pos_to_cell(local_pos)
	if cell.x < 0:
		return
	var item := item_at(cell)
	if item == null:
		return

	_dragging = item
	_drag_from = item.cell
	_drag_offset = local_pos - Vector2(item.cell * CELL_SIZE)
	GameGlobal.begin_drag(item, _drag_offset)
	_drag_pos = local_pos
	_hover_cell = Vector2i(-1, -1)
	_detail_panel.visible = false
	_page_items(page).erase(item)
	queue_redraw()


# 右键：把点到的这件东西交给窗口处理（仓库里右键装备 = 换上）
func _right_click(local_pos: Vector2) -> void:
	var cell := _pos_to_cell(local_pos)
	if cell.x < 0:
		return
	var item := item_at(cell)
	if item:
		item_right_clicked.emit(item)


## 放下：先问别的窗口要不要（比如装备面板），没人要就落在当前格
## 放不下（越界、重叠、拖到格子外、临时页不让存）都送回原位
func _finish_drag() -> void:
	var item := _dragging
	_dragging = null
	GameGlobal.end_drag()

	for target in get_tree().get_nodes_in_group("drop_target"):
		if target != self and target.try_drop_at(item):
			inventory_changed.emit()
			queue_redraw()
			return

	# 鼠标已经不在仓库窗口里了（比如拖到装备窗口上松手）：送回原位，
	# 不然用的是离开前那个旧坐标，会落在想不到的格子上
	var cell := _drag_cell(item)
	if _mouse_in_window() and can_place(Rect2i(cell, item.cells()), page):
		item.cell = cell
	else:
		item.cell = _drag_from
	_page_items(page).append(item)
	inventory_changed.emit()
	queue_redraw()


## 不作数了：东西回原来那格（装备被拖出窗口时走这儿）
func _cancel_drag() -> void:
	var item := _dragging
	if item == null:
		return
	_dragging = null
	GameGlobal.end_drag()
	item.cell = _drag_from
	_page_items(page).append(item)
	inventory_changed.emit()
	queue_redraw()


## 别人（装备面板）把魂灵拖到我这儿，松手时会问：这一下能放下吗
func try_drop_at(item: InventoryItem) -> bool:
	if not is_visible_in_tree():
		return false
	# 先确认鼠标真在这个窗口里，不然拿到的是上次离开时的旧位置
	if not GameGlobal.mouse_in_window(get_window()):
		return false
	# 不要求指针正好在网格上：落在窗口里别的角落（分页栏、边距）就就近收进边上那一格
	return accept_at(get_local_mouse_position(), item)


## 按局部坐标算落点，能放下就放（按「抓在哪儿」对齐，再整件往页里收，跟自己的拖动一个规矩）
func accept_at(local_pos: Vector2, item: InventoryItem) -> bool:
	var cell := _clamp_into_page(local_pos - GameGlobal.dragged_offset, item.cells())
	if not can_place(Rect2i(cell, item.cells()), page):
		return false

	item.cell = cell
	_page_items(page).append(item)
	queue_redraw()
	inventory_changed.emit()
	return true


## 手上物品的左上角对着哪一格。
## 落点会**整件往页里收**：贴着右边（或下边）松手时，东西落在还能放下的最靠边那一列，
## 而不是因为「越界」整个弹回原位。鼠标落在窗口里但不在格子上（分页栏、边距）也算数。
## item 要传进来：`_finish_drag()` 里已经先把 `_dragging` 清掉了才来问落点。
func _drag_cell(item: InventoryItem) -> Vector2i:
	return _clamp_into_page(_drag_pos - _drag_offset, item.cells())


## 把「左上角想落在哪个像素位置」夹成「整件都放得进页里」的格（pos 是像素）
func _clamp_into_page(pos: Vector2, cells: Vector2i) -> Vector2i:
	var cell := (pos / float(CELL_SIZE)).floor()
	return Vector2i(
		clampi(int(cell.x), 0, maxi(PAGE_CELLS.x - cells.x, 0)),
		clampi(int(cell.y), 0, maxi(PAGE_CELLS.y - cells.y, 0))
	)


func _update_hover(local_pos: Vector2) -> void:
	var cell := _pos_to_cell(local_pos)
	if cell == _hover_cell:
		return
	_hover_cell = cell
	queue_redraw()
	_update_detail(local_pos)


## 像素坐标换成格子坐标，不在格子里就返回 (-1, -1)
func _pos_to_cell(local_pos: Vector2) -> Vector2i:
	if local_pos.x < 0.0 or local_pos.y < 0.0:
		return Vector2i(-1, -1)
	var cell := Vector2i(local_pos) / CELL_SIZE
	if cell.x >= PAGE_CELLS.x or cell.y >= PAGE_CELLS.y:
		return Vector2i(-1, -1)
	return cell


func _on_mouse_exited() -> void:
	_update_hover(Vector2(-1.0, -1.0))


func _mouse_in_window() -> bool:
	return GameGlobal.mouse_in_window(get_window())
