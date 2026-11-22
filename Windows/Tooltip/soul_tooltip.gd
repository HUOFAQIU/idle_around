class_name SoulTooltip
extends RefCounted

const COOLDOWN_PLACEHOLDER : String = "{cooldown}"
const CAST_TIMES_PLACEHOLDER : String = "{cast_times}"
const DAMAGE_PLACEHOLDER : String = "{damage}"
const DAMAGE_PER_SOUL_PLACEHOLDER : String = "{damage_per_soul}"
const EFFECT_DURATION_PLACEHOLDER : String = "{effect_duration}"


static func build(
	soul: SoulData,
	format: TooltipText.Format = TooltipText.Format.PLAIN,
	preview: SoulDamagePreview = null
) -> String:
	if soul == null:
		return TooltipText.EMPTY_TEXT

	var skill := soul.skill
	var damage := preview if preview != null else SoulDamagePreview.base_for(skill, soul)
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
	var emotions := _emotion_lines(soul)
	if not emotions.is_empty():
		lines.append(TooltipText.SEPARATOR)
		lines.append_array(emotions)
	lines.append(TooltipText.SEPARATOR)
	var body := "\n".join(lines)
	return TooltipText.render(body, format)


static func _collect_blocks(
	soul: SoulData, skill: SkillDefinition, damage: SoulDamagePreview
) -> PackedStringArray:
	var blocks := PackedStringArray()
	var cooldown := _cooldown_text(soul, skill)
	var cast_times := _cast_times_text(soul, skill)
	var damage_text := _damage_text(damage)
	var per_soul_text := TooltipText.format_number(damage.bonus_per_matching_soul)
	var effect_duration := _effect_duration_text(skill)
	for block in soul.tooltip_blocks:
		if block.is_empty():
			continue
		blocks.append(
			block
			.replace(COOLDOWN_PLACEHOLDER, cooldown)
			.replace(CAST_TIMES_PLACEHOLDER, cast_times)
			.replace(DAMAGE_PLACEHOLDER, damage_text)
			.replace(DAMAGE_PER_SOUL_PLACEHOLDER, per_soul_text)
			.replace(EFFECT_DURATION_PLACEHOLDER, effect_duration)
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


static func _effect_duration_text(skill: SkillDefinition) -> String:
	if skill == null:
		return "0"
	for step in skill.steps:
		if not step is UnitSkillStep:
			continue
		var unit_step := step as UnitSkillStep
		if unit_step.effect_duration > 0.0:
			return TooltipText.format_number(unit_step.effect_duration)
		for effect in unit_step.effects:
			if effect != null and effect.policy == GameplayEffect.DurationPolicy.DURATION:
				return TooltipText.format_number(effect.duration)
	return "0"


static func _crit_chance(skill: SkillDefinition) -> float:
	return skill.crit_chance if skill != null else 0.0


static func _cooldown_text(soul: SoulData, skill: SkillDefinition) -> String:
	var value := SoulEmotionValues.cooldown_seconds(soul)
	if value >= 0.0:
		return TooltipText.format_number(value)
	return TooltipText.format_number(skill.cooldown_seconds) if skill != null else "0"


static func _cast_times_text(soul: SoulData, skill: SkillDefinition) -> String:
	var value := SoulEmotionValues.cast_times(soul)
	if value > 0:
		return str(value)
	return str(maxi(skill.cast_times, 1)) if skill != null else "1"


static func _emotion_lines(soul: SoulData) -> PackedStringArray:
	var lines := PackedStringArray()
	var ids := SoulEmotion.ordered_ids(soul.emotions)
	if ids.is_empty():
		return lines
	var labels := PackedStringArray()
	var values := PackedStringArray()
	var label_columns := 0
	var value_columns := 0
	for id in ids:
		var label := SoulEmotion.display_name(id)
		if not SoulEmotionValues.is_effective(soul, id):
			label = TooltipText.DIM_PREFIX + label
		var value := "%d%%" % SoulEmotionValues.share(soul, id)
		labels.append(label)
		values.append(value)
		label_columns = maxi(label_columns, TerminalWidth.text_columns(label))
		value_columns = maxi(value_columns, TerminalWidth.text_columns(value))
	lines.append("情绪")
	for i in labels.size():
		var padding := (
			label_columns
			- TerminalWidth.text_columns(labels[i])
			+ 1
			+ value_columns
			- TerminalWidth.text_columns(values[i])
		)
		lines.append(labels[i] + " ".repeat(padding) + values[i])
	return lines
