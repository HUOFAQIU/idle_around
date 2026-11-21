class_name NetStatusTickExecution extends PeriodicStatusTickExecution


func net_stacks(_target_asc: AbilitySystemComponent) -> float:
	return 0.0


func stack_amount() -> float:
	return 1.0


func execute(_spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var net := net_stacks(target_asc)
	if net <= 0.0:
		return {}
	var amount := floorf(net * stack_amount())
	if amount <= 0.0:
		return {}
	return {"health": amount if is_heal() else -amount}
