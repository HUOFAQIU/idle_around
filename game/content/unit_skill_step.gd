class_name UnitSkillStep extends SkillStep
## 以战斗单位为目标的技能步骤。

## 选单位规则
@export var target_rule: TargetRule
## 施加到每个目标的效果列表（可多个：例如"伤害 + 中毒"）
@export var effects: Array[GameplayEffect] = []
## 命中特效标签：每次结算到目标身上时播一次；留空不播
@export var hit_cue_tag: StringName = &""
## 投射物场景；留空 = 选完目标立刻结算
@export var projectile_scene: PackedScene
## 投射物飞行速度（像素/秒）；0 或负数使用投射物默认速度
@export var projectile_speed: float = 420.0
## 本步骤对 StatusApplyExecution 的数值覆盖；< 0 = 使用效果资源自己的 base_amount
@export_range(-1.0, 9999.0, 0.1) var status_magnitude: float = -1.0


func execute(ctx: SkillCastContext) -> SkillStepResult:
	if target_rule == null:
		push_error("UnitSkillStep 缺少 target_rule：%s" % get_script().resource_path)
		return SkillStepResult.empty("目标规则缺失")

	var groups := target_rule.resolve(ctx.caster_asc, ctx.battle)
	if groups.is_empty():
		ctx.ability.record_step("release_empty", ctx.trace, {
			"reason": "范围内没目标",
			"release_index": ctx.release_index,
			"release_count": ctx.release_count,
		})
		return SkillStepResult.empty("范围内没目标")

	ctx.ability.record_step("targets", ctx.trace, {
		"targets": ctx.ability.targets_summary(groups),
		"count": ctx.ability.target_count(groups),
		"release_index": ctx.release_index,
		"release_count": ctx.release_count,
	})
	ctx.battle.log_cast(ctx.caster_unit, ctx.ability.ability_name, groups)

	if projectile_scene != null:
		ctx.ability.launch_projectiles(self, groups, ctx)
		return SkillStepResult.hit_result()

	for group in groups:
		if not ctx.battle.is_running:
			break
		for target in group:
			apply_to_target(ctx, target)
	return SkillStepResult.hit_result()


## 对单个目标结算；投射物落地也走这里。
func apply_to_target(ctx: SkillCastContext, target: BattleUnit) -> void:
	if target == null or ctx.battle == null:
		return
	var crit_multiplier := ctx.ability.roll_crit(ctx.battle)
	if crit_multiplier > 1.0:
		ctx.ability.record_step("crit", ctx.trace, {"target_unit": target})
	ctx.ability.apply_effects(effects, target, crit_multiplier, ctx.trace, status_magnitude)
	ctx.ability.play_hit_cue(hit_cue_tag, target, get_instance_id())
