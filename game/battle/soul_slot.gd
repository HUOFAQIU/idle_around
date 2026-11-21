class_name SoulSlot extends RefCounted

var soul: SoulData
var vessel: SoulVesselData
var container_name: String = ""
var column: int = 0
var width: int = 1


static func virtual_slots(soul_list: Array[SoulData]) -> Array[SoulSlot]:
	var slots: Array[SoulSlot] = []
	var next_column := 0
	for soul_data in soul_list:
		if soul_data == null:
			slots.append(null)
			continue
		var slot := SoulSlot.new()
		slot.soul = soul_data
		slot.container_name = "virtual"
		slot.column = next_column
		slot.width = maxi(soul_data.get_shape().x, 1)
		next_column += slot.width
		slots.append(slot)
	return slots
