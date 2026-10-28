## 魂灵直接伤害的 GAS 执行计算。
##
## 伤害 = (base_damage + 施法者 damage_bonus) × 暴击倍率
## 暴击倍率由 AutoCastAbility 通过 spec 的 SetByCaller 传入。
## 最终伤害交给 DamageResolver 先扣护盾，再扣生命。
##
## 灼烧/剧毒/治疗不要挂这个 execution，它们走自己的效果。
class_name SoulDamageExecution extends GameplayExecutionCalculation

## AutoCastAbility 写入的暴击倍率标签；不暴击时写 1.0
const CRIT_MULTIPLIER_TAG : StringName = &"Data.CritMultiplier"

## 这个伤害效果的基础伤害（正数）
@export var base_damage: float = 0.0


func execute(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var damage_bonus := 0.0
	var source_asc := _source_asc(spec)
	if source_asc != null:
		var attr := source_asc.get_attribute("damage_bonus")
		if attr != null:
			damage_bonus = maxf(attr.current_value, 0.0)

	var crit_multiplier := 1.0
	if spec != null:
		crit_multiplier = maxf(spec.get_set_by_caller_magnitude(CRIT_MULTIPLIER_TAG, 1.0), 0.0)

	var damage := maxf(base_damage + damage_bonus, 0.0) * crit_multiplier
	if damage <= 0.0:
		return {}
	if crit_multiplier > 1.0:
		spec.inject_tag(GameplayTags.Event_Combat_Critical)
	return DamageResolver.split_damage(target_asc, damage, 1.0)


## 施法者的 ASC；context.instigator 通常是 BattleUnit
func _source_asc(spec: GameplayEffectSpec) -> AbilitySystemComponent:
	if spec == null or spec.context == null:
		return null
	var instigator := spec.context.instigator
	if instigator is AbilitySystemComponent:
		return instigator as AbilitySystemComponent
	if instigator != null:
		return instigator.get_node_or_null("AbilitySystemComponent") as AbilitySystemComponent
	return null
