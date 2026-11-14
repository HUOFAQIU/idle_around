extends RefCounted
## 拖拽表现：幽灵 ItemView、跟随指针的浮层和丢弃区域。
##
## 只负责“看起来怎样”，不判断能不能放下；状态与命令由 MovingItemService 管。
class_name DragPresenter

## 跟着鼠标的幽灵物品视图
var _view: ItemView
## 丢弃区域；由 DropAreaView 入树时注册
var _drop_area: DropAreaView


## 开始拖拽：创建幽灵视图，交给 ItemWindow 跟随鼠标
func begin(item_data: ItemData, grab_offset: Vector2i, base_size: int) -> void:
	_view = null
	if ItemWindow.instance:
		_view = ItemView.new(item_data, base_size)
		ItemWindow.instance.hold(_view, grab_offset, base_size)
	if _drop_area:
		_drop_area.show()


## 结束拖拽：清掉幽灵视图并隐藏丢弃区域
func end() -> void:
	# 没有 ItemWindow 时幽灵视图从未入树，需要自己释放
	if _view != null and not _view.is_inside_tree():
		_view.queue_free()
	if ItemWindow.instance:
		ItemWindow.instance.clear()
	_view = null
	if _drop_area:
		_drop_area.hide()


## 同步背包/商店的格子与堆叠样式
func apply_stack_style(base_size: int, font: Font, font_size: int, margin: int, color: Color) -> void:
	if _view == null:
		return
	_view.base_size = base_size
	_view.stack_num_font = font
	_view.stack_num_font_size = font_size
	_view.stack_num_margin = margin
	_view.stack_num_color = color


## 只同步格子大小（装备槽不画堆叠数字）
func set_base_size(base_size: int) -> void:
	if _view:
		_view.base_size = base_size


## 注册场景里的丢弃区域
func register_drop_area(area: DropAreaView) -> void:
	_drop_area = area
