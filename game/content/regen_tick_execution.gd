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
