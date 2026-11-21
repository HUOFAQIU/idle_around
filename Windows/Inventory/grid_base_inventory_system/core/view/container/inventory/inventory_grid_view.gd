extends BaseGridView
class_name InventoryGridView

func _gui_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	
	GBIS.item_focus_service.item_lose_focus()
	
	if event.is_action_pressed(GBIS.input_click):
		_container_view.handle_grid_click(grid_id, offset, _size)
		return
	
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
