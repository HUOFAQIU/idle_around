class_name SoulTooltip
extends RefCounted
## 魂灵 tooltip 正文格式化器。
##
## 标题（魂灵名）由 TooltipWindow 用大字号单独显示，这里只生成正文：
## 类型行（尺寸 + 语义类型，可选）→ 暴击率 / 攻击距离 → SoulData.tooltip_blocks。
## 段落之间和最后一段之后各有一条分隔线；( X 秒 ) 冷却行放大到 20 号（正文 16、标题 24）。
## {cooldown} / {cast_times} 来自技能；{damage} / {damage_per_soul} 来自直接伤害执行。
## 传入 preview 且带当前装备上下文时，{damage} 前面加 * 表示会随当前装备变化。
## 没有段落时正文为「无」；format 决定输出纯文本、BBCode 还是终端 ANSI。

const COOLDOWN_PLACEHOLDER : String = "{cooldown}"
const CAST_TIMES_PLACEHOLDER : String = "{cast_times}"
const DAMAGE_PLACEHOLDER : String = "{damage}"
const DAMAGE_PER_SOUL_PLACEHOLDER : String = "{damage_per_soul}"


## 生成魂灵 tooltip 正文（不含魂灵名）
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
	lines.append("攻击距离，%d" % _attack_range(skill))
	lines.append(TooltipText.SEPARATOR)
	for i in blocks.size():
		if i > 0:
			lines.append(TooltipText.SEPARATOR)
		lines.append(blocks[i])
	lines.append(TooltipText.SEPARATOR)
	var body := "\n".join(lines)
	return TooltipText.render(body, format)


## 读取魂灵自身的 tooltip 段落，并替换所有静态/运行期数值占位符
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


## 伤害数值；只有带当前装备上下文时才加 *，表示会随当前装备变化
static func _damage_text(damage: SoulDamagePreview) -> String:
	if damage == null or not damage.has_damage:
		return "0"
	var text := TooltipText.format_number(damage.total())
	return "*%s" % text if damage.is_dynamic else text


## 类型行：尺寸标签排最前，再按 SoulData.types 的顺序显示语义类型。
## 中文名统一由 SoulText 提供；都没有时不显示这一行。
static func _header_line(soul: SoulData) -> String:
	var labels := PackedStringArray()
	var size_tag := soul.size_tag()
	if not size_tag.is_empty():
		labels.append("[%s]" % SoulText.size_name(size_tag))
	for soul_type in soul.types:
		labels.append("[%s]" % SoulText.type_name(soul_type))
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
