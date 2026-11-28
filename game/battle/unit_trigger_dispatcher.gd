class_name UnitTriggerDispatcher
extends RefCounted


static func on_enemy_moved(
	owner: BattleUnit,
	moving_unit: BattleUnit,
	from_cell: Vector2i,
	to_cell: Vector2i
) -> void:
	if owner.is_dead or owner.battle == null or not owner.battle.is_running or owner.asc == null:
		return
	if moving_unit == null or moving_unit.is_dead or moving_unit.team == owner.team:
		return
	if owner.soul_loadout == null or not owner.soul_loadout.has_trigger(GameplayTags.Event_Movement_UnitMoved):
		return
	var trace := CombatTrace.new("event:UnitMoved", null)
	owner.asc.send_gameplay_event(GameplayTags.Event_Movement_UnitMoved, {
		"target": moving_unit,
		"from_cell": from_cell,
		"to_cell": to_cell,
		"trace": trace,
	})


static func check_health_triggers(owner: BattleUnit, old_value: float, new_value: float) -> void:
	if owner.is_dead or owner.asc == null or owner.max_health_attr == null or new_value <= 0.0:
		return
	if new_value >= old_value:
		return
	var max_hp := owner.max_health_attr.current_value
	if max_hp <= 0.0:
		return
	var ratio := new_value / max_hp
	if owner.soul_loadout == null or not owner.soul_loadout.has_health_trigger_for(ratio):
		return
	var trace := CombatTrace.new("event:HealthBelowPercent", null)
	owner.asc.send_gameplay_event(GameplayTags.Event_Health_BelowPercent, {
		"target": owner,
		"old": old_value,
		"new": new_value,
		"ratio": ratio,
		"trace": trace,
	})


static func notify_soul_used(
	owner: BattleUnit,
	used: ChargedAbility,
	parent_trace: CombatTrace = null
) -> void:
	if owner.is_dead or owner.battle == null or not owner.battle.is_running or owner.asc == null:
		return
	if owner.soul_loadout == null or not owner.soul_loadout.has_trigger(GameplayTags.Event_Combat_SoulUsed):
		return
	var trace := parent_trace if parent_trace != null else CombatTrace.new("event:SoulUsed", null)
	var used_soul: SoulData = null
	if used is AutoCastAbility:
		used_soul = (used as AutoCastAbility).soul_data
	owner.asc.send_gameplay_event(GameplayTags.Event_Combat_SoulUsed, {
		"target": owner,
		"used_ability": used,
		"used_soul": used_soul,
		"trace": trace,
	})


static func notify_freeze_applied(
	owner: BattleUnit,
	event_target: BattleUnit,
	parent_trace: CombatTrace = null
) -> void:
	if owner.battle == null or not owner.battle.is_running or event_target == null:
		return
	var trace := parent_trace if parent_trace != null else CombatTrace.new("event:FreezeApplied", null)
	for unit in owner.battle.trigger_listeners(GameplayTags.Event_Combat_FreezeApplied):
		if unit.team == event_target.team or unit.asc == null:
			continue
		if unit.soul_loadout == null or not unit.soul_loadout.has_trigger(GameplayTags.Event_Combat_FreezeApplied):
			continue
		unit.asc.send_gameplay_event(GameplayTags.Event_Combat_FreezeApplied, {
			"target": event_target,
			"source": owner,
			"trace": trace,
		})


static func notify_slow_applied(owner: BattleUnit, parent_trace: CombatTrace = null) -> void:
	if owner.battle == null or not owner.battle.is_running:
		return
	var trace := parent_trace if parent_trace != null else CombatTrace.new("event:SlowApplied", null)
	for unit in owner.battle.trigger_listeners(GameplayTags.Event_Combat_SlowApplied):
		if unit.team == owner.team or unit.asc == null:
			continue
		if unit.soul_loadout == null or not unit.soul_loadout.has_trigger(GameplayTags.Event_Combat_SlowApplied):
			continue
		unit.asc.send_gameplay_event(GameplayTags.Event_Combat_SlowApplied, {
			"target": owner,
			"source": owner,
			"trace": trace,
		})


static func apply_trigger_effect(
	owner: BattleUnit,
	effect: GameplayEffect,
	target: BattleUnit,
	magnitude: float,
	suppress_state_log: bool = false,
	trace: CombatTrace = null,
	display_name: String = "",
	soul_runtime: SoulRuntime = null,
	effect_duration: float = 0.0
) -> void:
	if effect == null or owner.asc == null or target == null or target.asc == null:
		return
	var context := SoulEffectContext.new(owner, owner, trace)
	context.soul_runtime = soul_runtime
	context.target_data.append_node(target)
	var spec := GameplayEffectSpec.new(effect, context, 1.0)
	if not display_name.is_empty():
		spec.display_name = display_name
	spec.set_set_by_caller_magnitude(GameplayTags.Data_TriggerMagnitude, magnitude)
	if effect_duration > 0.0:
		spec.duration = effect_duration
	if suppress_state_log:
		spec.inject_tag(BattleUnit.SUPPRESS_STATE_LOG_TAG)
	owner.asc.apply_effect_spec_to_target(spec, target.asc)
	if effect.granted_tags.has(GameplayTags.State_Frozen):
		notify_freeze_applied(owner, target, trace)
