class_name DragOverlay
extends Control

## 铺满整个窗口的一层，专门画「手上拖着的那件」。
##
## 为什么要有它：装备窗口里能接东西的只有魂灵区那一小块，鼠标移到行的其它地方
## （部位名、行距、窗口边距）时那些控件都管不着；而 DragGhost 又只在鼠标**出了我们窗口**才顶上，
## 于是两不管，东西就凭空没了。这一层铺满窗口，谁也不用操心归属。

const CELL_SIZE : int = InventoryItem.CELL_SIZE
const NAME_FONT_SIZE : int = 14


func _ready() -> void:
	# Control 直接挂在 Window 底下时，光设锚点不会重算尺寸（得连偏移一起设），
	# 不然它会是个 0×0 的控件——画是照样画，但别留这种坑
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 在窗口内容之上、提示框（z_index 10）之下
	z_index = 5
	# 松手那一下也得重画：不然最后一帧（比如放不下的那颗魂灵）会留在原地
	GameGlobal.drag_ended.connect(queue_redraw)


func _process(_delta: float) -> void:
	if GameGlobal.dragged_item:
		queue_redraw()


func _draw() -> void:
	# 装备不许离开仓库窗口，也就轮不到在这儿画
	if not GameGlobal.dragged_item_can_leave():
		return
	var item := GameGlobal.dragged_item
	# 鼠标不在这个窗口里就不画：那是 DragGhost 的活儿
	if not GameGlobal.mouse_in_window(get_window()):
		return

	var rect := Rect2(get_local_mouse_position() - GameGlobal.dragged_offset, Vector2(item.cells() * CELL_SIZE))
	ItemDraw.block(self, rect, item, NAME_FONT_SIZE)
