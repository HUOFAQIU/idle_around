class_name BattleUnit extends Node

signal died(unit: BattleUnit)
@warning_ignore("unused_signal")
signal moved(unit: BattleUnit, from_cell: Vector2i, to_cell: Vector2i)

enum Team { PLAYER, ENEMY }

const SUPPRESS_STATE_LOG_TAG : StringName = &"Data.SuppressStateLog"
const PLAYER_STATS_SCRIPT: GDScript = preload("res://godot_gas/attributes/player_stats_attribute_set.gd")
const MONSTER_STATS_SCRIPT: GDScript = preload("res://godot_gas/attributes/monster_stats_attribute_set.gd")

@export var unit_name: String = ""
@export var team: Team = Team.PLAYER
## 血量上限（在场景根节点上配置）
@export var max_health: float = 100.0
## 死亡掉落（怪物场景里配置；玩家留空）
@export var drops: Array[DropEntry] = []
## 场景配置的魂灵（怪物用；玩家场景留空，运行时从装备读取）
@export var souls: Array[SoulData] = []

## 攻击范围（像素，圆心到圆心）。怪物只有在这个距离内才会开始给魂灵充能。
## 约等于一格（地图格宽 32px），和 TargetRule 的 max_range 口径保持一致。
@export var attack_range: float = 30.0
## 移动速度（像素/秒）。默认约等于 3 秒走一格。
@export var move_speed: float = 11.0
## 逻辑碰撞半径（像素，用于单位占位与防穿模）。
@export var body_radius: float = 8.0

var battle: BattleManager
var asc: AbilitySystemComponent
var brain: BattleBrain
var monster_data: MonsterData
var level: int = 1
var tier: int = MonsterData.Tier.MOB
var position: Vector2 = Vector2.ZERO
var global_position: Vector2:
	get:
		return position
var velocity: Vector2 = Vector2.ZERO
var cached_sep: Vector2 = Vector2.ZERO
var yaw: float = 0.0
var anim_phase: float = 0.0
var swing: float = 0.0
var flash: float = 0.0
var is_moving: bool = false
var batch_key: String = ""
var visual_scale: float = 1.0
var hit_height: float = 0.6
var debris_color: Color = Color(0.55, 0.52, 0.48, 1.0)
var move_phase_scale: float = 3.8
var attack_anim_speed: float = 1.95
var flash_decay: float = 5.0
var cached_ground_y: float = 0.0
var ground_y_dirty: bool = true
var is_dead: bool = false
var is_test_spawn: bool = false
var _death_queued: bool = false
var _pooled: bool = false
var _active_effect_count: int = 0
var _souls_loaded: bool = false
var soul_loadout: SoulLoadout

var loadout: Array[SoulRuntime]:
	get:
		if soul_loadout == null:
			return []
		return soul_loadout.runtimes

var cell: Vector2i = Vector2i.ZERO

var health_attr: AttributeData
var max_health_attr: AttributeData
var shield_attr: AttributeData
var move_speed_attr: AttributeData


static func opposing_team(team_id: Team) -> Team:
	return Team.ENEMY if team_id == Team.PLAYER else Team.PLAYER


static func create_headless(p_team: Team) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.team = p_team
	unit.body_radius = 10.0 if p_team == Team.PLAYER else 8.0
	var asc_node := AbilitySystemComponent.new()
	asc_node.name = "AbilitySystemComponent"
	var stats_set: AttributeSet = (
		PLAYER_STATS_SCRIPT.new()
		if p_team == Team.PLAYER
		else MONSTER_STATS_SCRIPT.new()
	)
	asc_node.attribute_sets = [stats_set]
	unit.add_child(asc_node)
	var brain_node := BattleBrain.new()
	brain_node.name = "BattleBrain"
	unit.add_child(brain_node)
	return unit


func setup_from_scene(
	p_battle: BattleManager,
	passive_effects: Array[GameplayEffect] = []
) -> void:
	battle = p_battle

	asc = get_node("AbilitySystemComponent")
	_init_attributes()
	_apply_passive_effects(passive_effects)
	battle.events.unit_asc_ready.emit(self)

	brain = get_node("BattleBrain")
	brain.unit = self
	if team == Team.ENEMY:
		brain.set_physics_process(false)
	for child in asc.get_children():
		if child is GameplayAbility:
			brain.abilities.append(child as GameplayAbility)
	if team == Team.PLAYER:
		add_soul_abilities(souls)
		_souls_loaded = true

	_connect_asc()
	sync_asc_processing()


