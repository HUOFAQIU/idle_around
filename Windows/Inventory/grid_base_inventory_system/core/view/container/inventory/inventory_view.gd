@tool
extends BaseContainerView
## 背包视图，控制背包的绘制
class_name InventoryView

## 允许存放的物品大类，如果背包名字重复，可存放的物品大类需要一样
@export_enum("ANY", "SOUL", "VESSEL") var avilable_types: Array[String] = ["ANY"]
## 魂器类型限制（NONE = 不限制；角色魂器网格用 COMBAT）
@export_enum("NONE", "COMBAT", "TOOL") var vessel_kind: String = "NONE"
## 最多物品件数；0 = 不限制（角色魂器网格不设）
@export var max_items: int = 0
## 是否在 _ready 时注册容器。魂器窗口这种运行时才绑定数据源的视图设为 false，
## 避免在仓库/商店里留下一个看不见的占位容器。
@export var auto_register: bool = true

func grid_hover(grid_id: Vector2i) -> void:
	_handle_grid_hover(grid_id, true)
 
func grid_lose_hover(grid_id: Vector2i) -> void:
	_handle_grid_hover(grid_id, false)
 
func _handle_grid_hover(grid_id: Vector2i, is_hover: bool) -> void:
	# auto_register=false 的视图（魂器窗口）在绑定数据源前没有容器
	if _container_data() == null:
		return
	if not GBIS.moving_item_service.is_dragging():
		var data: ItemData = GBIS.inventory_service.find_item_data_by_grid(container_name, grid_id)
		if data:
			if is_hover:
				GBIS.item_focus_service.focus_item(data, container_name)
			else:
				GBIS.item_focus_service.item_lose_focus()
		return

	if is_hover:
		_apply_drag_ghost_style()
	var moving_item_offset := GBIS.moving_item_service.moving_item_offset
	var moving_item := GBIS.moving_item_service.moving_item
	var grids := _get_grids_by_shape(grid_id - moving_item_offset, moving_item.get_shape())

	var state := ContainerData.DropState.BLOCKED
	var container := _container_data()
	if is_hover and container != null:
		state = container.drop_state_at(moving_item, grid_id, moving_item_offset)

	for grid in grids:
		var grid_view := _grid_map[grid]
		if is_hover:
			grid_view.state = BaseGridView.State.AVILABLE if state != ContainerData.DropState.BLOCKED else BaseGridView.State.CONFLICT
		else:
			grid_view.state = BaseGridView.State.TAKEN if grid_view.has_taken else BaseGridView.State.EMPTY


## 点击格子：拖拽中尝试放下，空手时从该格拿起；随后刷新悬停预览
func handle_grid_click(grid_id: Vector2i, offset: Vector2i, pick_base_size: int) -> void:
	var moving := GBIS.moving_item_service
	if moving.is_dragging():
		moving.drop_on_grid(container_name, grid_id)
	elif _grid_item_map.get(grid_id) != null:
		moving.pick_from_grid(container_name, grid_id, offset, pick_base_size)
	grid_hover(grid_id)

## 切换当前显示的容器（仓库翻页用）；只重建视图，不动容器数据
func change_data_source(new_container_name: String) -> void:
	if new_container_name == container_name:
		return

	var old_container_name := container_name
	var was_visible := is_visible_in_tree()
	GBIS.item_focus_service.item_lose_focus()

	var ret = GBIS.inventory_service.regist(new_container_name, container_columns, container_rows, false, avilable_types)
	ret.vessel_kind = "" if vessel_kind == "NONE" else vessel_kind
	ret.max_items = max_items
	var shape_changed: bool = ret.columns != container_columns or ret.rows != container_rows
	container_name = new_container_name
	avilable_types = ret.avilable_types
	container_columns = ret.columns
	container_rows = ret.rows

	if shape_changed:
		_clear_inv()
		for child in get_children():
			remove_child(child)
			child.queue_free()
		_init_grid_container()
		_init_item_container()
		_init_grids()
	else:
		# 同尺寸翻页：保留格子 Control 与信号连接，只清物品和占用状态
		_clear_inv()

	# 快速移动只认打开的容器：旧页移出，新页在窗口可见时加入
	GBIS.opened_containers.erase(old_container_name)
	if was_visible and not GBIS.opened_containers.has(new_container_name):
		GBIS.opened_containers.append(new_container_name)

	mark_dirty()


