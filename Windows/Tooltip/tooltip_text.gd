class_name TooltipText
extends RefCounted
## Tooltip 正文共用的数字 / 颜色 / 文本格式化工具。
##
## SoulTooltip 和 VesselTooltip 都走这里，避免两套着色规则漂移。
## 正文先拆成带颜色和强调标记的 Run，再按渲染目标序列化：
## PLAIN 纯文本、BBCODE 给 RichTextLabel、ANSI 给 TerminalView.write_ansi()。
## 分隔线暗色；冷却行强调（BBCode 放大字号、终端粗体）；暴击率整行暴击色；
## 其余行只给状态词上色。

enum Format { PLAIN, BBCODE, ANSI }

const SEPARATOR : String = "==================================="
const SEPARATOR_COLOR : String = "#4a4f58"
const COOLDOWN_FONT_SIZE : int = 20
const EMPTY_TEXT : String = "无"
const CRIT_PREFIX : String = "暴击率"
const ANSI_BOLD : String = "\u001b[1m"
const ANSI_RESET : String = "\u001b[0m"

static var _keyword_regex : RegEx


## 4.0 → "4"，4.5 → "4.5"
static func format_number(value: float) -> String:
	if is_zero_approx(value):
		return "0"
	var text := String.num(value, 2)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text


## 按目标渲染器格式化；PLAIN 返回规范化后的纯文本
static func render(text: String, output_format: Format) -> String:
	var normalized := normalize_newlines(text)
	match output_format:
		Format.BBCODE:
			return to_bbcode(normalized)
		Format.ANSI:
			return to_ansi(normalized)
		_:
			return normalized


## 统一换行：Windows 下 .tres 可能读成 CRLF，终端会把 \r 当回车覆盖行首
static func normalize_newlines(text: String) -> String:
	return text.replace("\r\n", "\n").replace("\r", "")


## 转成 RichTextLabel 的 BBCode；方括号会转义成 [lb] / [rb]
static func to_bbcode(text: String) -> String:
	var parts := PackedStringArray()
	var emphasis_open := false
	for run in collect_runs(text):
		if run.emphasis != emphasis_open:
			if run.emphasis:
				parts.append("[font_size=%d]" % COOLDOWN_FONT_SIZE)
			else:
				parts.append("[/font_size]")
			emphasis_open = run.emphasis
		var escaped := escape_bbcode(run.text)
		if run.color.is_empty():
			parts.append(escaped)
		else:
			parts.append("[color=%s]%s[/color]" % [run.color, escaped])
	if emphasis_open:
		parts.append("[/font_size]")
	return "".join(parts)


## 转成终端 ANSI SGR；颜色用 truecolor，强调用粗体
static func to_ansi(text: String) -> String:
	var parts := PackedStringArray()
	for run in collect_runs(text):
		if run.color.is_empty() and not run.emphasis:
			parts.append(run.text)
			continue
		var codes := PackedStringArray()
		if run.emphasis:
			codes.append("1")
		if not run.color.is_empty():
			codes.append(_truecolor_code(run.color))
		parts.append("\u001b[%sm%s%s" % [",".join(codes), run.text, ANSI_RESET])
	return "".join(parts)


## 标题行 ANSI：终端没有字号，用粗体对应 TooltipWindow 的标题大字号
static func title_ansi(title: String) -> String:
	return "%s%s%s" % [ANSI_BOLD, title, ANSI_RESET]


## 把正文拆成最小样式片段；换行也作为独立 Run，序列化器原样输出
static func collect_runs(text: String) -> Array[Run]:
	var runs: Array[Run] = []
	var lines := normalize_newlines(text).split("\n")
	for i in lines.size():
		if i > 0:
			runs.append(Run.new("\n"))
		_append_line_runs(runs, lines[i])
	return runs


## 固定分隔线，或带容器尺寸的 ==[ 6 ][ 2 ]===... 分隔线
static func is_separator_line(line: String) -> bool:
	return line == SEPARATOR or line.begins_with("==[")


## 冷却行形如 ( 6 秒 )；只对这种行强调
static func is_cooldown_line(line: String) -> bool:
	return line.begins_with("(") and line.ends_with("秒 )")


## 转义方括号，避免 [ 狼 ] 被 RichTextLabel 当成 BBCode 标签；
## 用占位符分两步替换，防止 [lb] 自己的方括号被第二轮再次替换。
static func escape_bbcode(text: String) -> String:
	const OPEN_PLACEHOLDER : String = "\u0001"
	const CLOSE_PLACEHOLDER : String = "\u0002"
	var escaped := text.replace("[", OPEN_PLACEHOLDER).replace("]", CLOSE_PLACEHOLDER)
	return escaped.replace(OPEN_PLACEHOLDER, "[lb]").replace(CLOSE_PLACEHOLDER, "[rb]")


## 给一行生成样式片段：分隔线 / 冷却行 / 暴击率行 / 普通关键词行
static func _append_line_runs(runs: Array[Run], line: String) -> void:
	if is_separator_line(line):
		runs.append(Run.new(line, SEPARATOR_COLOR))
	elif is_cooldown_line(line):
		_append_keyword_runs(runs, line, true)
	elif line.begins_with(CRIT_PREFIX):
		runs.append(Run.new(line, GameColors.CRIT))
	else:
		_append_keyword_runs(runs, line, false)


## 按 GameColors.STATUS_PATTERN 把一行拆成普通片段和状态词片段
static func _append_keyword_runs(runs: Array[Run], line: String, emphasis: bool) -> void:
	var cursor := 0
	for found in _get_keyword_regex().search_all(line):
		if found.get_start() > cursor:
			runs.append(Run.new(line.substr(cursor, found.get_start() - cursor), "", emphasis))
		var word := found.get_string()
		runs.append(Run.new(word, GameColors.STATUS.get(word, GameColors.TEXT_PRIMARY), emphasis))
		cursor = found.get_end()
	if cursor < line.length():
		runs.append(Run.new(line.substr(cursor), "", emphasis))


## "#rrggbb" → ANSI truecolor 参数 "38;2;r;g;b"
static func _truecolor_code(hex: String) -> String:
	var color := GameColors.to_color(hex)
	return "38;2;%d;%d;%d" % [color.r8, color.g8, color.b8]


static func _get_keyword_regex() -> RegEx:
	if _keyword_regex == null:
		_keyword_regex = RegEx.new()
		_keyword_regex.compile(GameColors.STATUS_PATTERN)
	return _keyword_regex


## 一段同样式文本；color 为空表示默认前景色，emphasis 表示冷却行
class Run:
	var text: String
	var color: String
	var emphasis: bool

	func _init(run_text: String = "", run_color: String = "", is_emphasis: bool = false) -> void:
		text = run_text
		color = run_color
		emphasis = is_emphasis
