class_name TerminalWindow
extends BaseWindow
## 游戏内终端窗口：TerminalView 显示 + 底部命令输入。
##
## 输入走 CommandRegistry.run()，Tab 补全走 CommandRegistry.complete()，
## 和 AI 探针共用同一套命令；显示 API 仍可外部写入。

const COMMAND_REGISTRY: GDScript = preload("res://Scripts/commands/command_registry.gd")
const COMMAND_FORMATTER: GDScript = preload("res://Scripts/commands/command_formatter.gd")

const WELCOME_TITLE: String = "IDLE AROUND // 终端"
const WELCOME_HINT: String = "输入 help 查看调试命令；输入时自动提示，Tab 补全。"
const COMPLETION_GAP: float = 2.0

@onready var terminal: TerminalView = $Layout/TerminalView
@onready var input: LineEdit = $Layout/Input
@onready var completion: CompletionPanel = $CompletionPanel

## 欢迎信息只写一次；等 TerminalView 完成首次布局、buffer 建好后再写
var _welcomed: bool = false
## 窗口还没布局时先缓存内容，等 buffer 建好后一次性写入
var _pending_lines: PackedStringArray = PackedStringArray()
var _pending_style: TerminalStyle
var _has_pending_content: bool = false

var _history: PackedStringArray = PackedStringArray()
var _history_index: int = 0
## 历史/程序化改文本时不要自动弹补全
var _suppress_completion_refresh: bool = false
## 面板当前对应的 token 区间；接受前校验，避免光标移动后改错 token
var _completion_start: int = -1
var _completion_end: int = -1
var _ok_style: TerminalStyle
var _error_style: TerminalStyle
var _prompt_style: TerminalStyle


func _ready() -> void:
	super()
	title = "终端"
	_build_styles()
	_setup_input()
	_setup_completion()
	terminal.resized.connect(_try_write_welcome)
	_try_write_welcome()
	visibility_changed.connect(_on_visibility_changed)


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


## 提交一行命令；终端输入和探针测试共用
func submit_command(line: String) -> void:
	_hide_completion()
	var text := line.strip_edges()
	if text.is_empty():
		return
	_history.append(text)
	_history_index = _history.size()
	input.clear()
	terminal.write_line("> " + text, _prompt_style)
	if text == "clear":
		terminal.clear()
		return
	_write_result(COMMAND_REGISTRY.run(text))
	terminal.scroll_to_bottom()
	input.grab_focus()


func _build_styles() -> void:
	_ok_style = TerminalStyle.new()
	_ok_style.fg = TerminalPalette.color(10)
	_error_style = TerminalStyle.new()
	_error_style.fg = TerminalPalette.color(9)
	_prompt_style = TerminalStyle.new()
	_prompt_style.fg = TerminalPalette.color(6)


func _setup_input() -> void:
	input.text_submitted.connect(submit_command)
	input.gui_input.connect(_on_input_gui_input)
	input.keep_editing_on_text_submit = true
	input.add_theme_font_size_override("font_size", terminal.font_size)
	input.add_theme_color_override("font_color", TerminalPalette.default_fg())
	input.add_theme_color_override("font_placeholder_color", TerminalPalette.color(8))
	var normal := StyleBoxFlat.new()
	normal.bg_color = TerminalPalette.default_bg()
	normal.border_color = TerminalPalette.color(8)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(4)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = TerminalPalette.color(6)
	input.add_theme_stylebox_override("normal", normal)
	input.add_theme_stylebox_override("focus", focus)


func _setup_completion() -> void:
	completion.font = terminal.font
	completion.font_size = terminal.font_size
	completion.candidate_chosen.connect(_on_candidate_chosen)
	input.text_changed.connect(_on_input_text_changed)
	input.focus_exited.connect(_hide_completion)


func _write_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		var lines := String(result.get("error", "未知错误")).split("\n")
		for index in lines.size():
			var prefix := "ERR " if index == 0 else ""
			terminal.write_line(prefix + lines[index], _error_style)
		return
	var value: Variant = result.get("value", null)
	if value is String:
		for line in String(value).split("\n"):
			terminal.write_line(line)
		return
	if value == null:
		terminal.write_line("OK", _ok_style)
		return
	if value is bool or value is int or value is float:
		terminal.write_line("OK " + str(value), _ok_style)
		return
	terminal.write_line("OK", _ok_style)
	for line in COMMAND_FORMATTER.format(value):
		terminal.write_line(line)


func _on_input_gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed:
		# 点输入框会移动光标，旧候选的 token 区间不再可信
		_hide_completion()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT \
			or key.keycode == KEY_HOME or key.keycode == KEY_END:
		_hide_completion()
		return
	if key.keycode == KEY_TAB:
		_handle_tab()
		input.accept_event()
	elif key.keycode == KEY_UP:
		if completion.is_open():
			completion.move_selection(-1)
		else:
			_navigate_history(-1)
		input.accept_event()
	elif key.keycode == KEY_DOWN:
		if completion.is_open():
			completion.move_selection(1)
		else:
			_navigate_history(1)
		input.accept_event()
	elif key.keycode == KEY_ESCAPE and completion.is_open():
		_hide_completion()
		input.accept_event()


