class_name ModContentValidator
extends RefCounted

const CONTENT_NAMING: GDScript = preload("res://scripts/mod/content_naming.gd")
const MOD_PATHS: GDScript = preload("res://scripts/mod/mod_paths.gd")

var _report_error: Callable
var _content_root_of: Callable
var _validated_effect_ids: Dictionary = {}
var _overrides: Dictionary = {}


func _init(report_error: Callable, content_root_of: Callable) -> void:
	_report_error = report_error
	_content_root_of = content_root_of


func validate_content_id(mod: ModInfo, spec: Dictionary, raw_id: String) -> bool:
	var global_namespace := mod.manifest.content_namespace == "global"
	if bool(spec.get("is_tag", false)):
		var cue_prefix := _cue_tag_prefix(mod)
		if not global_namespace and (not raw_id.begins_with(cue_prefix) or raw_id.length() == cue_prefix.length()):
			_report_error.call(mod, "cue 标签必须使用 %s 前缀：%s" % [cue_prefix, raw_id])
			return false
		if not CONTENT_NAMING.is_valid_tag(raw_id):
			_report_error.call(mod, "cue 标签不是合法 GAS 标签：%s" % raw_id)
			return false
		return true

	if not global_namespace and not raw_id.begins_with(String(mod.id) + ":"):
		_report_error.call(mod, "内容 ID 必须以 %s: 开头：%s" % [mod.id, raw_id])
		return false
	var local_id: String = CONTENT_NAMING.local_id_of(StringName(raw_id), mod.id)
	if not CONTENT_NAMING.is_valid_local_id(local_id):
		_report_error.call(mod, "内容 ID 不合法（小写 snake_case）：%s" % raw_id)
		return false
	var suffix := String(spec.get("id_suffix", ""))
	if suffix.is_empty():
		return true
	if not local_id.ends_with(suffix) or local_id.length() <= suffix.length():
		_report_error.call(mod, "%s ID 应以 %s 结尾：%s" % [String(spec.get("label", "内容")), suffix, raw_id])
		return false
	return true


func normalize_skill_id(mod: ModInfo, soul: SoulData) -> void:
	var skill := soul.skill
	if skill == null:
		return
	var owns_skill := not skill.resource_path.is_empty() and skill.resource_path.begins_with(String(_content_root_of.call(mod)))
	if not owns_skill:
		_validate_external_skill_id(mod, skill)
		return

	var global_namespace := mod.manifest.content_namespace == "global"
	if skill.id.is_empty():
		skill.id = CONTENT_NAMING.skill_suffix(mod.id, soul.content_id, global_namespace)
		return
	if not CONTENT_NAMING.is_valid_tag(skill.id):
		_report_error.call(mod, "技能 id 不是合法 GAS 标签：%s" % skill.id)
		return
	if not CONTENT_NAMING.is_skill_suffix_allowed(skill.id, mod.id, global_namespace):
		_report_error.call(mod, "技能 id 必须使用 %s%s. 前缀：%s" % [
			CONTENT_NAMING.MOD_TAG_PREFIX,
			CONTENT_NAMING.to_pascal(String(mod.id)),
			skill.id,
		])
		return
	if global_namespace:
		var expected: String = CONTENT_NAMING.skill_suffix(mod.id, soul.content_id, true)
		if skill.id != expected:
			_report_error.call(mod, "core 技能 id 应与魂灵 ID 对应，应为 %s：%s" % [expected, skill.id])


func _validate_external_skill_id(mod: ModInfo, skill: SkillDefinition) -> void:
	if skill.id.is_empty():
		_report_error.call(mod, "外部技能资源缺少 id：%s" % skill.resource_path)
	elif not CONTENT_NAMING.is_valid_tag(skill.id):
		_report_error.call(mod, "技能 id 不是合法 GAS 标签：%s" % skill.id)


func validate_soul_vocabulary(mod: ModInfo, soul: SoulData) -> void:
	for type in soul.types:
		if not _is_soul_type(type):
			_report_error.call(mod, "魂灵 %s 的类型应为 Soul.types.<PascalName>：%s" % [soul.content_id, type])
	for tag in soul.tags:
		if not _is_soul_tag(tag):
			_report_error.call(mod, "魂灵 %s 的标签应为 Soul.tags.<PascalName>：%s" % [soul.content_id, tag])
	var size_count := 0
	for tag in soul.tags:
		if SoulData.SIZE_TAGS.has(tag):
			size_count += 1
	if size_count != 1:
		_report_error.call(mod, "魂灵 %s 必须且只能带一个尺寸标签（Small/Medium/Large）：实际 %d 个" % [
			soul.content_id, size_count,
		])
	for trigger in soul.triggers:
		if trigger == null:
			continue
		if trigger.max_range < 0:
			_report_error.call(mod, "魂灵 %s 的触发器 max_range 不能为负：%d" % [soul.content_id, trigger.max_range])
		for type in trigger.required_soul_types:
			if not _is_soul_type(type):
				_report_error.call(mod, "魂灵 %s 的触发条件类型应为 Soul.types.<PascalName>：%s" % [soul.content_id, type])


