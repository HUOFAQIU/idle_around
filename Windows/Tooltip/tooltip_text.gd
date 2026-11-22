class_name TooltipText
extends RefCounted

enum Format { PLAIN, BBCODE, ANSI }

const SEPARATOR : String = "==================================="
const SEPARATOR_COLOR : String = "#4a4f58"
const COOLDOWN_FONT_SIZE : int = 20
const EMPTY_TEXT : String = "无"
const CRIT_PREFIX : String = "暴击率"
const DIM_PREFIX : String = "· "
const ANSI_BOLD : String = "\u001b[1m"
const ANSI_RESET : String = "\u001b[0m"

static var _keyword_regex : RegEx


static func format_number(value: float) -> String:
	if is_zero_approx(value):
		return "0"
	var text := String.num(value, 2)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text


static func render(text: String, output_format: Format) -> String:
	var normalized := normalize_newlines(text)
	match output_format:
		Format.BBCODE:
			return to_bbcode(normalized)
		Format.ANSI:
			return to_ansi(normalized)
		_:
			return normalized


static func normalize_newlines(text: String) -> String:
	return text.replace("\r\n", "\n").replace("\r", "")


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


static func title_ansi(title: String) -> String:
	return "%s%s%s" % [ANSI_BOLD, title, ANSI_RESET]


static func collect_runs(text: String) -> Array[Run]:
	var runs: Array[Run] = []
	var lines := normalize_newlines(text).split("\n")
	for i in lines.size():
		if i > 0:
			runs.append(Run.new("\n"))
		_append_line_runs(runs, lines[i])
	return runs


static func is_separator_line(line: String) -> bool:
	return line == SEPARATOR or line.begins_with("==[")


static func is_cooldown_line(line: String) -> bool:
	return line.begins_with("(") and line.ends_with("秒 )")


static func escape_bbcode(text: String) -> String:
	const OPEN_PLACEHOLDER : String = "\u0001"
	const CLOSE_PLACEHOLDER : String = "\u0002"
	var escaped := text.replace("[", OPEN_PLACEHOLDER).replace("]", CLOSE_PLACEHOLDER)
	return escaped.replace(OPEN_PLACEHOLDER, "[lb]").replace(CLOSE_PLACEHOLDER, "[rb]")


static func _append_line_runs(runs: Array[Run], line: String) -> void:
	if is_separator_line(line):
		runs.append(Run.new(line, SEPARATOR_COLOR))
	elif is_cooldown_line(line):
		_append_keyword_runs(runs, line, true)
	elif line.begins_with(CRIT_PREFIX):
		runs.append(Run.new(line, GameColors.CRIT))
	elif line.begins_with(DIM_PREFIX):
		runs.append(Run.new(line, GameColors.TEXT_SECONDARY))
	else:
		_append_keyword_runs(runs, line, false)


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


static func _truecolor_code(hex: String) -> String:
	var color := GameColors.to_color(hex)
	return "38;2;%d;%d;%d" % [color.r8, color.g8, color.b8]


static func _get_keyword_regex() -> RegEx:
	if _keyword_regex == null:
		_keyword_regex = RegEx.new()
		_keyword_regex.compile(GameColors.STATUS_PATTERN)
	return _keyword_regex


class Run:
	var text: String
	var color: String
	var emphasis: bool

	func _init(run_text: String = "", run_color: String = "", is_emphasis: bool = false) -> void:
		text = run_text
		color = run_color
		emphasis = is_emphasis
