## 怪物携带的一颗魂灵与掉落几率。
##
## 怪物没有魂器，魂灵按列表顺序生成虚拟魂灵栏；配了哪些魂灵就排哪些。
## 击败怪物时每条各掷一次骰子。

class_name MonsterSoulEntry extends Resource

@export var soul: SoulData
## 掉落几率（0~1）
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.2
