class_name TerminalView
extends Control

const FALLBACK_FONTS: Array[String] = [
	"Cascadia Mono", "Consolas", "JetBrains Mono", "DejaVu Sans Mono",
	"Liberation Mono", "Courier New", "monospace",
]
const CJK_FALLBACK_FONTS: Array[String] = [
	"Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC",
	"Source Han Sans SC", "Sarasa Mono SC", "PingFang SC", "SimHei",
]
const CURSOR_BLINK_INTERVAL: float = 0.5
const BOLD_EMBOLDEN: float = 0.6
const DEBUG_GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.05)

@export var font_size: int = 16
@export var font: Font
## 双宽字符字体；留空时自动按 CJK_FALLBACK_FONTS 找系统字体
@export var cjk_font: Font
@export var cursor_visible: bool = true
## 调试用：在字符格边界画网格线；正式显示保持关闭
@export var debug_grid: bool = false
## 不画终端自己的背景，露出父级面板底色；嵌在 Tooltip 等面板里时使用
@export var transparent_background: bool = false
## 回看历史上限（行）；0 表示不保留历史
@export var scrollback_lines: int = 1000

static var _shared_font: Font
static var _shared_cjk_font: Font

var buffer: TerminalBuffer
var view_offset: int = 0
var auto_scroll: bool = true

var _cell_size: Vector2 = Vector2(8.0, 16.0)
var _ascent: float = 0.0
var _bold_font: FontVariation
var _bold_cjk_font: FontVariation
var _ansi_parser: TerminalAnsiParser
var _cursor_on: bool = true
var _blink_timer: Timer
var _span_renderer := TerminalSpanRenderer.new()


func _ready() -> void:
	clip_contents = true
	_ensure_font()
	_refresh_metrics()
	if cursor_visible:
		_blink_timer = Timer.new()
		_blink_timer.wait_time = CURSOR_BLINK_INTERVAL
		_blink_timer.autostart = true
		_blink_timer.timeout.connect(_on_blink_timeout)
		add_child(_blink_timer)
	resized.connect(_sync_grid_to_size)
	_sync_grid_to_size()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_by(3)
		accept_event()
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_by(-3)
		accept_event()


func write_text(text: String, style: TerminalStyle = null) -> void:
	if buffer == null:
		return
	var history_before := _history_pushed()
	buffer.write_text(text, style)
	_after_write(history_before)


func write_line(text: String, style: TerminalStyle = null) -> void:
	if buffer == null:
		return
	var history_before := _history_pushed()
	buffer.write_line(text, style)
	_after_write(history_before)


func write_ansi(text: String) -> void:
	if buffer == null:
		return
	if _ansi_parser == null:
		_ansi_parser = TerminalAnsiParser.new()
	var history_before := _history_pushed()
	_ansi_parser.write(buffer, text)
	_after_write(history_before)


func write_ansi_line(text: String) -> void:
	write_ansi(text + "\n")


func set_content(
	lines: PackedStringArray, style: TerminalStyle = null, start_row: int = 0
) -> void:
	if buffer == null:
		return
	buffer.clear()
	reset_ansi()
	clear_spans()
	var text := "\n".join(lines)
	if not text.is_empty():
		buffer.cursor_row = clampi(start_row, 0, buffer.rows - 1)
		buffer.cursor_col = 0
		buffer.write_text(text, style)
	view_offset = 0
	auto_scroll = true
	_restart_cursor_blink()
	queue_redraw()


func set_ansi_content(lines: PackedStringArray, start_row: int = 0) -> void:
	if buffer == null:
		return
	buffer.clear()
	reset_ansi()
	clear_spans()
	var text := "\n".join(lines)
	if not text.is_empty():
		buffer.cursor_row = clampi(start_row, 0, buffer.rows - 1)
		buffer.cursor_col = 0
		if _ansi_parser == null:
			_ansi_parser = TerminalAnsiParser.new()
		_ansi_parser.write(buffer, text)
	view_offset = 0
	auto_scroll = true
	_restart_cursor_blink()
	queue_redraw()


func append_line(text: String, style: TerminalStyle = null) -> void:
	write_line(text, style)


func append_ansi_line(text: String) -> void:
	write_ansi_line(text)


func scroll_to_bottom() -> void:
	view_offset = 0
	auto_scroll = true
	queue_redraw()


func scroll_by(lines: int) -> void:
	if buffer == null:
		return
	var history := buffer.get_history()
	var target := clampi(view_offset + lines, 0, history.count)
	if target == view_offset:
		return
	view_offset = target
	auto_scroll = target == 0
	queue_redraw()


func set_auto_scroll(enabled: bool) -> void:
	if enabled:
		scroll_to_bottom()
	else:
		auto_scroll = false


func is_at_bottom() -> bool:
	return view_offset == 0


