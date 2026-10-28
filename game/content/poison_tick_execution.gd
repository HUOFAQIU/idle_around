## 剧毒的周期结算。
##
## 每秒造成当前剧毒值的伤害，伤害不衰减、无视护盾。
## 异常状态的暴击只在施加时判定；施加后的每跳都不再暴击。
class_name PoisonTickExecution extends GameplayExecutionCalculation

## 每点剧毒每跳的伤害
@export var damage_per_stack: float = 1.0


## 用 execution 类型判断“这是剧毒周期效果”。
static func is_poison_tick_effect(effect: GameplayEffect) -> bool:
	if effect == null:
		return false
	for execution in effect.executions:
		if execution is PoisonTickExecution:
			return true
	return false


func execute(_spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var poison_attr := target_asc.get_attribute("poison") if target_asc != null else null
	if poison_attr == null:
		return {}

	var stacks := maxf(poison_attr.current_value, 0.0)
	if stacks <= 0.0:
		return {}

	# 剧毒无视护盾，直接扣生命。
	return {"health": -stacks * damage_per_stack}
