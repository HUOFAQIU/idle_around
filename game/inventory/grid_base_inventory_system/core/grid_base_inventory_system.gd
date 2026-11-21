extends Node

@warning_ignore("unused_signal")
signal sig_inv_item_added(inv_name: String, item_data: ItemData, grids: Array[Vector2i])
@warning_ignore("unused_signal")
signal sig_inv_item_removed(inv_name: String, item_data: ItemData)
@warning_ignore("unused_signal")
signal sig_inv_item_updated(inv_name: String, grid_id: Vector2i)
@warning_ignore("unused_signal")
signal sig_inv_refresh
@warning_ignore("unused_signal")
signal sig_shop_refresh
@warning_ignore("unused_signal")
signal sig_slot_refresh
@warning_ignore("unused_signal")
signal sig_slot_item_equipped(slot_name: String, item_data: ItemData)
@warning_ignore("unused_signal")
signal sig_slot_item_unequipped(slot_name: String, item_data: ItemData)
@warning_ignore("unused_signal")
signal sig_item_focused(item_data: ItemData, container_name: String)
@warning_ignore("unused_signal")
signal sig_item_focus_lost(item_data: ItemData)
@warning_ignore("unused_signal")
signal sig_item_activated(item_data: ItemData)

const DEFAULT_PLAYER: String = "player_1"
const DEFAULT_INVENTORY_NAME: String = "Inventory"
const DEFAULT_SHOP_NAME: String = "Shop"
const DEFAULT_SLOT_NAME: String = "Equipment Slot"
const DEFAULT_SAVE_FOLDER: String = "res://Saves/"

var inventory_service: InventoryService = InventoryService.new()
var shop_service: ShopService = ShopService.new()
var equipment_slot_service: EquipmentSlotService = EquipmentSlotService.new()
var moving_item_service: MovingItemService = MovingItemService.new()
var item_focus_service: ItemFocusService = ItemFocusService.new()

var item_material: ShaderMaterial

var inventory_names: Array[String]
var shop_names: Array[String]

var opened_containers: Array[String]
var opened_equipment_slots: Array[String]

var current_save_path: String = DEFAULT_SAVE_FOLDER
var current_save_name: String = "default.tres"

var input_click: String = "inv_click"
var input_quick_move: String = "inv_quick_move"
var input_quick_sell: String = "inv_quick_sell"
var input_use: String = "inv_use"
var input_split: String = "inv_split"

func save() -> void:
	inventory_service.save()
	equipment_slot_service.save()

func load() -> void:
	await get_tree().process_frame
	inventory_service.load()
	equipment_slot_service.load()
	sig_inv_refresh.emit()
	sig_slot_refresh.emit()
	sig_shop_refresh.emit()

func get_root() -> Node:
	return get_tree().root

func add_item(inv_name: String, item_data: ItemData) -> bool:
	return inventory_service.add_item(inv_name, item_data)

func add_quick_move_relation(inv_name: String, target_inv_name: String) -> void:
	inventory_service.add_quick_move_relation(inv_name, target_inv_name)

func remove_quick_move_relation(inv_name: String, target_inv_name: String) -> void:
	inventory_service.remove_quick_move_relation(inv_name, target_inv_name)

func has_moving_item() -> bool:
	return moving_item_service.is_dragging()

func has_opened_shop() -> bool:
	for shop_name in shop_names:
		if opened_containers.has(shop_name):
			return true
	return false
