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
