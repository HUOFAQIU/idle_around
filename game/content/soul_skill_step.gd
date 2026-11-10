class_name SoulSkillStep extends SkillStep
## 以魂灵为目标的技能步骤。

## 选魂灵规则
@export var target_rule: SoulTargetRule
## 加速/减速/冻结时长（秒）；0 = 不施加
@export_range(0.0, 60.0, 0.1) var haste_duration: float = 0.0
@export_range(0.0, 60.0, 0.1) var slow_duration: float = 0.0
@export_range(0.0, 60.0, 0.1) var freeze_duration: float = 0.0
## 充能数值（秒）：直接减少目标当前冷却；0 = 不充能
@export_range(0.0, 60.0, 0.1) var charge_duration: float = 0.0


func execute(ctx: SkillCastContext) -> SkillStepResult:
	if target_rule == null:
		push_error("SoulSkillStep 缺少 target_rule：%s" % get_script().resource_path)
		return SkillStepResult.empty("魂灵目标规则缺失")

	var targets := target_rule.resolve(ctx.ability, ctx.battle.rng)
	if targets.is_empty():
		ctx.ability.record_step("release_empty", ctx.trace, {
			"reason": "没有可施加状态的魂灵",
			"release_index": ctx.release_index,
			"release_count": ctx.release_count,
		})
		return SkillStepResult.empty("没有可施加状态的魂灵")

	var names: Array[String] = []
	for target in targets:
		names.append(target.ability_name)
	ctx.ability.record_step("soul_targets", ctx.trace, {
		"targets": names,
		"release_index": ctx.release_index,
		"release_count": ctx.release_count,
	})
	ctx.battle.log_line("%s 施放【%s】→ %s" % [
		ctx.ability.caster_name(),
		ctx.ability.ability_name,
		"、".join(names),
	], "#6fb7ff")

	for target in targets:
		if not is_instance_valid(target):
			continue
		var charge_applied := false
		if charge_duration > 0.0 and target.cooldown > 0.0:
			target.add_charge(charge_duration, ctx.trace)
			if ctx.ability.soul_runtime != null:
				ctx.ability.soul_runtime.add_counter("charges_given", charge_duration)
			ctx.battle.log_line("%s 获得充能（%.1f 秒）" % [target.ability_name, charge_duration], GameColors.CHARGE)
			charge_applied = true
		if haste_duration > 0.0 and target.apply_haste(haste_duration, ctx.trace):
			ctx.battle.log_line("%s 获得状态【加速】（%.1f 秒）" % [target.ability_name, haste_duration], GameColors.HASTE)
		if slow_duration > 0.0 and target.apply_slow(slow_duration, ctx.trace):
			ctx.battle.log_line("%s 获得状态【减速】（%.1f 秒）" % [target.ability_name, slow_duration], GameColors.SLOW)
		if freeze_duration > 0.0 and target.apply_freeze(freeze_duration, ctx.trace):
			ctx.battle.log_line("%s 获得状态【冻结】（%.1f 秒）" % [target.ability_name, freeze_duration], GameColors.FREEZE)
		# 充能满就同帧释放：避免目标晚一帧归零，之后和充能者相位锁死。
		if (
			charge_applied
			and target.is_ready()
			and not target.is_active
			and not target.is_frozen()
			and target.can_activate_now()
		):
			target.try_activate(ctx.trace)
	return SkillStepResult.hit_result()
