extends Node
## 移动物品业务类
class_name MovingItemService

## 正在移动的物品
var moving_item: ItemData
## 正在移动的物品View
var moving_item_view: ItemView
## 正在移动的物品的偏移（例：一个2*2的物品，点击左上角移动时，偏移是[0,0]，点击右下角移动时，偏移是[1,1]）
var moving_item_offset: Vector2i = Vector2i.ZERO
## 丢弃物品检测区域
var drop_area_view: DropAreaView

## 顶层，用于展示移动物品的View
var _moving_item_layer: MovingItemLayer
## 跟随层当前挂在哪个 Viewport（窗口）下
var _layer_viewport: Viewport


## 跟随层。它必须待在「鼠标所在那个窗口」的画布下，不能挂死在 get_tree().root：
## 仓库、装备面板各自是独立的 OS 窗口（project.godot 里 embed_subwindows=false），
## **每个 Window 只画得了自己的画布**。挂在 root 上就等于画进那个 300x300 的主窗口，
## 鼠标在仓库窗口上时算出来的坐标（屏幕坐标 - 主窗口坐标）落在 300x300 之外，
## 整件东西被裁得干干净净 —— 看起来就是「装备跟着鼠标，但 icon 没画出来」。
## 所以让它每帧跟着鼠标换窗口，跨窗口拖（仓库 -> 装备槽）也不会断。
class MovingItemLayer:
	extends CanvasLayer

	## 谁生了我，回头找谁问「鼠标现在在哪个窗口」。故意不写类型，免得跟外层类循环引用
	var service

	func _process(_delta: float) -> void:
			if service:
					service.follow_mouse_window()


## 获取顶层，没有则新建
func get_moving_item_layer() -> CanvasLayer:
	if not _moving_item_layer:
			_moving_item_layer = MovingItemLayer.new()
			_moving_item_layer.service = self
			_moving_item_layer.layer = 128
	_set_layer_viewport(_viewport_under_mouse())
	return _moving_item_layer


## 跟随层换到鼠标当前所在的窗口（每帧由 MovingItemLayer 调）
func follow_mouse_window() -> void:
	if _moving_item_layer:
			_set_layer_viewport(_viewport_under_mouse())


## 把跟随层挂到指定窗口的画布下
func _set_layer_viewport(target: Viewport) -> void:
	if _layer_viewport == target:
			return
	if _moving_item_layer.get_parent():
			_moving_item_layer.get_parent().remove_child(_moving_item_layer)
	target.add_child(_moving_item_layer)
	_layer_viewport = target
	# 搬这一下，手上的 ItemView 跟着出树又入树，这一帧它的 _process 不会跑，
	# 位置还停在旧窗口的坐标系里 —— 不马上补算，就会在新窗口里闪一帧。
	if moving_item_view:
		moving_item_view.update_moving_position()


## 鼠标底下是哪个窗口。
## 窗口是嵌入的时候大家共用一个画布，那就还是回 root（原来的行为）
func _viewport_under_mouse() -> Viewport:
	var root := GBIS.get_root() as Window
	if root == null or root.gui_embed_subwindows:
			return GBIS.get_root()

	var mouse := DisplayServer.mouse_get_position()
	var sub_windows: Array[Window] = []
	_collect_sub_windows(root, sub_windows)
	for win in sub_windows:
			if win.visible and Rect2i(win.position, win.size).has_point(mouse):
					return win
	# 鼠标在桌面上（哪个窗口都不是）时留着上一个，别闪
	return _layer_viewport if _layer_viewport else root


## 收集 root 下面所有的子窗口（仓库、装备面板那些）
func _collect_sub_windows(node: Node, out: Array[Window]) -> void:
	for child in node.get_children():
			if child is Window:
					out.append(child)
			_collect_sub_windows(child, out)


## 清除正在移动的物品
func clear_moving_item() -> void:
	if _moving_item_layer:
			for o in _moving_item_layer.get_children():
					o.queue_free()
	moving_item = null
	moving_item_view = null
	if drop_area_view:
			drop_area_view.hide()

func move_item_by_data(item_data: ItemData, offset: Vector2i, base_size: int) -> void:
	self.moving_item = item_data
	self.moving_item_offset = offset
	self.moving_item_view = ItemView.new(item_data, base_size)
	get_moving_item_layer().add_child(moving_item_view)
	moving_item_view.move(offset)
	if drop_area_view:
			drop_area_view.show()

func move_item_by_grid(inv_name: String, grid_id: Vector2i, offset: Vector2i, base_size: int) -> void:
	if moving_item:
			push_error("Already had moving item.")
			return
	var item_data = GBIS.inventory_service.find_item_data_by_grid(inv_name, grid_id)
	if item_data:
			move_item_by_data(item_data, offset, base_size)
			GBIS.inventory_service.remove_item_by_data(inv_name, item_data)
			if drop_area_view:
					drop_area_view.show()
