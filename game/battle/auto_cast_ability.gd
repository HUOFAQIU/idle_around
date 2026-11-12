## 通用自动施法技能：全场共用这一个脚本，差异全在 SkillDefinition 数据里。
##
## 施法顺序：
##   ① commit_cost() + reset_charge()  扣费 + 清空充能 —— 充满就放，不等任何东西
##   ② 吟唱（可选）       吟唱结束后才选目标，避免对着尸体放大
##   ③ 按 steps 顺序结算  每步自己选目标；全部步骤都空放才记一次空放
##
## SkillDefinition.cast_times > 1 时（多重触发），②～④ 会重复执行：
## 每次释放重新选目标、独立暴击、独立结算自身效果。第 2 次起各占一个 20 刻
## 激活锁，所以 1 秒最多释放 6 次，超出的顺延到后续秒继续，不丢弃。
## 一次激活仍只扣一次充能、只广播一次 SoulUsed。
##
## 投射物发射后立即返回，不占用 is_active：箭独立飞行、逐箭结算，
## 同一颗魂灵的下一次释放只受充能和 20 刻激活锁限制。
##
## 门卫检查（花费 / 施法条件标签 / 是否在施法中）由框架的 can_activate_ability()
## 负责；冷却由 ChargedAbility 的充能值控制。
##
## 释放逻辑按 SkillDefinition.steps 顺序执行；每一步自己决定目标域（单位/魂灵）。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name AutoCastAbility extends ChargedAbility

## 一次释放的结果；多重触发的循环据此决定继续、停止还是记空放。
enum ReleaseResult {
	HIT,        ## 选中目标并完成结算
	EMPTY,      ## 本次释放没有目标
	CANCELLED,  ## 吟唱被打断，后续释放不再进行
	STOPPED,    ## 战斗结束或施法者倒下，后续释放正常停止
}

## 等待下一次释放的结果。
enum WaitResult {
	READY,      ## 激活锁已走完，可以释放
	CANCELLED,  ## 施法被打断
	STOPPED,    ## 战斗结束或施法者倒下
}

## 本技能的数据定义（由 SoulLoadout 构建时注入）
@export var skill: SkillDefinition
## 本技能来源的魂灵数据；用于 OTHER_SOUL_USED 触发器的标签过滤
var soul_data: SoulData
## 本技能对应的战斗运行期状态（由 BattleUnit 注入）
var soul_runtime: SoulRuntime
## 释放步骤；apply_definition() 时缓存
var _steps: Array[SkillStep] = []
## 命中特效的方向计数：按 step 实例 id 分开，多个单位步骤互不影响
var _hit_cue_counts: Dictionary = {}
## 本次释放各步骤的空放原因；供整次激活的空放日志使用
var _last_empty_reasons: Array[String] = []


func _ready() -> void:
	super()
	# 通过场景节点直接配置 skill 的用法：入树时翻译成框架配置。
	# 代码创建的技能在授予前已经 apply 过，ability_name 非空，不会重复执行
	if skill != null and ability_name.is_empty():
		apply_definition(skill)


## 外部充能实际生效后累计本魂灵的运行期统计
func _on_charge_received(seconds: float) -> void:
	if soul_runtime != null:
		soul_runtime.add_counter("charges_received", seconds)


## 把一份 SkillDefinition 翻译成框架的技能配置。
## p_display_name 来自魂灵物品的 item_name；不传时退回内部 id。
func apply_definition(def: SkillDefinition, p_display_name: String = "") -> void:
	skill = def
	_steps = def.steps.duplicate()
	_hit_cue_counts.clear()
	_last_empty_reasons.clear()
	ability_name = p_display_name if not p_display_name.is_empty() else def.id
	ability_tag = StringName("Skill." + def.id)
	# 魂灵冷却使用充能模型，不是 GAS 的 DURATION 冷却效果；
	# GameplayAbility.cooldown_effect 保持为空，避免门卫按标签再判一次冷却。
	cooldown = def.cooldown_seconds

	# 施法条件翻译成框架标签查询，由门卫统一检查
	if not def.cast_require_all_tags.is_empty() or not def.cast_block_tags.is_empty():
		var query := GameplayTagQuery.new()
		query.require_all_tags.append_array(def.cast_require_all_tags)
		query.ignore_tags.append_array(def.cast_block_tags)
		activation_query = query


