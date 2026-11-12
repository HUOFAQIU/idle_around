class_name ContainerIds
extends RefCounted
## 容器名（GBIS 注册键 / 存档键）与角色魂器槽的集中定义。
##
## 场景里的 `container_name` 仍是字面量（.tscn 不能引用常量），
## 这里的常量必须与场景保持一致；改名时两边一起改。

const WAREHOUSE_PREFIX: String = "inventory_"

const MAIN_INVENTORY: String = "inventory_0"
const SHOP: String = "shop_0"

## 角色窗口里的三个魂器槽容器名，顺序即槽位顺序
const VESSEL_CELLS: Array[String] = [
	"vessel_cell_0",
	"vessel_cell_1",
	"vessel_cell_2",
]


## 仓库页码（0 起）→ 容器名
static func warehouse_page(page: int) -> String:
	return "%s%d" % [WAREHOUSE_PREFIX, page]


## 魂器槽容器名，按槽位顺序
static func vessel_cells() -> Array[String]:
	return VESSEL_CELLS.duplicate()
