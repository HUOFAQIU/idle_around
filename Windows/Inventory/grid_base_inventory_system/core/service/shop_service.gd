extends BaseContainerService
class_name ShopService

func load_goods(shop_name: String, goods: Array[ItemData]) -> void:
	for good in goods:
		_container_repository.get_container(shop_name).add_item(good.make_instance())

func buy(_shop_name: String, item: ItemData) -> bool:
	if item == null or not item.can_buy():
		return false
	for target_inv in GBIS.inventory_names:
		if GBIS.inventory_service.add_item(target_inv, item):
			item.cost()
			return true
	return false

func sell_item(item: ItemData) -> bool:
	if item and item.can_sell():
		item.sold()
		return true
	return false

func get_container(container_name: String) -> ContainerData:
	if GBIS.shop_names.has(container_name):
		return _container_repository.get_container(container_name)
	return null
