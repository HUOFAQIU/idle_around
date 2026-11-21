class_name ShieldExecution extends GameplayExecutionCalculation

## 基础护盾量（正数）
@export var base_shield: float = 0.0


func execute(spec: GameplayEffectSpec, _target_asc: AbilitySystemComponent) -> Dictionary:
	var multiplier := CritResolution.multiplier(spec)
	var amount := floorf(maxf(base_shield * multiplier, 0.0))
	if amount <= 0.0:
		return {}
	CritResolution.inject_if_critical(spec, multiplier)
	return {"shield": amount}
