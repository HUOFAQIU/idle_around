extends BaseGridView
class_name ShopGridView

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(GBIS.input_click):
		_container_view.handle_grid_click(grid_id, offset, _size)
