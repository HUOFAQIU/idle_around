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

## hover 到东西浮出来的提示框：装备一个、魂灵一个，按 hover 到的东西二选一
const EQUIPMENT_TOOLTIP : PackedScene = preload("res://Kits/Tooltip/equipment_tooltip.tscn")
const SOUL_TOOLTIP : PackedScene = preload("res://Kits/Tooltip/soul_tooltip.tscn")

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

## 当前页每件东西挂一个视图节点，美术在 Tokens/ 的场景里
var _views : Array[ItemView] = []
## 铺满网格的一层，只画**拖动落点框**——那个得压在所有东西上面（挡住就没法预览了）。
## hover 高亮不在这儿：它画在网格自己的 `_draw()` 里，正好被东西挡住
var _overlay : Control
## 鼠标指到装备 / 魂灵时浮出来的提示框，同一时刻最多浮一个
var _equipment_tip : EquipmentTooltip
var _soul_tip : SoulTooltip


func _ready() -> void:
	custom_minimum_size = Vector2(PAGE_CELLS * CELL_SIZE)
	mouse_exited.connect(_on_mouse_exited)
	# 别人拖着的东西在我这儿画过一帧，松手了得擦掉
	GameGlobal.drag_ended.connect(_refresh_overlay)
	_build_overlay()
	_build_tooltip()
	_sync_views()
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


# 提示框跟着鼠标走；拖动期间每帧跟住鼠标，松开左键就放下
# （在网格外松开也算，所以在这里收尾）
func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return

	var mouse := get_local_mouse_position()
	var tip := _visible_tip()
	if tip:
		tip.place_near(mouse, size)

	# 别人正拖着东西：鼠标在我这个窗口里就得跟着重画，不然看不到手上拿着什么
	# （手上那件由窗口那层 DragOverlay 画，这儿只管落点框）
	if GameGlobal.dragged_item and _mouse_in_window():
		_refresh_overlay()

	if _dragging == null:
		return
	_drag_pos = mouse
	_refresh_overlay()
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

	# 鼠标底下那一格的高亮：画在这儿（父节点自己的 `_draw()`）而不是 `_overlay` 那层——
	# 父节点画的在子节点**底下**，东西压在上面正好把它挡住（跟装备面板的魂灵区格线一个道理）。
	# 空格子上没有东西挡，所以照样看得见
	if _hover_cell.x >= 0:
		draw_rect(_cell_rect(_hover_cell), COLOR_HOVER, false, 1.0)


# 这一层只管**要压在所有东西上面**的框：拖动时的落点框（预览要是被东西挡住就没法看了）。
# hover 那格的高亮不归这儿，见 `_draw()`
func _draw_overlay() -> void:
	if _dragging and _mouse_in_window():
		# 会落在哪：放得下画绿框，放不下画红框
		# 框画的就是收边之后的落点，所以看到框在哪就是落在哪
		var cells := _dragging.cells()
		var target := _drag_cell(_dragging)
		var fits := can_place(Rect2i(target, cells), page)
		_overlay.draw_rect(_cell_rect(target, cells), COLOR_DROP_OK if fits else COLOR_DROP_BAD, false, 2.0)


# ---------------------------------------------------------------- 视图

# 页里的东西变了就重挂一遍。只在“东西真的增减了”的时候调，别每帧调
func _sync_views() -> void:
	for view in _views:
		if is_instance_valid(view) and view.get_parent() == self:
			remove_child(view)
			view.queue_free()
	_views.clear()

	for item in get_page_items():
		var view := ItemView.new(item)
		view.place_at_cell()
		add_child(view)
		_views.append(view)

	# 落点框那层得一直在最上面
	if _overlay:
		move_child(_overlay, -1)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _build_tooltip() -> void:
	_equipment_tip = EQUIPMENT_TOOLTIP.instantiate()
	_equipment_tip.z_index = 10
	add_child(_equipment_tip)

	_soul_tip = SOUL_TOOLTIP.instantiate()
	_soul_tip.z_index = 10
	add_child(_soul_tip)


# ---------------------------------------------------------------- 详情提示

# 鼠标底下有东西就浮出提示，没有就藏起来
func _update_tooltip(local_pos: Vector2) -> void:
	var item : InventoryItem = null
	if _hover_cell.x >= 0 and _dragging == null:
		item = item_at(_hover_cell)

	_hide_tips()
	if item is Equipment:
		_equipment_tip.show_for(item as Equipment, local_pos, size)
	elif item is Soul:
		_soul_tip.show_for(item as Soul, local_pos, size)


# 现在浮着的那个（同一时刻最多一个），每帧跟着鼠标走
func _visible_tip() -> TooltipBase:
	if _equipment_tip.visible:
		return _equipment_tip
	return _soul_tip if _soul_tip.visible else null


func _hide_tips() -> void:
	_equipment_tip.hide_tip()
	_soul_tip.hide_tip()


## 设置普通页数；后面会多出 1 页临时页，专门堆换装换下来的东西
func set_page_count(count: int) -> void:
	pages.resize(count + 1)
	for i in pages.size():
		if pages[i] == null:
			pages[i] = []
	page = clampi(page, 0, maxi(pages.size() - 1, 0))
	_refresh()


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
		_refresh()
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
	_hide_tips()
	_refresh()
	page_changed.emit(page)


## 把物品放进指定页；越界或和已有物品重叠就不放，返回是否放成功
func add_item(item: InventoryItem, p_page: int) -> bool:
	if not can_place(item.cell_rect(), p_page):
		return false
	_page_items(p_page).append(item)
	if p_page == page:
		_refresh()
	return true


## 把东西从它所在的页里摘掉（右键换装时用）
func remove_item(item: InventoryItem) -> void:
	for p_page in pages.size():
		var items := _page_items(p_page)
		if items.has(item):
			items.erase(item)
			if p_page == page:
				_refresh()
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
	_hide_tips()
	_page_items(page).erase(item)
	_refresh()


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
			_refresh()
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
	_refresh()


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
	_refresh()


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
	_refresh()
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
	# hover 框画在网格自己的 `_draw()` 里，所以重画网格（不是重画 overlay 那层）
	queue_redraw()
	_update_tooltip(local_pos)


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


# 页里的东西变了：重挂视图，两个画框的地方都跟着重画
# （网格自己的 `_draw()` 里有 hover 高亮——翻页会把 `_hover_cell` 清掉，得把它擦掉）
func _refresh() -> void:
	_sync_views()
	_refresh_overlay()
	queue_redraw()


func _refresh_overlay() -> void:
	if _overlay:
		_overlay.queue_redraw()


func _mouse_in_window() -> bool:
	return GameGlobal.mouse_in_window(get_window())
