class_name InfoWindow
extends BaseWindow

## 战斗日志最多保留这么多行，超出从顶部删，避免长时间挂机无限增长
const MAX_LOG_LINES: int = 500

## 全局唯一。战斗窗口左上角那颗 ☰ 就是开关它，别处要写信息直接 InfoWindow.instance
static var instance : InfoWindow

## 日志缓冲：窗口隐藏时也持续累积，打开时一次性重建到终端
var _lines : PackedStringArray = PackedStringArray()
var _colors : PackedColorArray = PackedColorArray()
## 终端还没有 buffer（窗口首次打开前）时，等布局完成再重建
var _needs_rebuild : bool = true

@onready var log_terminal : TerminalView = $LogPanel/LogTerminal


func _ready() -> void:
	super()
	instance = self
	title = "战斗信息"
	log_terminal.scrollback_lines = MAX_LOG_LINES
	log_terminal.resized.connect(_on_terminal_resized)
	visibility_changed.connect(_on_visibility_changed)


## 加一行信息（战斗日志走这儿）；超过上限时裁掉最旧的行。
## 窗口隐藏时只写缓冲，打开时重建；可见时直接追加到终端。
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


## 清空（每场战斗重开时用）
func clear_log() -> void:
	_lines.clear()
	_colors.clear()
	_needs_rebuild = false
	if log_terminal.buffer != null:
		log_terminal.clear()


## 当前日志纯文本；TestAPI 用
func get_log_text() -> String:
	if _lines.is_empty():
		return ""
	return "\n".join(_lines) + "\n"


## 开/关：开着就收起来，关着就按 open_position 打开（没配就居中）
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


## 用 ANSI 真彩色一次性重建全部缓冲行；窗口隐藏时不调用
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


## 和 Tooltip 的 ANSI 一样用 truecolor；战斗日志只需要逐行前景色
static func _ansi_line(text: String, color: Color) -> String:
	return "\u001b[38;2;%d;%d;%dm%s\u001b[0m" % [
		color.r8, color.g8, color.b8, text,
	]
