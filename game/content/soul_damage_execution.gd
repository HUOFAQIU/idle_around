## 魂灵直接伤害的 GAS 执行计算。
##
## 伤害 = (base_damage + 施法者 damage_bonus + 匹配魂灵数量 × bonus_per_matching_soul) × 暴击倍率
## 暴击倍率由 AutoCastAbility 通过 spec 的 SetByCaller 传入。
## 最终伤害交给 DamageResolver 先扣护盾，再扣生命。
##
## 灼烧/剧毒/治疗不要挂这个 execution，它们走自己的效果。
class_name SoulDamageExecution extends GameplayExecutionCalculation

## AutoCastAbility 写入的暴击倍率标签；不暴击时写 1.0
const CRIT_MULTIPLIER_TAG : StringName = &"Data.CritMultiplier"

## 这个伤害效果的基础伤害（正数）
@export var base_damage: float = 0.0

## 每有一颗带匹配类型的魂灵，额外增加的伤害（在暴击前加到基础伤害上）
@export var bonus_per_matching_soul: float = 0.0

## 匹配的魂灵类型（SoulData.types）；空 = 不按魂灵数量加成
@export var matching_soul_types: Array[StringName] = []


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

	var soul_bonus := _matching_soul_bonus(source_asc)
	var damage := maxf(base_damage + damage_bonus + soul_bonus, 0.0) * crit_multiplier
	if damage <= 0.0:
		return {}
	if crit_multiplier > 1.0:
		spec.inject_tag(GameplayTags.Event_Combat_Critical)
	return DamageResolver.split_damage(target_asc, damage, 1.0)


## 数施法者装备栏里带匹配类型的魂灵；恐狼自己也算一颗。
func _matching_soul_bonus(source_asc: AbilitySystemComponent) -> float:
	if bonus_per_matching_soul <= 0.0 or matching_soul_types.is_empty():
		return 0.0
	if source_asc == null:
		return 0.0
	var unit := source_asc.get_parent() as BattleUnit
	if unit == null:
		return 0.0
	var count := 0
	for runtime in unit.loadout:
		if runtime == null or runtime.soul == null:
			continue
		for soul_type in matching_soul_types:
			if runtime.soul.types.has(soul_type):
				count += 1
				break
	return float(count) * bonus_per_matching_soul


## 施法者的 ASC；context.instigator 通常是 BattleUnit。
## 周期效果可能比施加者活得久，context 里可能是已释放实例，先判有效再取。
func _source_asc(spec: GameplayEffectSpec) -> AbilitySystemComponent:
	if spec == null or spec.context == null:
		return null
	var instigator := spec.context.instigator
	if is_instance_valid(instigator):
		if instigator is AbilitySystemComponent:
			return instigator as AbilitySystemComponent
		var instigator_asc := instigator.get_node_or_null("AbilitySystemComponent")
		if instigator_asc != null:
			return instigator_asc as AbilitySystemComponent
	var causer := spec.context.causer
	if is_instance_valid(causer):
		if causer is AbilitySystemComponent:
			return causer as AbilitySystemComponent
		var causer_asc := causer.get_node_or_null("AbilitySystemComponent")
		if causer_asc != null:
			return causer_asc as AbilitySystemComponent
	return null
