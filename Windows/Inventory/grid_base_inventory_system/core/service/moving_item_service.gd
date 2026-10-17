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


## 清除正在移动的物品
func clear_moving_item() -> void:
	if ItemWindow.instance:
		ItemWindow.instance.clear()
	moving_item = null
	moving_item_view = null
	if drop_area_view:
		drop_area_view.hide()

func move_item_by_data(item_data: ItemData, offset: Vector2i, base_size: int) -> void:
	self.moving_item = item_data
	self.moving_item_offset = offset
	self.moving_item_view = ItemView.new(item_data, base_size)
	# 交给跟着鼠标的小窗口去画。留在原窗口里的话，鼠标一拖出窗口，
	# 物品就被那个窗口的画布裁掉了（每个 Window 只画得了自己的画布）
	if ItemWindow.instance:
		ItemWindow.instance.hold(moving_item_view, offset, base_size)
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
