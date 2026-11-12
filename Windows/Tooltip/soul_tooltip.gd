class_name SoulTooltip
extends RefCounted
## 魂灵 tooltip 正文格式化器。
##
## 标题（魂灵名）由 TooltipWindow 用大字号单独显示，这里只生成正文：
## 类型行（尺寸 + 语义类型，可选）→ 暴击率 / 攻击距离 → SoulData.tooltip_blocks。
## 段落之间固定一条分隔线；( X 秒 ) 冷却行放大到 20 号（正文 16、标题 24）。
## {cooldown} 会替换成技能冷却，{cast_times} 会替换成多重触发次数；没有段落时正文为「无」。
## colored = true 时按 GameColors 全局色板给状态词上色，返回 BBCode。

const COOLDOWN_PLACEHOLDER : String = "{cooldown}"
const CAST_TIMES_PLACEHOLDER : String = "{cast_times}"


## 生成魂灵 tooltip 正文（不含魂灵名）
static func build(soul: SoulData, colored: bool = false) -> String:
	if soul == null:
		return TooltipText.EMPTY_TEXT

	var skill := soul.skill
	var blocks := _collect_blocks(soul, skill)
	if blocks.is_empty():
		blocks.append(TooltipText.EMPTY_TEXT)

	var lines := PackedStringArray()
	var header := _header_line(soul)
	if not header.is_empty():
		lines.append(header)
		lines.append("")
	lines.append("暴击率，%s %%" % TooltipText.format_number(_crit_chance(skill) * 100.0))
	lines.append("攻击距离，%d" % _attack_range(skill))
	lines.append(TooltipText.SEPARATOR)
	for i in blocks.size():
		if i > 0:
			lines.append(TooltipText.SEPARATOR)
		lines.append(blocks[i])
	var body := "\n".join(lines)
	return TooltipText.colorize(body) if colored else body


## 读取魂灵自身的 tooltip 段落，并替换 {cooldown} / {cast_times}
static func _collect_blocks(soul: SoulData, skill: SkillDefinition) -> PackedStringArray:
	var blocks := PackedStringArray()
	var cooldown := _cooldown_text(skill)
	var cast_times := _cast_times_text(skill)
	for block in soul.tooltip_blocks:
		if block.is_empty():
			continue
		blocks.append(
			block
			.replace(COOLDOWN_PLACEHOLDER, cooldown)
			.replace(CAST_TIMES_PLACEHOLDER, cast_times)
		)
	return blocks


## 类型行：尺寸标签排最前，再按 SoulData.types 的顺序显示语义类型。
## 中文名统一由 SoulText 提供；都没有时不显示这一行。
static func _header_line(soul: SoulData) -> String:
	var labels := PackedStringArray()
	var size_tag := soul.size_tag()
	if not size_tag.is_empty():
		labels.append("[ %s ]" % SoulText.size_name(size_tag))
	for soul_type in soul.types:
		labels.append("[ %s ]" % SoulText.type_name(soul_type))
	return "".join(labels)


## 攻击距离取所有单位步骤里的最大格数；魂灵步骤按 0 算
static func _attack_range(skill: SkillDefinition) -> int:
	if skill == null:
		return 0
	var max_range := 0
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


## 多重触发次数；没有技能时按 1 显示
static func _cast_times_text(skill: SkillDefinition) -> String:
	return str(maxi(skill.cast_times, 1)) if skill != null else "1"
