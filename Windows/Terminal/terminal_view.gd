class_name TerminalView
extends Control
## 字符网格渲染器：从 TerminalBuffer 读数据，用等宽字体逐格绘制。
##
## 只负责画：背景色块、字符、下划线、光标。输入 / ANSI 解析 / 选区不在这里。
## 尺寸变化时按当前 cell 尺寸重算行列；内容保留左上角。
## 双宽字符（Buffer 里带 ATTR_WIDE）用 cjk_font 画，占两个 cell。
## 第一版每次重绘整屏，80x24 的量级足够；后面需要时再按脏行裁剪。

## 字体为空时按这个顺序挑系统等宽字体
const FALLBACK_FONTS: Array[String] = [
	"Cascadia Mono", "Consolas", "JetBrains Mono", "DejaVu Sans Mono",
	"Liberation Mono", "Courier New", "monospace",
]
## 双宽字符的中文字体；找不到时退回 font
const CJK_FALLBACK_FONTS: Array[String] = [
	"Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC",
	"Source Han Sans SC", "Sarasa Mono SC", "PingFang SC", "SimHei",
]
const CURSOR_BLINK_INTERVAL: float = 0.5
const BOLD_EMBOLDEN: float = 0.6
## 调试网格线颜色；预览 overlay 和主终端共用
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

var buffer: TerminalBuffer
## 从底部往上回看的行数；0 = 实时屏幕
var view_offset: int = 0
## 新内容是否自动滚到底部
var auto_scroll: bool = true

var _cell_size: Vector2 = Vector2(8.0, 16.0)
var _ascent: float = 0.0
var _bold_font: FontVariation
var _bold_cjk_font: FontVariation
var _ansi_parser: TerminalAnsiParser
var _cursor_on: bool = true
var _blink_timer: Timer
## 跨格大字；Buffer 里对应格子只是占位，不参与文本绘制
var _spans: Array[TerminalSpan] = []
## 每个 span 实际覆盖的格子矩形，由 _rebuild_span_rects() 缓存
var _span_rects: Array[Rect2i] = []


func _ready() -> void:
	clip_contents = true
	_ensure_font()
	_refresh_metrics()
	_blink_timer = Timer.new()
	_blink_timer.wait_time = CURSOR_BLINK_INTERVAL
	_blink_timer.autostart = true
	_blink_timer.timeout.connect(_on_blink_timeout)
	add_child(_blink_timer)
	resized.connect(_sync_grid_to_size)
	_sync_grid_to_size()


## 鼠标滚轮：向上翻历史，向下回到底部
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


## 直接写文本；写完光标常亮并重新计时
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


## 按 ANSI 转义序列解析后写入；SGR 样式跨调用保持
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


## 显示用：整屏替换为若干纯文本行；历史一起清空，视图回到底部。
## start_row 用于给顶部跨格大字预留空行。
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


## 显示用：整屏替换为若干 ANSI 文本行；历史一起清空，视图回到底部。
## start_row 用于给顶部跨格大字预留空行。
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


## 滚回实时屏幕，并恢复自动滚底
func scroll_to_bottom() -> void:
	view_offset = 0
	auto_scroll = true
	queue_redraw()


## 正值往历史翻，负值往底部翻
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


## 关掉后新内容不会把视图拉回底部；重新打开会立即回到底部
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


## 重置 ANSI 样式和未完成的转义序列
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


## 开关调试网格；主终端和预览共用同一套绘制
func set_debug_grid(enabled: bool) -> void:
	if debug_grid == enabled:
		return
	debug_grid = enabled
	queue_redraw()


## 设置跨格大字；Buffer 里对应格子需要调用方自己留空。
## 修改 span 的 text / rows / col / row 后要重新调用本方法刷新尺寸。
func set_spans(spans: Array[TerminalSpan]) -> void:
	_ensure_font()
	_refresh_metrics()
	_spans.clear()
	for span in spans:
		if span != null and not span.text.is_empty():
			_spans.append(span)
	_rebuild_span_rects()
	queue_redraw()


func clear_spans() -> void:
	_spans.clear()
	_span_rects.clear()
	queue_redraw()


func get_spans() -> Array[TerminalSpan]:
	return _spans.duplicate()


## 跨格大字实际覆盖的格子矩形；调试/测试用
func get_span_rects() -> Array[Rect2i]:
	return _span_rects.duplicate()


