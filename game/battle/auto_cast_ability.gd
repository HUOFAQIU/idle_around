## 通用自动施法技能：全场共用这一个脚本，差异全在 SkillDefinition 数据里。
##
## 施法顺序：
##   ① commit_ability()  扣费 + 进冷却 —— 冷却一到就放，不等任何东西
##   ② 选目标            选不到就是空放：照放、照扣冷却，只是什么也没打着
##   ③ 吟唱（可选）       吟唱结束后重新选人，避免对着尸体放大
##   ④ 结算              有投射物 → 一支箭对一个目标，飞到才结算、空了就是空了；
##                       没投射物 → 直接按批次施加效果
##
## 门卫检查（冷却倒计时 / 花费 / 施法条件标签 / 是否在施法中）全部由框架的
## can_activate_ability() 负责，这里不重复实现。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name AutoCastAbility extends GameplayAbility

## 本技能的数据定义（由 BattleBrain 在授予时注入；也可在场景里直接配置）
@export var skill: SkillDefinition


func _ready() -> void:
	super()
	# 场景里预配置的技能：入树时翻译成框架配置。
	# 代码创建的技能在授予前已经 apply 过，ability_name 非空，不会重复执行
	if skill != null and ability_name.is_empty():
		apply_definition(skill)


## 把一份 SkillDefinition 翻译成框架的技能配置。
func apply_definition(def: SkillDefinition) -> void:
	skill = def
	ability_name = def.display_name
	ability_tag = StringName("Skill." + def.id)
	# 框架的 cooldown_effect 槽位 = 我们的"冷却效果"：开局挂上、释放后重新挂上，
	# 门卫靠它授予的标签判定"冷却是否完成"。
	cooldown_effect = def.charge_effect

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

	# ① 冷却一到就放，不等任何东西 —— 先把冷却扣掉（扫描线也从头重扫）
	commit_ability()

	# ② 选目标。选不到就是空放：照放、照扣冷却，只是什么也没打着
	var groups := skill.target_rule.resolve(owner_asc, battle)

	# ③ 吟唱（可选）：醒来后重新选人，有人中途倒下就换目标。
	if skill.cast_time > 0.0:
		await task_wait_delay(skill.cast_time)
		groups = skill.target_rule.resolve(owner_asc, battle)

	if not battle.is_running:
		return true
	if groups.is_empty():
		# 空放只播报我方的：怪的"咬"够不着人是常态，一场几条蛇每 3 秒刷一行，
		# 会把真正有意思的行冲掉
		var caster := _caster_unit()
		if caster and caster.team == BattleUnit.Team.PLAYER:
			battle.log_line("%s 的【%s】空放了（范围内没目标）" % [_caster_name(), skill.display_name], "gray")
		return true

	# ④ 报幕 + 结算
	battle.log_cast(_caster_unit(), skill, groups)

	if skill.projectile_scene:
		return await _cast_projectiles(battle, groups)

	# 没有投射物：逐批直接结算。REPEAT 规则会给出多个批次，每批独立结算。
	for group in groups:
		if not battle.is_running:
			break
		var target_data := GameplayAbilityTargetData.new()
		for target in group:
			target_data.append_node(target)
		for effect in skill.effects:
			if effect:
				apply_effect_to_targets(effect, target_data)  # GameplayAbility 自带的方法，内部走 owner_asc
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
	if not battle.is_running:
		return true

	var missed := targets.size() - hit_count
	if missed > 0:
		battle.log_line("%s 的【%s】有 %d 支空了" % [caster.unit_name, skill.display_name, missed], "gray")
	return true


## 一支箭落地就地结算。远近不同的目标各打各的，互不等待 ——
## 等全部飞完再一起结算的话，近的那支会白等，看起来就是"打中了却不掉血"
func _on_projectile_landed(hit_unit: BattleUnit) -> void:
	if hit_unit == null:
		return
	var target_data := GameplayAbilityTargetData.new()
	target_data.append_node(hit_unit)
	for effect in skill.effects:
		if effect:
			apply_effect_to_targets(effect, target_data)


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
