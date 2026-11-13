## 获得护盾的执行计算。
##
## 护盾量 = floor(base_shield × 本次技能的暴击倍率)；计算允许小数，落地取整。
## 不吃 GAS 的 damage_bonus；护盾没有上限，也没有持续时间。
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
