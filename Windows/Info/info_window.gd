class_name InfoWindow
extends BaseWindow

const MAX_LOG_LINES: int = 500

static var instance : InfoWindow

var _lines : PackedStringArray = PackedStringArray()
var _colors : PackedColorArray = PackedColorArray()
var _needs_rebuild : bool = true

@onready var log_terminal : TerminalView = $LogPanel/LogTerminal


func _ready() -> void:
	super()
	instance = self
	title = "战斗信息"
	log_terminal.scrollback_lines = MAX_LOG_LINES
	log_terminal.resized.connect(_on_terminal_resized)
	visibility_changed.connect(_on_visibility_changed)


func append_line(line: String, color: String = "white") -> void:
	var fg := Color.from_string(color, Color.WHITE)
	_lines.append(line)
	_colors.append(fg)
	while _lines.size() > MAX_LOG_LINES:
		_lines.remove_at(0)
		_colors.remove_at(0)
	if not _can_render():
		_needs_rebuild = true
		return
	if _needs_rebuild:
		_rebuild_log()
	else:
		_write_line(line, fg)


func clear_log() -> void:
	_lines.clear()
	_colors.clear()
	_needs_rebuild = false
	if log_terminal.buffer != null:
		log_terminal.clear()


func get_log_text() -> String:
	if _lines.is_empty():
		return ""
	return "\n".join(_lines) + "\n"


func toggle() -> void:
	if visible:
		hide()
		return
	_needs_rebuild = true
	open_window()
	if _needs_rebuild:
		_rebuild_log()


func _on_terminal_resized() -> void:
	if _needs_rebuild:
		_rebuild_log()


func _on_visibility_changed() -> void:
	if visible and _needs_rebuild:
		_rebuild_log()


func _can_render() -> bool:
	return visible and log_terminal.buffer != null


func _rebuild_log() -> void:
	if not _can_render():
		return
	var ansi_lines := PackedStringArray()
	for i in _lines.size():
		ansi_lines.append(_ansi_line(_lines[i], _colors[i]))
	log_terminal.set_ansi_content(ansi_lines)
	_needs_rebuild = false


func _write_line(text: String, color: Color) -> void:
	var style := TerminalStyle.new()
	style.fg = color
	log_terminal.write_line(text, style)


static func _ansi_line(text: String, color: Color) -> String:
	return "\u001b[38;2;%d;%d;%dm%s\u001b[0m" % [
		color.r8, color.g8, color.b8, text,
	]
