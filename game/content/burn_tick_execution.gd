## 灼烧的周期结算。
##
## 每跳先按当前整数层数结算伤害，再把层数 ×0.97 向下取整：
##   8 层 → 8,7,6,5,4,3,2,1，总计 36
## 每层每跳的伤害由 damage_per_stack 控制，默认 1。
##
## 被动施加的灼烧不写暴击率，所以不会暴击；
## 主动灼烧技能可以在 spec 里写入 Data.CritChance / Data.CritMultiplier。
class_name BurnTickExecution extends GameplayExecutionCalculation

const CRIT_CHANCE_TAG : StringName = &"Data.CritChance"
const CRIT_MULTIPLIER_TAG : StringName = &"Data.CritMultiplier"

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


func execute(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var burn_attr := target_asc.get_attribute("burn") if target_asc != null else null
	if burn_attr == null:
		return {}

	var stacks := int(floor(maxf(burn_attr.current_value, 0.0)))
	if stacks <= 0:
		return {}

	var critical := _roll_critical(spec, target_asc)
	var multiplier := 1.0
	if spec != null:
		multiplier = maxf(spec.get_set_by_caller_magnitude(CRIT_MULTIPLIER_TAG, 1.5), 0.0)
	var damage := stacks * damage_per_stack * (multiplier if critical else 1.0)
	var next_stacks := int(floor(float(stacks) * (1.0 - decay_rate)))

	return {
		"health": -damage,
		"burn": float(next_stacks - stacks),
	}


## 每跳独立判定暴击；没有暴击率就是不暴击。
## 动态暴击标签必须先清掉，否则上一跳暴击会让后面每跳都当成暴击。
func _roll_critical(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> bool:
	if spec == null:
		return false
	spec.dynamic_tags.erase(GameplayTags.Event_Combat_Critical)

	var chance := clampf(spec.get_set_by_caller_magnitude(CRIT_CHANCE_TAG, 0.0), 0.0, 1.0)
	if chance <= 0.0:
		return false
	var rng := _battle_rng(target_asc)
	var roll := rng.randf() if rng != null else randf()
	if roll >= chance:
		return false
	spec.inject_tag(GameplayTags.Event_Combat_Critical)
	return true


func _battle_rng(target_asc: AbilitySystemComponent) -> RandomNumberGenerator:
	if target_asc == null:
		return null
	var unit := target_asc.get_parent() as BattleUnit
	if unit == null or unit.battle == null:
		return null
	return unit.battle.rng
