## 通用自动施法技能：全场共用这一个脚本，差异全在 SkillDefinition 数据里。
##
## 施法顺序：
##   ① commit_cost() + reset_charge()  扣费 + 清空充能 —— 充满就放，不等任何东西
##   ② 选目标            选不到就是空放：照放、照清充能，只是什么也没打着
##   ③ 吟唱（可选）       吟唱结束后重新选人，避免对着尸体放大
##   ④ 结算              有投射物 → 一支箭对一个目标，飞到才结算、空了就是空了；
##                       没投射物 → 逐目标直接结算，暴击独立判定
##
## 投射物发射后立即返回，不占用 is_active：箭独立飞行、逐箭结算，
## 同一颗魂灵的下一次释放只受充能和 20 刻激活锁限制。
##
## 门卫检查（花费 / 施法条件标签 / 是否在施法中）由框架的 can_activate_ability()
## 负责；冷却由 ChargedAbility 的充能值控制。
##
## target_rule 是 SoulTargetRule 的技能走魂灵分支：目标是魂灵能力（加速等），不是战斗单位。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name AutoCastAbility extends ChargedAbility

## 本技能的数据定义（由 BattleUnit.add_soul_abilities() 注入）
@export var skill: SkillDefinition
## 本技能来源的魂灵数据；用于 OTHER_SOUL_USED 触发器的标签过滤
var soul_data: SoulData
## 本技能对应的战斗运行期状态（由 BattleUnit 注入）
var soul_runtime: SoulRuntime


func _ready() -> void:
	super()
	# 通过场景节点直接配置 skill 的用法：入树时翻译成框架配置。
	# 代码创建的技能在授予前已经 apply 过，ability_name 非空，不会重复执行
	if skill != null and ability_name.is_empty():
		apply_definition(skill)


## 把一份 SkillDefinition 翻译成框架的技能配置。
## p_display_name 来自魂灵物品的 item_name；不传时退回内部 id。
func apply_definition(def: SkillDefinition, p_display_name: String = "") -> void:
	skill = def
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
	_record_cast("attempt", trace, {"cooldown": cooldown})
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
	mark_activated()

	# ① 充满就放，不等任何东西 —— 先扣费并清空充能（扫描线从头重扫）
	commit_cost()
	reset_charge()
	if soul_runtime != null:
		soul_runtime.add_counter("activations")
		soul_runtime.set_counter_timestamp("last_activation_t", battle.elapsed_seconds())
	_record_cast("activate", trace, {"cooldown": cooldown})
	# 空放也算“使用”：先广播，让 OTHER_SOUL_USED 触发器有机会充能别的魂灵
	_notify_soul_used(trace)

	# 只对施法者自己结算的效果（例如温泉的再生），不管有没有选中敌人都会生效
	_apply_self_effects(battle, trace)

	# 魂灵目标技能（加速/减速/冻结/充能）：目标不是战斗单位
	if skill.target_rule is SoulTargetRule:
		return await _activate_soul_skill(battle, trace)

	if skill.target_rule == null:
		return true

	# ② 选目标。选不到就是空放：照放、照扣冷却，只是什么也没打着
	var groups := (skill.target_rule as TargetRule).resolve(owner_asc, battle)

	# ③ 吟唱（可选）：醒来后重新选人，有人中途倒下就换目标。
	if skill.cast_time > 0.0:
		_record_cast("cast_start", trace, {"cast_time": skill.cast_time})
		await task_wait_delay(skill.cast_time)
		if not is_active:
			_record_cast("cancelled", trace, {"detail": "吟唱被打断"})
			return false
		groups = (skill.target_rule as TargetRule).resolve(owner_asc, battle)

	if not battle.is_running:
		return true
	if groups.is_empty():
		_record_cast("empty", trace, {"detail": "范围内没目标"})
		# 空放只播报我方的：怪的"咬"够不着人是常态，一场几条蛇每 3 秒刷一行，
		# 会把真正有意思的行冲掉
		var caster := _caster_unit()
		if caster and caster.team == BattleUnit.Team.PLAYER:
			battle.log_line("%s 的【%s】空放了（范围内没目标）" % [_caster_name(), ability_name], "gray")
			if soul_runtime != null:
				soul_runtime.add_counter("empty_casts")
		return true

	# ④ 报幕 + 结算
	_record_cast("targets", trace, {
		"targets": _targets_summary(groups),
		"count": _target_count(groups),
	})
	battle.log_cast(_caster_unit(), ability_name, groups)

	if skill.projectile_scene:
		_cast_projectiles(groups, trace)
		return true

	# 没有投射物：逐目标直接结算，暴击对每个目标独立判定。
	for group in groups:
		if not battle.is_running:
			break
		for target in group:
			_apply_effects_to_target(target, trace)
	return true


