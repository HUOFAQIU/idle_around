class_name ItemWindow
extends Window

## 拖动中的"幽灵物品"：一个独立小窗口，里面就放着被拖的那个 ItemView。
##
## 为什么非得用窗口：每个 Window 只画得了自己的画布（embed_subwindows = false），
## 物品视图留在原窗口里，鼠标一拖出窗口就被裁掉。单独开一个窗口跟着鼠标走，
## 拖到哪个窗口上、甚至拖到桌面上都不会被裁。
##
## 跟 TooltipWindow 一个套路：全局唯一，别处用 ItemWindow.instance 拿。

static var instance : ItemWindow

## 窗口左上角相对鼠标的偏移（像素）—— 抓着物品的哪一格，就偏多少
var _grab_offset : Vector2 = Vector2.ZERO
## 现在装着的物品视图
var _view : ItemView
## 上次同步过的尺寸（变了才去写窗口尺寸）
var _last_size : Vector2i = Vector2i.ZERO


func _ready() -> void:
	instance = self
	visible = false


## 接住被拖的物品。grab_offset_cells 是抓在物品的第几格
## （2×2 的物品点右下角时是 (1,1)），保证物品相对鼠标的位置和拖之前一样
func hold(view: ItemView, grab_offset_cells: Vector2i, base_size: int) -> void:
	clear()
	_view = view
	add_child(view)
	view.position = Vector2.ZERO
	_grab_offset = Vector2(
		base_size * grab_offset_cells.x + base_size / 2.0,
		base_size * grab_offset_cells.y + base_size / 2.0
	)
	_sync_size()
	_reposition()
	visible = true


## 放下 / 取消
func clear() -> void:
	for child in get_children():
		child.queue_free()
	_view = null
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	_sync_size()
	_reposition()


## 窗口尺寸对齐物品：不同格子悬停时会改 base_size，
## 物品会变大变小，窗口得跟上（不然会被窗口裁掉或者留一圈底）
func _sync_size() -> void:
	if _view == null or not is_instance_valid(_view):
		return
	var want := Vector2i(_view.size)
	if want != _last_size and want.x > 0 and want.y > 0:
		_last_size = want
		size = want


## 跟着鼠标。position 是客户区左上角（不含标题栏），所以物品正好落在鼠标那儿
func _reposition() -> void:
	position = DisplayServer.mouse_get_position() - Vector2i(_grab_offset)
