extends Control
## 字符网格的独立预览场景，按 F6 运行。
##
## 这里只做“看效果”的 demo：16 色、样式、光标、换行、滚动、resize。
## 网格线和悬停格子由 DebugOverlay 画在 TerminalView 之上，不进入正式渲染路径。

const TYPING_TEXT := (
	"The quick brown fox jumps over the lazy dog. "
	+ "Terminals are just grids of cells, and every keystroke eventually becomes bytes. "
	+ "Type enough text and the cursor wraps to the next row, then the grid scrolls "
	+ "when it reaches the bottom."
)
const TYPE_INTERVAL: float = 0.035
const PANEL_BG: String = "#141414"
const PANEL_BORDER: String = "#262626"

var _terminal: TerminalView
var _overlay: DebugOverlay
var _grid_info_label: Label
var _hover_label: Label
var _grid_toggle: CheckBox
var _typing_timer: Timer
var _typing_index: int = 0


func _ready() -> void:
	_prepare_preview_window()
	_build_ui()
	await get_tree().process_frame
	if _terminal.buffer == null:
		await get_tree().process_frame
	_write_sample()
	_update_grid_info()


## 预览用窗口：从项目的全屏透明外壳切成可缩放的普通窗口，方便看 resize
func _prepare_preview_window() -> void:
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.title = "Terminal Grid Preview"
	window.borderless = false
	window.unresizable = false
	window.transparent = false
	var screen_size := DisplayServer.screen_get_size()
	var target := Vector2i(mini(1100, screen_size.x), mini(720, screen_size.y))
	window.size = target
	window.position = (screen_size - target) / 2


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = TerminalPalette.default_bg()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root_box.add_child(header)

	var title := Label.new()
	title.text = "Terminal Grid Preview"
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_grid_info_label = Label.new()
	_grid_info_label.add_theme_font_size_override("font_size", 13)
	_grid_info_label.add_theme_color_override("font_color", TerminalPalette.color(8))
	header.add_child(_grid_info_label)

	_grid_toggle = CheckBox.new()
	_grid_toggle.text = "显示网格"
	_grid_toggle.button_pressed = true
	header.add_child(_grid_toggle)

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _make_frame_style())
	root_box.add_child(frame)

	_terminal = TerminalView.new()
	_terminal.font_size = 16
	_terminal.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(_terminal)

	_overlay = DebugOverlay.new()
	_overlay.terminal = _terminal
	_overlay.show_grid = _grid_toggle.button_pressed
	_terminal.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	root_box.add_child(footer)

	_hover_label = Label.new()
	_hover_label.text = "悬停格子：— · 滚轮回看历史"
	_hover_label.add_theme_font_size_override("font_size", 13)
	_hover_label.add_theme_color_override("font_color", TerminalPalette.color(8))
	_hover_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_hover_label)

	_add_button(footer, "写入样例", _write_sample)
	_add_button(footer, "打字演示", _start_typing_demo)
	_add_button(footer, "滚动测试", _run_scroll_test)
	_add_button(footer, "清空", _clear_terminal)
	_add_button(footer, "回到底部", _scroll_to_bottom)
	_add_button(footer, "退出预览", _quit_preview)

	_typing_timer = Timer.new()
	_typing_timer.wait_time = TYPE_INTERVAL
	_typing_timer.timeout.connect(_on_typing_tick)
	add_child(_typing_timer)

	_grid_toggle.toggled.connect(_on_grid_toggled)
	_overlay.hover_changed.connect(_on_hover_changed)
	_terminal.resized.connect(_update_grid_info)


func _write_sample() -> void:
	_stop_typing()
	_terminal.clear()
	var title_style := _make_style(10, true)
	var dim_style := _make_style(8)
	var normal_style := TerminalStyle.new()
	var border_style := _make_style(14)
	var prompt_style := _make_style(10, true)

	_terminal.write_line("IDLE AROUND // terminal grid preview", title_style)
	_terminal.write_line("")
	_terminal.write_line("中文双宽：终端字符网格", normal_style)
	_terminal.write_line("混合 mixed 中文 123 ABC", dim_style)
	var esc := String.chr(27)
	_terminal.write_ansi(
		"ANSI SGR: "
		+ esc + "[31mred" + esc + "[0m "
		+ esc + "[1;33mbold yellow" + esc + "[0m "
		+ esc + "[38;5;196m256 red" + esc + "[0m "
		+ esc + "[38;2;0;200;255mtruecolor" + esc + "[0m\n"
	)
	_terminal.write_line("")
	var grid := _terminal.get_grid_size()
	var cell := _terminal.get_cell_size()
	_terminal.write_line("grid  : %d x %d cells" % [grid.x, grid.y], dim_style)
	_terminal.write_line("cell  : %.0f x %.0f px" % [cell.x, cell.y], dim_style)
	_terminal.write_line("font  : system monospace, %d px" % _terminal.font_size, dim_style)
	_terminal.write_line("")
	_terminal.write_line("ANSI palette (16 colors):", normal_style)
	var swatch_style := TerminalStyle.new()
	for index in 16:
		swatch_style.bg = TerminalPalette.color(index)
		swatch_style.fg = swatch_style.bg
		_terminal.write_text("   ", swatch_style)
	_terminal.write_text("\n")
	for index in 16:
		_terminal.write_text("%2d " % index, dim_style)
	_terminal.write_text("\n\n")
	_write_box(border_style, normal_style)
	_terminal.write_text("\n")
	_terminal.write_text("bold ", _make_style(15, true))
	_terminal.write_text("underline ", _make_style(15, false, true))
	_terminal.write_text("reverse ", _make_style(15, false, false, true))
	_terminal.write_text("dim\n", dim_style)
	_terminal.write_text("INFO  ", _make_style(2, true))
	_terminal.write_text("battle started\n")
	_terminal.write_text("WARN  ", _make_style(3, true))
	_terminal.write_text("monster hp is low\n")
	_terminal.write_text("ERROR ", _make_style(1, true))
	_terminal.write_text("freeze effect not found\n")
	_terminal.write_text("\n")
	_terminal.write_text("> ", prompt_style)
	_terminal.write_text("cursor blink test")


