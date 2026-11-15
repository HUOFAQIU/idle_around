## 剧毒的周期结算。
##
## 每秒把当前剧毒与生命再生直接相减，剧毒多时才造成差值伤害；伤害不衰减、无视护盾。
## 属性原值不改动，反向比较由生命再生周期结算负责。
## 异常状态的暴击只在施加时判定；施加后的每跳都不再暴击。
class_name PoisonTickExecution extends NetStatusTickExecution

## 每点剧毒每跳的伤害
@export var damage_per_stack: float = 1.0


func status_attribute() -> String:
	return "poison"


func remove_when_zero() -> bool:
	return true


func popup_style() -> PopupStyle:
	return PopupStyle.POISON


func net_stacks(target_asc: AbilitySystemComponent) -> float:
	return StatusNetRule.poison_minus_regen(target_asc)


func stack_amount() -> float:
	return damage_per_stack