func _init_attributes() -> void:
	max_health = floorf(max_health)
	asc.get_attribute("max_health").base_value = max_health
	asc.get_attribute("health").base_value = max_health

	health_attr = asc.get_attribute("health")
	max_health_attr = asc.get_attribute("max_health")
	shield_attr = asc.get_attribute("shield")
	move_speed_attr = asc.get_attribute("move_speed")
	if move_speed_attr != null:
		move_speed_attr.base_value = maxf(move_speed, 0.0)

	asc.add_tag(GameplayTags.Team_Player if team == Team.PLAYER else GameplayTags.Team_Enemy)


func _apply_passive_effects(effects: Array[GameplayEffect]) -> void:
	if effects.is_empty():
		return
	var health_ratio := health_attr.current_value / maxf(max_health_attr.current_value, 0.001)
	var max_before := max_health_attr.current_value
	for effect in effects:
		if effect != null:
			asc.apply_gameplay_effect(effect, asc)
	if not is_equal_approx(max_before, max_health_attr.current_value):
		var target_health := floorf(max_health_attr.current_value * health_ratio)
		var health_delta := target_health - health_attr.current_value
		_apply_health_delta_effect(health_delta)


func _apply_health_delta_effect(health_delta: float) -> void:
	if is_zero_approx(health_delta) or asc == null:
		return
	var sync_effect := GameplayEffect.new()
	sync_effect.policy = GameplayEffect.DurationPolicy.INSTANT
	var modifier := GameplayEffectModifier.new()
	modifier.attribute_name = "health"
	modifier.operation = GameplayEffectModifier.Operation.ADD
	modifier.magnitude = health_delta
	sync_effect.modifiers.append(modifier)
	asc.apply_gameplay_effect(sync_effect, asc)