func get_scrollback_count() -> int:
	if buffer == null:
		return 0
	return buffer.get_history().count


func reset_ansi() -> void:
	if _ansi_parser != null:
		_ansi_parser.reset()


func clear() -> void:
	if buffer == null:
		return
	buffer.clear()
	reset_ansi()
	clear_spans()
	view_offset = 0
	auto_scroll = true
	_restart_cursor_blink()
	queue_redraw()


func set_debug_grid(enabled: bool) -> void:
	if debug_grid == enabled:
		return
	debug_grid = enabled
	queue_redraw()


func set_spans(spans: Array[TerminalSpan]) -> void:
	_ensure_font()
	_refresh_metrics()
	_span_renderer.set_spans(spans, font, cjk_font, font_size, _cell_size, _pick_font)
	queue_redraw()


func clear_spans() -> void:
	_span_renderer.clear()
	queue_redraw()


func get_spans() -> Array[TerminalSpan]:
	return _span_renderer.get_spans()


func get_span_rects() -> Array[Rect2i]:
	return _span_renderer.get_rects()


func measure_span(text: String, rows: int = 2, style: TerminalStyle = null) -> Vector2i:
	_ensure_font()
	_refresh_metrics()
	return _span_renderer.measure_span(
		text, rows, style, font, cjk_font, font_size, _cell_size, _pick_font
	)


func fit_text(text: String, reserved_rows: int = 0, min_cols: int = 1) -> Vector2i:
	_ensure_font()
	_refresh_metrics()
	var normalized := text.replace("\r\n", "\n").replace("\r", "")
	var cols := maxi(min_cols, 1)
	var body_rows := 0
	if not normalized.is_empty():
		var lines := normalized.split("\n")
		body_rows = maxi(lines.size(), 1)
		for line in lines:
			var width := 0
			for i in line.length():
				width += TerminalWidth.columns(line.unicode_at(i))
			cols = maxi(cols, width)
	var rows := maxi(reserved_rows + body_rows, 1)
	buffer = TerminalBuffer.new(cols, rows, scrollback_lines)
	clear_spans()
	view_offset = 0
	auto_scroll = true
	custom_minimum_size = Vector2(cols * _cell_size.x, rows * _cell_size.y)
	queue_redraw()
	return Vector2i(cols, rows)


func get_cell_size() -> Vector2:
	return _cell_size


func get_grid_size() -> Vector2i:
	if buffer == null:
		return Vector2i.ZERO
	return Vector2i(buffer.cols, buffer.rows)


func cell_at_local_position(local_position: Vector2) -> Vector2i:
	if buffer == null or _cell_size.x <= 0.0 or _cell_size.y <= 0.0:
		return Vector2i(-1, -1)
	var col := int(floor(local_position.x / _cell_size.x))
	var row := int(floor(local_position.y / _cell_size.y))
	if col < 0 or row < 0 or col >= buffer.cols or row >= buffer.rows:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


func _draw() -> void:
	if buffer == null:
		return
	if not transparent_background:
		draw_rect(Rect2(Vector2.ZERO, size), TerminalPalette.default_bg(), true)
	var cols := buffer.cols
	var rows := buffer.rows
	var history := buffer.get_history()
	_clamp_view_offset()
	var start := history.count - view_offset
	var hist_chars := history.get_chars()
	var hist_fg := history.get_fg_colors()
	var hist_bg := history.get_bg_colors()
	var hist_attrs := history.get_attrs()
	var screen_chars := buffer.get_chars()
	var screen_fg := buffer.get_fg_colors()
	var screen_bg := buffer.get_bg_colors()
	var screen_attrs := buffer.get_attrs()
	for row in rows:
		var combined := start + row
		if combined < history.count:
			var hist_base := history.get_row_base(combined)
			_draw_row_background(row, cols, hist_fg, hist_bg, hist_attrs, hist_base)
			_draw_row_glyphs(row, cols, hist_chars, hist_fg, hist_bg, hist_attrs, hist_base)
		else:
			var screen_row := combined - history.count
			if screen_row < 0 or screen_row >= rows:
				continue
			var screen_base := buffer.get_row_base(screen_row)
			_draw_row_background(row, cols, screen_fg, screen_bg, screen_attrs, screen_base)
			_draw_row_glyphs(row, cols, screen_chars, screen_fg, screen_bg, screen_attrs, screen_base)
	if view_offset == 0:
		_span_renderer.draw_spans(self, font, cjk_font, font_size, _cell_size, _pick_font)
		_draw_cursor(cols, rows, screen_chars, screen_fg, screen_bg, screen_attrs)
	if debug_grid:
		_draw_grid(cols, rows)