func validate_monster_config(mod: ModInfo, monster: MonsterData) -> void:
	if monster.display_name.is_empty():
		_report_error.call(mod, "怪物 %s 缺少 display_name" % monster.content_id)
	if monster.health_per_level <= 0.0:
		_report_error.call(mod, "怪物 %s 的 health_per_level 必须大于 0：%s" % [monster.content_id, monster.health_per_level])
	if monster.attack_range < 0.0:
		_report_error.call(mod, "怪物 %s 的 attack_range 不能为负：%s" % [monster.content_id, monster.attack_range])
	if monster.move_speed < 0.0:
		_report_error.call(mod, "怪物 %s 的 move_speed 不能为负：%s" % [monster.content_id, monster.move_speed])
	if monster.spawn_distances.is_empty():
		_report_error.call(mod, "怪物 %s 的 spawn_distances 不能为空" % monster.content_id)
	for distance in monster.spawn_distances:
		if distance < 1:
			_report_error.call(mod, "怪物 %s 的刷新距离必须 >= 1：%d" % [monster.content_id, distance])
	if monster.mesh_3d == null:
		_report_error.call(mod, "怪物 %s 缺少 mesh_3d" % monster.content_id)


func validate_vessel_config(mod: ModInfo, vessel: SoulVesselData) -> void:
	if vessel.category != "VESSEL":
		_report_error.call(mod, "魂器 %s 的 category 应为 VESSEL：%s" % [vessel.content_id, vessel.category])
	if vessel.columns <= 0 or vessel.rows <= 0:
		_report_error.call(mod, "魂器 %s 的物品占格必须大于 0：%dx%d" % [vessel.content_id, vessel.columns, vessel.rows])
	if vessel.container_columns <= 0 or vessel.container_rows <= 0:
		_report_error.call(mod, "魂器 %s 的容器尺寸必须大于 0：%dx%d" % [
			vessel.content_id, vessel.container_columns, vessel.container_rows
		])
	if vessel.vessel_kind != "COMBAT" and vessel.vessel_kind != "TOOL":
		_report_error.call(mod, "魂器 %s 的类型应为 COMBAT / TOOL：%s" % [vessel.content_id, vessel.vessel_kind])
	if vessel.tooltip_blocks.is_empty():
		_report_error.call(mod, "魂器 %s 缺少 tooltip_blocks" % vessel.content_id)
	for effect in vessel.effects:
		if effect == null:
			_report_error.call(mod, "魂器 %s 的效果列表里有空项" % vessel.content_id)
			continue
		if effect.stat == SoulVesselEffect.Stat.DAMAGE_BONUS and effect.value < 0.0:
			_report_error.call(mod, "魂器 %s 的伤害加成不能为负：%s" % [vessel.content_id, effect.value])


func _is_soul_type(value: StringName) -> bool:
	var text := String(value)
	return text.begins_with("Soul.types.") and CONTENT_NAMING.is_valid_tag(text.trim_prefix("Soul.types."))


func _is_soul_tag(value: StringName) -> bool:
	var text := String(value)
	return text.begins_with("Soul.tags.") and CONTENT_NAMING.is_valid_tag(text.trim_prefix("Soul.tags."))


func validate_soul_tags(mod: ModInfo, soul: SoulData) -> void:
	var skill := soul.skill
	if skill != null:
		for tag in skill.cast_require_all_tags:
			_validate_tag(mod, tag, "", "魂灵 %s 的 cast_require_all_tags" % soul.content_id)
		for tag in skill.cast_block_tags:
			_validate_tag(mod, tag, "", "魂灵 %s 的 cast_block_tags" % soul.content_id)
		_validate_effects(mod, skill.self_effects, soul.content_id)
		for step in skill.steps:
			var unit_step := step as UnitSkillStep
			if unit_step != null:
				_validate_tag(mod, unit_step.hit_cue_tag, "Cue.", "魂灵 %s 的 hit_cue_tag" % soul.content_id)
				_validate_effects(mod, unit_step.effects, soul.content_id)
	if soul is PassiveSoulData:
		_validate_effects(mod, (soul as PassiveSoulData).passive_effects, soul.content_id)
	for trigger in soul.triggers:
		if trigger == null:
			continue
		_validate_tag(mod, trigger.event_tag, "Event.", "魂灵 %s 的 trigger.event_tag" % soul.content_id)
		_validate_effects(mod, trigger.effects, soul.content_id)


