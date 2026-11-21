extends Node
class_name BaseContainerService

var _container_repository: ContainerRepository = ContainerRepository.instance

func save() -> void:
	_container_repository.save()

func load() -> void:
	_container_repository.load()

func regist(container_name: String, columns: int, rows: int, is_shop: bool, avilable_types: Array[String] = ["ANY"]) -> ContainerData:
	if is_shop and not GBIS.shop_names.has(container_name):
		GBIS.shop_names.append(container_name)
	elif not is_shop and not GBIS.inventory_names.has(container_name):
		GBIS.inventory_names.append(container_name)
	return _container_repository.add_container(container_name, columns, rows, avilable_types)

func find_item_data_by_item_name(container_name: String, item_name: String) -> Array[ItemData]:
	var inv = _container_repository.get_container(container_name)
	if inv:
		return inv.find_item_data_by_item_name(item_name)
	return []

func find_item_data_by_grid(container_name: String, grid_id: Vector2i) -> ItemData:
	return _container_repository.get_container(container_name).find_item_data_by_grid(grid_id)

func place_to(container_name: String, item_data: ItemData, grid_id: Vector2i) -> bool:
	if item_data:
		var inv = _container_repository.get_container(container_name)
		if inv:
			var grids = inv.try_add_to_grid(item_data, grid_id - GBIS.moving_item_service.moving_item_offset)
			if grids:
				GBIS.sig_inv_item_added.emit(container_name, item_data, grids)
				return true
	return false