## 由框架在通过门卫后调用；返回 true = 正常结束，false = 结束且算"取消"。
func _activate_ability() -> bool:
	var battle := _get_battle()
	var trace := CombatTrace.new("cast:" + ability_name, _trace_from_payload(current_event_payload))
	var total := _cast_times()
	_record_cast("attempt", trace, {"cooldown": cooldown, "cast_times": total})
	if skill == null or battle == null:
		_record_cast("failed", trace, {"detail": "skill 或 battle 为空"})
		return false
	# 底层激活锁：同一颗魂灵 20 刻内最多激活一次（1 秒最多 6 次）。
	# 放在扣费/清空充能之前，被锁拒绝时不产生任何副作用。
	if not can_activate_now():
		_record_cast("blocked", trace, {
			"detail": "激活锁剩余 %.2f 秒" % activation_lock_seconds(),
			"reason": "ACTIVATION_LOCK",
		})
		return false
	# 第一次释放占用这次激活的锁；多重触发的后续释放各自再等一个锁周期
	mark_activated()

	# ① 充满就放，不等任何东西 —— 先扣费并清空充能（扫描线从头重扫）
	commit_cost()
	reset_charge()
	if soul_runtime != null:
		soul_runtime.add_counter("activations")
		soul_runtime.set_counter_timestamp("last_activation_t", battle.elapsed_seconds())
	_record_cast("activate", trace, {"cooldown": cooldown, "cast_times": total})
	# 空放也算“使用”：先广播，让 OTHER_SOUL_USED 触发器有机会充能别的魂灵
	_notify_soul_used(trace)

	# ②～④ 按多重触发次数循环释放
	return await _run_releases(battle, trace, total)


## 按多重触发次数连续释放；每次独立选目标、独立暴击、独立结算自身效果。
## 第 2 次起要等激活锁走完，所以 1 秒最多释放 6 次，超出的顺延到后续秒继续。
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

	# 所有释放都没选中目标才记一次空放；部分空放不刷屏
	if not hit_any and not _steps.is_empty():
		_log_empty_activation(battle, trace, total, _last_empty_reasons)
	return true


## 等激活锁走完再放下一次；冻结、战斗结束、施法者倒下时不释放。
## 激活锁由 BattleBrain 的物理帧推进，所以这里按物理帧轮询。
func _wait_for_next_release(battle: BattleManager) -> WaitResult:
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
		await get_tree().physics_frame
	return WaitResult.CANCELLED if not is_active else WaitResult.STOPPED


## 执行一次释放：先结算自身效果，再按 steps 顺序执行。
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
		await task_wait_delay(skill.cast_time)
		if not is_active:
			_record_cast("cancelled", trace, {
				"detail": "吟唱被打断",
				"release_index": release_index,
				"release_count": release_count,
			})
			return ReleaseResult.CANCELLED
		var caster := caster_unit()
		if not battle.is_running or caster == null or caster.is_dead:
			return ReleaseResult.STOPPED

	var ctx := SkillCastContext.new(self, battle, trace, release_index, release_count)
	var hit_any := false
	for step in _steps:
		if step == null:
			continue
		if not battle.is_running:
			return ReleaseResult.STOPPED
		var result := step.execute(ctx)
		if result == null:
			push_error("技能 %s 的步骤没有返回结果：%s" % [ability_name, step])
			continue
		if result.hit:
			hit_any = true
		elif not result.empty_reason.is_empty() and not _last_empty_reasons.has(result.empty_reason):
			_last_empty_reasons.append(result.empty_reason)

	return ReleaseResult.HIT if hit_any else ReleaseResult.EMPTY


