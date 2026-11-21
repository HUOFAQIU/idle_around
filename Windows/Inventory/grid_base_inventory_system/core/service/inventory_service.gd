extends BaseContainerService
class_name InventoryService

func add_item(inv_name: String, item_data: ItemData) -> bool:
	var new_item_data = item_data.make_instance()
	if new_item_data is StackableData:
		if new_item_data.current_amount > new_item_data.stack_size:
			new_item_data.current_amount = new_item_data.stack_size
		var items = find_item_data_by_item_name(inv_name, new_item_data.item_name)
		for item in items:
			if not item.is_full():
				new_item_data.current_amount = item.add_amount(new_item_data.current_amount)
				var new_item_grids = _container_repository.get_container(inv_name).find_grids_by_item_data(item)
				assert(not new_item_grids.is_empty())
				GBIS.sig_inv_item_updated.emit(inv_name, new_item_grids[0])
				if new_item_data.current_amount <= 0:
					return true
	var grids = _container_repository.get_container(inv_name).add_item(new_item_data)
	if not grids.is_empty():
		GBIS.sig_inv_item_added.emit(inv_name, new_item_data, grids)
		return true
	return false

func drop_state_at(container_name: String, item_data: ItemData, hovered_grid: Vector2i, grab_offset: Vector2i) -> ContainerData.DropState:
	var container := _container_repository.get_container(container_name)
	if container == null:
		return ContainerData.DropState.BLOCKED
	return container.drop_state_at(item_data, hovered_grid, grab_offset)


func stack_moving_item(inv_name: String, anchor_grid: Vector2i) -> bool:
	var moving := GBIS.moving_item_service.moving_item
	if moving == null:
		return false
	var stackable := find_item_data_by_grid(inv_name, anchor_grid) as StackableData
	if stackable == null or stackable.item_name != moving.item_name:
		return false
	var amount_left := stackable.add_amount(moving.current_amount)
	if amount_left > 0:
		moving.current_amount = amount_left
		moving.sig_refresh.emit()
	GBIS.sig_inv_item_updated.emit(inv_name, anchor_grid)
	return amount_left <= 0


func place_moving_item(inv_name: String, grid_id: Vector2i) -> bool:
	return place_to(inv_name, GBIS.moving_item_service.moving_item, grid_id)


func restore_to_grid(container_name: String, grid: Vector2i, moving: ItemData) -> bool:
	var container := _container_repository.get_container(container_name)
	if container == null:
		return false

	var grids := container.try_add_to_grid(moving, grid)
	if grids.is_empty():
		grids = container.add_item(moving)
	if grids.is_empty():
		push_warning("背包：取消拿起失败，%s 已没有空位" % container_name)
		return false

	GBIS.sig_inv_item_added.emit(container_name, moving, grids)
	return true

func use_item(inv_name: String, grid_id: Vector2i) -> bool:
	var item_data = find_item_data_by_grid(inv_name, grid_id)
	if not item_data:
		return false
	if item_data is EquipmentData:
		if GBIS.equipment_slot_service.try_equip(item_data):
			remove_item_by_data(inv_name, item_data)
			return true
	elif item_data is ConsumableData:
		if item_data.use():
			remove_item_by_data(inv_name, item_data)
		else:
			GBIS.sig_inv_item_updated.emit(inv_name, grid_id)
		return true
	elif item_data.activate():
		GBIS.sig_item_activated.emit(item_data)
		return true
	return false

func split_item(inv_name: String, grid_id: Vector2i, offset: Vector2i, base_size: int) -> ItemData:
	var inv = _container_repository.get_container(inv_name)
	if inv:
		var item = inv.find_item_data_by_grid(grid_id)
		if item and item is StackableData and item.stack_size > 1 and item.current_amount > 1:
			var origin_amount = item.current_amount
			var new_amount_1 = origin_amount / 2
			var new_amount_2 = origin_amount - new_amount_1
			item.current_amount = new_amount_1
			GBIS.sig_inv_item_updated.emit(inv_name, grid_id)
			
			var new_item = item.duplicate()
			new_item.current_amount = new_amount_2
			GBIS.moving_item_service.begin_detached(new_item, offset, base_size)
			return new_item
	return null

func quick_move(inv_name: String, grid_id: Vector2i) -> void:
	var target_inventories = _container_repository.get_quick_move_relations(inv_name)
	var item_to_move = _container_repository.get_container(inv_name).find_item_data_by_grid(grid_id)
	if target_inventories.is_empty() or not item_to_move:
		return
	for target_container in target_inventories:
		if not GBIS.opened_containers.has(target_container):
			continue
		if add_item(target_container, item_to_move):
			remove_item_by_data(inv_name, item_to_move)
			break
		elif item_to_move is StackableData:
			GBIS.sig_inv_item_updated.emit(inv_name, grid_id)

func quick_sell(inv_name: String, grid_id: Vector2i) -> bool:
	if not GBIS.opened_containers.has(inv_name) or not GBIS.has_opened_shop():
		return false
	var item := find_item_data_by_grid(inv_name, grid_id)
	if item == null:
		return false
	if not GBIS.shop_service.sell_item(item):
		return false
	remove_item_by_data(inv_name, item)
	return true

func add_quick_move_relation(inv_name: String, target_inv_name: String) -> void:
	_container_repository.add_quick_move_relation(inv_name, target_inv_name)

func remove_quick_move_relation(inv_name: String, target_inv_name: String) -> void:
	_container_repository.remove_quick_move_relation(inv_name, target_inv_name)

func remove_item_by_data(inv_name: String, item_data: ItemData) -> void:
	if _container_repository.get_container(inv_name).remove_item(item_data):
		GBIS.sig_inv_item_removed.emit(inv_name, item_data)

func get_container(container_name: String) -> ContainerData:
	if GBIS.inventory_names.has(container_name):
		return _container_repository.get_container(container_name)
	return null
