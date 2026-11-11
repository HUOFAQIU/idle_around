extends BaseGridView
## 格子视图，用于绘制格子
class_name ShopGridView

## 输入控制
func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(GBIS.input_click):
		_container_view.handle_grid_click(grid_id, offset, _size)
