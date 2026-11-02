## 当前战斗快照：给 DebugWindow 实时面板和 TestAPI 用。
##
## 只读 BattleManager / BattleUnit / ASC / SoulRuntime，不改变任何状态。
## 敌人只给摘要（无限刷怪时不能每帧展开全部属性/效果）；玩家和选中单位给完整详情。
class_name CombatSnapshot extends RefCounted

const POLICIES: Array[String] = ["INSTANT", "DURATION", "INFINITE", "TURN_BASED"]


static func build(battle: BattleManager, detail_unit: BattleUnit = null) -> Dictionary:
	if battle == null or not is_instance_valid(battle):
		return {
			"running": false,
			"run_id": CombatTelemetry.current_run_id,
		}
	var envelope: Dictionary = {
		"running": battle.is_running,
		"run_id": CombatTelemetry.current_run_id,
		"elapsed": battle.elapsed_seconds(),
		"enemy_count": battle.enemy_count(),
		"player": {},
		"enemies": [],
		"selected": {},
	}
	if battle.player != null:
		envelope["player"] = unit_detail(battle.player, battle)
	var enemies: Array = []
	for unit in battle.units:
		if unit == null or unit == battle.player:
			continue
		enemies.append(unit_summary(unit, battle))
	envelope["enemies"] = enemies
	if detail_unit != null and is_instance_valid(detail_unit):
		envelope["selected"] = unit_detail(detail_unit, battle)
	return envelope


static func unit_summary(unit: BattleUnit, battle: BattleManager = null) -> Dictionary:
	if unit == null or not is_instance_valid(unit):
		return {}
	var result: Dictionary = {
		"id": unit.get_instance_id(),
		"name": unit.unit_name,
		"team": CombatEvent.team_name(unit.team),
		"dead": unit.is_dead,
		"hp": _attr_value(unit.asc, "health"),
		"max_hp": _attr_value(unit.asc, "max_health"),
		"shield": _attr_value(unit.asc, "shield"),
		"burn": _attr_value(unit.asc, "burn"),
		"poison": _attr_value(unit.asc, "poison"),
		"regen": _attr_value(unit.asc, "regen"),
		"frozen": _has_tag(unit.asc, GameplayTags.State_Frozen),
		"tags_count": unit.asc._active_tags.size() if unit.asc != null else 0,
		"effects_count": unit.asc._active_effects.size() if unit.asc != null else 0,
		"abilities_count": unit.asc._active_abilities.size() if unit.asc != null else 0,
		"cell": [unit.cell.x, unit.cell.y],
		"position": [unit.position.x, unit.position.y],
		"souls": _soul_names(unit),
	}
	if battle != null and battle.player != null:
		result["distance_to_player"] = unit.distance_to_unit(battle.player)
		result["in_attack_range"] = (
			unit.team == BattleUnit.Team.ENEMY and unit.is_in_attack_range(battle.player)
		)
	return result


static func unit_detail(unit: BattleUnit, battle: BattleManager = null) -> Dictionary:
	if unit == null or not is_instance_valid(unit):
		return {}
	var result := unit_summary(unit, battle)
	result["attributes"] = attributes(unit.asc)
	result["tags"] = tags(unit.asc)
	result["effects"] = effects(unit.asc)
	result["abilities"] = abilities(unit)
	result["loadout"] = loadout(unit)
	result["triggers"] = triggers(unit)
	return result


static func attributes(asc: AbilitySystemComponent) -> Dictionary:
	var result: Dictionary = {}
	if asc == null:
		return result
	for attribute_set in asc.attribute_sets:
		if attribute_set == null:
			continue
		for prop in attribute_set.get_property_list():
			if prop.class_name != &"AttributeData":
				continue
			var attr: AttributeData = attribute_set.get(prop.name)
			if attr != null:
				result[prop.name] = {
					"base": attr.base_value,
					"current": attr.current_value,
				}
	return result


static func tags(asc: AbilitySystemComponent) -> Dictionary:
	if asc == null:
		return {}
	var result: Dictionary = {}
	for tag in asc._active_tags.keys():
		result[String(tag)] = int(asc._active_tags[tag])
	return result


