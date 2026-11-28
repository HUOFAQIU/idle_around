## @meta_addon: GodotGAS
## @meta_license: MIT

class_name AutoCastAbility extends ChargedAbility

enum ReleaseResult {
	HIT,
	EMPTY,
	CANCELLED,
	STOPPED,
}

enum WaitResult {
	READY,
	CANCELLED,
	STOPPED,
}

## 本技能的数据定义（由 SoulLoadout 构建时注入）
@export var skill: SkillDefinition
var soul_data: SoulData
var soul_runtime: SoulRuntime
var _steps: Array[SkillStep] = []
var _hit_cue_counts: Dictionary = {}
var _last_empty_reasons: Array[String] = []


func _ready() -> void:
	super()
	if skill != null and ability_name.is_empty():
		apply_definition(skill)


func _on_charge_received(seconds: float) -> void:
	if soul_runtime != null:
		soul_runtime.add_counter("charges_received", seconds)


func apply_definition(def: SkillDefinition, p_display_name: String = "") -> void:
	skill = def
	_steps = def.steps.duplicate()
	_hit_cue_counts.clear()
	_last_empty_reasons.clear()
	ability_name = p_display_name if not p_display_name.is_empty() else def.id
	ability_tag = StringName("Skill." + def.id)
	cooldown = def.cooldown_seconds

	if not def.cast_require_all_tags.is_empty() or not def.cast_block_tags.is_empty():
		var query := GameplayTagQuery.new()
		query.require_all_tags.append_array(def.cast_require_all_tags)
		query.ignore_tags.append_array(def.cast_block_tags)
		activation_query = query


func apply_soul_emotions() -> void:
	if soul_data == null:
		return
	var value := SoulEmotionValues.cooldown_seconds(soul_data)
	if value >= 0.0:
		cooldown = value


func _activate_ability() -> bool:
	var battle := _get_battle()
	var trace := CombatTrace.new("cast:" + ability_name, _trace_from_payload(current_event_payload))
	var total := _cast_times()
	_record_cast("attempt", trace, {"cooldown": cooldown, "cast_times": total})
	if skill == null or battle == null:
		_record_cast("failed", trace, {"detail": "skill 或 battle 为空"})
		return false
	if not can_activate_now():
		_record_cast("blocked", trace, {
			"detail": "激活锁剩余 %.2f 秒" % activation_lock_seconds(),
			"reason": "ACTIVATION_LOCK",
		})
		return false
	mark_activated()

	commit_cost()
	reset_charge()
	if soul_runtime != null:
		soul_runtime.add_counter("activations")
		soul_runtime.set_counter_timestamp("last_activation_t", battle.elapsed_seconds())
	_record_cast("activate", trace, {"cooldown": cooldown, "cast_times": total})
	_notify_soul_used(trace)

	return await _run_releases(battle, trace, total)


func _run_releases(battle: BattleManager, trace: CombatTrace, total: int) -> bool:
	var hit_any := false
	for index in total:
		if index > 0:
			var wait_result: WaitResult = await _wait_for_next_release(battle)
			if wait_result == WaitResult.CANCELLED:
				_record_cast("cancelled", trace, {
					"detail": "等待多重触发时被打断",
					"release_index": index,
					"release_count": total,
				})
				return false
			if wait_result == WaitResult.STOPPED:
				return true
			mark_activated()

		if not is_active:
			return false
		if soul_runtime != null:
			soul_runtime.add_counter("releases")
		_record_cast("release", trace, {
			"release_index": index + 1,
			"release_count": total,
		})
		var result: ReleaseResult = await _release_once(battle, trace, index + 1, total)
		match result:
			ReleaseResult.CANCELLED:
				return false
			ReleaseResult.STOPPED:
				return true
			ReleaseResult.HIT:
				hit_any = true

	if not hit_any and not _steps.is_empty():
		_log_empty_activation(battle, trace, total, _last_empty_reasons)
	return true


func _wait_for_next_release(battle: BattleManager) -> WaitResult:
	if battle.clock == null:
		return WaitResult.STOPPED
	var caster := _caster_unit()
	while (
		is_active
		and battle.is_running
		and caster != null
		and is_instance_valid(caster)
		and not caster.is_dead
	):
		if not is_frozen() and can_activate_now():
			return WaitResult.READY
		await battle.clock.wait_ticks(1)
	return WaitResult.CANCELLED if not is_active else WaitResult.STOPPED


func _wait_cast_ticks(battle: BattleManager, seconds: float) -> WaitResult:
	if battle.clock == null:
		return WaitResult.STOPPED
	var remaining := battle.ticks_for_seconds(seconds)
	while remaining > 0:
		var state := _cast_wait_state(battle)
		if state != WaitResult.READY:
			return state
		await battle.clock.wait_ticks(1)
		remaining -= 1
	return _cast_wait_state(battle)


