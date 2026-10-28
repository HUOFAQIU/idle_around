## 被动魂灵的触发规则：战斗中某个事件发生时，对事件目标施加一批效果。
##
## 当前只支持“敌方单位移动”。后续要加“受到伤害”“击杀”等事件时，
## 在 Event 里补枚举，并在 BattleUnit._on_battle_unit_moved() 那一层分发。
class_name PassiveTrigger extends Resource

## 触发效果读取数值用的 SetByCaller 标签
const MAGNITUDE_TAG : StringName = &"Data.TriggerMagnitude"

enum Event {
	ENEMY_MOVED,
}

## 触发事件
@export var event: Event = Event.ENEMY_MOVED
## 本触发器施加效果时传入的数值（例如 8 层灼烧）
@export var magnitude: float = 0.0
## 触发时按顺序施加给事件目标的效果
@export var effects: Array[GameplayEffect] = []
