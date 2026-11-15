## 生命再生的周期结算。
##
## 每秒把当前生命再生与剧毒直接相减，生命再生多时才恢复差值生命；不衰减，溢出部分由生命值上限丢弃。
## 属性原值不改动，反向比较由剧毒周期结算负责。
## 生命再生不是治疗，不触发治疗净化。
## 生命再生状态只在施加时判定暴击，之后每跳都不再暴击。
class_name RegenTickExecution extends NetStatusTickExecution

## 每点生命再生每跳恢复的生命
@export var heal_per_stack: float = 1.0


func status_attribute() -> String:
	return "regen"


func popup_style() -> PopupStyle:
	return PopupStyle.REGEN


func is_heal() -> bool:
	return true


func net_stacks(target_asc: AbilitySystemComponent) -> float:
	return StatusNetRule.regen_minus_poison(target_asc)


func stack_amount() -> float:
	return heal_per_stack
