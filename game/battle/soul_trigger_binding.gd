## 魂灵触发器在单位上的运行时绑定。
##
## 触发规则是数据资源（PassiveTrigger），同一份资源会被多个单位/多颗同名魂灵共用；
## 这里保存“这一次装备”的来源技能和是否已经触发，避免把运行期状态写进资源。

class_name SoulTriggerBinding extends RefCounted

## 触发规则
var trigger: PassiveTrigger
## 来源魂灵技能；被动魂灵没有技能时为 null
var ability: ChargedAbility
## 来源魂灵的显示名，用于触发日志
var source_name: String = ""
## 本场战斗是否已经触发过（配合 once_per_battle）
var fired: bool = false


func _init(
	p_trigger: PassiveTrigger = null,
	p_ability: ChargedAbility = null,
	p_source_name: String = ""
) -> void:
	trigger = p_trigger
	ability = p_ability
	source_name = p_source_name