## 魂灵目标技能：选魂灵、施加加速/减速/冻结/充能；空放也照常消耗冷却。
func _activate_soul_skill(battle: BattleManager, trace: CombatTrace) -> bool:
	var rule := skill.target_rule as SoulTargetRule
	if rule == null:
		return true
	var targets := rule.resolve(self, battle.rng)

	# 吟唱结束后重新选，避免对着已经离开的魂灵施放
	if skill.cast_time > 0.0:
		_record_cast("cast_start", trace, {"cast_time": skill.cast_time})
		await task_wait_delay(skill.cast_time)
		if not is_active:
			_record_cast("cancelled", trace, {"detail": "吟唱被打断"})
			return false
		if not battle.is_running:
			return true
		targets = rule.resolve(self, battle.rng)

	if targets.is_empty():
		_record_cast("empty", trace, {"detail": "没有可施加状态的魂灵"})
		battle.log_line("%s 的【%s】空放了（没有可施加状态的魂灵）" % [_caster_name(), ability_name], "gray")
		if soul_runtime != null:
			soul_runtime.add_counter("empty_casts")
		return true

	var names: Array[String] = []
	for target in targets:
		names.append(target.ability_name)
	_record_cast("soul_targets", trace, {"targets": names})
	battle.log_line("%s 施放【%s】→ %s" % [_caster_name(), ability_name, "、".join(names)], "#6fb7ff")

	for target in targets:
		if not is_instance_valid(target):
			continue
		var charge_applied := false
		if skill.charge_duration > 0.0 and target.cooldown > 0.0:
			target.add_charge(skill.charge_duration, trace)
			if soul_runtime != null:
				soul_runtime.add_counter("charges_given", skill.charge_duration)
			battle.log_line("%s 获得充能（%.1f 秒）" % [target.ability_name, skill.charge_duration], CombatColors.CHARGE)
			charge_applied = true
		if skill.haste_duration > 0.0 and target.apply_haste(skill.haste_duration, trace):
			battle.log_line("%s 获得状态【加速】（%.1f 秒）" % [target.ability_name, skill.haste_duration], CombatColors.HASTE)
		if skill.slow_duration > 0.0 and target.apply_slow(skill.slow_duration, trace):
			battle.log_line("%s 获得状态【减速】（%.1f 秒）" % [target.ability_name, skill.slow_duration], CombatColors.SLOW)
		if skill.freeze_duration > 0.0 and target.apply_freeze(skill.freeze_duration, trace):
			battle.log_line("%s 获得状态【冻结】（%.1f 秒）" % [target.ability_name, skill.freeze_duration], CombatColors.FREEZE)
		# 充能满就同帧释放：避免目标晚一帧归零，之后和充能者相位锁死。
		# 冻结或激活锁未走完时不释放，留到之后由 BattleBrain 主循环统一处理。
		if (
			charge_applied
			and target.is_ready()
			and not target.is_active
			and not target.is_frozen()
			and target.can_activate_now()
		):
			target.try_activate(trace)
	return true


## 有投射物的技能：一支箭对一个目标，射向它"此刻"的坐标。
## 箭飞到谁身上才算打中谁（可能打空、也可能打到别只），所以效果要等命中才施加 ——
## 而且是**每支箭各自落地就各自结算**，不等其他箭飞完。
##
## 发射完立即返回：投射物飞行不再占用 is_active。
## 否则同一颗魂灵要等箭落地才能再次释放，被加速/充能提前灌满时会白白撞顶。
func _cast_projectiles(groups: Array, trace: CombatTrace) -> void:
	var caster := _caster_unit()
	if caster == null:
		return
	var targets : Array[BattleUnit] = []
	for group in groups:
		for unit in group:
			if unit is BattleUnit:
				targets.append(unit)
	if targets.is_empty():
		return
	_record_cast("projectiles", trace, {"projectile_count": targets.size()})

	# 任务挂在施法者身上，不绑定技能生命周期：技能结束后箭仍继续结算；
	# 单位/战场销毁时任务随节点一起释放。
	var task := AbilityTask_Projectile.new()
	caster.add_child(task)
	task.projectile_landed.connect(_on_projectile_landed.bind(trace))
	task.task_finished.connect(_on_projectiles_finished.bind(targets.size(), trace))
	task.execute(caster, targets, skill.projectile_scene, skill.projectile_speed)