## 整次激活的所有释放都没选中目标时，只报一次空放。
## 只要技能里有魂灵步骤就播报；纯单位技能只播报我方的。
func _log_empty_activation(
	battle: BattleManager,
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


## 多重触发次数：至少释放 1 次
func _cast_times() -> int:
	return maxi(skill.cast_times, 1) if skill != null else 1


## 有投射物的步骤：一支箭对一个目标，射向它"此刻"的坐标。
## 发射完立即返回；落地回调带着发起它的 step，各自结算自己的 effects/cue。
func launch_projectiles(step: UnitSkillStep, groups: Array, ctx: SkillCastContext) -> void:
	if step == null or step.projectile_scene == null:
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

	# 任务挂在施法者身上，不绑定技能生命周期：技能结束后箭仍继续结算；
	# 单位/战场销毁时任务随节点一起释放。
	var task := AbilityTask_Projectile.new()
	caster.add_child(task)
	task.projectile_landed.connect(_on_step_projectile_landed.bind(step, ctx))
	task.task_finished.connect(_on_projectiles_finished.bind(targets.size(), ctx.trace))
	task.execute(caster, targets, step.projectile_scene, step.projectile_speed)


## 一支箭落地就地结算。远近不同的目标各打各的，互不等待。
## 这里不再检查 is_active：技能早已结束，箭仍然要正常结算。
func _on_step_projectile_landed(hit_unit: BattleUnit, step: UnitSkillStep, ctx: SkillCastContext) -> void:
	if hit_unit == null or not is_instance_valid(hit_unit) or hit_unit.is_dead:
		_record_cast("projectile_miss", ctx.trace)
		return
	if ctx.battle == null or not ctx.battle.is_running:
		return
	_record_cast("projectile_hit", ctx.trace, {"target_unit": hit_unit})
	if step != null:
		step.apply_to_target(ctx, hit_unit)


## 所有箭落地/飞空后统计空箭；不再阻塞释放，只补一条日志。
func _on_projectiles_finished(result: Variant, target_count: int, trace: CombatTrace) -> void:
	var battle := _get_battle()
	if battle == null or not battle.is_running:
		return
	var hit_count: int = result if result is int else 0
	var missed: int = target_count - hit_count
	_record_cast("projectiles_finished", trace, {
		"projectile_count": target_count,
		"hit_count": hit_count,
		"missed": missed,
	})


## 对施法者自己结算 self_effects；每次释放各结算一次，独立掷暴击。
## 即使目标规则空放，也照常生效（没有怪物时也会提高再生）。
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


## 掷一次暴击，返回倍率；steps 共用同一套暴击配置。
func roll_crit(battle: BattleManager) -> float:
	if skill == null:
		return 1.0
	var is_crit := skill.crit_chance > 0.0 and battle.rng.randf() < skill.crit_chance
	return skill.crit_multiplier if is_crit else 1.0


## 把一组效果施加到目标；crit_multiplier 已经由调用方掷好。
func apply_effects(
	effects: Array[GameplayEffect],
	target: BattleUnit,
	crit_multiplier: float,
	trace: CombatTrace,
	status_magnitude: float = -1.0
) -> void:
	_apply_effect_list_to_target(effects, target, crit_multiplier, trace, status_magnitude)


## 在受击目标身上播放命中特效；方向按 step 自己的命中次数交替。
## 致命击时挂到战场层，避免 Cue 随目标一起消失。
func play_hit_cue(tag: StringName, target: BattleUnit, step_key: int) -> void:
	if tag.is_empty():
		return
	if target == null or not is_instance_valid(target) or target.asc == null:
		return
	var count := int(_hit_cue_counts.get(step_key, 0))
	var direction := -1.0 if count % 2 == 0 else 1.0
	_hit_cue_counts[step_key] = count + 1
	var payload := {"direction": direction}
	if target.is_dying() and target.get_parent() != null:
		payload["position"] = target.global_position
		GameplayCueManager.execute_cue(tag, target.get_parent(), payload)
		return
	target.asc.execute_cue(tag, payload)


func _apply_effect_list_to_target(
	effects: Array[GameplayEffect],
	target: BattleUnit,
	crit_multiplier: float,
	trace: CombatTrace,
	status_magnitude: float = -1.0
) -> void:
	for effect in effects:
		if effect != null:
			_apply_effect_to_target(effect, target, crit_multiplier, trace, status_magnitude)


## 用当前目标建 spec，把暴击倍率注入给 SoulDamageExecution。
## 伤害加成由 SoulDamageExecution 自己从施法者 ASC 的 damage_bonus 读取。
func _apply_effect_to_target(
	effect: GameplayEffect,
	target: BattleUnit,
	crit_multiplier: float,
	trace: CombatTrace,
	status_magnitude: float = -1.0
) -> void:
	if owner_asc == null or target == null or target.asc == null:
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
	# 异常状态的暴击在释放时已经结算进施加数值；后续每跳不再乘倍率。
	spec.set_set_by_caller_magnitude(GameplayTags.Data_CritMultiplier, crit_multiplier)
	if status_magnitude >= 0.0:
		spec.set_set_by_caller_magnitude(GameplayTags.Data_SkillMagnitude, status_magnitude)
	owner_asc.apply_effect_spec_to_target(spec, target.asc)
	# 每冻住一个目标算一次冻结事件；全场任何单位的冻结触发器都会收到广播
	if effect.granted_tags.has(GameplayTags.State_Frozen):
		caster.notify_freeze_applied(target, trace)
		if soul_runtime != null:
			soul_runtime.add_counter("freezes_applied")


## 广播“本魂灵被使用”；空放也广播，因为冷却已经消耗
func _notify_soul_used(trace: CombatTrace) -> void:
	var caster := _caster_unit()
	var battle := _get_battle()
	if caster == null or battle == null:
		return
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


#region 给 SkillStep / SkillCastContext 的公开接口
func caster_unit() -> BattleUnit:
	return _caster_unit()


func get_battle_manager() -> BattleManager:
	return _get_battle()


func record_step(type: String, trace: CombatTrace, fields: Dictionary = {}) -> void:
	_record_cast(type, trace, fields)


func targets_summary(groups: Array) -> String:
	return _targets_summary(groups)


func target_count(groups: Array) -> int:
	return _target_count(groups)
#endregion


func _record_cast(type: String, trace: CombatTrace, fields: Dictionary = {}) -> void:
	var battle := _get_battle()
	if battle == null:
		return
	var caster := _caster_unit()
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


func _targets_summary(groups: Array) -> String:
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


func _target_count(groups: Array) -> int:
	var count := 0
	for group in groups:
		count += group.size()
	return count


func _caster_unit() -> BattleUnit:
	return owner_asc.get_parent() as BattleUnit


func _get_battle() -> BattleManager:
	var caster := _caster_unit()
	return caster.battle if caster else null