func _handle_tab() -> void:
	if completion.is_open():
		_accept_completion()
		return
	var result: Dictionary = COMMAND_REGISTRY.complete(input.text, input.caret_column)
	if not bool(result.get("ok", false)):
		return
	var candidates: PackedStringArray = result.get("candidates", PackedStringArray())
	if candidates.is_empty():
		return
	if candidates.size() == 1:
		_apply_completion(result, candidates[0])
		return
	var common: String = String(result.get("common_prefix", ""))
	var prefix: String = String(result.get("prefix", ""))
	if common.length() > prefix.length():
		_replace_token(result, common)
	var refreshed: Dictionary = COMMAND_REGISTRY.complete(input.text, input.caret_column)
	if not bool(refreshed.get("ok", false)):
		return
	_show_completion(refreshed)


func _show_completion(result: Dictionary) -> void:
	var candidates: PackedStringArray = result.get("candidates", PackedStringArray())
	if candidates.is_empty():
		_hide_completion()
		return
	_completion_start = int(result.get("start", -1))
	_completion_end = int(result.get("end", -1))
	completion.show_candidates(candidates, input.size.x, _completion_hint(result))
	_position_completion()
	completion.move_to_front()


func _position_completion() -> void:
	var parent := completion.get_parent() as Control
	if parent == null:
		return
	var input_top := parent.make_canvas_position_local(input.get_global_rect().position)
	var target_y: float = input_top.y - completion.size.y - COMPLETION_GAP
	completion.position = Vector2(input_top.x, maxf(target_y, 0.0))


func _accept_completion() -> void:
	var candidate: String = completion.selected_text()
	if candidate.is_empty():
		_hide_completion()
		return
	var result: Dictionary = COMMAND_REGISTRY.complete(input.text, input.caret_column)
	if not _can_accept(result, candidate):
		_hide_completion()
		return
	_apply_completion(result, candidate)


func _apply_completion(result: Dictionary, candidate: String) -> void:
	_hide_completion()
	var start := int(result.get("start", 0))
	var end := int(result.get("end", start))
	var text := input.text
	var tail := text.substr(end)
	var suffix := "" if not tail.is_empty() else " "
	_suppress_completion_refresh = true
	input.text = text.substr(0, start) + candidate + suffix + tail
	input.caret_column = start + candidate.length() + suffix.length()
	_suppress_completion_refresh = false
	_refresh_completion()


func _replace_token(result: Dictionary, replacement: String) -> void:
	var start := int(result.get("start", 0))
	var end := int(result.get("end", start))
	var text := input.text
	_suppress_completion_refresh = true
	input.text = text.substr(0, start) + replacement + text.substr(end)
	input.caret_column = start + replacement.length()
	_suppress_completion_refresh = false


func _on_candidate_chosen(candidate: String) -> void:
	var result: Dictionary = COMMAND_REGISTRY.complete(input.text, input.caret_column)
	if not _can_accept(result, candidate):
		_hide_completion()
		return
	_apply_completion(result, candidate)


func _on_input_text_changed(_new_text: String) -> void:
	if _suppress_completion_refresh:
		return
	_refresh_completion()


## 按当前文本和光标自动预览；空文本、无候选或唯一完整匹配时收起
func _refresh_completion() -> void:
	if input.text.is_empty():
		_hide_completion()
		return
	var result: Dictionary = COMMAND_REGISTRY.complete(input.text, input.caret_column)
	if not bool(result.get("ok", false)):
		_hide_completion()
		return
	var candidates: PackedStringArray = result.get("candidates", PackedStringArray())
	if candidates.is_empty() or _is_exact_single(result):
		_hide_completion()
		return
	_show_completion(result)


## 面板展示后光标可能被外部改走；token 区间或候选对不上就不接受
func _can_accept(result: Dictionary, candidate: String) -> bool:
	if not bool(result.get("ok", false)):
		return false
	if int(result.get("start", -1)) != _completion_start:
		return false
	if int(result.get("end", -1)) != _completion_end:
		return false
	var candidates: PackedStringArray = result.get("candidates", PackedStringArray())
	return candidates.has(candidate)


## 当前 token 已经完整命中唯一候选时不再自动弹，避免提示自己
func _is_exact_single(result: Dictionary) -> bool:
	var candidates: PackedStringArray = result.get("candidates", PackedStringArray())
	return candidates.size() == 1 and candidates[0] == String(result.get("prefix", ""))


func _completion_hint(result: Dictionary) -> String:
	var usage := String(result.get("usage", ""))
	var summary := String(result.get("summary", ""))
	if usage.is_empty():
		return summary
	if summary.is_empty():
		return usage
	return "%s — %s" % [usage, summary]


func _hide_completion() -> void:
	_completion_start = -1
	_completion_end = -1
	completion.hide_panel()


func _navigate_history(delta: int) -> void:
	if _history.is_empty():
		return
	_hide_completion()
	_history_index = clampi(_history_index + delta, 0, _history.size())
	_suppress_completion_refresh = true
	input.text = "" if _history_index == _history.size() else _history[_history_index]
	_suppress_completion_refresh = false
	input.caret_column = input.text.length()


func _on_visibility_changed() -> void:
	if visible:
		input.grab_focus()
	else:
		_hide_completion()


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
