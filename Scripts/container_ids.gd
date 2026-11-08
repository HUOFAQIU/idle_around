class_name ContainerIds
extends RefCounted
## 容器名（GBIS 注册键 / 存档键）与魂灵部位格的集中定义。
##
## 场景里的 `container_name` 仍是字面量（.tscn 不能引用常量），
## 这里的常量必须与场景保持一致；改名时两边一起改。

const WAREHOUSE_PREFIX: String = "inventory_"

const MAIN_INVENTORY: String = "inventory_0"
const SHOP: String = "shop_0"

## 部位枚举 → 魂灵格容器名
const PART_SOUL_CELLS: Dictionary = {
	"HEADSOUL": "cell_0",
	"TORSOSOUL": "cell_1",
	"ARMSSOUL": "cell_2",
	"LEGSSOUL": "cell_3",
}

## 仓库页码（0 起）→ 容器名
static func warehouse_page(page: int) -> String:
	return "%s%d" % [WAREHOUSE_PREFIX, page]


## 魂灵格容器名，按部位顺序排列
static func soul_cells() -> Array[String]:
	var cells: Array[String] = []
	for part in PART_SOUL_CELLS:
		cells.append(String(PART_SOUL_CELLS[part]))
	return cells


## 部位 → 魂灵格容器名；ANY/未知返回空字符串
static func soul_cell_for_part(part: String) -> String:
	return String(PART_SOUL_CELLS.get(part, ""))


## 魂灵格容器名 → 部位枚举；未知返回空字符串
static func part_for_soul_cell(cell: String) -> String:
	for part in PART_SOUL_CELLS:
		if String(PART_SOUL_CELLS[part]) == cell:
			return String(part)
	return ""
