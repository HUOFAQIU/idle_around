## 通用自动施法技能：全场共用这一个脚本，差异全在 SkillDefinition 数据里。
##
## 施法顺序：
##   ① commit_cost() + reset_charge()  扣费 + 清空充能 —— 充满就放，不等任何东西
##   ② 选目标            选不到就是空放：照放、照清充能，只是什么也没打着
##   ③ 吟唱（可选）       吟唱结束后重新选人，避免对着尸体放大
##   ④ 结算              有投射物 → 一支箭对一个目标，飞到才结算、空了就是空了；
##                       没投射物 → 逐目标直接结算，暴击独立判定
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
	# 冷却效果只作为时长数据，不再挂到 ASC；清空避免门卫检查它的标签
	setup_cooldown_from_effect(def.cooldown_effect)
	cooldown_effect = null

	# 施法条件（例如"只在受伤时治疗"）翻译成框架的标签查询，由门卫统一检查
	if not def.cast_requires_tags.is_empty():
		var query := GameplayTagQuery.new()
		for tag in def.cast_requires_tags:
			query.require_any_tags.append(tag)
		activation_query = query


## 由框架在通过门卫后调用；返回 true = 正常结束，false = 结束且算"取消"。
func _activate_ability() -> bool:
	var battle := _get_battle()
	if skill == null or battle == null:
		return false

	# ① 充满就放，不等任何东西 —— 先扣费并清空充能（扫描线从头重扫）
	commit_cost()
	reset_charge()

	# 魂灵目标技能（加速/减速/充能）：目标不是战斗单位
	if skill.target_rule is SoulTargetRule:
		return await _activate_soul_skill(battle)

	if skill.target_rule == null:
		return true

	# ② 选目标。选不到就是空放：照放、照扣冷却，只是什么也没打着
	var groups := (skill.target_rule as TargetRule).resolve(owner_asc, battle)

	# ③ 吟唱（可选）：醒来后重新选人，有人中途倒下就换目标。
	if skill.cast_time > 0.0:
		await task_wait_delay(skill.cast_time)
		if not is_active:
			return false
		groups = (skill.target_rule as TargetRule).resolve(owner_asc, battle)

	if not battle.is_running:
		return true
	if groups.is_empty():
		# 空放只播报我方的：怪的"咬"够不着人是常态，一场几条蛇每 3 秒刷一行，
		# 会把真正有意思的行冲掉
		var caster := _caster_unit()
		if caster and caster.team == BattleUnit.Team.PLAYER:
			battle.log_line("%s 的【%s】空放了（范围内没目标）" % [_caster_name(), ability_name], "gray")
		return true

	# ④ 报幕 + 结算
	battle.log_cast(_caster_unit(), ability_name, groups)

	if skill.projectile_scene:
		return await _cast_projectiles(battle, groups)

	# 没有投射物：逐目标直接结算，暴击对每个目标独立判定。
	for group in groups:
		if not battle.is_running:
			break
		for target in group:
			_apply_effects_to_target(target)
	return true


## 魂灵目标技能：选魂灵、施加加速；空放也照常消耗冷却。
## 当前只支持加速；减速/充能以后在这条分支里扩。
func _activate_soul_skill(battle: BattleManager) -> bool:
	var rule := skill.target_rule as SoulTargetRule
	if rule == null:
		return true
	var targets := rule.resolve(self, battle.rng)

	# 吟唱结束后重新选，避免对着已经离开的魂灵施放
	if skill.cast_time > 0.0:
		await task_wait_delay(skill.cast_time)
		if not is_active:
			return false
		if not battle.is_running:
			return true
		targets = rule.resolve(self, battle.rng)

	if targets.is_empty():
		battle.log_line("%s 的【%s】空放了（没有可施加状态的魂灵）" % [_caster_name(), ability_name], "gray")
		return true

	var names: Array[String] = []
	for target in targets:
		names.append(target.ability_name)
	battle.log_line("%s 施放【%s】→ %s" % [_caster_name(), ability_name, "、".join(names)], "#6fb7ff")

	for target in targets:
		if not is_instance_valid(target):
			continue
		var charge_applied := false
		if skill.charge_duration > 0.0 and target.cooldown > 0.0:
			target.add_charge(skill.charge_duration)
			battle.log_line("%s 获得充能（%.1f 秒）" % [target.ability_name, skill.charge_duration], "#ffd866")
			charge_applied = true
		if skill.haste_duration > 0.0 and target.apply_haste(skill.haste_duration):
			battle.log_line("%s 获得状态【加速】（%.1f 秒）" % [target.ability_name, skill.haste_duration], "#57d9e8")
		if skill.slow_duration > 0.0 and target.apply_slow(skill.slow_duration):
			battle.log_line("%s 获得状态【减速】（%.1f 秒）" % [target.ability_name, skill.slow_duration], "#57d9e8")
		# 充能满就同帧释放：避免目标晚一帧归零，之后和充能者相位锁死。
		# 冰冻目标不释放，留到解冻后的下一物理帧由 BattleBrain 统一处理。
		if charge_applied and target.is_ready() and not target.is_active and not target.is_frozen():
			target.try_activate()
	return true


