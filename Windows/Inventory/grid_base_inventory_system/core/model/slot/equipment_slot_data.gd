extends Resource
class_name EquipmentSlotData

## 已装备的物品，未装备时null，可用于检测是否有装备
@export_storage var equipped_item: ItemData
## 允许装备的物品大类，对应 ItemData.category
@export_storage var avilable_types: Array[String]
## 装备槽的名字
@export_storage var slot_name: String

func equip(item_data: ItemData) -> bool:
	if can_accept(item_data):
		equipped_item = item_data
		equipped_item.equipped(slot_name)
		return true
	return false

func unequip() -> ItemData:
	if not equipped_item:
		return null
	var ret = equipped_item
	ret.unequipped(slot_name)
	equipped_item = null
	return ret

func is_item_avilable(item_data: ItemData) -> bool:
	if avilable_types.has("ANY") or avilable_types.has(item_data.category):
		return item_data.test_need(slot_name)
	return false


func can_accept(item_data: ItemData) -> bool:
	return equipped_item == null and is_item_avilable(item_data)

@warning_ignore("shadowed_variable")
func _init(slot_name: String = GBIS.DEFAULT_SLOT_NAME, avilable_types: Array[String] = []) -> void:
	self.slot_name = slot_name
	self.avilable_types = avilable_types
