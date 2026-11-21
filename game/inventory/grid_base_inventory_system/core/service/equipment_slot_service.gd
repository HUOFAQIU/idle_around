extends Node
class_name EquipmentSlotService

var _equipment_slot_repository: EquipmentSlotRepository = EquipmentSlotRepository.instance

func save() -> void:
	_equipment_slot_repository.save()

func load() -> void:
	_equipment_slot_repository.load()

func get_slot(slot_name: String) -> EquipmentSlotData:
	return _equipment_slot_repository.get_slot(slot_name)

func regist_slot(slot_name: String, avilable_types: Array[String]) -> bool:
	var slot_data = _equipment_slot_repository.get_slot(slot_name)
	if slot_data:
		var is_same_avilable_types = avilable_types.size() == slot_data.avilable_types.size()
		if is_same_avilable_types:
			for i in range(avilable_types.size()):
				is_same_avilable_types = avilable_types[i] == slot_data.avilable_types[i]
				if not is_same_avilable_types:
					break
		return is_same_avilable_types
	else:
		return _equipment_slot_repository.add_slot(slot_name, avilable_types)

func try_equip(item_data: ItemData) -> bool:
	if not item_data:
		return false
	var slot = _equipment_slot_repository.try_equip(item_data)
	if slot:
		GBIS.sig_slot_item_equipped.emit(slot.slot_name, item_data)
		return true
	return false

func equip_moving_item(slot_name: String) -> bool:
	return equip_to(slot_name, GBIS.moving_item_service.moving_item)

func equip_to(slot_name: String, item_data: ItemData) -> bool:
	var slot := _equipment_slot_repository.get_slot(slot_name)
	if slot == null or item_data == null:
		return false
	if slot.equip(item_data):
		GBIS.sig_slot_item_equipped.emit(slot_name, item_data)
		return true
	return false

func unequip(slot_name) -> ItemData:
	var opened_containers = GBIS.opened_containers.duplicate()
	opened_containers.reverse()
	for current_inventory in opened_containers:
		if not GBIS.inventory_names.has(current_inventory):
			continue
		var item_data = get_slot(slot_name).equipped_item
		if item_data and GBIS.inventory_service.add_item(current_inventory, item_data):
			_equipment_slot_repository.get_slot(slot_name).unequip()
			GBIS.sig_slot_item_unequipped.emit(slot_name, item_data)
			return item_data
	return null

func take_from_slot(slot_name: String) -> ItemData:
	var slot := _equipment_slot_repository.get_slot(slot_name)
	if slot == null:
		return null
	var item_data := slot.unequip()
	if item_data != null:
		GBIS.sig_slot_item_unequipped.emit(slot_name, item_data)
	return item_data


func restore_to_slot(slot_name: String, item_data: ItemData) -> bool:
	return equip_to(slot_name, item_data)
