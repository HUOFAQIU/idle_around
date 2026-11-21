class_name PassiveTrigger extends Resource

enum TargetScope {
	EVENT_TARGET,
	SELF,
	ALL_ENEMIES,
}

## 触发事件标签（GAS GameplayEvent）
@export_custom(PROPERTY_HINT_NONE, "gas::tag") var event_tag: StringName = &"Event.Movement.UnitMoved"
## 本触发器施加效果时传入的数值（例如 8 层灼烧）
@export var magnitude: float = 0.0
## 触发时按顺序施加的效果
@export var effects: Array[GameplayEffect] = []

## 生命值事件：严格低于该比例时触发（0~1）
@export_range(0.0, 1.0, 0.01) var threshold_ratio: float = 0.5
@export var target_scope: TargetScope = TargetScope.EVENT_TARGET
## 每场战斗只触发一次（半血这类一次性事件用）
@export var once_per_battle: bool = false
## 触发时给来源魂灵技能充能的秒数；0 = 不充能
@export_range(0.0, 60.0, 0.1) var charge_source_seconds: float = 0.0
## 被使用的魂灵必须带齐这些类型；空 = 不限
@export var required_soul_types: Array[StringName] = []
## 被使用的魂灵必须与本魂灵在同一魂器容器内、左右紧邻
@export var require_adjacent: bool = false
## 触发日志里显示的名字；留空则不写触发日志
@export var trigger_name: String = ""


static func event_label(tag: StringName) -> String:
	match tag:
		GameplayTags.Event_Movement_UnitMoved:
			return "敌方移动"
		GameplayTags.Event_Health_BelowPercent:
			return "生命低于比例"
		GameplayTags.Event_Combat_SoulUsed:
			return "其他魂灵被使用"
		GameplayTags.Event_Combat_FreezeApplied:
			return "冻结施加"
		_:
			return String(tag)


static func target_scope_name(scope_id: int) -> String:
	var names: Array[String] = ["EVENT_TARGET", "SELF", "ALL_ENEMIES"]
	return names[scope_id] if scope_id >= 0 and scope_id < names.size() else "UNKNOWN"