func _cast_wait_state(battle: BattleManager) -> WaitResult:
	if not is_active:
		return WaitResult.CANCELLED
	var caster := caster_unit()
	if not battle.is_running or caster == null or caster.is_dead:
		return WaitResult.STOPPED
	return WaitResult.READY


func _release_once(
	battle: BattleManager,
	trace: CombatTrace,
	release_index: int,
	release_count: int
) -> ReleaseResult:
	_last_empty_reasons.clear()
	_apply_self_effects(battle, trace)
	if _steps.is_empty():
		return ReleaseResult.HIT

	if skill.cast_time > 0.0:
		_record_cast("cast_start", trace, {
			"cast_time": skill.cast_time,
			"release_index": release_index,
			"release_count": release_count,
		})
		var wait_result: WaitResult = await _wait_cast_ticks(battle, skill.cast_time)
		if wait_result == WaitResult.CANCELLED:
			_record_cast("cancelled", trace, {
				"detail": "吟唱被打断",
				"release_index": release_index,
				"release_count": release_count,
			})
			return ReleaseResult.CANCELLED
		if wait_result == WaitResult.STOPPED:
			return ReleaseResult.STOPPED

	var ctx := SkillCastContext.new(self, battle, trace, release_index, release_count)
	var hit_any := false
	for step in _steps:
		if step == null:
			continue
		if not battle.is_running:
			return ReleaseResult.STOPPED
		var result := _run_step(step, ctx)
		if result == null:
			push_error("技能 %s 的步骤没有返回结果：%s" % [ability_name, step])
			continue
		if result.hit:
			hit_any = true
		elif not result.empty_reason.is_empty() and not _last_empty_reasons.has(result.empty_reason):
			_last_empty_reasons.append(result.empty_reason)

	return ReleaseResult.HIT if hit_any else ReleaseResult.EMPTY


func _run_step(step: SkillStep, ctx: SkillCastContext) -> SkillStepResult:
	if step is SoulSkillStep:
		return (step as SoulSkillStep).execute(ctx)
	if step is UnitSkillStep:
		return (step as UnitSkillStep).execute(ctx)
	push_error("技能 %s 的步骤类型没有执行入口：%s" % [ability_name, step])
	return null


func _log_empty_activation(
	_battle: BattleManager,
	trace: CombatTrace,
	release_count: int,
	reasons: Array[String]
) -> void:
	var has_soul_step := false
	for step in _steps:
		if step is SoulSkillStep:
			has_soul_step = true
			break
	var detail := "没有目标"
	if not reasons.is_empty():
		detail = "；".join(PackedStringArray(reasons))
	var caster := _caster_unit()
	var narrate := has_soul_step or (caster != null and caster.team == BattleUnit.Team.PLAYER)
	_record_cast("empty", trace, {
		"detail": detail,
		"release_count": release_count,
		"narrate": narrate,
	})
	if narrate and soul_runtime != null:
		soul_runtime.add_counter("empty_casts")


func _cast_times() -> int:
	if soul_data != null:
		var value := SoulEmotionValues.cast_times(soul_data)
		if value > 0:
			return value
	return maxi(skill.cast_times, 1) if skill != null else 1


func launch_projectiles(step: UnitSkillStep, groups: Array, ctx: SkillCastContext) -> void:
	if step == null or not step.uses_projectile:
		return
	var caster := caster_unit()
	if caster == null:
		return
	var targets: Array[BattleUnit] = []
	for group in groups:
		for unit in group:
			if unit is BattleUnit:
				targets.append(unit)
	if targets.is_empty():
		return
	_record_cast("projectiles", ctx.trace, {"projectile_count": targets.size()})

	var task := AbilityTask_Projectile.new()
	caster.add_child(task)
	task.projectile_landed.connect(_on_step_projectile_landed.bind(step, ctx))
	task.task_finished.connect(_on_projectiles_finished.bind(targets.size(), ctx.trace))
	task.execute(caster, targets, step.projectile_speed)


func _on_step_projectile_landed(hit_unit: BattleUnit, step: UnitSkillStep, ctx: SkillCastContext) -> void:
	if hit_unit == null or not is_instance_valid(hit_unit) or hit_unit.is_dead:
		_record_cast("projectile_miss", ctx.trace)
		return
	if ctx.battle == null or not ctx.battle.is_running:
		return
	_record_cast("projectile_hit", ctx.trace, {"target_unit": hit_unit})
	if step != null:
		step.apply_to_target(ctx, hit_unit)


func _on_projectiles_finished(result: Variant, projectile_count: int, trace: CombatTrace) -> void:
	var battle := _get_battle()
	if battle == null or not battle.is_running:
		return
	var hit_count: int = result if result is int else 0
	var missed: int = projectile_count - hit_count
	_record_cast("projectiles_finished", trace, {
		"projectile_count": projectile_count,
		"hit_count": hit_count,
		"missed": missed,
	})