## 计算一段文本作为跨格大字时占用的网格尺寸；换行按空格处理。
## rows 是块高，字号由 _span_font_size() 按字体行高反推。
func measure_span(text: String, rows: int = 2, style: TerminalStyle = null) -> Vector2i:
	_ensure_font()
	_refresh_metrics()
	var span_rows := maxi(rows, 1)
	var scaled_size := _span_font_size(span_rows)
	var columns := _measure_span_columns(_normalize_span_text(text), scaled_size, style)
	return Vector2i(maxi(columns, 1), span_rows)


## 按纯文本计算所需行列，设置最小尺寸并重建缓冲；返回网格尺寸。
## 供自动尺寸的 Tooltip 使用，传入的文本不要带 ANSI 转义。
## reserved_rows 是顶部留给跨格大字的空行数；min_cols 用来保证标题不被正文裁窄。
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


## 当前每格像素尺寸（调试 overlay 用）
func get_cell_size() -> Vector2:
	return _cell_size


## 当前行列数；还没有布局尺寸时返回零
func get_grid_size() -> Vector2i:
	if buffer == null:
		return Vector2i.ZERO
	return Vector2i(buffer.cols, buffer.rows)


## 本地坐标 → 格子坐标；超出范围返回 (-1, -1)
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
		_draw_spans()
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
		if view_offset == 0 and not _span_rects.is_empty() and _cell_in_span(view_row, col):
			continue
		var index := base + col
		var code := chars[index]
		# 空格、双宽字符的续格（-1）都不画字形
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
	for span_rect in _span_rects:
		if span_rect.intersects(cursor_rect):
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
	# 光标下的字符用反色再画一遍，否则会被色块盖住
	if code <= 0 or code == TerminalBuffer.SPACE:
		return
	var draw_font := _pick_font(code, wide, (attr & TerminalBuffer.ATTR_BOLD) != 0)
	var origin := _glyph_origin(col, row, code, wide, draw_font)
	draw_font.draw_char(get_canvas_item(), origin, code, font_size, text_color)


## 调试网格：只画格边界，不参与正式渲染。
## 最外圈线向内收 1px，否则会被 Control 的 clip_contents 裁掉，
## 看起来就像左上角没有格线、直接贴到面板边。
## 跨格大字内部的分隔线跳过，避免网格线切过大字。
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


## 竖线 col 被 span 内部切断后剩下的 y 区间
func _vertical_grid_segments(col: int, max_y: float) -> Array[Vector2]:
	var segments: Array[Vector2] = [Vector2(0.0, max_y)]
	if view_offset != 0:
		return segments
	for rect in _span_rects:
		if col <= rect.position.x or col >= rect.end.x:
			continue
		segments = _subtract_interval(
			segments, rect.position.y * _cell_size.y, rect.end.y * _cell_size.y
		)
	return segments


## 横线 row 被 span 内部切断后剩下的 x 区间
func _horizontal_grid_segments(row: int, max_x: float) -> Array[Vector2]:
	var segments: Array[Vector2] = [Vector2(0.0, max_x)]
	if view_offset != 0:
		return segments
	for rect in _span_rects:
		if row <= rect.position.y or row >= rect.end.y:
			continue
		segments = _subtract_interval(
			segments, rect.position.x * _cell_size.x, rect.end.x * _cell_size.x
		)
	return segments


## 从若干区间里挖掉 [cut_start, cut_end]
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


## 画跨格大字；对应的 Buffer 格子在 _draw_row_glyphs() 里已经跳过
func _draw_spans() -> void:
	for span in _spans:
		_draw_span(span)


func _draw_span(span: TerminalSpan) -> void:
	var text := _normalize_span_text(span.text)
	if text.is_empty():
		return
	var span_rows := maxi(span.rows, 1)
	var scaled_size := _span_font_size(span_rows)
	var block_x := span.col * _cell_size.x
	var block_y := span.row * _cell_size.y
	var block_height := span_rows * _cell_size.y
	var columns := _measure_span_columns(text, scaled_size, span.style)
	var block_width := columns * _cell_size.x
	var color := TerminalPalette.default_fg()
	var background := TerminalPalette.default_bg()
	var bold := false
	if span.style != null:
		color = span.style.fg
		background = span.style.bg
		bold = span.style.bold
		if span.style.reverse:
			var swap := color
			color = background
			background = swap
	if background != TerminalPalette.default_bg():
		draw_rect(
			Rect2(Vector2(block_x, block_y), Vector2(block_width, block_height)),
			background,
			true
		)
	var cursor_col := 0
	for i in text.length():
		var code := text.unicode_at(i)
		if code < 32:
			continue
		var wide := TerminalWidth.columns(code) == 2
		var draw_font := _pick_font(code, wide, bold)
		var advance := draw_font.get_char_size(code, scaled_size).x
		if advance <= 0.0:
			advance = _cell_size.x * (2.0 if wide else 1.0)
		var glyph_cols := maxi(ceili(advance / _cell_size.x), 1)
		if code != TerminalBuffer.SPACE:
			var x := block_x + cursor_col * _cell_size.x
			x += (glyph_cols * _cell_size.x - advance) * 0.5
			var line_height := draw_font.get_height(scaled_size)
			var top := block_y + maxf((block_height - line_height) * 0.5, 0.0)
			var origin := Vector2(x, top + draw_font.get_ascent(scaled_size))
			draw_font.draw_char(get_canvas_item(), origin, code, scaled_size, color)
			if span.style != null and span.style.underline:
				draw_rect(
					Rect2(
						Vector2(
							block_x + cursor_col * _cell_size.x,
							block_y + block_height - 1.0
						),
						Vector2(glyph_cols * _cell_size.x, 1.0)
					),
					color,
					true
				)
		cursor_col += glyph_cols