## 初始化
func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_recalculate_size")
		return
	
	if not container_name:
		push_error("Inventory must have a name.")
		return

	if auto_register:
		var ret = GBIS.inventory_service.regist(container_name, container_columns, container_rows, false, avilable_types)
		ret.vessel_kind = "" if vessel_kind == "NONE" else vessel_kind
		ret.max_items = max_items

		if is_visible_in_tree() and not GBIS.opened_containers.has(container_name):
			GBIS.opened_containers.append(container_name)

		if not GBIS.inventory_names.has(container_name):
			GBIS.inventory_names.append(container_name)

		# 使用已注册的信息覆盖View设置
		avilable_types = ret.avilable_types
		container_columns = ret.columns
		container_rows = ret.rows

	mouse_filter = Control.MOUSE_FILTER_PASS
	_init_grid_container()
	_init_item_container()
	_init_grids()
	GBIS.sig_inv_item_added.connect(_on_item_added)
	GBIS.sig_inv_item_removed.connect(_on_item_removed)
	GBIS.sig_inv_item_updated.connect(_on_inv_item_updated)
	GBIS.sig_inv_refresh.connect(mark_dirty)
	GBIS.moving_item_service.drag_ended.connect(_on_drag_ended)

	visibility_changed.connect(_on_visible_changed)

	if not stack_num_font:
		stack_num_font = get_theme_font("font")

	mark_dirty()

## 拖拽中右键取消：放回原格；来源未知的拖拽（分割等）不处理
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not is_visible_in_tree():
		return
	if not event.is_action_pressed(GBIS.input_use):
		return
	if not GBIS.has_moving_item():
		return
	if GBIS.moving_item_service.cancel():
		get_viewport().set_input_as_handled()

## 拖拽结束：把拖动时留下的可用/冲突高亮恢复成空/占用
func _on_drag_ended() -> void:
	for grid in _grid_map.values():
		grid.state = BaseGridView.State.TAKEN if grid.has_taken else BaseGridView.State.EMPTY

## 监听添加物品
func _on_item_added(inv_name:String, item_data: ItemData, grids: Array[Vector2i]) -> void:
	if not inv_name == container_name:
		return
	if not is_visible_in_tree():
		mark_dirty()
		return

	var item = _draw_item(item_data, grids[0])
	_items.append(item)
	_item_grids_map[item] = grids
	for grid in grids:
		_grid_map[grid].taken(grid - grids[0])
		_grid_item_map[grid] = item

## 监听移除物品
func _on_item_removed(inv_name:String, item_data: ItemData) -> void:
	if not inv_name == container_name:
		return
	if not is_visible_in_tree():
		mark_dirty()
		return

	for i in range(_items.size() - 1, -1, -1):
		var item = _items[i]
		if item.data == item_data:
			var grids = _item_grids_map[item]
			for grid in grids:
				_grid_map[grid].release()
				_grid_item_map[grid] = null
			item.queue_free()
			_items.remove_at(i)
			break

## 监听更新物品
func _on_inv_item_updated(inv_name: String, grid_id: Vector2i) -> void:
	if not inv_name == container_name:
		return
	if not is_visible_in_tree():
		mark_dirty()
		return

	var item_view := _grid_item_map.get(grid_id) as ItemView
	if item_view != null:
		item_view.queue_redraw()

## 绘制物品
func _draw_item(item_data: ItemData, first_grid: Vector2i) -> ItemView:
	var item = ItemView.new(item_data, base_size, stack_num_font, stack_num_font_size, stack_num_margin, stack_num_color)
	_item_container.add_child(item)
	item.global_position = _grid_map[first_grid].global_position
	return item

## 初始化格子View
func _init_grids() -> void:
	_grid_map.clear()
	for row in container_rows:
		for col in container_columns:
			var grid_id = Vector2i(col, row)
			var grid = InventoryGridView.new(self, grid_id, base_size, grid_border_size, grid_border_color, 
				gird_background_color_empty, gird_background_color_taken, gird_background_color_conflict, grid_background_color_avilable)
			_grid_container.add_child(grid)
			_grid_map[grid_id] = grid
