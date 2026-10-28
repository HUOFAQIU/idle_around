## 被动魂灵数据：没有冷却，不进入自动施法队列。
## 装备后，战斗开始时把 passive_effects 挂到角色 ASC 上。
class_name PassiveSoulData extends SoulData

## 被动效果；用 PassiveEffect（继承 GameplayEffect）标记，通常用 INFINITE 效果添加属性
@export var passive_effects: Array[GameplayEffect] = []
## 触发型被动：战斗事件发生时，对事件目标施加 effects
@export var triggers: Array[PassiveTrigger] = []
