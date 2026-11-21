extends Node

const PAGE_COUNT: int = 10
const PAGE_COLUMNS: int = 26
const PAGE_ROWS: int = 24
const PAGE_TYPES: Array[String] = ["SOUL", "VESSEL", "MAP", "STONE"]
const CONTAINER_IDS: GDScript = preload("res://Scripts/container_ids.gd")


func _ready() -> void:
	for page in PAGE_COUNT:
		var avilable_types: Array[String] = PAGE_TYPES.duplicate()
		GBIS.inventory_service.regist(page_name(page), PAGE_COLUMNS, PAGE_ROWS, false, avilable_types)


static func page_name(page: int) -> String:
	return CONTAINER_IDS.warehouse_page(page)


static func page_index(container_name: String) -> int:
	if not container_name.begins_with(CONTAINER_IDS.WAREHOUSE_PREFIX):
		return -1
	var index_text := container_name.trim_prefix(CONTAINER_IDS.WAREHOUSE_PREFIX)
	if not index_text.is_valid_int():
		return -1
	var page := index_text.to_int()
	if page < 0 or page >= PAGE_COUNT:
		return -1
	return page


func add_item(item_data: ItemData) -> bool:
	for page in PAGE_COUNT:
		if GBIS.add_item(page_name(page), item_data):
			return true
	return false


func add_item_to_page(page: int, item_data: ItemData) -> bool:
	if page < 0 or page >= PAGE_COUNT:
		return false
	return GBIS.add_item(page_name(page), item_data)
