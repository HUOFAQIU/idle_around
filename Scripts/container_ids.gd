class_name ContainerIds
extends RefCounted
## 容器名（GBIS 注册键 / 存档键）与角色魂器网格的集中定义。
##
## 场景里的 `container_name` 仍是字面量（.tscn 不能引用常量），
## 这里的常量必须与场景保持一致；改名时两边一起改。

const WAREHOUSE_PREFIX: String = "inventory_"

const MAIN_INVENTORY: String = "inventory_0"
const SHOP: String = "shop_0"

## 角色窗口的魂器网格容器名；魂器按占格放进来
const VESSEL_GRID: String = "vessel_cells"


## 仓库页码（0 起）→ 容器名
static func warehouse_page(page: int) -> String:
	return "%s%d" % [WAREHOUSE_PREFIX, page]
