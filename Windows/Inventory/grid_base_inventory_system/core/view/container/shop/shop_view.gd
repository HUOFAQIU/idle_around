@tool
extends BaseContainerView
## 背包视图，控制背包的绘制
class_name ShopView

@export var goods: Array[ItemData]

## 格子高亮
func grid_hover(grid_id: Vector2i) -> void:
	if not GBIS.moving_item_service.is_dragging():
		var data: ItemData = GBIS.inventory_service.find_item_data_by_grid(container_name, grid_id)
		if data:
			GBIS.item_focus_service.focus_item(data, container_name)
		return

	_apply_drag_ghost_style()

## 格子失去高亮
func grid_lose_hover(_grid_id: Vector2i) -> void:
	GBIS.item_focus_service.item_lose_focus()


## 商店左键：拖拽中出售手中物品，否则购买该格货物
func handle_grid_click(grid_id: Vector2i, _offset: Vector2i, _base_size: int) -> void:
	if GBIS.moving_item_service.is_dragging():
		GBIS.moving_item_service.sell_dragged()
		return
	var item := GBIS.shop_service.find_item_data_by_grid(container_name, grid_id)
	GBIS.shop_service.buy(container_name, item)

## 初始化
func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_recalculate_size")
		return
	
	if not container_name:
		push_error("Shop must have a name.")
		return
	
	var ret = GBIS.shop_service.regist(container_name, container_columns, container_rows, true)
	
	if is_visible_in_tree():
		GBIS.opened_containers.append(container_name)
	
	# 使用已注册的信息覆盖View设置
	container_columns = ret.columns
	container_rows = ret.rows
	
	# 加载货物
	GBIS.shop_service.get_container(container_name).clear()
	GBIS.shop_service.load_goods(container_name, goods)
	
	mouse_filter = Control.MOUSE_FILTER_PASS
	_init_grid_container()
	_init_item_container()
	_init_grids()
	GBIS.sig_inv_refresh.connect(mark_dirty)

	visibility_changed.connect(_on_visible_changed)

	if not stack_num_font:
		stack_num_font = get_theme_font("font")

	mark_dirty()

## 初始化格子View
func _init_grids() -> void:
	for row in container_rows:
		for col in container_columns:
			var grid_id = Vector2i(col, row)
			var grid = ShopGridView.new(self, grid_id, base_size, grid_border_size, grid_border_color, 
				gird_background_color_empty, gird_background_color_taken, gird_background_color_conflict, grid_background_color_avilable)
			_grid_container.add_child(grid)
			_grid_map[grid_id] = grid
