class_name SoulLoadout extends RefCounted

var unit: BattleUnit
var souls: Array[SoulData] = []
var slots: Array[SoulSlot] = []
var abilities: Array[AutoCastAbility] = []
var runtimes: Array[SoulRuntime] = []
var triggers: Array[SoulTriggerAbility] = []


func _init(
	owner_unit: BattleUnit,
	soul_list: Array[SoulData],
	provided_slots: Array[SoulSlot] = []
) -> void:
	unit = owner_unit
	souls = soul_list
	slots = provided_slots
	if slots.is_empty():
		slots = SoulSlot.virtual_slots(souls)
	_create_abilities()
	_create_triggers()
	_apply_slots()
	_create_runtimes()


static func collect_passive_effects(soul_list: Array[SoulData]) -> Array[GameplayEffect]:
	var effects: Array[GameplayEffect] = []
	for soul in soul_list:
		var passive := soul as PassiveSoulData
		if passive == null:
			continue
		for effect in passive.passive_effects:
			if effect != null:
				effects.append(effect)
	return effects


func runtime_for_source_index(index: int) -> SoulRuntime:
	if index >= 0 and index < runtimes.size():
		return runtimes[index]
	return null


func has_trigger(event_tag: StringName) -> bool:
	for trigger_ability in triggers:
		if trigger_ability == null or trigger_ability.trigger_event_tag != event_tag:
			continue
		if (
			trigger_ability.definition != null
			and trigger_ability.definition.once_per_battle
			and trigger_ability.fired
		):
			continue
		return true
	return false


func has_health_trigger_for(ratio: float) -> bool:
	for trigger_ability in triggers:
		if trigger_ability == null or trigger_ability.trigger_event_tag != GameplayTags.Event_Health_BelowPercent:
			continue
		var definition := trigger_ability.definition
		if definition == null:
			continue
		if definition.once_per_battle and trigger_ability.fired:
			continue
		if ratio < definition.threshold_ratio:
			return true
	return false


func clear() -> void:
	for runtime in runtimes:
		if runtime != null:
			SoulRuntimeDB.unregister(runtime)
	runtimes.clear()


func _create_abilities() -> void:
	abilities.clear()
	for soul in souls:
		var ability: AutoCastAbility = null
		if soul != null and not (soul is PassiveSoulData) and soul.skill != null:
			ability = AutoCastAbility.new()
			ability.apply_definition(soul.skill, soul.item_name)
			ability.soul_data = soul
			ability.status_applied.connect(_on_status_applied)
			unit.brain.add_ability(ability)
		abilities.append(ability)


func _on_status_applied(status_name: String, _seconds: float, trace: CombatTrace) -> void:
	if status_name == ChargedAbility.STATUS_SLOW:
		unit.notify_slow_applied(trace)


func _create_triggers() -> void:
	triggers.clear()
	for i in mini(souls.size(), abilities.size()):
		var soul := souls[i]
		if soul == null:
			continue
		for trigger in soul.triggers:
			if trigger == null:
				continue
			var trigger_ability := SoulTriggerAbility.new(
				trigger,
				abilities[i],
				soul.item_name,
				i,
				unit
			)
			trigger_ability.owner_asc = unit.asc
			unit.asc.grant_ability(trigger_ability)
			triggers.append(trigger_ability)


func _apply_slots() -> void:
	var ability_loadout: Array[ChargedAbility] = []
	for ability in abilities:
		if ability != null:
			ability_loadout.append(ability)
	for i in mini(slots.size(), abilities.size()):
		var ability := abilities[i]
		if ability == null or slots[i] == null:
			continue
		ability.soul_container = slots[i].container_name
		ability.soul_column = slots[i].column
		ability.soul_width = slots[i].width
	for ability in ability_loadout:
		ability.unit_soul_abilities = ability_loadout


func _create_runtimes() -> void:
	runtimes.clear()
	for i in souls.size():
		var soul := souls[i]
		if soul == null:
			continue
		var slot: SoulSlot = slots[i] if i < slots.size() else null
		var ability: ChargedAbility = abilities[i] if i < abilities.size() else null
		var runtime := SoulRuntime.new(soul, slot, ability, unit)
		for trigger_ability in triggers:
			if trigger_ability.source_index == i:
				runtime.triggers.append(trigger_ability)
		if ability is AutoCastAbility:
			(ability as AutoCastAbility).soul_runtime = runtime
		runtimes.append(runtime)
		if unit.team == BattleUnit.Team.PLAYER:
			SoulRuntimeDB.register(runtime)
		if ability != null and unit.battle != null:
			unit.battle.events.soul_runtime_created.emit(unit, ability, runtime)
