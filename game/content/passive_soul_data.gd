## 被动魂灵数据：没有冷却，不进入自动施法队列。
## 装备后，战斗开始时把 passive_effects 挂到角色 ASC 上。
## 触发规则 triggers 在 SoulData 基类上，主动/被动魂灵通用。
class_name PassiveSoulData extends SoulData

## 被动效果；用 PassiveEffect（继承 GameplayEffect）标记，通常用 INFINITE 效果添加属性
@export var passive_effects: Array[GameplayEffect] = []
