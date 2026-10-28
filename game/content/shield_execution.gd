## 获得护盾的执行计算。
##
## 护盾量 = base_shield × 本次技能的暴击倍率。
## 不吃 gym 的 damage_bonus；护盾没有上限，也没有持续时间。
class_name ShieldExecution extends GameplayExecutionCalculation

## 基础护盾量（正数）
@export var base_shield: float = 0.0


func execute(spec: GameplayEffectSpec, _target_asc: AbilitySystemComponent) -> Dictionary:
	var multiplier := 1.0
	if spec != null:
		multiplier = maxf(spec.get_set_by_caller_magnitude(SoulDamageExecution.CRIT_MULTIPLIER_TAG, 1.0), 0.0)
	var amount := maxf(base_shield * multiplier, 0.0)
	if amount <= 0.0:
		return {}
	return {"shield": amount}