func on_enemy_moved(moving_unit: BattleUnit, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if is_dead or battle == null or not battle.is_running or asc == null:
		return
	if moving_unit == null or moving_unit.is_dead or moving_unit.team == team:
		return
	if soul_loadout == null or not soul_loadout.has_trigger(GameplayTags.Event_Movement_UnitMoved):
		return
	var trace := CombatTrace.new("event:UnitMoved", null)
	asc.send_gameplay_event(GameplayTags.Event_Movement_UnitMoved, {
		"target": moving_unit,
		"from_cell": from_cell,
		"to_cell": to_cell,
		"trace": trace,
	})


func _check_health_triggers(old_value: float, new_value: float) -> void:
	if is_dead or asc == null or max_health_attr == null or new_value <= 0.0:
		return
	if new_value >= old_value:
		return
	var max_hp := max_health_attr.current_value
	if max_hp <= 0.0:
		return
	var ratio := new_value / max_hp
	if soul_loadout == null or not soul_loadout.has_health_trigger_for(ratio):
		return
	var trace := CombatTrace.new("event:HealthBelowPercent", null)
	asc.send_gameplay_event(GameplayTags.Event_Health_BelowPercent, {
		"target": self,
		"old": old_value,
		"new": new_value,
		"ratio": ratio,
		"trace": trace,
	})


func notify_soul_used(used: ChargedAbility, parent_trace: CombatTrace = null) -> void:
	if is_dead or battle == null or not battle.is_running or asc == null:
		return
	if soul_loadout == null or not soul_loadout.has_trigger(GameplayTags.Event_Combat_SoulUsed):
		return
	var trace := parent_trace if parent_trace != null else CombatTrace.new("event:SoulUsed", null)
	var used_soul: SoulData = null
	if used is AutoCastAbility:
		used_soul = (used as AutoCastAbility).soul_data
	asc.send_gameplay_event(GameplayTags.Event_Combat_SoulUsed, {
		"target": self,
		"used_ability": used,
		"used_soul": used_soul,
		"trace": trace,
	})


func notify_freeze_applied(event_target: BattleUnit, parent_trace: CombatTrace = null) -> void:
	if battle == null or not battle.is_running or event_target == null:
		return
	var trace := parent_trace if parent_trace != null else CombatTrace.new("event:FreezeApplied", null)
	for unit in battle.trigger_listeners(GameplayTags.Event_Combat_FreezeApplied):
		if unit.team == event_target.team or unit.asc == null:
			continue
		if unit.soul_loadout == null or not unit.soul_loadout.has_trigger(GameplayTags.Event_Combat_FreezeApplied):
			continue
		unit.asc.send_gameplay_event(GameplayTags.Event_Combat_FreezeApplied, {
			"target": event_target,
			"source": self,
			"trace": trace,
		})


func notify_slow_applied(parent_trace: CombatTrace = null) -> void:
	if battle == null or not battle.is_running:
		return
	var trace := parent_trace if parent_trace != null else CombatTrace.new("event:SlowApplied", null)
	for unit in battle.trigger_listeners(GameplayTags.Event_Combat_SlowApplied):
		if unit.team == team or unit.asc == null:
			continue
		if unit.soul_loadout == null or not unit.soul_loadout.has_trigger(GameplayTags.Event_Combat_SlowApplied):
			continue
		unit.asc.send_gameplay_event(GameplayTags.Event_Combat_SlowApplied, {
			"target": self,
			"source": self,
			"trace": trace,
		})


func apply_trigger_effect(
	effect: GameplayEffect,
	target: BattleUnit,
	magnitude: float,
	suppress_state_log: bool = false,
	trace: CombatTrace = null,
	display_name: String = "",
	soul_runtime: SoulRuntime = null,
	effect_duration: float = 0.0
) -> void:
	if effect == null or asc == null or target == null or target.asc == null:
		return
	var context := SoulEffectContext.new(self, self, trace)
	context.soul_runtime = soul_runtime
	context.target_data.append_node(target)
	var spec := GameplayEffectSpec.new(effect, context, 1.0)
	if not display_name.is_empty():
		spec.display_name = display_name
	spec.set_set_by_caller_magnitude(GameplayTags.Data_TriggerMagnitude, magnitude)
	if effect_duration > 0.0:
		spec.duration = effect_duration
	if suppress_state_log:
		spec.inject_tag(SUPPRESS_STATE_LOG_TAG)
	asc.apply_effect_spec_to_target(spec, target.asc)
	if effect.granted_tags.has(GameplayTags.State_Frozen):
		notify_freeze_applied(target, trace)


func ensure_soul_abilities_loaded() -> void:
	if _souls_loaded:
		return
	_souls_loaded = true
	if not souls.is_empty():
		add_soul_abilities(souls)


func cache_monster_visuals(data: MonsterData) -> void:
	monster_data = data
	if data == null:
		return
	body_radius = data.body_radius
	visual_scale = data.visual_scale
	hit_height = data.hit_height
	debris_color = data.debris_color
	if data.anim_config != null:
		move_phase_scale = data.anim_config.move_phase_scale
		attack_anim_speed = data.anim_config.attack_speed
		flash_decay = data.anim_config.flash_decay


func add_soul_abilities(
	soul_list: Array[SoulData],
	slots: Array[SoulSlot] = []
) -> Array[AutoCastAbility]:
	soul_loadout = SoulLoadout.new(self, soul_list, slots)
	_refresh_trigger_listeners()
	return soul_loadout.abilities


func _refresh_trigger_listeners() -> void:
	if battle == null:
		return
	_sync_trigger_listener(GameplayTags.Event_Movement_UnitMoved)
	_sync_trigger_listener(GameplayTags.Event_Combat_FreezeApplied)
	_sync_trigger_listener(GameplayTags.Event_Combat_SlowApplied)


func _sync_trigger_listener(event_tag: StringName) -> void:
	var enabled := soul_loadout != null and soul_loadout.has_trigger(event_tag)
	battle.set_trigger_listener(self, event_tag, enabled)


func _clear_trigger_listeners() -> void:
	if battle == null:
		return
	battle.set_trigger_listener(self, GameplayTags.Event_Movement_UnitMoved, false)
	battle.set_trigger_listener(self, GameplayTags.Event_Combat_FreezeApplied, false)
	battle.set_trigger_listener(self, GameplayTags.Event_Combat_SlowApplied, false)


func runtime_for_source_index(index: int) -> SoulRuntime:
	return soul_loadout.runtime_for_source_index(index) if soul_loadout != null else null


func unregister_soul_runtimes() -> void:
	if soul_loadout == null:
		return
	soul_loadout.clear()
	soul_loadout = null


func sync_asc_processing() -> void:
	if asc == null:
		return
	if team == Team.PLAYER or is_dead:
		asc.process_mode = Node.PROCESS_MODE_INHERIT
		return
	var brain_active := brain != null and brain.is_physics_processing()
	var should_run := brain_active or _active_effect_count > 0
	asc.process_mode = Node.PROCESS_MODE_INHERIT if should_run else Node.PROCESS_MODE_DISABLED


func _connect_asc() -> void:
	asc.attribute_changed.connect(_on_attribute_changed)
	asc.periodic_effect_ticked.connect(_on_periodic_effect_ticked)
	asc.active_effect_added.connect(_on_active_effect_added)
	asc.active_effect_removed.connect(_on_active_effect_removed)


func _on_active_effect_added(_active_effect: ActiveGameplayEffect) -> void:
	_active_effect_count += 1
	sync_asc_processing()


func _on_active_effect_removed(_active_effect: ActiveGameplayEffect) -> void:
	_active_effect_count = maxi(_active_effect_count - 1, 0)
	sync_asc_processing()


func set_cell(p_cell: Vector2i) -> void:
	cell = p_cell
	position = battle.cell_to_world(p_cell)


func distance_to_unit(other: BattleUnit) -> float:
	if other == null:
		return INF
	return position.distance_to(other.position)


func is_in_attack_range(other: BattleUnit) -> bool:
	return other != null and distance_to_unit(other) <= attack_range


func is_dying() -> bool:
	return is_dead or (health_attr != null and health_attr.current_value <= 0.0)


func is_unit_frozen() -> bool:
	return asc != null and asc.has_tag(GameplayTags.State_Frozen)


func health_percent() -> float:
	return health_attr.current_value / maxf(max_health_attr.current_value, 0.001)


func get_move_speed() -> float:
	if move_speed_attr != null:
		return move_speed_attr.current_value
	return maxf(move_speed, 0.0)


func _on_attribute_changed(attribute_name: String, old_value: float, new_value: float, _spec: GameplayEffectSpec) -> void:
	if attribute_name != "health":
		return
	if new_value <= 0.0:
		_queue_death()
	else:
		_check_health_triggers(old_value, new_value)


func _on_periodic_effect_ticked(active_effect: ActiveGameplayEffect, spec: GameplayEffectSpec) -> void:
	if spec == null:
		return
	var tick := PeriodicStatusTickExecution.find(spec.effect_def)
	if tick == null or not tick.remove_when_zero():
		return
	var attr := asc.get_attribute(tick.status_attribute())
	if attr != null and attr.current_value <= 0.0:
		asc.remove_active_effect(active_effect)


func _queue_death() -> void:
	if _death_queued:
		return
	_death_queued = true
	_die_deferred.call_deferred()


func _die_deferred() -> void:
	_death_queued = false
	if is_dead or health_attr == null or health_attr.current_value > 0.0:
		return
	_die()


func cleanup_asc() -> void:
	_clear_trigger_listeners()
	unregister_soul_runtimes()
	if asc != null:
		asc.cleanup()


func recycle_to_pool() -> void:
	if _pooled:
		return
	_pooled = true
	is_dead = true
	_death_queued = false
	cleanup_asc()
	if brain != null:
		brain.abilities.clear()
		brain.begin_charge()
		brain.set_process(false)
		brain.set_physics_process(false)
	if asc != null:
		asc.process_mode = Node.PROCESS_MODE_DISABLED
	souls.clear()
	drops.clear()
	monster_data = null
	batch_key = ""
	velocity = Vector2.ZERO
	cached_sep = Vector2.ZERO
	swing = 0.0
	flash = 0.0
	is_moving = false
	ground_y_dirty = true
	_active_effect_count = 0
	_souls_loaded = false
	is_test_spawn = false
	level = 1
	tier = MonsterData.Tier.MOB


func activate_from_pool(p_battle: BattleManager) -> void:
	_pooled = false
	battle = p_battle
	is_dead = false
	_death_queued = false
	_active_effect_count = 0
	_souls_loaded = false
	_reset_status_attributes()
	_init_attributes()
	if brain != null:
		brain.unit = self
		brain.set_physics_process(false)
	sync_asc_processing()


func _reset_status_attributes() -> void:
	if asc == null:
		return
	for attr_name in ["burn", "shield", "poison", "regen"]:
		var attr := asc.get_attribute(attr_name)
		if attr != null:
			attr.base_value = 0.0


func _die() -> void:
	is_dead = true
	asc.add_tag(GameplayTags.State_Dead)
	if brain != null:
		brain.set_process(false)
		brain.set_physics_process(false)
	died.emit(self)
