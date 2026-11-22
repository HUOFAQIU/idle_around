class_name SoulDamagePreview
extends RefCounted

var base_damage: float = 0.0
var bonus_per_matching_soul: float = 0.0
var matching_soul_types: Array[StringName] = []
var matching_soul_count: int = 0
var player_damage_bonus: float = 0.0
var vessel_damage_bonus: float = 0.0
var has_damage: bool = false
var is_dynamic: bool = false
var has_runtime: bool = false


static func base_for(skill: SkillDefinition, soul: SoulData = null) -> SoulDamagePreview:
	var preview := SoulDamagePreview.new()
	var execution := find_damage_execution(skill)
	if execution == null:
		return preview
	preview.has_damage = true
	preview.base_damage = execution.base_damage
	var emotion_damage := SoulEmotionValues.damage_base(soul)
	if emotion_damage >= 0.0:
		preview.base_damage = emotion_damage
	preview.bonus_per_matching_soul = execution.bonus_per_matching_soul
	preview.matching_soul_types = execution.matching_soul_types.duplicate()
	return preview


static func for_soul(soul: SoulData, runtime: SoulRuntime) -> SoulDamagePreview:
	var preview := base_for(soul.skill if soul != null else null, soul)
	if runtime == null or not is_instance_valid(runtime.owner_unit):
		return preview
	var unit := runtime.owner_unit
	preview.is_dynamic = true
	preview.has_runtime = true
	preview.matching_soul_count = SoulDamageExecution.matching_soul_count(
		unit.loadout, preview.matching_soul_types
	)
	preview.player_damage_bonus = _player_damage_bonus(unit)
	preview.vessel_damage_bonus = maxf(runtime.vessel_damage_bonus, 0.0)
	return preview


static func preview_for(
	soul: SoulData,
	vessel: SoulVesselData,
	equipped_souls: Array[SoulData]
) -> SoulDamagePreview:
	var preview := base_for(soul.skill if soul != null else null, soul)
	if soul == null:
		return preview
	var souls: Array[SoulData] = equipped_souls.duplicate()
	if vessel != null:
		for item in vessel.ensure_contents().items:
			if item is SoulData and not souls.has(item):
				souls.append(item as SoulData)
	if not souls.has(soul):
		souls.append(soul)
	preview.is_dynamic = true
	preview.matching_soul_count = _matching_soul_count(souls, preview.matching_soul_types)
	preview.player_damage_bonus = _passive_damage_bonus(SoulLoadout.collect_passive_effects(souls))
	preview.vessel_damage_bonus = maxf(vessel.soul_damage_bonus(), 0.0) if vessel != null else 0.0
	return preview


func total() -> float:
	var soul_bonus := float(matching_soul_count) * bonus_per_matching_soul
	return floorf(SoulDamageExecution.total_before_crit(
		base_damage, player_damage_bonus, soul_bonus, vessel_damage_bonus
	))


static func find_damage_execution(skill: SkillDefinition) -> SoulDamageExecution:
	if skill == null:
		return null
	for step in skill.steps:
		if not step is UnitSkillStep:
			continue
		for effect in (step as UnitSkillStep).effects:
			if effect == null:
				continue
			for execution in effect.executions:
				if execution is SoulDamageExecution:
					return execution as SoulDamageExecution
	return null


static func _player_damage_bonus(unit: BattleUnit) -> float:
	if unit == null or unit.asc == null:
		return 0.0
	var attr := unit.asc.get_attribute("damage_bonus")
	return maxf(attr.current_value, 0.0) if attr != null else 0.0


static func _passive_damage_bonus(effects: Array[GameplayEffect]) -> float:
	var addition := 0.0
	var percent_addition := 0.0
	var multiplication := 1.0
	var division := 1.0
	var has_override := false
	var override_priority := -2147483648
	var override_value := -INF
	for effect in effects:
		if effect == null:
			continue
		for modifier in effect.modifiers:
			if modifier == null or modifier.attribute_name != "damage_bonus":
				continue
			if modifier.magnitude_calculation != GameplayEffectModifier.MagnitudeCalculationType.STATIC:
				continue
			var magnitude := modifier.calculate_magnitude(1.0)
			match modifier.operation:
				GameplayEffectModifier.Operation.ADD:
					addition += magnitude
				GameplayEffectModifier.Operation.PERCENT_ADD:
					percent_addition += magnitude
				GameplayEffectModifier.Operation.MULTIPLY:
					multiplication *= magnitude
				GameplayEffectModifier.Operation.DIVIDE:
					if not is_zero_approx(magnitude):
						division *= magnitude
				GameplayEffectModifier.Operation.OVERRIDE:
					if (
						not has_override
						or modifier.override_priority > override_priority
						or (
							modifier.override_priority == override_priority
							and magnitude > override_value
						)
					):
						has_override = true
						override_priority = modifier.override_priority
						override_value = magnitude
	var value := override_value if has_override else addition * (1.0 + percent_addition) * multiplication / division
	return maxf(floorf(value), 0.0)


static func _matching_soul_count(souls: Array[SoulData], matching_types: Array[StringName]) -> int:
	var count := 0
	for soul in souls:
		if _soul_matches(soul, matching_types):
			count += 1
	return count


static func _soul_matches(soul: SoulData, matching_types: Array[StringName]) -> bool:
	if soul == null:
		return false
	for soul_type in matching_types:
		if soul.types.has(soul_type):
			return true
	return false
