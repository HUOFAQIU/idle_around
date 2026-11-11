extends Node
## 装备槽业务类
class_name EquipmentSlotService

## 装备槽数据库引用
var _equipment_slot_repository: EquipmentSlotRepository = EquipmentSlotRepository.instance

## 保存所有装备槽数据
func save() -> void:
	_equipment_slot_repository.save()

## 读取所有装备槽数据
func load() -> void:
	_equipment_slot_repository.load()

## 获取指定名称的装备槽
func get_slot(slot_name: String) -> EquipmentSlotData:
	return _equipment_slot_repository.get_slot(slot_name)

## 注册装备槽，如果重名，则检测是否和已有的数据相符
## 注意：如果装备槽不显示，大概率是注册返回失败了，请检查配置
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

## 尝试穿戴装备，如果成功，发射信号 sig_slot_item_equipped
func try_equip(item_data: ItemData) -> bool:
	if not item_data:
		return false
	var slot = _equipment_slot_repository.try_equip(item_data)
	if slot:
		GBIS.sig_slot_item_equipped.emit(slot.slot_name, item_data)
		return true
	return false

## 尝试装备正在移动的物品，返回是否成功
func equip_moving_item(slot_name: String) -> bool:
	return equip_to(slot_name, GBIS.moving_item_service.moving_item)

## 装备物品到指定的装备槽，成功后发射信号 sig_slot_item_equipped
func equip_to(slot_name: String, item_data: ItemData) -> bool:
	var slot := _equipment_slot_repository.get_slot(slot_name)
	if slot == null or item_data == null:
		return false
	if slot.equip(item_data):
		GBIS.sig_slot_item_equipped.emit(slot_name, item_data)
		return true
	return false

## 脱掉装备，成功后发射信号 sig_slot_item_unequipped
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

## 从装备槽拿起供拖拽；成功后发射信号 sig_slot_item_unequipped
func take_from_slot(slot_name: String) -> ItemData:
	var slot := _equipment_slot_repository.get_slot(slot_name)
	if slot == null:
		return null
	var item_data := slot.unequip()
	if item_data != null:
		GBIS.sig_slot_item_unequipped.emit(slot_name, item_data)
	return item_data


## 取消拖拽时放回原槽，成功后发射信号 sig_slot_item_equipped
func restore_to_slot(slot_name: String, item_data: ItemData) -> bool:
	return equip_to(slot_name, item_data)
