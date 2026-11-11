extends BaseGridView
## 格子视图，用于绘制格子
class_name InventoryGridView

func _gui_input(event: InputEvent) -> void:
	if not event.is_pressed():  # 只处理按键按下事件
		return
	
	GBIS.item_focus_service.item_lose_focus()
	
	# 处理点击动作
	if event.is_action_pressed(GBIS.input_click):
		_container_view.handle_grid_click(grid_id, offset, _size)
		return
	
	# 如果不是点击动作且格子没有物品，直接返回
	if not has_taken:
		return
	
	if event.is_action_pressed(GBIS.input_quick_move):
		GBIS.inventory_service.quick_move(_container_view.container_name, grid_id)
	elif event.is_action_pressed(GBIS.input_quick_sell):
		GBIS.inventory_service.quick_sell(_container_view.container_name, grid_id)
	elif event.is_action_pressed(GBIS.input_use):
		GBIS.inventory_service.use_item(_container_view.container_name, grid_id)
	elif event.is_action_pressed(GBIS.input_split) and not GBIS.moving_item_service.is_dragging():
		GBIS.inventory_service.split_item(_container_view.container_name, grid_id, offset, _size)
