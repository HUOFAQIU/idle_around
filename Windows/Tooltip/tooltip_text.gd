class_name TooltipText
extends RefCounted
## Tooltip 正文共用的数字 / 颜色 / BBCode 工具。
##
## SoulTooltip 和 VesselTooltip 都走这里，避免两套着色规则漂移。
## 分隔线暗色；冷却行放大；暴击率整行暴击色；其余行只给状态词上色。

const SEPARATOR : String = "==================================="
const SEPARATOR_COLOR : String = "#4a4f58"
const COOLDOWN_FONT_SIZE : int = 20
const EMPTY_TEXT : String = "无"

static var _keyword_regex : RegEx


## 4.0 → "4"，4.5 → "4.5"
static func format_number(value: float) -> String:
	if is_zero_approx(value):
		return "0"
	var text := String.num(value, 2)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text


## 给正文上色：分隔线暗色、冷却行放大、暴击率整行暴击色，其余行只给状态词上色。
static func colorize(text: String) -> String:
	var result := PackedStringArray()
	for line in text.split("\n"):
		var escaped := escape_bbcode(line)
		if is_separator_line(line):
			result.append("[color=%s]%s[/color]" % [SEPARATOR_COLOR, escaped])
		elif is_cooldown_line(line):
			result.append(
				"[font_size=%d]%s[/font_size]"
				% [COOLDOWN_FONT_SIZE, colorize_keywords(escaped)]
			)
		elif line.begins_with("暴击率"):
			result.append("[color=%s]%s[/color]" % [GameColors.CRIT, escaped])
		else:
			result.append(colorize_keywords(escaped))
	return "\n".join(result)


## 固定分隔线，或带容器尺寸的 ==[ 6 ][ 2 ]===... 分隔线
static func is_separator_line(line: String) -> bool:
	return line == SEPARATOR or line.begins_with("==[")


## 冷却行形如 ( 6 秒 )；只对这种行放大字号
static func is_cooldown_line(line: String) -> bool:
	return line.begins_with("(") and line.ends_with("秒 )")


## 转义方括号，避免 [ 狼 ] 被 RichTextLabel 当成 BBCode 标签；
## 用占位符分两步替换，防止 [lb] 自己的方括号被第二轮再次替换。
static func escape_bbcode(text: String) -> String:
	const OPEN_PLACEHOLDER : String = "\u0001"
	const CLOSE_PLACEHOLDER : String = "\u0002"
	var escaped := text.replace("[", OPEN_PLACEHOLDER).replace("]", CLOSE_PLACEHOLDER)
	return escaped.replace(OPEN_PLACEHOLDER, "[lb]").replace(CLOSE_PLACEHOLDER, "[rb]")


## 给已转义的一行套上状态词颜色
static func colorize_keywords(escaped: String) -> String:
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
