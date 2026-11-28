class_name TerminalSpanRenderer
extends RefCounted

var spans: Array[TerminalSpan] = []
var span_rects: Array[Rect2i] = []


func set_spans(
	new_spans: Array[TerminalSpan],
	font: Font,
	cjk_font: Font,
	font_size: int,
	cell_size: Vector2,
	pick_font: Callable
) -> void:
	spans.clear()
	for span in new_spans:
		if span != null and not span.text.is_empty():
			spans.append(span)
	rebuild_rects(font, cjk_font, font_size, cell_size, pick_font)


func clear() -> void:
	spans.clear()
	span_rects.clear()


func get_spans() -> Array[TerminalSpan]:
	return spans.duplicate()


func get_rects() -> Array[Rect2i]:
	return span_rects.duplicate()


func is_empty() -> bool:
	return span_rects.is_empty()


func cell_in_span(row: int, col: int) -> bool:
	for rect in span_rects:
		if (
			col >= rect.position.x
			and col < rect.end.x
			and row >= rect.position.y
			and row < rect.end.y
		):
			return true
	return false


func intersects_rect(target: Rect2i) -> bool:
	for rect in span_rects:
		if rect.intersects(target):
			return true
	return false


func measure_span(
	text: String,
	rows: int,
	style: TerminalStyle,
	font: Font,
	cjk_font: Font,
	font_size: int,
	cell_size: Vector2,
	pick_font: Callable
) -> Vector2i:
	var span_rows := maxi(rows, 1)
	var scaled_size := _span_font_size(span_rows, font, cjk_font, font_size, cell_size)
	var columns := _measure_columns(
		_normalize_text(text), scaled_size, style, cell_size, pick_font
	)
	return Vector2i(maxi(columns, 1), span_rows)


func rebuild_rects(
	font: Font,
	cjk_font: Font,
	font_size: int,
	cell_size: Vector2,
	pick_font: Callable
) -> void:
	span_rects.clear()
	for span in spans:
		var span_rows := maxi(span.rows, 1)
		var scaled_size := _span_font_size(span_rows, font, cjk_font, font_size, cell_size)
		var columns := _measure_columns(
			_normalize_text(span.text), scaled_size, span.style, cell_size, pick_font
		)
		span_rects.append(Rect2i(span.col, span.row, maxi(columns, 1), span_rows))


func draw_spans(
	canvas: Control,
	font: Font,
	cjk_font: Font,
	font_size: int,
	cell_size: Vector2,
	pick_font: Callable
) -> void:
	for span in spans:
		_draw_span(canvas, span, font, cjk_font, font_size, cell_size, pick_font)


func _draw_span(
	canvas: Control,
	span: TerminalSpan,
	font: Font,
	cjk_font: Font,
	font_size: int,
	cell_size: Vector2,
	pick_font: Callable
) -> void:
	var text := _normalize_text(span.text)
	if text.is_empty():
		return
	var span_rows := maxi(span.rows, 1)
	var scaled_size := _span_font_size(span_rows, font, cjk_font, font_size, cell_size)
	var block_x := span.col * cell_size.x
	var block_y := span.row * cell_size.y
	var block_height := span_rows * cell_size.y
	var columns := _measure_columns(text, scaled_size, span.style, cell_size, pick_font)
	var block_width := columns * cell_size.x
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
		canvas.draw_rect(
			Rect2(Vector2(block_x, block_y), Vector2(block_width, block_height)),
			background,
			true
		)
	var cursor_col := 0
	var canvas_item := canvas.get_canvas_item()
	for i in text.length():
		var code := text.unicode_at(i)
		if code < 32:
			continue
		var wide := TerminalWidth.columns(code) == 2
		var draw_font := pick_font.call(code, wide, bold) as Font
		var advance := draw_font.get_char_size(code, scaled_size).x
		if advance <= 0.0:
			advance = cell_size.x * (2.0 if wide else 1.0)
		var glyph_cols := maxi(ceili(advance / cell_size.x), 1)
		if code != TerminalBuffer.SPACE:
			var x := block_x + cursor_col * cell_size.x
			x += (glyph_cols * cell_size.x - advance) * 0.5
			var line_height := draw_font.get_height(scaled_size)
			var top := block_y + maxf((block_height - line_height) * 0.5, 0.0)
			var origin := Vector2(x, top + draw_font.get_ascent(scaled_size))
			draw_font.draw_char(canvas_item, origin, code, scaled_size, color)
			if span.style != null and span.style.underline:
				canvas.draw_rect(
					Rect2(
						Vector2(
							block_x + cursor_col * cell_size.x,
							block_y + block_height - 1.0
						),
						Vector2(glyph_cols * cell_size.x, 1.0)
					),
					color,
					true
				)
		cursor_col += glyph_cols


func _normalize_text(text: String) -> String:
	return text.replace("\r\n", "\n").replace("\r", "").replace("\n", " ")


func _span_font_size(
	rows: int,
	font: Font,
	cjk_font: Font,
	font_size: int,
	cell_size: Vector2
) -> int:
	var span_rows := maxi(rows, 1)
	var scaled_size := font_size * span_rows
	var max_height := span_rows * cell_size.y
	while scaled_size > 1:
		var line_height := font.get_height(scaled_size) if font != null else 0.0
		if cjk_font != null:
			line_height = maxf(line_height, cjk_font.get_height(scaled_size))
		if line_height <= max_height:
			break
		scaled_size -= 1
	return maxi(scaled_size, 1)


func _measure_columns(
	text: String,
	scaled_size: int,
	style: TerminalStyle,
	cell_size: Vector2,
	pick_font: Callable
) -> int:
	var columns := 0
	var bold := style != null and style.bold
	for i in text.length():
		var code := text.unicode_at(i)
		if code < 32:
			continue
		var wide := TerminalWidth.columns(code) == 2
		var draw_font := pick_font.call(code, wide, bold) as Font
		var advance := draw_font.get_char_size(code, scaled_size).x
		if advance <= 0.0:
			advance = cell_size.x * (2.0 if wide else 1.0)
		columns += maxi(ceili(advance / cell_size.x), 1)
	return columns
