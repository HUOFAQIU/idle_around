class_name SoulTooltip
extends RefCounted
## 魂灵 tooltip 正文格式化器。
##
## 标题（魂灵名）由 TooltipWindow 用大字号单独显示，这里只生成正文：
## 攻击距离 / 暴击率 → SoulData.tooltip_blocks 的每个段落，段落之间固定一条分隔线。
## {cooldown} 会替换成技能冷却；没有段落时正文为「无」。
## colored = true 时按 CombatColors 全局色板给状态词上色，返回 BBCode。

const SEPARATOR : String = "-----"
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
	lines.append("攻击距离，%d" % _attack_range(skill))
	lines.append("暴击率，%s %%" % _format_number(_crit_chance(skill) * 100.0))
	lines.append(SEPARATOR)
	for i in blocks.size():
		if i > 0:
			lines.append(SEPARATOR)
		lines.append(blocks[i])
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


## 给正文里的状态词套上战斗日志的颜色。
## 先转义方括号，避免 [ 4 ] 被 RichTextLabel 当成 BBCode 标签；
## 用占位符分两步替换，防止 [lb] 自己的方括号被第二轮再次替换。
static func _colorize(text: String) -> String:
	const OPEN_PLACEHOLDER : String = "\u0001"
	const CLOSE_PLACEHOLDER : String = "\u0002"
	var escaped := text.replace("[", OPEN_PLACEHOLDER).replace("]", CLOSE_PLACEHOLDER)
	escaped = escaped.replace(OPEN_PLACEHOLDER, "[lb]").replace(CLOSE_PLACEHOLDER, "[rb]")
	var parts := PackedStringArray()
	var cursor := 0
	for found in _get_keyword_regex().search_all(escaped):
		if found.get_start() > cursor:
			parts.append(escaped.substr(cursor, found.get_start() - cursor))
		var word := found.get_string()
		parts.append("[color=%s]%s[/color]" % [CombatColors.STATUS.get(word, "white"), word])
		cursor = found.get_end()
	if cursor < escaped.length():
		parts.append(escaped.substr(cursor))
	return "".join(parts)


static func _get_keyword_regex() -> RegEx:
	if _keyword_regex == null:
		_keyword_regex = RegEx.new()
		_keyword_regex.compile(CombatColors.STATUS_PATTERN)
	return _keyword_regex