func _draw_row_background(
	view_row: int,
	cols: int,
	fg_colors: PackedColorArray,
	bg_colors: PackedColorArray,
	attrs: PackedByteArray,
	base: int
) -> void:
	var cell := _cell_size
	var default_bg := TerminalPalette.default_bg()
	var col := 0
	while col < cols:
		var bg := bg_colors[base + col]
		if (attrs[base + col] & TerminalBuffer.ATTR_REVERSE) != 0:
			bg = fg_colors[base + col]
		var run_start := col
		col += 1
		while col < cols:
			var next_bg := bg_colors[base + col]
			if (attrs[base + col] & TerminalBuffer.ATTR_REVERSE) != 0:
				next_bg = fg_colors[base + col]
			if next_bg != bg:
				break
			col += 1
		if bg != default_bg:
			draw_rect(
				Rect2(
					Vector2(run_start * cell.x, view_row * cell.y),
					Vector2((col - run_start) * cell.x, cell.y)
				),
				bg,
				true
			)


func _draw_row_glyphs(
	view_row: int,
	cols: int,
	chars: PackedInt32Array,
	fg_colors: PackedColorArray,
	bg_colors: PackedColorArray,
	attrs: PackedByteArray,
	base: int
) -> void:
	var cell := _cell_size
	for col in cols:
		if view_offset == 0 and not _span_renderer.is_empty() and _span_renderer.cell_in_span(view_row, col):
			continue
		var index := base + col
		var code := chars[index]
		if code <= 0 or code == TerminalBuffer.SPACE:
			continue
		var attr := attrs[index]
		var fg := fg_colors[index]
		if (attr & TerminalBuffer.ATTR_REVERSE) != 0:
			fg = bg_colors[index]
		var wide := (attr & TerminalBuffer.ATTR_WIDE) != 0
		var draw_font := _pick_font(code, wide, (attr & TerminalBuffer.ATTR_BOLD) != 0)
		var origin := _glyph_origin(col, view_row, code, wide, draw_font)
		draw_font.draw_char(get_canvas_item(), origin, code, font_size, fg)
		if (attr & TerminalBuffer.ATTR_UNDERLINE) != 0:
			draw_rect(
				Rect2(
					Vector2(col * cell.x, view_row * cell.y + cell.y - 1.0),
					Vector2(cell.x * (2.0 if wide else 1.0), 1.0)
				),
				fg,
				true
			)


func _draw_cursor(
	cols: int,
	rows: int,
	chars: PackedInt32Array,
	fg_colors: PackedColorArray,
	bg_colors: PackedColorArray,
	attrs: PackedByteArray
) -> void:
	if not cursor_visible or not _cursor_on:
		return
	var col := mini(buffer.cursor_col, cols - 1)
	var row := mini(buffer.cursor_row, rows - 1)
	var cell := _cell_size
	var index := buffer.get_row_base(row) + col
	var attr := attrs[index]
	var code := chars[index]
	var wide := (attr & TerminalBuffer.ATTR_WIDE) != 0 and code > 0
	var cursor_rect := Rect2i(col, row, 2 if wide else 1, 1)
	if _span_renderer.intersects_rect(cursor_rect):
		return
	var cursor_color := fg_colors[index]
	var text_color := bg_colors[index]
	if (attr & TerminalBuffer.ATTR_REVERSE) != 0:
		cursor_color = bg_colors[index]
		text_color = fg_colors[index]
	var rect := Rect2(
		Vector2(col * cell.x, row * cell.y),
		Vector2(cell.x * (2.0 if wide else 1.0), cell.y)
	)
	draw_rect(rect, cursor_color, true)
	if code <= 0 or code == TerminalBuffer.SPACE:
		return
	var draw_font := _pick_font(code, wide, (attr & TerminalBuffer.ATTR_BOLD) != 0)
	var origin := _glyph_origin(col, row, code, wide, draw_font)
	draw_font.draw_char(get_canvas_item(), origin, code, font_size, text_color)


func _draw_grid(cols: int, rows: int) -> void:
	var grid_width := cols * _cell_size.x
	var grid_height := rows * _cell_size.y
	var max_x := maxf(minf(grid_width, size.x - 1.0), 0.5)
	var max_y := maxf(minf(grid_height, size.y - 1.0), 0.5)
	for col in range(cols + 1):
		var x := clampf(col * _cell_size.x, 0.5, max_x)
		for segment in _vertical_grid_segments(col, max_y):
			draw_line(Vector2(x, segment.x), Vector2(x, segment.y), DEBUG_GRID_COLOR)
	for row in range(rows + 1):
		var y := clampf(row * _cell_size.y, 0.5, max_y)
		for segment in _horizontal_grid_segments(row, max_x):
			draw_line(Vector2(segment.x, y), Vector2(segment.y, y), DEBUG_GRID_COLOR)