## 跨格大字按一行处理；换行替换成空格，避免测量和绘制错位
func _normalize_span_text(text: String) -> String:
	return text.replace("\r\n", "\n").replace("\r", "").replace("\n", " ")


## 多格大字的字号：按块高和字体行高反推，避免大字顶出块外
func _span_font_size(rows: int) -> int:
	var span_rows := maxi(rows, 1)
	var scaled_size := font_size * span_rows
	var max_height := span_rows * _cell_size.y
	while scaled_size > 1:
		var line_height := font.get_height(scaled_size) if font != null else 0.0
		if cjk_font != null:
			line_height = maxf(line_height, cjk_font.get_height(scaled_size))
		if line_height <= max_height:
			break
		scaled_size -= 1
	return maxi(scaled_size, 1)


func _measure_span_columns(text: String, scaled_size: int, style: TerminalStyle) -> int:
	var columns := 0
	var bold := style != null and style.bold
	for i in text.length():
		var code := text.unicode_at(i)
		if code < 32:
			continue
		var wide := TerminalWidth.columns(code) == 2
		var draw_font := _pick_font(code, wide, bold)
		var advance := draw_font.get_char_size(code, scaled_size).x
		if advance <= 0.0:
			advance = _cell_size.x * (2.0 if wide else 1.0)
		columns += maxi(ceili(advance / _cell_size.x), 1)
	return columns


func _rebuild_span_rects() -> void:
	_span_rects.clear()
	for span in _spans:
		var span_rows := maxi(span.rows, 1)
		var scaled_size := _span_font_size(span_rows)
		var columns := _measure_span_columns(
			_normalize_span_text(span.text), scaled_size, span.style
		)
		_span_rects.append(Rect2i(span.col, span.row, maxi(columns, 1), span_rows))


func _cell_in_span(row: int, col: int) -> bool:
	for rect in _span_rects:
		if (
			col >= rect.position.x
			and col < rect.end.x
			and row >= rect.position.y
			and row < rect.end.y
		):
			return true
	return false


## 双宽字符优先用 cjk_font；没有对应字形时退回主字体
func _pick_font(code: int, wide: bool, bold: bool) -> Font:
	if wide and cjk_font != null and cjk_font.has_char(code):
		if bold and _bold_cjk_font != null:
			return _bold_cjk_font
		return cjk_font
	if bold:
		return _bold_font
	return font


## 双宽字形按两格宽度居中，避免 CJK 字偏左
func _glyph_origin(col: int, row: int, code: int, wide: bool, draw_font: Font) -> Vector2:
	var x := col * _cell_size.x
	if wide:
		var glyph_width := draw_font.get_char_size(code, font_size).x
		if glyph_width > 0.0 and glyph_width < _cell_size.x * 2.0:
			x += (_cell_size.x * 2.0 - glyph_width) * 0.5
	return Vector2(x, row * _cell_size.y + _ascent)


func _ensure_font() -> void:
	if font == null:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(FALLBACK_FONTS)
		font = system_font
	if cjk_font == null:
		var cjk_system_font := SystemFont.new()
		cjk_system_font.font_names = PackedStringArray(CJK_FALLBACK_FONTS)
		cjk_font = cjk_system_font


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
	_rebuild_span_rects()


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
	_cursor_on = true
	if _blink_timer != null:
		_blink_timer.start()


func _on_blink_timeout() -> void:
	_cursor_on = not _cursor_on
	queue_redraw()