static func effects(asc: AbilitySystemComponent) -> Array:
	var result: Array = []
	if asc == null:
		return result
	for active_effect in asc._active_effects:
		if active_effect == null:
			continue
		var spec: GameplayEffectSpec = active_effect.spec
		var effect_def := active_effect.get_effect_def()
		if effect_def == null:
			continue
		var trace_ids := _trace_ids(spec)
		result.append({
			"name": CombatNames.effect_name(spec),
			"policy": POLICIES[effect_def.policy] if effect_def.policy < POLICIES.size() else "?",
			"duration": spec.duration,
			"remaining": active_effect.time_remaining,
			"period": spec.period,
			"stacks": active_effect.stack_count,
			"suppressed": active_effect.is_suppressed,
			"source": CombatNames.source_name(spec),
			"tags": _string_array(effect_def.granted_tags),
			"application_cues": _string_array(effect_def.application_cue_tags),
			"persistent_cues": _string_array(effect_def.persistent_cue_tags),
			"periodic_cues": _string_array(effect_def.periodic_cue_tags),
			"removal_cues": _string_array(effect_def.removal_cue_tags),
			"trace_id": trace_ids.get("trace_id", 0),
			"root_trace_id": trace_ids.get("root_trace_id", 0),
			"display_name": spec.display_name,
		})
	return result


static func abilities(unit: BattleUnit) -> Array:
	var result: Array = []
	if unit == null or unit.asc == null:
		return result
	for ability in unit.asc._active_abilities:
		if ability == null:
			continue
		var charged := ability as ChargedAbility
		result.append({
			"name": CombatNames.ability_name(ability),
			"tag": String(ability.ability_tag),
			"class": (
				ability.get_script().resource_path.get_file().get_basename()
				if ability.get_script() != null else ""
			),
			"active": ability.is_active,
			"trigger_event": String(ability.trigger_event_tag),
			"has_activation_query": ability.activation_query != null,
			"cooldown": charged.cooldown if charged != null else 0.0,
			"charge_ratio": charged.charge_ratio() if charged != null else 0.0,
			"charge_seconds": charged.charge_seconds() if charged != null else 0.0,
			"haste": charged.haste_seconds() if charged != null else 0.0,
			"slow": charged.slow_seconds() if charged != null else 0.0,
			"freeze": charged.freeze_seconds() if charged != null else 0.0,
			"frozen": charged.is_frozen() if charged != null else false,
			"activation_lock": charged.activation_lock_seconds() if charged != null else 0.0,
		})
	return result


static func loadout(unit: BattleUnit) -> Array:
	var result: Array = []
	if unit == null:
		return result
	for runtime in unit.loadout:
		if runtime != null:
			result.append(soul_runtime(runtime))
	return result


static func soul_runtime(runtime: SoulRuntime) -> Dictionary:
	if runtime == null:
		return {}
	var data := runtime.to_dict()
	if runtime.owner_unit != null and is_instance_valid(runtime.owner_unit):
		data["owner"] = {
			"id": runtime.owner_unit.get_instance_id(),
			"name": runtime.owner_unit.unit_name,
			"team": CombatEvent.team_name(runtime.owner_unit.team),
		}
	return data


static func triggers(unit: BattleUnit) -> Array:
	var result: Array = []
	if unit == null:
		return result
	for runtime in unit.loadout:
		if runtime == null:
			continue
		for trigger_ability in runtime.triggers:
			if trigger_ability == null or trigger_ability.definition == null:
				continue
			var definition := trigger_ability.definition
			result.append({
				"source": runtime.display_name(),
				"source_index": trigger_ability.source_index,
				"ability_tag": String(trigger_ability.ability_tag),
				"event": String(definition.event_tag),
				"event_label": PassiveTrigger.event_label(definition.event_tag),
				"target_scope": PassiveTrigger.target_scope_name(definition.target_scope),
				"threshold_ratio": definition.threshold_ratio,
				"once_per_battle": definition.once_per_battle,
				"fired": trigger_ability.fired,
				"run_count": trigger_ability.run_count,
				"charge_source_seconds": definition.charge_source_seconds,
				"required_soul_types": _string_array(definition.required_soul_types),
				"require_adjacent": definition.require_adjacent,
				"trigger_name": definition.trigger_name,
				"magnitude": definition.magnitude,
				"effect_count": definition.effects.size(),
			})
	return result


#region 内部
static func _attr_value(asc: AbilitySystemComponent, attribute_name: String) -> float:
	if asc == null:
		return 0.0
	var attr := asc.get_attribute(attribute_name)
	return attr.current_value if attr != null else 0.0


static func _has_tag(asc: AbilitySystemComponent, tag: StringName) -> bool:
	return asc != null and asc.has_tag(tag)


static func _soul_names(unit: BattleUnit) -> Array[String]:
	var names: Array[String] = []
	for runtime in unit.loadout:
		if runtime != null:
			names.append(runtime.display_name())
	if names.is_empty():
		for soul in unit.souls:
			if soul != null:
				names.append(soul.item_name)
	return names


static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result


static func _trace_ids(spec: GameplayEffectSpec) -> Dictionary:
	if spec == null or not (spec.context is SoulEffectContext):
		return {}
	var trace := (spec.context as SoulEffectContext).trace
	if trace == null:
		return {}
	return {"trace_id": trace.id, "root_trace_id": trace.root_id}
#endregion
