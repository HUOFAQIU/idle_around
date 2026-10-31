## 怪物携带的一颗魂灵：掉落几率与部位都跟着这条配置走。
##
## 部位不单独存，直接取魂灵自身的 equip_part —— 怪物配了哪些魂灵，
## 就有哪些部位；蛇只配头/身两颗，就不会出现手/腿。
## 击败怪物时每条各掷一次骰子。

class_name MonsterSoulEntry extends Resource

## 携带的魂灵
@export var soul: SoulData
## 掉落几率（0~1）
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.2


## 这颗魂灵占用的部位；没配魂灵时为空
func part() -> String:
	return soul.equip_part if soul != null else ""
