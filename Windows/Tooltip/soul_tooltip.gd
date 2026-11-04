class_name SoulTooltip
extends RefCounted
## 魂灵 tooltip 正文格式化器。
##
## 标题（魂灵名）由 TooltipWindow 用大字号单独显示，这里只生成正文：
## 类型行（可选）→ 暴击率 / 攻击距离 → SoulData.tooltip_blocks 的每个段落 → 部位行（可选）。
## 段落之间和部位行之前固定一条分隔线；分隔线用暗色。
## ( X 秒 ) 冷却行放大到 20 号（正文 16、标题 24）。
## {cooldown} 会替换成技能冷却；没有段落时正文为「无」。
## colored = true 时按 GameColors 全局色板给状态词上色，返回 BBCode。

const SEPARATOR : String = "==================================="
const SEPARATOR_COLOR : String = "#4a4f58"
const COOLDOWN_FONT_SIZE : int = 20
const EMPTY_TEXT : String = "无"
const COOLDOWN_PLACEHOLDER : String = "{cooldown}"

static var _keyword_regex : RegEx


## 生成魂灵 tooltip 正文（不含魂灵名）
static func build(soul: SoulData, colored: bool = false) -> String:
	if soul == null:
		return EMPTY_TEXT

	var skill := soul.skill
	var blocks := _collect_blocks(soul, skill)
	if blocks.is_empty():
		blocks.append(EMPTY_TEXT)

	var lines := PackedStringArray()
	var type_line := _type_line(soul)
	if not type_line.is_empty():
		lines.append(type_line)
		lines.append("")
	lines.append("暴击率，%s %%" % _format_number(_crit_chance(skill) * 100.0))
	lines.append("攻击距离，%d" % _attack_range(skill))
	lines.append(SEPARATOR)
	for i in blocks.size():
		if i > 0:
			lines.append(SEPARATOR)
		lines.append(blocks[i])
	var part_line := _part_line(soul)
	if not part_line.is_empty():
		lines.append(SEPARATOR)
		lines.append(part_line)
	var body := "\n".join(lines)
	return _colorize(body) if colored else body


## 读取魂灵自身的 tooltip 段落，并把 {cooldown} 替换成技能冷却
static func _collect_blocks(soul: SoulData, skill: SkillDefinition) -> PackedStringArray:
	var blocks := PackedStringArray()
	var cooldown := _cooldown_text(skill)
	for block in soul.tooltip_blocks:
		if block.is_empty():
			continue
		blocks.append(block.replace(COOLDOWN_PLACEHOLDER, cooldown))
	return blocks


## 类型行：按 SoulData.types 的顺序显示；中文名统一由 SoulText.type_name 提供
static func _type_line(soul: SoulData) -> String:
	var labels := PackedStringArray()
	for soul_type in soul.types:
		labels.append("[ %s ]" % SoulText.type_name(soul_type))
	return "".join(labels)


## 部位行：ANY 不显示，避免每颗魂灵都多一行「不限部位」
static func _part_line(soul: SoulData) -> String:
	if soul.equip_part.is_empty() or soul.equip_part == "ANY":
		return ""
	return "{ %s }" % SoulText.part_name(soul.equip_part)


## 攻击距离取目标规则的格数；非 TargetRule（如 SoulTargetRule）按 0 显示
static func _attack_range(skill: SkillDefinition) -> int:
	var rule: TargetRuleBase = skill.target_rule if skill != null else null
	if rule is TargetRule:
		return (rule as TargetRule).max_range
	return 0


static func _crit_chance(skill: SkillDefinition) -> float:
	return skill.crit_chance if skill != null else 0.0


static func _cooldown_text(skill: SkillDefinition) -> String:
	return _format_number(skill.cooldown_seconds) if skill != null else "0"


## 4.0 → "4"，4.5 → "4.5"
static func _format_number(value: float) -> String:
	if is_zero_approx(value):
		return "0"
	var text := String.num(value, 2)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text


## 给正文上色：分隔线暗色、冷却行放大、暴击率整行暴击色，其余行只给状态词上色。
static func _colorize(text: String) -> String:
	var lines := text.split("\n")
	var result := PackedStringArray()
	for line in lines:
		var escaped := _escape_bbcode(line)
		if line == SEPARATOR:
			result.append("[color=%s]%s[/color]" % [SEPARATOR_COLOR, escaped])
		elif _is_cooldown_line(line):
			result.append(
				"[font_size=%d]%s[/font_size]"
				% [COOLDOWN_FONT_SIZE, _colorize_keywords(escaped)]
			)
		elif line.begins_with("暴击率"):
			result.append("[color=%s]%s[/color]" % [GameColors.CRIT, escaped])
		else:
			result.append(_colorize_keywords(escaped))
	return "\n".join(result)


## 冷却行形如 ( 6 秒 )；只对这种行放大字号
static func _is_cooldown_line(line: String) -> bool:
	return line.begins_with("(") and line.ends_with("秒 )")


## 转义方括号，避免 [ 狼 ] 被 RichTextLabel 当成 BBCode 标签；
## 用占位符分两步替换，防止 [lb] 自己的方括号被第二轮再次替换。
static func _escape_bbcode(text: String) -> String:
	const OPEN_PLACEHOLDER : String = "\u0001"
	const CLOSE_PLACEHOLDER : String = "\u0002"
	var escaped := text.replace("[", OPEN_PLACEHOLDER).replace("]", CLOSE_PLACEHOLDER)
	return escaped.replace(OPEN_PLACEHOLDER, "[lb]").replace(CLOSE_PLACEHOLDER, "[rb]")


## 给已转义的一行套上状态词颜色
static func _colorize_keywords(escaped: String) -> String:
	var parts := PackedStringArray()
	var cursor := 0
	for found in _get_keyword_regex().search_all(escaped):
		if found.get_start() > cursor:
			parts.append(escaped.substr(cursor, found.get_start() - cursor))
		var word := found.get_string()
		parts.append("[color=%s]%s[/color]" % [GameColors.STATUS.get(word, GameColors.TEXT_PRIMARY), word])
		cursor = found.get_end()
	if cursor < escaped.length():
		parts.append(escaped.substr(cursor))
	return "".join(parts)


static func _get_keyword_regex() -> RegEx:
	if _keyword_regex == null:
		_keyword_regex = RegEx.new()
		_keyword_regex.compile(GameColors.STATUS_PATTERN)
	return _keyword_regex