func validate_skill_steps(mod: ModInfo, soul: SoulData) -> void:
	var skill := soul.skill
	if skill == null:
		return
	if skill.steps.is_empty() and skill.self_effects.is_empty():
		_report_error.call(mod, "魂灵 %s 的技能没有任何步骤或自身效果" % soul.content_id)
		return
	for index in skill.steps.size():
		var step := skill.steps[index]
		var step_no := index + 1
		if step == null:
			_report_error.call(mod, "魂灵 %s 的第 %d 个技能步骤为空" % [soul.content_id, step_no])
			continue
		if step is UnitSkillStep:
			var unit_step := step as UnitSkillStep
			if unit_step.target_rule == null or not unit_step.target_rule is TargetRule:
				_report_error.call(mod, "魂灵 %s 的第 %d 步 target_rule 必须是 TargetRule（UNIT）" % [soul.content_id, step_no])
			elif unit_step.target_rule is TargetRule:
				var unit_rule := unit_step.target_rule as TargetRule
				if unit_rule.max_range < 0:
					_report_error.call(mod, "魂灵 %s 的第 %d 步 max_range 不能为负：%d" % [soul.content_id, step_no, unit_rule.max_range])
				if unit_rule.count < 0:
					_report_error.call(mod, "魂灵 %s 的第 %d 步 count 不能为负：%d" % [soul.content_id, step_no, unit_rule.count])
			if unit_step.effects.is_empty() and not unit_step.uses_projectile:
				_report_error.call(mod, "魂灵 %s 的第 %d 步没有任何效果" % [soul.content_id, step_no])
			if unit_step.status_magnitude < -1.0:
				_report_error.call(mod, "魂灵 %s 的第 %d 步 status_magnitude 不能小于 -1：%s" % [soul.content_id, step_no, unit_step.status_magnitude])
		elif step is SoulSkillStep:
			var soul_step := step as SoulSkillStep
			if soul_step.target_rule == null or not soul_step.target_rule is SoulTargetRule:
				_report_error.call(mod, "魂灵 %s 的第 %d 步 target_rule 必须是 SoulTargetRule（SOUL）" % [soul.content_id, step_no])
			elif soul_step.target_rule is SoulTargetRule:
				var soul_rule := soul_step.target_rule as SoulTargetRule
				if soul_rule.count < 0:
					_report_error.call(mod, "魂灵 %s 的第 %d 步 count 不能为负：%d" % [soul.content_id, step_no, soul_rule.count])
			if (
				soul_step.haste_duration <= 0.0
				and soul_step.slow_duration <= 0.0
				and soul_step.freeze_duration <= 0.0
				and soul_step.charge_duration <= 0.0
			):
				_report_error.call(mod, "魂灵 %s 的第 %d 步没有任何状态时长" % [soul.content_id, step_no])
		else:
			var step_path := ""
			if step.get_script() != null:
				step_path = step.get_script().resource_path
			_report_error.call(mod, "魂灵 %s 的第 %d 步类型未知：%s" % [soul.content_id, step_no, step_path])


func _validate_effects(mod: ModInfo, effects: Array[GameplayEffect], mod_owner: StringName) -> void:
	for effect in effects:
		if effect != null:
			_validate_effect_tags(mod, effect, mod_owner)


func _validate_effect_tags(mod: ModInfo, effect: GameplayEffect, mod_owner: StringName) -> void:
	var effect_id := effect.get_instance_id()
	if _validated_effect_ids.has(effect_id):
		return
	_validated_effect_ids[effect_id] = true

	for tag in effect.granted_tags:
		_validate_tag(mod, tag, "", "效果 %s 的 granted_tags" % mod_owner)
	for tag in effect.remove_effects_with_tags:
		_validate_tag(mod, tag, "", "效果 %s 的 remove_effects_with_tags" % mod_owner)
	for tag in effect.application_cue_tags:
		_validate_tag(mod, tag, "Cue.", "效果 %s 的 application_cue_tags" % mod_owner)
	for tag in effect.persistent_cue_tags:
		_validate_tag(mod, tag, "Cue.", "效果 %s 的 persistent_cue_tags" % mod_owner)
	for tag in effect.periodic_cue_tags:
		_validate_tag(mod, tag, "Cue.", "效果 %s 的 periodic_cue_tags" % mod_owner)
	for tag in effect.removal_cue_tags:
		_validate_tag(mod, tag, "Cue.", "效果 %s 的 removal_cue_tags" % mod_owner)
	for tag in effect.event_tags:
		_validate_tag(mod, tag, "Event.", "效果 %s 的 event_tags" % mod_owner)

	for execution in effect.executions:
		_validate_execution_fields(mod, execution, mod_owner)
		if execution is SoulDamageExecution:
			for type in (execution as SoulDamageExecution).matching_soul_types:
				if not _is_soul_type(type):
					_report_error.call(mod, "效果 %s 的 matching_soul_types 应为 Soul.types.<PascalName>：%s" % [mod_owner, type])
	for overflow in effect.overflow_effects:
		if overflow != null:
			_validate_effect_tags(mod, overflow, mod_owner)


