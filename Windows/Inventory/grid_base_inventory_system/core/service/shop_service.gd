extends BaseContainerService
class_name ShopService

## 加载货物
func load_goods(shop_name: String, goods: Array[ItemData]) -> void:
	for good in goods:
		_container_repository.get_container(shop_name).add_item(good.make_instance())

## 购买物品：检查购买条件，放进第一个有空位的背包，再扣费。
## 购买链路由服务层负责，ItemData 只保留 can_buy() / cost() 钩子。
func buy(_shop_name: String, item: ItemData) -> bool:
	if item == null or not item.can_buy():
		return false
	for target_inv in GBIS.inventory_names:
		if GBIS.inventory_service.add_item(target_inv, item):
			item.cost()
			return true
	return false

## 出售物品（只结算，不负责从容器移除，也不结束拖拽）
func sell_item(item: ItemData) -> bool:
	if item and item.can_sell():
		item.sold()
		return true
	return false

## 只返回商店
func get_container(container_name: String) -> ContainerData:
	if GBIS.shop_names.has(container_name):
		return _container_repository.get_container(container_name)
	return null
