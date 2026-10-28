## 灼烧的周期结算。
##
## 每跳先按当前整数层数结算伤害，再把层数 ×0.97 向下取整：
##   8 层 → 8,7,6,5,4,3,2,1，总计 36
## 每层每跳的伤害由 damage_per_stack 控制，默认 1。
##
## 异常状态的暴击只在施加时判定；施加后的每跳都不再暴击。
## 伤害交给 DamageResolver 分流：灼烧对护盾减半并向下取整。
class_name BurnTickExecution extends GameplayExecutionCalculation

## 每层灼烧每跳的伤害
@export var damage_per_stack: float = 1.0
## 每跳衰减比例；当前层数 ×(1 - decay_rate) 后向下取整
@export_range(0.0, 1.0, 0.01) var decay_rate: float = 0.03


## 用 execution 类型判断“这是灼烧周期效果”，不依赖字符串 metadata。
static func is_burn_tick_effect(effect: GameplayEffect) -> bool:
	if effect == null:
		return false
	for execution in effect.executions:
		if execution is BurnTickExecution:
			return true
	return false


func execute(_spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var burn_attr := target_asc.get_attribute("burn") if target_asc != null else null
	if burn_attr == null:
		return {}

	var stacks := int(floor(maxf(burn_attr.current_value, 0.0)))
	if stacks <= 0:
		return {}

	var damage := stacks * damage_per_stack
	var next_stacks := int(floor(float(stacks) * (1.0 - decay_rate)))

	var result := DamageResolver.split_damage(target_asc, damage, 0.5)
	result["burn"] = float(next_stacks - stacks)
	return result
