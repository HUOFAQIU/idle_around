## 剧毒的周期结算。
##
## 每秒把当前剧毒与再生直接相减，剧毒多时才造成差值伤害；伤害不衰减、无视护盾。
## 属性原值不改动，反向比较由再生周期结算负责。
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
	var net_stacks := StatusNetRule.poison_minus_regen(target_asc)
	if net_stacks <= 0:
		return {}

	# 剧毒无视护盾，直接扣生命。
	return {"health": -net_stacks * damage_per_stack}