func _write_box(border_style: TerminalStyle, text_style: TerminalStyle) -> void:
	var width := clampi(_terminal.get_grid_size().x - 8, 30, 72)
	var inner := width - 4
	var horizontal := "─".repeat(width - 2)
	_terminal.write_line("┌" + horizontal + "┐", border_style)
	var lines: Array[String] = [
		"TerminalBuffer: chars + fg + bg + attrs, one entry per cell.",
		"TerminalView: background runs first, then glyphs, cursor on top.",
		"Next: ANSI parser, keyboard input, selection, scrollback.",
	]
	for line in lines:
		var padded := line.left(inner).rpad(inner)
		_terminal.write_line("│ " + padded + " │", text_style)
	_terminal.write_line("└" + horizontal + "┘", border_style)


func _run_scroll_test() -> void:
	_stop_typing()
	_terminal.clear()
	var style := _make_style(10)
	for index in 40:
		_terminal.write_line("scroll test line %02d  ·  the grid should move up" % index, style)


func _start_typing_demo() -> void:
	_stop_typing()
	_terminal.clear()
	_terminal.write_text("> ", _make_style(10, true))
	_typing_index = 0
	_typing_timer.start()


func _clear_terminal() -> void:
	_stop_typing()
	_terminal.clear()


func _scroll_to_bottom() -> void:
	_terminal.scroll_to_bottom()


func _quit_preview() -> void:
	get_tree().quit()


func _stop_typing() -> void:
	if _typing_timer != null:
		_typing_timer.stop()
	_typing_index = 0


func _on_typing_tick() -> void:
	if _typing_index >= TYPING_TEXT.length():
		_typing_timer.stop()
		return
	_terminal.write_text(TYPING_TEXT.substr(_typing_index, 1))
	_typing_index += 1


func _on_grid_toggled(pressed: bool) -> void:
	_overlay.show_grid = pressed
	_overlay.queue_redraw()


func _on_hover_changed(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0:
		_hover_label.text = "悬停格子：—"
		return
	_hover_label.text = "悬停格子：行 %d / 列 %d" % [cell.y, cell.x]


func _update_grid_info() -> void:
	if _terminal == null:
		return
	var grid := _terminal.get_grid_size()
	var cell := _terminal.get_cell_size()
	_grid_info_label.text = "%d x %d cells · %.0f x %.0f px" % [grid.x, grid.y, cell.x, cell.y]


func _add_button(parent: HBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func _make_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(PANEL_BG)
	style.border_color = Color.html(PANEL_BORDER)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	return style


func _make_style(
	fg_index: int,
	bold: bool = false,
	underline: bool = false,
	reverse: bool = false
) -> TerminalStyle:
	var style := TerminalStyle.new()
	style.fg = TerminalPalette.color(fg_index)
	style.bold = bold
	style.underline = underline
	style.reverse = reverse
	return style


class DebugOverlay extends Control:
	signal hover_changed(cell: Vector2i)

	var terminal: TerminalView
	var show_grid: bool = true
	var hover_cell: Vector2i = Vector2i(-1, -1)


	func _ready() -> void:
		# PASS 让未处理的滚轮事件继续落到父级 TerminalView
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_exited.connect(_on_mouse_exited)
		if terminal != null:
			terminal.resized.connect(queue_redraw)


	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseMotion):
			return
		var motion := event as InputEventMouseMotion
		var cell := terminal.cell_at_local_position(motion.position)
		if cell == hover_cell:
			return
		hover_cell = cell
		hover_changed.emit(hover_cell)
		queue_redraw()


	func _draw() -> void:
		if terminal == null:
			return
		var cell := terminal.get_cell_size()
		var grid := terminal.get_grid_size()
		if show_grid:
			var line_color := Color(1.0, 1.0, 1.0, 0.06)
			for col in range(grid.x + 1):
				var x := col * cell.x
				draw_line(Vector2(x, 0.0), Vector2(x, grid.y * cell.y), line_color)
			for row in range(grid.y + 1):
				var y := row * cell.y
				draw_line(Vector2(0.0, y), Vector2(grid.x * cell.x, y), line_color)
		if hover_cell.x >= 0 and hover_cell.y >= 0:
			var hover_rect := Rect2(
				Vector2(hover_cell.x * cell.x, hover_cell.y * cell.y),
				cell
			)
			draw_rect(hover_rect, Color(0.13, 0.77, 0.37, 0.22), true)
			draw_rect(hover_rect, Color(0.13, 0.77, 0.37, 0.85), false, 1.0)


	func _on_mouse_exited() -> void:
		if hover_cell.x < 0 and hover_cell.y < 0:
			return
		hover_cell = Vector2i(-1, -1)
		hover_changed.emit(hover_cell)
		queue_redraw()
