extends Node

const PAGE_COUNT: int = 10
const PAGE_COLUMNS: int = 26
const PAGE_ROWS: int = 24
const PAGE_TYPES: Array[String] = ["SOUL", "VESSEL", "MAP", "STONE"]
const VESSEL_COLUMNS: int = 9
const VESSEL_ROWS: int = 3
const VESSEL_TYPES: Array[String] = ["VESSEL"]
const CONTAINER_IDS: GDScript = preload("res://scripts/container_ids.gd")


func _ready() -> void:
	for page in PAGE_COUNT:
		var avilable_types: Array[String] = PAGE_TYPES.duplicate()
		GBIS.inventory_service.regist(page_name(page), PAGE_COLUMNS, PAGE_ROWS, false, avilable_types)
	var vessel_types: Array[String] = VESSEL_TYPES.duplicate()
	var vessel_grid := GBIS.inventory_service.regist(
		CONTAINER_IDS.VESSEL_GRID, VESSEL_COLUMNS, VESSEL_ROWS, false, vessel_types
	)
	if vessel_grid != null:
		vessel_grid.vessel_kind = "COMBAT"


static func page_name(page: int) -> String:
	return CONTAINER_IDS.warehouse_page(page)



func add_item(item_data: ItemData) -> bool:
	for page in PAGE_COUNT:
		if GBIS.add_item(page_name(page), item_data):
			return true
	return false


func add_item_to_page(page: int, item_data: ItemData) -> bool:
	if page < 0 or page >= PAGE_COUNT:
		return false
	return GBIS.add_item(page_name(page), item_data)