## 一支箭落地就地结算。远近不同的目标各打各的，互不等待 ——
## 等全部飞完再一起结算的话，近的那支会白等，看起来就是"打中了却不掉血"。
## 这里不再检查 is_active：技能早已结束，箭仍然要正常结算。
func _on_projectile_landed(hit_unit: BattleUnit, trace: CombatTrace) -> void:
	if hit_unit == null or not is_instance_valid(hit_unit) or hit_unit.is_dead:
		_record_cast("projectile_miss", trace)
		return
	var battle := _get_battle()
	if battle == null or not battle.is_running:
		return
	_record_cast("projectile_hit", trace, {"target_unit": hit_unit})
	_apply_effects_to_target(hit_unit, trace)


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
	if missed > 0:
		battle.log_line("%s 的【%s】有 %d 支空了" % [_caster_name(), ability_name, missed], "gray")


## 对施法者自己结算 self_effects；每次释放独立掷一次暴击。
## 即使目标规则空放，也照常生效（温泉没有怪物时也会提高再生）。
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


## 对单个目标结算技能效果；每支箭/每个目标独立掷一次暴击
func _apply_effects_to_target(target: BattleUnit, trace: CombatTrace) -> void:
	if target == null:
		return
	var battle := _get_battle()
	if battle == null:
		return
	var is_crit := skill.crit_chance > 0.0 and battle.rng.randf() < skill.crit_chance
	var crit_multiplier := skill.crit_multiplier if is_crit else 1.0
	if is_crit:
		_record_cast("crit", trace, {"target_unit": target})
	_apply_effect_list_to_target(skill.effects, target, crit_multiplier, trace)


func _apply_effect_list_to_target(
	effects: Array[GameplayEffect],
	target: BattleUnit,
	crit_multiplier: float,
	trace: CombatTrace
) -> void:
	for effect in effects:
		if effect != null:
			_apply_effect_to_target(effect, target, crit_multiplier, trace)


## 用当前目标建 spec，把暴击倍率注入给 SoulDamageExecution。
## 伤害加成由 SoulDamageExecution 自己从施法者 ASC 的 damage_bonus 读取。
func _apply_effect_to_target(
	effect: GameplayEffect,
	target: BattleUnit,
	crit_multiplier: float,
	trace: CombatTrace
) -> void:
	if owner_asc == null or target == null or target.asc == null:
		return
	var caster := owner_asc.get_parent() as BattleUnit
	if caster == null:
		return
	var context := SoulEffectContext.new(caster, caster, trace)
	var target_data := GameplayAbilityTargetData.new()
	target_data.append_node(target)
	context.target_data = target_data
	var spec := GameplayEffectSpec.new(effect, context, ability_level)
	spec.display_name = ability_name
	# 异常状态的暴击在释放时已经结算进施加数值；后续每跳不再乘倍率。
	spec.set_set_by_caller_magnitude(SoulDamageExecution.CRIT_MULTIPLIER_TAG, crit_multiplier)
	owner_asc.apply_effect_spec_to_target(spec, target.asc)
	# 每冻住一个目标算一次冻结事件；全场任何单位的冻结触发器都会收到广播
	if effect.granted_tags.has(GameplayTags.State_Frozen):
		caster.notify_freeze_applied(target, trace)
		if soul_runtime != null:
			soul_runtime.add_counter("freezes_applied")


## 广播“本魂灵被使用”；空放也广播，因为冷却已经消耗
func _notify_soul_used(trace: CombatTrace) -> void:
	var caster := _caster_unit()
	if caster == null:
		return
	var soul_label := ""
	if soul_runtime != null:
		soul_label = soul_runtime.display_name()
	elif soul_data != null:
		soul_label = soul_data.item_name
	CombatTelemetry.record(CombatEvent.SOUL, "used", {
		"actor_unit": caster,
		"soul": soul_label,
		"ability": ability_name,
		"trace": trace,
	}, CombatEvent.IMPORTANT if caster.team == BattleUnit.Team.PLAYER else CombatEvent.DETAIL)
	caster.notify_soul_used(self, trace)


func _trace_from_payload(payload: Variant) -> CombatTrace:
	if payload is CombatTrace:
		return payload as CombatTrace
	if payload is Dictionary:
		var value: Variant = (payload as Dictionary).get("trace", null)
		if value is CombatTrace:
			return value as CombatTrace
	return null


func _record_cast(type: String, trace: CombatTrace, fields: Dictionary = {}) -> void:
	var caster := _caster_unit()
	fields["actor_unit"] = caster
	fields["ability"] = ability_name
	fields["ability_tag"] = String(ability_tag)
	if soul_runtime != null:
		fields["soul"] = soul_runtime.display_name()
	if trace != null:
		fields["trace"] = trace
	var importance := CombatEvent.DETAIL
	if caster != null and caster.team == BattleUnit.Team.PLAYER:
		importance = CombatEvent.IMPORTANT
	CombatTelemetry.record(CombatEvent.CAST, type, fields, importance)


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


func _caster_name() -> String:
	var caster := _caster_unit()
	return caster.unit_name if caster else "???"


func _get_battle() -> BattleManager:
	var caster := _caster_unit()
	return caster.battle if caster else null
