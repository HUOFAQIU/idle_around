## 战斗中一颗已装备魂灵的位置信息。
##
## 用于“左/右相邻”判断和“同冷却从左到右”的触发顺序：
##   container_name  所在容器（魂器内部容器名；怪物为 virtual）
##   vessel          来源魂器（怪物为 null）
##   column          魂灵占用的最左列
##   width           魂灵占用的列数

class_name SoulSlot extends RefCounted

var soul: SoulData
var vessel: SoulVesselData
var container_name: String = ""
var column: int = 0
var width: int = 1


## 没有真实容器的单位（怪物）按魂灵列表顺序生成一行虚拟魂灵栏。
## 魂灵不再分部位，所有魂灵按列从左到右排。
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
