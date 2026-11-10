## 治疗执行计算。
##
## 治疗量 = base_heal × 释放时的暴击倍率。
## 同时按“治疗量 × cleanse_ratio 向下取整”净化目标自身的灼烧和剧毒。
## 治疗谁就净化谁：target_asc 是实际接受治疗的单位。
class_name HealExecution extends GameplayExecutionCalculation

## 基础治疗量
@export var base_heal: float = 0.0
## 净化比例：治疗量的 5%
@export_range(0.0, 1.0, 0.01) var cleanse_ratio: float = 0.05


func execute(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var multiplier := CritResolution.multiplier(spec)
	var heal := maxf(base_heal * multiplier, 0.0)
	if heal <= 0.0:
		return {}

	CritResolution.inject_if_critical(spec, multiplier)

	var result := {"health": heal}
	if target_asc != null:
		var cleanse: float = floor(heal * cleanse_ratio)
		if cleanse > 0.0:
			result["burn"] = -cleanse
			result["poison"] = -cleanse
	return result
