class_name SoulTooltip
extends RefCounted

const COOLDOWN_PLACEHOLDER : String = "{cooldown}"
const CAST_TIMES_PLACEHOLDER : String = "{cast_times}"
const DAMAGE_PLACEHOLDER : String = "{damage}"
const DAMAGE_PER_SOUL_PLACEHOLDER : String = "{damage_per_soul}"


static func build(
	soul: SoulData,
	format: TooltipText.Format = TooltipText.Format.PLAIN,
	preview: SoulDamagePreview = null
) -> String:
	if soul == null:
		return TooltipText.EMPTY_TEXT

	var skill := soul.skill
	var damage := preview if preview != null else SoulDamagePreview.base_for(skill)
	var blocks := _collect_blocks(soul, skill, damage)
	if blocks.is_empty():
		blocks.append(TooltipText.EMPTY_TEXT)

	var lines := PackedStringArray()
	var header := _header_line(soul)
	if not header.is_empty():
		lines.append(header)
		lines.append("")
	lines.append("暴击率，%s %%" % TooltipText.format_number(_crit_chance(skill) * 100.0))
	lines.append("攻击距离，%d" % _attack_range(soul, skill))
	lines.append(TooltipText.SEPARATOR)
	for i in blocks.size():
		if i > 0:
			lines.append(TooltipText.SEPARATOR)
		lines.append(blocks[i])
	lines.append(TooltipText.SEPARATOR)
	var body := "\n".join(lines)
	return TooltipText.render(body, format)


static func _collect_blocks(
	soul: SoulData, skill: SkillDefinition, damage: SoulDamagePreview
) -> PackedStringArray:
	var blocks := PackedStringArray()
	var cooldown := _cooldown_text(skill)
	var cast_times := _cast_times_text(skill)
	var damage_text := _damage_text(damage)
	var per_soul_text := TooltipText.format_number(damage.bonus_per_matching_soul)
	for block in soul.tooltip_blocks:
		if block.is_empty():
			continue
		blocks.append(
			block
			.replace(COOLDOWN_PLACEHOLDER, cooldown)
			.replace(CAST_TIMES_PLACEHOLDER, cast_times)
			.replace(DAMAGE_PLACEHOLDER, damage_text)
			.replace(DAMAGE_PER_SOUL_PLACEHOLDER, per_soul_text)
		)
	return blocks


static func _damage_text(damage: SoulDamagePreview) -> String:
	if damage == null or not damage.has_damage:
		return "0"
	var text := TooltipText.format_number(damage.total())
	return "*%s" % text if damage.is_dynamic else text


static func _header_line(soul: SoulData) -> String:
	var labels := PackedStringArray()
	var size_tag := soul.size_tag()
	if not size_tag.is_empty():
		labels.append("[%s]" % SoulText.size_name(size_tag))
	for soul_type in soul.types:
		labels.append("[%s]" % SoulText.type_name(soul_type))
	return "".join(labels)


static func _attack_range(soul: SoulData, skill: SkillDefinition) -> int:
	var max_range := 0
	if skill == null:
		for trigger in soul.triggers:
			if trigger != null:
				max_range = maxi(max_range, trigger.max_range)
		return max_range
	for step in skill.steps:
		if step is UnitSkillStep:
			var unit_step := step as UnitSkillStep
			if unit_step.target_rule != null:
				max_range = maxi(max_range, unit_step.target_rule.max_range_cells())
	return max_range


static func _crit_chance(skill: SkillDefinition) -> float:
	return skill.crit_chance if skill != null else 0.0


static func _cooldown_text(skill: SkillDefinition) -> String:
	return TooltipText.format_number(skill.cooldown_seconds) if skill != null else "0"


static func _cast_times_text(skill: SkillDefinition) -> String:
	return str(maxi(skill.cast_times, 1)) if skill != null else "1"
