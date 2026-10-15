## 通用自动施法技能：全场共用这一个脚本，差异全在 SkillDefinition 数据里。
##
## 施法顺序（重要，决定了"空放不消耗"的行为）：
##   ① 先选目标          完全选不到人 → 直接放弃，不扣冷却
##   ② commit_ability()  扣费 + 进冷却（之后的意外不再退还，由游戏设计决定）
##   ③ 吟唱（可选）       吟唱结束后重新选人，避免对着尸体放大
##   ④ 逐批结算          一个批次 = 一份 Spec = 一次施加
##
## 门卫检查（冷却倒计时 / 花费 / 施法条件标签 / 是否在施法中）全部由框架的
## can_activate_ability() 负责，这里不重复实现。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name AutoCastAbility extends GameplayAbility

## 本技能的数据定义（由 BattleBrain 在授予时注入）
var skill: SkillDefinition


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

	# ① 先选目标。完全没有目标 = 空放，趁 commit 之前撤退，不消耗冷却。
	var groups := skill.target_rule.resolve(owner_asc, battle)
	if groups.is_empty():
		return false

	# ② 提交：扣费 + 进冷却。冷却倒计时从这里开始（由框架 tick）。
	commit_ability()

	# ③ 吟唱（可选）：醒来后重新选人，有人中途倒下就换目标。
	if skill.cast_time > 0.0:
		await task_wait_delay(skill.cast_time)
		groups = skill.target_rule.resolve(owner_asc, battle)

	if not battle.is_running:
		return true
	if groups.is_empty():
		battle.log_line("%s 的【%s】空放了（目标已全部倒下）" % [_caster_name(), skill.display_name], "gray")
		return true

	# ④ 报幕 + 逐批结算：REPEAT 规则会给出多个批次，每批独立结算。
	battle.log_cast(_caster_unit(), skill, groups)
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


func _caster_unit() -> BattleUnit:
	return owner_asc.get_parent() as BattleUnit


func _caster_name() -> String:
	var caster := _caster_unit()
	return caster.unit_name if caster else "???"


func _get_battle() -> BattleManager:
	var caster := _caster_unit()
	return caster.battle if caster else null
