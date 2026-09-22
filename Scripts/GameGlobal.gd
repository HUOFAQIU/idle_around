extends Node

const WINDOWPOSOFFSET : int = 5

## 正被鼠标拖着的东西，没在拖就是 null。
## 跨窗口拖动时，「拿东西的手」在仓库那边，装备面板要靠它才能把东西画出来。
var dragged_item : InventoryItem = null
## 抓在东西内部的哪个位置（像素）：拖动时按它对齐，松手就落在看到的地方。
## 松手那一下还得靠它算落点，所以拖完不清，下次 begin_drag() 覆盖掉。
var dragged_offset : Vector2 = Vector2.ZERO

## 一趟拖动结束了。画过「手上那件」的地方（仓库网格、窗口里那层画布、各行的落点框）
## 都得听这一声——它们平时只在拖动途中重画，不擦的话最后一帧会留在屏幕上
signal drag_ended

var _ghost : DragGhost


## 开始拖
func begin_drag(item: InventoryItem, offset: Vector2) -> void:
	dragged_item = item
	dragged_offset = offset


## 松手（落点算完了再喊这个，不然算不出落在哪一格）
func end_drag() -> void:
	dragged_item = null
	drag_ended.emit()


## 手上这件能不能离开自己的窗口。装备不行：它只能在仓库里挪位置，
## 鼠标拖出仓库窗口时仓库那边会把这次拖动作废（`inventory_grid._cancel_drag()`）
func dragged_item_can_leave() -> bool:
	return dragged_item != null and not (dragged_item is Equipment)


# 鼠标走到我们窗口外面时，靠那个小窗口把东西画出来（每个窗口只画得了自己的画布）
func _process(_delta: float) -> void:
	if not dragged_item_can_leave():
		if _ghost:
			_ghost.hide_drag()
		return

	# 鼠标在仓库 / 装备面板上：让那个窗口自己画，它画得准，也不会挡住鼠标事件
	if _over_drop_window():
		if _ghost:
			_ghost.hide_drag()
		return

	if _ghost == null:
		_ghost = DragGhost.new()
		add_child(_ghost)
	_ghost.show_drag(dragged_item, dragged_offset, DisplayServer.mouse_get_position())


## 鼠标底下是不是某个能接东西的窗口
func _over_drop_window() -> bool:
	for target in get_tree().get_nodes_in_group("drop_target"):
		if mouse_in_window(target.get_window()):
			return true
	return false


## 鼠标是不是在这个窗口里。
## 按屏幕坐标算，别用窗口自己的 `get_mouse_position()`：鼠标跑到别的窗口上之后，
## 那个窗口记的还是它最后进来时的位置，拿它判断落点会算到错的地方。
func mouse_in_window(win: Window) -> bool:
	if win == null or not win.visible:
		return false
	return Rect2i(win.position, win.size).has_point(DisplayServer.mouse_get_position())


## 鼠标在这个窗口里的位置（换算成窗口画布坐标）。
## 鼠标跑到别的窗口上时，窗口自己记的那个位置停在离开前，别拿它算落点。
func mouse_in_window_pos(win: Window) -> Vector2:
	if win == null:
		return Vector2.ZERO
	return Vector2(DisplayServer.mouse_get_position() - win.position)
