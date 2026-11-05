extends Node
## 仓库分页（Autoload：Warehouse）。
##
## 启动时预注册 [constant PAGE_COUNT] 个容器，每页 [constant PAGE_COLUMNS]×[constant PAGE_ROWS]。
## 页面没打开时容器也存在，存档/读档和掉落都能覆盖全部页。
## 掉落、见闻右键入仓都调用 [method add_item]，从第 1 页开始找空位。

## 仓库页数；以后要扩仓库改这里
const PAGE_COUNT: int = 10
## 每页列数
const PAGE_COLUMNS: int = 26
## 每页行数
const PAGE_ROWS: int = 24
## 每页允许的物品大类
const PAGE_TYPES: Array[String] = ["SOUL"]
## 容器名前缀；第 1 页是 inventory_0
const PAGE_NAME_PREFIX: String = "inventory_"


func _ready() -> void:
	for page in PAGE_COUNT:
		# 每页用自己的数组，避免 ContainerData 共享只读常量
		var avilable_types: Array[String] = PAGE_TYPES.duplicate()
		GBIS.inventory_service.regist(page_name(page), PAGE_COLUMNS, PAGE_ROWS, false, avilable_types)


## 页码（0 起）→ 容器名
static func page_name(page: int) -> String:
	return "%s%d" % [PAGE_NAME_PREFIX, page]


## 容器名 → 页码（0 起）；不是仓库页时返回 -1
static func page_index(container_name: String) -> int:
	if not container_name.begins_with(PAGE_NAME_PREFIX):
		return -1
	var index_text := container_name.trim_prefix(PAGE_NAME_PREFIX)
	if not index_text.is_valid_int():
		return -1
	var page := index_text.to_int()
	if page < 0 or page >= PAGE_COUNT:
		return -1
	return page


## 放入仓库：从第 1 页开始找第一个放得下的页
func add_item(item_data: ItemData) -> bool:
	for page in PAGE_COUNT:
		if GBIS.add_item(page_name(page), item_data):
			return true
	return false


## 放入指定页（0 起）
func add_item_to_page(page: int, item_data: ItemData) -> bool:
	if page < 0 or page >= PAGE_COUNT:
		return false
	return GBIS.add_item(page_name(page), item_data)
