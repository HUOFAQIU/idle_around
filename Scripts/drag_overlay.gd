class_name DragOverlay
extends Control

## 铺满整个窗口的一层，专门摆「手上拖着的那件」。
##
## 为什么要有它：装备窗口里能接东西的只有魂灵区那一小块，仓库里能接的只有网格那一块；
## 鼠标移到行的其它地方（部位名、行距、窗口边距）时那些控件都管不着，而 DragGhost 又只在
## 鼠标**出了我们窗口**才顶上，于是两不管，东西就凭空没了。这一层铺满窗口，谁也不用操心归属。

## 这个窗口显不显示正在拖的装备。
## 装备连仓库窗口都出不去（只能在仓库里挪位置），所以只有仓库那层该开这个开关；
## 装备窗口永远是默认的 false —— 装备槽根本不接拖过来的装备。
var allow_equipment : bool = false

var _item : InventoryItem = null
var _view : ItemView = null


func _ready() -> void:
	# Control 直接挂在 Window 底下时，光设锚点不会重算尺寸（得连偏移一起设），
	# 不然它会是个 0×0 的控件——东西是照样摆，但别留这种坑
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 在窗口内容之上、提示框（z_index 10）之下
	z_index = 5
	# 松手那一下也得收摊：不收的话最后一帧（比如放不下的那颗魂灵）会留在原地
	GameGlobal.drag_ended.connect(_clear)


func _process(_delta: float) -> void:
	if GameGlobal.dragged_item:
		_follow()


# 按「抓在哪儿」把它摆在指针底下，正好是松手后会落到的位置
func _follow() -> void:
	var item := GameGlobal.dragged_item
	if not _shows(item):
		_clear()
		return

	if _item != item:
		_rebuild(item)
	_view.position = get_local_mouse_position() - GameGlobal.dragged_offset


func _shows(item: InventoryItem) -> bool:
	if item is Equipment and not allow_equipment:
		return false
	# 鼠标不在这个窗口里就不摆：那是 DragGhost 的活儿
	return GameGlobal.mouse_in_window(get_window())


func _rebuild(item: InventoryItem) -> void:
	_clear()
	_item = item
	_view = ItemView.new(item)
	add_child(_view)


func _clear() -> void:
	if is_instance_valid(_view) and _view.get_parent() == self:
		remove_child(_view)
		_view.queue_free()
	_view = null
	_item = null
