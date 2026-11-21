extends ItemData
class_name EquipmentData

func test_need(slot_name: String) -> bool:
	push_warning("[Override this function] [%s] test passed." % slot_name)
	return true

func equipped(slot_name: String) -> void:
	push_warning("[Override this function] equipped item [%s] at slot [%s]" % [item_name, slot_name])

func unequipped(slot_name: String) -> void:
	push_warning("[Override this function] unequipped item [%s] at slot [%s]" % [item_name, slot_name])