func _apply_self_effects(battle: BattleManager, trace: CombatTrace) -> void:
	if skill == null or skill.self_effects.is_empty():
		return
	var caster := _caster_unit()
	if caster == null or caster.is_dead:
		return
	var is_crit := skill.crit_chance > 0.0 and battle.rng.randf() < skill.crit_chance
	var crit_multiplier := skill.crit_multiplier if is_crit else 1.0
	if is_crit:
		_record_cast("self_crit", trace)
	_apply_effect_list_to_target(skill.self_effects, caster, crit_multiplier, trace)


func roll_crit(battle: BattleManager) -> float:
	if skill == null:
		return 1.0
	var is_crit := skill.crit_chance > 0.0 and battle.rng.randf() < skill.crit_chance
	return skill.crit_multiplier if is_crit else 1.0


func apply_effects(
	effects: Array[GameplayEffect],
	target: BattleUnit,
	crit_multiplier: float,
	trace: CombatTrace,
	status_magnitude: float = -1.0,
	effect_duration: float = 0.0
) -> void:
	_apply_effect_list_to_target(
		effects, target, crit_multiplier, trace, status_magnitude, effect_duration
	)


func play_hit_cue(tag: StringName, target: BattleUnit, step_key: int) -> void:
	if tag.is_empty():
		return
	if target == null or not is_instance_valid(target) or target.asc == null:
		return
	var count := int(_hit_cue_counts.get(step_key, 0))
	var direction := -1.0 if count % 2 == 0 else 1.0
	_hit_cue_counts[step_key] = count + 1
	var caster := _caster_unit()
	if caster != null and caster.battle != null:
		caster.battle.events.emit_event(BattleEvent.CATEGORY_CUE, "hit_cue", {
			"actor_unit": caster,
			"target_unit": target,
			"cue_tag": String(tag),
			"direction": direction,
		}, BattleEvent.IMPORTANCE_DETAIL)


func _apply_effect_list_to_target(
	effects: Array[GameplayEffect],
	target: BattleUnit,
	crit_multiplier: float,
	trace: CombatTrace,
	status_magnitude: float = -1.0,
	effect_duration: float = 0.0
) -> void:
	AbilityEffectApplier.apply_list(
		owner_asc, ability_name, ability_level, soul_runtime,
		effects, target, crit_multiplier, trace, status_magnitude, effect_duration
	)


func should_record_detail() -> bool:
	return CombatTelemetry.is_unit_detailed(_caster_unit())


func _notify_soul_used(trace: CombatTrace) -> void:
	var caster := _caster_unit()
	var battle := _get_battle()
	if caster == null or battle == null:
		return
	if CombatTelemetry.is_unit_detailed(caster):
		var soul_label := ""
		if soul_runtime != null:
			soul_label = soul_runtime.display_name()
		elif soul_data != null:
			soul_label = soul_data.item_name
		var importance := BattleEvent.IMPORTANCE_DETAIL
		if caster.team == BattleUnit.Team.PLAYER:
			importance = BattleEvent.IMPORTANCE_IMPORTANT
		battle.events.emit_event(BattleEvent.CATEGORY_SOUL, "used", {
			"actor_unit": caster,
			"soul": soul_label,
			"ability": ability_name,
			"trace": trace,
		}, importance)
	caster.notify_soul_used(self, trace)


func _trace_from_payload(payload: Variant) -> CombatTrace:
	if payload is CombatTrace:
		return payload as CombatTrace
	if payload is Dictionary:
		var value: Variant = (payload as Dictionary).get("trace", null)
		if value is CombatTrace:
			return value as CombatTrace
	return null


func caster_unit() -> BattleUnit:
	return _caster_unit()


func get_battle_manager() -> BattleManager:
	return _get_battle()


func record_step(type: String, trace: CombatTrace, fields: Dictionary = {}) -> void:
	_record_cast(type, trace, fields)


func targets_summary(groups: Array) -> String:
	return AbilityEffectApplier.targets_summary(groups)


func target_count(groups: Array) -> int:
	return AbilityEffectApplier.target_count(groups)


func _record_cast(type: String, trace: CombatTrace, fields: Dictionary = {}) -> void:
	var battle := _get_battle()
	if battle == null:
		return
	var caster := _caster_unit()
	if not CombatTelemetry.is_unit_detailed(caster):
		if type == "release" and caster != null:
			caster.swing = 1.0
		return
	fields["actor_unit"] = caster
	fields["ability"] = ability_name
	fields["ability_tag"] = String(ability_tag)
	if soul_runtime != null:
		fields["soul"] = soul_runtime.display_name()
	if trace != null:
		fields["trace"] = trace
	var importance := BattleEvent.IMPORTANCE_DETAIL
	if caster != null and caster.team == BattleUnit.Team.PLAYER:
		importance = BattleEvent.IMPORTANCE_IMPORTANT
	battle.events.emit_event(BattleEvent.CATEGORY_CAST, type, fields, importance)



func _caster_unit() -> BattleUnit:
	return owner_asc.get_parent() as BattleUnit


func _get_battle() -> BattleManager:
	var caster := _caster_unit()
	return caster.battle if caster else null
