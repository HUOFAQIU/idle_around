## 战斗中一颗已装备魂灵的位置信息。
##
## 用于“左/右相邻”判断和“同冷却从左到右”的触发顺序：
##   container_name  所在部位容器（cell_0..cell_3）
##   column          魂灵占用的最左列
##   width           魂灵占用的列数

class_name SoulSlot extends RefCounted

var soul: SoulData
var container_name: String = ""
var column: int = 0
var width: int = 1


## 没有真实容器的单位（怪物）按魂灵部位生成虚拟魂灵栏。
## 只处理实际配置的部位，蛇不会凭空多出手/腿。
static func virtual_slots(soul_list: Array[SoulData]) -> Array[SoulSlot]:
	var slots: Array[SoulSlot] = []
	var part_columns: Dictionary = {}
	for soul in soul_list:
		if soul == null:
			slots.append(null)
			continue
		var part := soul.equip_part if not soul.equip_part.is_empty() else "ANY"
		var slot := SoulSlot.new()
		slot.soul = soul
		slot.container_name = part
		slot.column = int(part_columns.get(part, 0))
		slot.width = maxi(soul.columns, 1)
		part_columns[part] = slot.column + slot.width
		slots.append(slot)
	return slots
