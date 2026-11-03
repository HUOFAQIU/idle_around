class_name SoulTooltip
extends RefCounted
## 魂灵 tooltip 正文格式化器。
##
## 标题（魂灵名）由 TooltipWindow 用大字号单独显示，这里只生成正文：
## 攻击距离 / 暴击率 → 技能段 → 触发段，段与段之间固定一条分隔线。
## 技能段来自 SkillDefinition.tooltip_lines，触发段来自 PassiveTrigger.tooltip_text；
## 两段都没有时正文为「无」。

const SEPARATOR : String = "-----"
const EMPTY_TEXT : String = "无"


## 生成魂灵 tooltip 正文（不含魂灵名）
static func build(soul: SoulData) -> String:
	if soul == null:
		return EMPTY_TEXT

	var skill := soul.skill
	var blocks := _collect_blocks(soul, skill)
	if blocks.is_empty():
		blocks.append(EMPTY_TEXT)

	var lines := PackedStringArray()
	lines.append("攻击距离，%d" % _attack_range(skill))
	lines.append("暴击率，%s %%" % _format_number(_crit_chance(skill) * 100.0))
	lines.append(SEPARATOR)
	for i in blocks.size():
		if i > 0:
			lines.append(SEPARATOR)
		lines.append(blocks[i])
	return "\n".join(lines)


## 技能段 + 每条触发器的文案；顺序与 SoulData.triggers 一致
static func _collect_blocks(soul: SoulData, skill: SkillDefinition) -> PackedStringArray:
	var blocks := PackedStringArray()
	if skill != null:
		var skill_lines := PackedStringArray()
		for line in skill.tooltip_lines:
			if not line.is_empty():
				skill_lines.append("- " + line)
		if not skill_lines.is_empty():
			skill_lines.insert(0, "[ %s ]" % _format_number(skill.cooldown_seconds))
			blocks.append("\n".join(skill_lines))
	for trigger in soul.triggers:
		if trigger != null and not trigger.tooltip_text.is_empty():
			blocks.append(trigger.tooltip_text)
	return blocks


## 攻击距离取目标规则的格数；非 TargetRule（如 SoulTargetRule）按 0 显示
static func _attack_range(skill: SkillDefinition) -> int:
	var rule: TargetRuleBase = skill.target_rule if skill != null else null
	if rule is TargetRule:
		return (rule as TargetRule).max_range
	return 0


static func _crit_chance(skill: SkillDefinition) -> float:
	return skill.crit_chance if skill != null else 0.0


## 4.0 → "4"，4.5 → "4.5"
static func _format_number(value: float) -> String:
	if is_zero_approx(value):
		return "0"
	var text := String.num(value, 2)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text
