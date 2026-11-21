class_name ContainerIds
extends RefCounted

const WAREHOUSE_PREFIX: String = "inventory_"

const MAIN_INVENTORY: String = "inventory_0"
const SHOP: String = "shop_0"

const VESSEL_GRID: String = "vessel_cells"


static func warehouse_page(page: int) -> String:
	return "%s%d" % [WAREHOUSE_PREFIX, page]
