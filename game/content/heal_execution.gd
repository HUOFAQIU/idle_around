class_name HealExecution extends GameplayExecutionCalculation

@export var base_heal: float = 0.0
## 净化比例：治疗量的 5%
@export_range(0.0, 1.0, 0.01) var cleanse_ratio: float = 0.05


func execute(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var multiplier := CritResolution.multiplier(spec)
	var heal := floorf(maxf(base_heal * multiplier, 0.0))
	if heal <= 0.0:
		return {}

	CritResolution.inject_if_critical(spec, multiplier)

	var result := {"health": heal}
	if target_asc != null:
		var cleanse := floorf(heal * cleanse_ratio)
		if cleanse > 0.0:
			result["burn"] = -cleanse
			result["poison"] = -cleanse
	return result
