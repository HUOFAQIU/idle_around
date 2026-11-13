## 魂器对内部魂灵的一条效果。
##
## 只描述“加什么”，由战斗侧读取；显示文案仍写在 SoulVesselData.tooltip_blocks。
## 当前只实现直接伤害加成，后续增加新属性时在这里扩展 Stat。
class_name SoulVesselEffect extends Resource

enum Stat { DAMAGE_BONUS }

@export var stat: Stat = Stat.DAMAGE_BONUS
@export var value: float = 0.0
