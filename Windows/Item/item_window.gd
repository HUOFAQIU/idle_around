class_name ItemWindow
extends Control

## 拖动中的"幽灵物品"：主视口里的一个浮层，里面放着被拖的那个 ItemView。
##
## 单窗口模式下所有窗口共用主视口，幽灵不再需要独立 OS 窗口；它放在
## DragLayer（layer 1025）里，盖在所有嵌入窗口之上，跟随主视口鼠标。
## 鼠标拖到主窗口外没有意义，幽灵会在窗口边缘被裁掉。
##
## 跟 TooltipWindow 一个套路：全局唯一，别处用 ItemWindow.instance 拿。

static var instance : ItemWindow

## 幽灵左上角相对鼠标的偏移（像素）—— 抓着物品的哪一格，就偏多少
var _grab_offset : Vector2 = Vector2.ZERO
var _view : ItemView
## 上次同步过的尺寸（变了才去写浮层尺寸）
var _last_size : Vector2i = Vector2i.ZERO


func _ready() -> void:
	instance = self
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 接住被拖的物品。grab_offset_cells 是抓在物品的第几格
## （2×2 的物品点右下角时是 (1,1)），保证物品相对鼠标的位置和拖之前一样
func hold(view: ItemView, grab_offset_cells: Vector2i, base_size: int) -> void:
	clear()
	_view = view
	add_child(view)
	_set_mouse_ignore(view)
	view.position = Vector2.ZERO
	_grab_offset = Vector2(
		base_size * grab_offset_cells.x + base_size / 2.0,
		base_size * grab_offset_cells.y + base_size / 2.0
	)
	_sync_size()
	visible = true
	_reposition()


func clear() -> void:
	for child in get_children():
		child.queue_free()
	_view = null
	_last_size = Vector2i.ZERO
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	_sync_size()
	_reposition()


## 浮层尺寸对齐物品：不同格子悬停时会改 base_size，
## 物品会变大变小，浮层得跟上（不然会被裁掉或者留一圈底）
func _sync_size() -> void:
	if _view == null or not is_instance_valid(_view):
		return
	var want := Vector2i(_view.size)
	if want != _last_size and want.x > 0 and want.y > 0:
		_last_size = want
		size = Vector2(want)


## 跟着主视口鼠标；position 是浮层左上角相对主视口的位置
func _reposition() -> void:
	position = get_viewport().get_mouse_position() - _grab_offset


## 幽灵不能挡住放置/取消等鼠标事件：整棵子树都忽略鼠标
func _set_mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore(child)