## 有投射物的技能：一支箭对一个目标，射向它"此刻"的坐标。
## 箭飞到谁身上才算打中谁（可能打空、也可能打到别只），所以效果要等命中才施加 ——
## 而且是**每支箭各自落地就各自结算**，不等其他箭飞完。
func _cast_projectiles(battle: BattleManager, groups: Array) -> bool:
	var caster := _caster_unit()
	var targets : Array[BattleUnit] = []
	for group in groups:
		for unit in group:
			if unit is BattleUnit:
				targets.append(unit)
	if targets.is_empty():
		return true

	var hit_count := await task_projectile(caster, targets, skill.projectile_scene)
	if not is_active:
		return false
	if not battle.is_running:
		return true

	var missed := targets.size() - hit_count
	if missed > 0:
		battle.log_line("%s 的【%s】有 %d 支空了" % [caster.unit_name, ability_name, missed], "gray")
	return true


## 一支箭落地就地结算。远近不同的目标各打各的，互不等待 ——
## 等全部飞完再一起结算的话，近的那支会白等，看起来就是"打中了却不掉血"
func _on_projectile_landed(hit_unit: BattleUnit) -> void:
	if not is_active:
		return
	_apply_effects_to_target(hit_unit)


## 对单个目标结算技能效果；每支箭/每个目标独立掷一次暴击
func _apply_effects_to_target(target: BattleUnit) -> void:
	if target == null:
		return
	var battle := _get_battle()
	if battle == null:
		return
	var is_crit := skill.crit_chance > 0.0 and battle.rng.randf() < skill.crit_chance
	var crit_multiplier := skill.crit_multiplier if is_crit else 1.0
	for effect in skill.effects:
		if effect != null:
			_apply_effect_to_target(effect, target, crit_multiplier)


## 用当前目标建 spec，把暴击倍率注入给 SoulDamageExecution。
## 伤害加成由 SoulDamageExecution 自己从施法者 ASC 的 damage_bonus 读取。
func _apply_effect_to_target(effect: GameplayEffect, target: BattleUnit, crit_multiplier: float) -> void:
	if owner_asc == null or target == null or target.asc == null:
		return
	var caster := owner_asc.get_parent()
	if caster == null:
		return
	var context := GameplayEffectContext.new(caster, caster)
	var target_data := GameplayAbilityTargetData.new()
	target_data.append_node(target)
	context.target_data = target_data
	var spec := GameplayEffectSpec.new(effect, context, ability_level)
	spec.set_set_by_caller_magnitude(SoulDamageExecution.CRIT_MULTIPLIER_TAG, crit_multiplier)
	owner_asc.apply_effect_spec_to_target(spec, target.asc)


## 发一批投射物，等它们全部落地，返回打中了几支。
## 飞行物本身的"走到哪算到哪"在 SoulProjectile 里；这里负责发、以及等最后一下收场。
## 只取一个计数不取名单：先落地的箭可能已经把目标打死了，名单会变成已释放对象
func task_projectile(caster: BattleUnit, targets: Array[BattleUnit], projectile_scene: PackedScene) -> int:
	var task := AbilityTask_Projectile.new()
	bind_task(task)
	task.projectile_landed.connect(_on_projectile_landed)
	task.execute(caster, targets, projectile_scene)
	var result = await task.task_finished
	return result if result is int else 0


func _caster_unit() -> BattleUnit:
	return owner_asc.get_parent() as BattleUnit


func _caster_name() -> String:
	var caster := _caster_unit()
	return caster.unit_name if caster else "???"


func _get_battle() -> BattleManager:
	var caster := _caster_unit()
	return caster.battle if caster else null
