## 生命再生的周期结算。
##
## 每秒把当前再生与剧毒直接相减，再生多时才恢复差值生命；不衰减，溢出部分由生命值上限丢弃。
## 属性原值不改动，反向比较由剧毒周期结算负责。
## 再生不是治疗，不触发治疗净化。
## 再生状态只在施加时判定暴击，之后每跳都不再暴击。
class_name RegenTickExecution extends GameplayExecutionCalculation

## 每点再生每跳恢复的生命
@export var heal_per_stack: float = 1.0


## 用 execution 类型判断“这是生命再生周期效果”。
static func is_regen_tick_effect(effect: GameplayEffect) -> bool:
	if effect == null:
		return false
	for execution in effect.executions:
		if execution is RegenTickExecution:
			return true
	return false


func execute(_spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var net_stacks := StatusNetRule.regen_minus_poison(target_asc)
	if net_stacks <= 0:
		return {}

	return {"health": net_stacks * heal_per_stack}
