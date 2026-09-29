class_name DragGhost
extends Window

## 拖着东西时跟着指针跑的小窗口（暗黑 2 那种「拎着东西走」的样子）。
## 每个窗口只画得了自己画布里的东西，鼠标走到我们窗口外面时，仓库 / 装备面板就摆不出来了，
## 只好另开一个无边框小窗口顶上去。它由 GameGlobal 管着，只在拖动期间露脸。

## 窗口本身就开成东西那么大，视图贴在左上角
var _item : InventoryItem = null
var _view : ItemView = null


func _init() -> void:
	borderless = true
	unresizable = true
	unfocusable = true
	always_on_top = true
	# 尽量别挡住鼠标事件；万一系统不认这条，GameGlobal 会在鼠标进我们窗口时把它藏起来
	mouse_passthrough = true
	visible = false


## 按「抓在哪儿」把它摆在指针底下，正好是松手后会落到的位置
func show_drag(item: InventoryItem, offset: Vector2, mouse: Vector2i) -> void:
	if _item != item:
		_rebuild(item)
	position = mouse - Vector2i(offset)
	if not visible:
		visible = true


func hide_drag() -> void:
	if visible:
		visible = false


func _rebuild(item: InventoryItem) -> void:
	if is_instance_valid(_view) and _view.get_parent() == self:
		remove_child(_view)
		_view.queue_free()

	_item = item
	size = Vector2i(item.cells() * InventoryItem.CELL_SIZE)
	_view = ItemView.new(item)
	add_child(_view)
	_view.position = Vector2.ZERO
