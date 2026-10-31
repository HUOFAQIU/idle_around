## 魂灵触发规则：战斗中某个事件发生时，对指定范围施加一批效果。
##
## 被动魂灵和主动魂灵都可以配；主动魂灵还能在触发时给自己充能。
## 后续要加“受到伤害”“击杀”等事件时，在 Event 里补枚举，
## 并在 BattleUnit 的事件分发处补检查。
class_name PassiveTrigger extends Resource

## 触发效果读取数值用的 SetByCaller 标签
const MAGNITUDE_TAG : StringName = &"Data.TriggerMagnitude"

enum Event {
	ENEMY_MOVED,
	SELF_HEALTH_BELOW_PERCENT,
	OTHER_SOUL_USED,  ## 另一个魂灵被使用（技能成功激活）
	FREEZE_APPLIED,   ## 本魂灵造成的冻结成功施加到一个单位
}

## 效果施加范围
enum TargetScope {
	EVENT_TARGET,  ## 事件目标（例：移动的怪物）
	SELF,          ## 触发器所属单位自己
	ALL_ENEMIES,   ## 触发器所属单位的全体敌人
}

## 触发事件
@export var event: Event = Event.ENEMY_MOVED
## 本触发器施加效果时传入的数值（例如 8 层灼烧）
@export var magnitude: float = 0.0
## 触发时按顺序施加的效果
@export var effects: Array[GameplayEffect] = []

## 生命值事件：严格低于该比例时触发（0~1）
@export_range(0.0, 1.0, 0.01) var threshold_ratio: float = 0.5
## 效果施加范围
@export var target_scope: TargetScope = TargetScope.EVENT_TARGET
## 每场战斗只触发一次（半血这类一次性事件用）
@export var once_per_battle: bool = false
## 触发时给来源魂灵技能充能的秒数；0 = 不充能
@export_range(0.0, 60.0, 0.1) var charge_source_seconds: float = 0.0
## OTHER_SOUL_USED 事件：被使用的魂灵必须带齐这些标签；空 = 不限
@export var required_soul_tags: Array[StringName] = []
## OTHER_SOUL_USED 事件：被使用的魂灵必须与本魂灵同一部位栏、左右紧邻
@export var require_adjacent: bool = false
## 触发日志里显示的名字；留空则不写触发日志
@export var trigger_name: String = ""
