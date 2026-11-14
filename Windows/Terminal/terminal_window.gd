class_name TerminalWindow
extends BaseWindow
## 游戏内终端窗口：内容区铺满 TerminalView，只负责显示。
##
## 输入与 ANSI 解析尚未接入；外部通过 TerminalView.write_line() 或
## TestAPI.terminal_write_line() 写入内容。

const WELCOME_TITLE: String = "IDLE AROUND // 终端"
const WELCOME_HINT: String = "渲染层已连接，输入与 ANSI 解析待接入。"

@onready var terminal: TerminalView = $TerminalView

## 欢迎信息只写一次；等 TerminalView 完成首次布局、buffer 建好后再写
var _welcomed: bool = false
## 窗口还没布局时先缓存内容，等 buffer 建好后一次性写入
var _pending_lines: PackedStringArray = PackedStringArray()
var _pending_style: TerminalStyle
var _has_pending_content: bool = false


func _ready() -> void:
	super()
	title = "终端"
	terminal.resized.connect(_try_write_welcome)
	_try_write_welcome()


## 显示用：替换终端内容；buffer 还没建好时先缓存
func set_content(lines: PackedStringArray, style: TerminalStyle = null) -> void:
	if terminal.buffer == null:
		_pending_lines = lines.duplicate()
		_pending_style = style.duplicate_style() if style != null else null
		_has_pending_content = true
		return
	_has_pending_content = false
	terminal.set_content(lines, style)


## 追加一行；buffer 还没建好时先缓存
func append_line(text: String, style: TerminalStyle = null) -> void:
	if terminal.buffer == null:
		_pending_lines.append(text)
		_pending_style = style.duplicate_style() if style != null else null
		_has_pending_content = true
		return
	terminal.append_line(text, style)


func _try_write_welcome() -> void:
	if _welcomed or terminal.buffer == null:
		return
	_welcomed = true
	if _has_pending_content:
		var lines := _pending_lines
		var style := _pending_style
		_pending_lines = PackedStringArray()
		_pending_style = null
		_has_pending_content = false
		terminal.set_content(lines, style)
		return
	var title_style := TerminalStyle.new()
	title_style.fg = TerminalPalette.color(10)
	title_style.bold = true
	terminal.write_line(WELCOME_TITLE, title_style)
	terminal.write_line(WELCOME_HINT)
	terminal.write_line("")
