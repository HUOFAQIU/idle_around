class_name SoulDamageExecution extends GameplayExecutionCalculation

## 这个伤害效果的基础伤害（正数）
@export var base_damage: float = 0.0

## 每有一颗带匹配类型的魂灵，额外增加的伤害（在暴击前加到基础伤害上）
@export var bonus_per_matching_soul: float = 0.0

## 匹配的魂灵类型（SoulData.types）；空 = 不按魂灵数量加成
@export var matching_soul_types: Array[StringName] = []


static func total_before_crit(
	base_damage_value: float,
	damage_bonus: float,
	soul_bonus: float,
	vessel_bonus: float
) -> float:
	return maxf(base_damage_value + damage_bonus + soul_bonus + vessel_bonus, 0.0)


static func matching_soul_count(loadout: Array, matching_types: Array[StringName]) -> int:
	var count := 0
	for runtime in loadout:
		if not (runtime is Object):
			continue
		var soul: Variant = runtime.get("soul")
		if soul == null:
			continue
		var types: Variant = soul.get("types")
		if types == null:
			continue
		for soul_type in matching_types:
			if types.has(soul_type):
				count += 1
				break
	return count


func execute(spec: GameplayEffectSpec, target_asc: AbilitySystemComponent) -> Dictionary:
	var damage_bonus := 0.0
	var source_asc := _source_asc(spec)
	if source_asc != null:
		var attr := source_asc.get_attribute("damage_bonus")
		if attr != null:
			damage_bonus = maxf(attr.current_value, 0.0)

	var crit_multiplier := CritResolution.multiplier(spec)

	var soul_bonus := _matching_soul_bonus(source_asc)
	var vessel_bonus := _vessel_damage_bonus(spec)
	var damage := total_before_crit(_damage_base(spec), damage_bonus, soul_bonus, vessel_bonus) * crit_multiplier
	if damage <= 0.0:
		return {}
	CritResolution.inject_if_critical(spec, crit_multiplier)
	return DamageResolver.split_damage(target_asc, damage, 1.0)


func _matching_soul_bonus(source_asc: AbilitySystemComponent) -> float:
	if bonus_per_matching_soul <= 0.0 or matching_soul_types.is_empty():
		return 0.0
	if source_asc == null:
		return 0.0
	var unit := source_asc.get_parent() as BattleUnit
	if unit == null:
		return 0.0
	var count := matching_soul_count(unit.loadout, matching_soul_types)
	return float(count) * bonus_per_matching_soul


func _damage_base(spec: GameplayEffectSpec) -> float:
	if spec == null or spec.context == null:
		return base_damage
	var runtime: Variant = spec.context.get("soul_runtime")
	if not runtime is Object:
		return base_damage
	var soul: Variant = runtime.get("soul")
	if not soul is SoulData:
		return base_damage
	var value := SoulEmotionValues.damage_base(soul as SoulData)
	return value if value >= 0.0 else base_damage


func _vessel_damage_bonus(spec: GameplayEffectSpec) -> float:
	if spec == null or spec.context == null:
		return 0.0
	var runtime: Variant = spec.context.get("soul_runtime")
	if not runtime is Object:
		return 0.0
	var bonus: Variant = runtime.get("vessel_damage_bonus")
	return maxf(float(bonus) if bonus != null else 0.0, 0.0)


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