func _vertical_grid_segments(col: int, max_y: float) -> Array[Vector2]:
	var segments: Array[Vector2] = [Vector2(0.0, max_y)]
	if view_offset != 0:
		return segments
	for rect in _span_renderer.span_rects:
		if col <= rect.position.x or col >= rect.end.x:
			continue
		segments = _subtract_interval(
			segments, rect.position.y * _cell_size.y, rect.end.y * _cell_size.y
		)
	return segments


func _horizontal_grid_segments(row: int, max_x: float) -> Array[Vector2]:
	var segments: Array[Vector2] = [Vector2(0.0, max_x)]
	if view_offset != 0:
		return segments
	for rect in _span_renderer.span_rects:
		if row <= rect.position.y or row >= rect.end.y:
			continue
		segments = _subtract_interval(
			segments, rect.position.x * _cell_size.x, rect.end.x * _cell_size.x
		)
	return segments


func _subtract_interval(
	segments: Array[Vector2], cut_start: float, cut_end: float
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for segment in segments:
		if cut_end <= segment.x or cut_start >= segment.y:
			result.append(segment)
			continue
		if cut_start > segment.x:
			result.append(Vector2(segment.x, cut_start))
		if cut_end < segment.y:
			result.append(Vector2(cut_end, segment.y))
	return result


func _pick_font(code: int, wide: bool, bold: bool) -> Font:
	if wide and cjk_font != null and cjk_font.has_char(code):
		if bold and _bold_cjk_font != null:
			return _bold_cjk_font
		return cjk_font
	if bold:
		return _bold_font
	return font


func _glyph_origin(col: int, row: int, code: int, wide: bool, draw_font: Font) -> Vector2:
	var x := col * _cell_size.x
	if wide:
		var glyph_width := draw_font.get_char_size(code, font_size).x
		if glyph_width > 0.0 and glyph_width < _cell_size.x * 2.0:
			x += (_cell_size.x * 2.0 - glyph_width) * 0.5
	return Vector2(x, row * _cell_size.y + _ascent)


func _ensure_font() -> void:
	if font == null:
		if _shared_font == null:
			var system_font := SystemFont.new()
			system_font.font_names = PackedStringArray(FALLBACK_FONTS)
			_shared_font = system_font
		font = _shared_font
	if cjk_font == null:
		if _shared_cjk_font == null:
			var cjk_system_font := SystemFont.new()
			cjk_system_font.font_names = PackedStringArray(CJK_FALLBACK_FONTS)
			_shared_cjk_font = cjk_system_font
		cjk_font = _shared_cjk_font


func _refresh_metrics() -> void:
	if font == null:
		return
	var char_width := font.get_char_size("M".unicode_at(0), font_size).x
	_cell_size.x = maxf(ceilf(char_width), 1.0)
	_cell_size.y = maxf(ceilf(font.get_height(font_size)), 1.0)
	_ascent = font.get_ascent(font_size)
	if _bold_font == null:
		_bold_font = FontVariation.new()
	_bold_font.base_font = font
	_bold_font.variation_embolden = BOLD_EMBOLDEN
	if cjk_font != null:
		if _bold_cjk_font == null:
			_bold_cjk_font = FontVariation.new()
		_bold_cjk_font.base_font = cjk_font
		_bold_cjk_font.variation_embolden = BOLD_EMBOLDEN
	_span_renderer.rebuild_rects(font, cjk_font, font_size, _cell_size, _pick_font)


func _sync_grid_to_size() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_refresh_metrics()
	var new_cols := maxi(int(floor(size.x / _cell_size.x)), 1)
	var new_rows := maxi(int(floor(size.y / _cell_size.y)), 1)
	if buffer == null:
		buffer = TerminalBuffer.new(new_cols, new_rows, scrollback_lines)
	else:
		buffer.resize(new_cols, new_rows)
	if auto_scroll:
		view_offset = 0
	else:
		view_offset = clampi(view_offset, 0, buffer.get_history().count)
	queue_redraw()


func _clamp_view_offset() -> void:
	if buffer == null:
		view_offset = 0
		return
	view_offset = clampi(view_offset, 0, buffer.get_history().count)


func _history_pushed() -> int:
	if buffer == null:
		return 0
	return buffer.get_history().pushed


func _after_write(history_before: int) -> void:
	if auto_scroll:
		view_offset = 0
	else:
		var history := buffer.get_history()
		var added := history.pushed - history_before
		if added > 0:
			view_offset = mini(view_offset + added, history.count)
	_restart_cursor_blink()
	queue_redraw()


func _restart_cursor_blink() -> void:
	if not cursor_visible:
		return
	_cursor_on = true
	if _blink_timer != null:
		_blink_timer.start()


func _on_blink_timeout() -> void:
	_cursor_on = not _cursor_on
	queue_redraw()
