class_name AbilityEffectApplier
extends RefCounted


static func apply_list(
	owner_asc: AbilitySystemComponent,
	ability_name: String,
	ability_level: float,
	soul_runtime: SoulRuntime,
	effects: Array[GameplayEffect],
	target: BattleUnit,
	crit_multiplier: float,
	trace: CombatTrace,
	status_magnitude: float = -1.0,
	effect_duration: float = 0.0
) -> void:
	for effect in effects:
		if effect != null:
			apply_one(
				owner_asc,
				ability_name,
				ability_level,
				soul_runtime,
				effect,
				target,
				crit_multiplier,
				trace,
				status_magnitude,
				effect_duration
			)


static func apply_one(
	owner_asc: AbilitySystemComponent,
	ability_name: String,
	ability_level: float,
	soul_runtime: SoulRuntime,
	effect: GameplayEffect,
	target: BattleUnit,
	crit_multiplier: float,
	trace: CombatTrace,
	status_magnitude: float = -1.0,
	effect_duration: float = 0.0
) -> void:
	if owner_asc == null or effect == null or target == null or target.asc == null:
		return
	var caster := owner_asc.get_parent() as BattleUnit
	if caster == null:
		return
	var context := SoulEffectContext.new(caster, caster, trace)
	context.soul_runtime = soul_runtime
	var target_data := GameplayAbilityTargetData.new()
	target_data.append_node(target)
	context.target_data = target_data
	var spec := GameplayEffectSpec.new(effect, context, ability_level)
	spec.display_name = ability_name
	spec.set_set_by_caller_magnitude(GameplayTags.Data_CritMultiplier, crit_multiplier)
	if status_magnitude >= 0.0:
		spec.set_set_by_caller_magnitude(GameplayTags.Data_SkillMagnitude, status_magnitude)
	if effect_duration > 0.0:
		spec.duration = effect_duration
	owner_asc.apply_effect_spec_to_target(spec, target.asc)
	if effect.granted_tags.has(GameplayTags.State_Frozen):
		caster.notify_freeze_applied(target, trace)
		if soul_runtime != null:
			soul_runtime.add_counter("freezes_applied")


static func targets_summary(groups: Array) -> String:
	var counts: Dictionary = {}
	var order: Array[String] = []
	for group in groups:
		for unit in group:
			if unit == null:
				continue
			var label: String = unit.unit_name
			if not counts.has(label):
				counts[label] = 0
				order.append(label)
			counts[label] = int(counts[label]) + 1
	var parts: Array[String] = []
	for label in order:
		var count := int(counts[label])
		parts.append(label if count == 1 else "%s ×%d" % [label, count])
	return "、".join(parts)


static func target_count(groups: Array) -> int:
	var count := 0
	for group in groups:
		count += group.size()
	return count
