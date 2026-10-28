## 生命再生的周期结算。
##
## 每秒恢复当前再生值的生命；不衰减，溢出部分由生命值上限丢弃。
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
	var regen_attr := target_asc.get_attribute("regen") if target_asc != null else null
	if regen_attr == null:
		return {}

	var stacks := int(floor(maxf(regen_attr.current_value, 0.0)))
	if stacks <= 0:
		return {}

	return {"health": stacks * heal_per_stack}
