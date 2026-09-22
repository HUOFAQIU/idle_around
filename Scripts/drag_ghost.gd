class_name DragGhost
extends Window

## 拖着东西时跟着指针跑的小窗口（暗黑 2 那种「拎着东西走」的样子）。
## 每个窗口只画得了自己画布里的东西，鼠标走到我们窗口外面时，仓库 / 装备面板就画不出来了，
## 只好另开一个无边框小窗口顶上去。它由 GameGlobal 管着，只在拖动期间露脸。

const CELL_SIZE : int = InventoryItem.CELL_SIZE
const NAME_FONT_SIZE : int = 14

var _canvas : Control
var _item : InventoryItem = null


func _init() -> void:
	borderless = true
	unresizable = true
	unfocusable = true
	always_on_top = true
	# 尽量别挡住鼠标事件；万一系统不认这条，GameGlobal 会在鼠标进我们窗口时把它藏起来
	mouse_passthrough = true
	visible = false

	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_item)
	add_child(_canvas)


## 按「抓在哪儿」把它摆在指针底下，正好是松手后会落到的位置
func show_drag(item: InventoryItem, offset: Vector2, mouse: Vector2i) -> void:
	_item = item
	var item_size := Vector2i(item.cells() * CELL_SIZE)
	if size != item_size:
		size = item_size
		_canvas.queue_redraw()
	position = mouse - Vector2i(offset)
	if not visible:
		visible = true


func hide_drag() -> void:
	if visible:
		visible = false


func _draw_item() -> void:
	if _item == null:
		return
	ItemDraw.block(_canvas, Rect2(Vector2.ZERO, Vector2(size)), _item, NAME_FONT_SIZE)
