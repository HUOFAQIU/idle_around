## 魂灵触发器能力：监听一个 GAS GameplayEvent，按 PassiveTrigger 配置施加效果/充能。
##
## 每颗魂灵的每条触发器生成一个节点，grant 到 ASC 并设置 trigger_event_tag；
## `ASC.send_gameplay_event()` 会按标签找到它并 try_activate(payload)。
##
## payload 约定（Dictionary）：
##   target       事件目标 BattleUnit
##   used_ability 被使用的魂灵能力（SoulUsed）
##   used_soul    被使用魂灵的 SoulData（SoulUsed）
##   ratio        生命比例（Health.BelowPercent）
##   trace        CombatTrace
class_name SoulTriggerAbility extends GameplayAbility

var definition: PassiveTrigger
var source_ability: ChargedAbility
var source_name: String = ""
var source_index: int = -1
var owner_unit: BattleUnit
## once_per_battle 是否已经用掉
var fired: bool = false
## 本场实际触发次数（非 once 触发器也计数）
var run_count: int = 0


func _init(
	p_definition: PassiveTrigger = null,
	p_source_ability: ChargedAbility = null,
	p_source_name: String = "",
	p_source_index: int = -1,
	p_owner: BattleUnit = null
) -> void:
	definition = p_definition
	source_ability = p_source_ability
	source_name = p_source_name
	source_index = p_source_index
	owner_unit = p_owner
	ability_name = trigger_label()
	if definition != null:
		trigger_event_tag = definition.event_tag
		ability_tag = ability_tag_for_event(definition.event_tag)


## 由框架在通过门卫后调用。
func _activate_ability() -> bool:
	if definition == null or owner_unit == null or not is_instance_valid(owner_unit):
		return false
	if owner_unit.is_dead:
		return false
	if definition.once_per_battle and fired:
		return false

	var payload := _payload()
	if not _conditions_match(payload):
		return false

	var event_target := _event_target(payload)
	var label := trigger_label()
	var parent_trace := _trace(payload)
	var trace := parent_trace.child("trigger:" + source_name + ":" + label)
	run_count += 1
	if definition.once_per_battle:
		fired = true

	var targets := _targets(event_target)
	var suppress_state_logs := targets.size() > 1
	var battle := owner_unit.battle
	var runtime := owner_unit.runtime_for_source_index(source_index)

	if battle != null:
		battle.events.emit_event(BattleEvent.CATEGORY_TRIGGER, "fired", {
			"actor_unit": owner_unit,
			"soul": source_name,
			"trigger": label,
			"trigger_name": definition.trigger_name,
			"event": String(definition.event_tag),
			"target_scope": PassiveTrigger.target_scope_name(definition.target_scope),
			"targets": targets.size(),
			"detail": "%s：%d 个目标" % [PassiveTrigger.event_label(definition.event_tag), targets.size()],
			"trace": trace,
		}, BattleEvent.IMPORTANCE_IMPORTANT)
		if runtime != null:
			runtime.add_counter("triggers_fired")
			runtime.set_counter_timestamp("last_trigger_t", battle.elapsed_seconds())

	for target in targets:
		for effect in definition.effects:
			owner_unit.apply_trigger_effect(
				effect,
				target,
				definition.magnitude,
				suppress_state_logs,
				trace,
				label
			)
			if effect != null and effect.granted_tags.has(GameplayTags.State_Frozen) and runtime != null:
				runtime.add_counter("freezes_applied")

	if definition.charge_source_seconds > 0.0 and source_ability != null:
		source_ability.add_charge(definition.charge_source_seconds, trace)
		if runtime != null:
			runtime.add_counter("charges_given", definition.charge_source_seconds)
		if owner_unit.brain != null:
			owner_unit.brain.request_activation(source_ability, trace)
	return true


static func ability_tag_for_event(event_tag: StringName) -> StringName:
	match event_tag:
		GameplayTags.Event_Movement_UnitMoved:
			return GameplayTags.Skill_Trigger_Movement
		GameplayTags.Event_Health_BelowPercent:
			return GameplayTags.Skill_Trigger_Health
		GameplayTags.Event_Combat_SoulUsed:
			return GameplayTags.Skill_Trigger_SoulUsed
		GameplayTags.Event_Combat_FreezeApplied:
			return GameplayTags.Skill_Trigger_Freeze
		_:
			return &"Skill.Trigger"


func trigger_label() -> String:
	if definition == null:
		return "触发器"
	if not definition.trigger_name.is_empty():
		return definition.trigger_name
	return PassiveTrigger.event_label(definition.event_tag)


func _payload() -> Dictionary:
	if current_event_payload is Dictionary:
		return current_event_payload as Dictionary
	return {}


func _trace(payload: Dictionary) -> CombatTrace:
	var value: Variant = payload.get("trace", null)
	if value is CombatTrace:
		return value as CombatTrace
	var label := String(definition.event_tag) if definition != null else "event"
	return CombatTrace.new("event:" + label, null)


func _event_target(payload: Dictionary) -> BattleUnit:
	var value: Variant = payload.get("target", null)
	if value is BattleUnit and is_instance_valid(value) and not (value as BattleUnit).is_dead:
		return value as BattleUnit
	return owner_unit


func _conditions_match(payload: Dictionary) -> bool:
	if definition == null:
		return false
	match definition.event_tag:
		GameplayTags.Event_Health_BelowPercent:
			var ratio := float(payload.get("ratio", -1.0))
			if ratio < 0.0:
				ratio = owner_unit.health_percent()
			if ratio >= definition.threshold_ratio:
				return false
		GameplayTags.Event_Combat_SoulUsed:
			var used: Variant = payload.get("used_ability", null)
			if not (used is ChargedAbility):
				return false
			if used == source_ability:
				return false
			if not _matches_used_soul(used as ChargedAbility, payload):
				return false
		GameplayTags.Event_Combat_FreezeApplied:
			if not (payload.get("target") is BattleUnit):
				return false
		GameplayTags.Event_Movement_UnitMoved:
			if not (payload.get("target") is BattleUnit):
				return false
	return true


func _matches_used_soul(used: ChargedAbility, payload: Dictionary) -> bool:
	if not definition.required_soul_types.is_empty():
		var used_soul: Variant = payload.get("used_soul", null)
		if not (used_soul is SoulData):
			return false
		for soul_type in definition.required_soul_types:
			if not (used_soul as SoulData).types.has(soul_type):
				return false
	if definition.require_adjacent:
		return SoulTargetRule.is_adjacent(source_ability, used)
	return true


func _targets(event_target: BattleUnit) -> Array[BattleUnit]:
	var targets: Array[BattleUnit] = []
	match definition.target_scope:
		PassiveTrigger.TargetScope.EVENT_TARGET:
			if event_target != null and not event_target.is_dead:
				targets.append(event_target)
		PassiveTrigger.TargetScope.SELF:
			if not owner_unit.is_dead:
				targets.append(owner_unit)
		PassiveTrigger.TargetScope.ALL_ENEMIES:
			if owner_unit.battle == null:
				return targets
			for unit in owner_unit.battle.units_of_team(BattleUnit.opposing_team(owner_unit.team)):
				if unit != null and not unit.is_dead:
					targets.append(unit)
	return targets