func _validate_execution_fields(mod: ModInfo, execution: Variant, mod_owner: StringName) -> void:
	if execution is StatusApplyExecution:
		var status := execution as StatusApplyExecution
		if not StatusText.NAMES.has(status.attribute_name):
			_report_error.call(mod, "效果 %s 的 StatusApplyExecution.attribute_name 不合法：%s（应为 burn / poison / regen）" % [mod_owner, status.attribute_name])
		if status.base_amount < 0.0:
			_report_error.call(mod, "效果 %s 的 StatusApplyExecution.base_amount 不能为负：%s" % [mod_owner, status.base_amount])
	elif execution is PoisonDamageExecution:
		var poison := execution as PoisonDamageExecution
		_validate_damage_execution(mod, poison, mod_owner)
		if poison.poison_ratio < 0.0 or poison.poison_ratio > 1.0:
			_report_error.call(mod, "效果 %s 的 PoisonDamageExecution.poison_ratio 必须在 0～1：%s" % [mod_owner, poison.poison_ratio])
	elif execution is SoulDamageExecution:
		_validate_damage_execution(mod, execution as SoulDamageExecution, mod_owner)
	elif execution is HealExecution:
		var heal := execution as HealExecution
		if heal.base_heal < 0.0:
			_report_error.call(mod, "效果 %s 的 HealExecution.base_heal 不能为负：%s" % [mod_owner, heal.base_heal])
		if heal.cleanse_ratio < 0.0 or heal.cleanse_ratio > 1.0:
			_report_error.call(mod, "效果 %s 的 HealExecution.cleanse_ratio 必须在 0～1：%s" % [mod_owner, heal.cleanse_ratio])
	elif execution is ShieldExecution:
		var shield := execution as ShieldExecution
		if shield.base_shield < 0.0:
			_report_error.call(mod, "效果 %s 的 ShieldExecution.base_shield 不能为负：%s" % [mod_owner, shield.base_shield])


func _validate_damage_execution(mod: ModInfo, damage: SoulDamageExecution, mod_owner: StringName) -> void:
	if damage.base_damage < 0.0:
		_report_error.call(mod, "效果 %s 的伤害执行 base_damage 不能为负：%s" % [mod_owner, damage.base_damage])
	if damage.bonus_per_matching_soul < 0.0:
		_report_error.call(mod, "效果 %s 的伤害执行 bonus_per_matching_soul 不能为负：%s" % [mod_owner, damage.bonus_per_matching_soul])


func _validate_tag(mod: ModInfo, tag: StringName, required_prefix: String, context: String) -> void:
	if tag.is_empty():
		return
	var text := String(tag)
	if not CONTENT_NAMING.is_valid_tag(text):
		_report_error.call(mod, "%s 不是合法 GAS 标签：%s" % [context, text])
		return
	if not required_prefix.is_empty() and not text.begins_with(required_prefix):
		_report_error.call(mod, "%s 应以 %s 开头：%s" % [context, required_prefix, text])


func validate_overrides(mod: ModInfo) -> void:
	for raw_path in mod.manifest.overrides:
		var path := raw_path.simplify_path()
		if not path.begins_with("res://"):
			_report_error.call(mod, "override 必须是 res:// 路径：%s" % raw_path)
			continue
		if _is_protected_override(path):
			_report_error.call(mod, "不允许覆盖受保护路径：%s" % path)
			continue
		if not ResourceLoader.exists(path):
			_report_error.call(mod, "override 目标不存在：%s" % path)
			continue
		if _overrides.has(path) and _overrides[path] != mod.id:
			_report_error.call(mod, "override 路径已被 %s 覆盖：%s" % [_overrides[path], path])
		_overrides[path] = mod.id


func _is_protected_override(path: String) -> bool:
	if path == "res://project.godot":
		return true
	if path.begins_with("res://.godot/"):
		return true
	if path.begins_with("res://scripts/mod/"):
		return true
	if path.begins_with(MOD_PATHS.BUILTIN_MODS_DIR + "/") and path.ends_with("/mod.json"):
		return true
	return false


func _cue_tag_prefix(mod: ModInfo) -> String:
	return "Cue.Mod.%s." % CONTENT_NAMING.to_pascal(String(mod.id))


