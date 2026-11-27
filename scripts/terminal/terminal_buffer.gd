class_name TerminalBuffer
extends RefCounted

const ATTR_BOLD: int = 1 << 0
const ATTR_UNDERLINE: int = 1 << 1
const ATTR_REVERSE: int = 1 << 2
const ATTR_WIDE: int = 1 << 3

const WIDE_CONTINUATION: int = -1

const SPACE: int = 32
const NEWLINE: int = 10
const CARRIAGE_RETURN: int = 13
const BACKSPACE: int = 8
const TAB: int = 9
const TAB_WIDTH: int = 8

var cols: int = 0
var rows: int = 0
var cursor_col: int = 0
var cursor_row: int = 0

var _chars: PackedInt32Array = PackedInt32Array()
var _fg: PackedColorArray = PackedColorArray()
var _bg: PackedColorArray = PackedColorArray()
var _attrs: PackedByteArray = PackedByteArray()
var _row_start: int = 0
var _history: TerminalHistory


func _init(initial_cols: int = 80, initial_rows: int = 24, history_limit: int = 1000) -> void:
	_history = TerminalHistory.new(maxi(initial_cols, 1), history_limit)
	resize(initial_cols, initial_rows)


func resize(new_cols: int, new_rows: int) -> void:
	new_cols = maxi(new_cols, 1)
	new_rows = maxi(new_rows, 1)
	if new_cols == cols and new_rows == rows:
		return
	var old_cols := cols
	var old_rows := rows
	var old_row_start := _row_start
	var old_cursor_col := cursor_col
	var old_cursor_row := cursor_row
	var old_chars := _chars.duplicate()
	var old_fg := _fg.duplicate()
	var old_bg := _bg.duplicate()
	var old_attrs := _attrs.duplicate()
	cols = new_cols
	rows = new_rows
	_allocate()
	if _history != null:
		_history.resize_cols(cols)
	var copy_cols := mini(old_cols, cols)
	var copy_rows := mini(old_rows, rows)
	for row in copy_rows:
		var src_base := ((old_row_start + row) % old_rows) * old_cols
		var dst_base := row * cols
		for col in copy_cols:
			_chars[dst_base + col] = old_chars[src_base + col]
			_fg[dst_base + col] = old_fg[src_base + col]
			_bg[dst_base + col] = old_bg[src_base + col]
			_attrs[dst_base + col] = old_attrs[src_base + col]
	_repair_wide_cells()
	cursor_col = clampi(old_cursor_col, 0, cols - 1)
	cursor_row = clampi(old_cursor_row, 0, rows - 1)


func clear() -> void:
	_clear_screen()
	if _history != null:
		_history.clear()


func _clear_screen() -> void:
	_chars.fill(SPACE)
	_fg.fill(TerminalPalette.default_fg())
	_bg.fill(TerminalPalette.default_bg())
	_attrs.fill(0)
	_row_start = 0
	cursor_col = 0
	cursor_row = 0


func write_text(text: String, style: TerminalStyle = null) -> void:
	var cell_style := style if style != null else TerminalStyle.new()
	for i in text.length():
		_write_codepoint(text.unicode_at(i), cell_style)


func write_line(text: String, style: TerminalStyle = null) -> void:
	write_text(text, style)
	newline()


func newline() -> void:
	cursor_col = 0
	cursor_row += 1
	if cursor_row >= rows:
		scroll_up(1)
		cursor_row = rows - 1


func scroll_up(count: int = 1) -> void:
	count = clampi(count, 0, rows)
	if count <= 0:
		return
	if _history != null:
		var push_count := mini(count, rows)
		for row in push_count:
			_history.push_row(_chars, _fg, _bg, _attrs, get_row_base(row))
	if count >= rows:
		_clear_rows(0, rows)
		_row_start = 0
		return
	_row_start = (_row_start + count) % rows
	_clear_rows(rows - count, rows)


func get_history() -> TerminalHistory:
	return _history


func get_row_base(row: int) -> int:
	if rows <= 0:
		return 0
	return ((_row_start + row) % rows) * cols


func get_chars() -> PackedInt32Array:
	return _chars


func get_fg_colors() -> PackedColorArray:
	return _fg


func get_bg_colors() -> PackedColorArray:
	return _bg


func get_attrs() -> PackedByteArray:
	return _attrs


func _allocate() -> void:
	var count := cols * rows
	_chars.resize(count)
	_fg.resize(count)
	_bg.resize(count)
	_attrs.resize(count)
	_clear_screen()


func _clear_rows(from_row: int, to_row: int) -> void:
	for row in range(from_row, to_row):
		var base := get_row_base(row)
		for col in cols:
			var index := base + col
			_chars[index] = SPACE
			_fg[index] = TerminalPalette.default_fg()
			_bg[index] = TerminalPalette.default_bg()
			_attrs[index] = 0


func _write_codepoint(code: int, style: TerminalStyle) -> void:
	match code:
		NEWLINE:
			newline()
		CARRIAGE_RETURN:
			cursor_col = 0
		BACKSPACE:
			_backspace()
		TAB:
			_tab_forward()
		_:
			if code < 32:
				return
			var columns := TerminalWidth.columns(code)
			if columns <= 0:
				return
			_write_cell(code, columns, style)


func _write_cell(code: int, columns: int, style: TerminalStyle) -> void:
	if columns == 2 and cols < 2:
		columns = 1
	if columns == 2 and cursor_col >= cols - 1:
		newline()
	elif cursor_col >= cols:
		newline()
	var index := get_row_base(cursor_row) + cursor_col
	_clear_overlapping_wide(index)
	_write_cell_at(index, code, style, ATTR_WIDE if columns == 2 else 0)
	if columns == 2:
		var next_index := index + 1
		_clear_overlapping_wide(next_index)
		_write_cell_at(next_index, WIDE_CONTINUATION, style, 0)
	cursor_col += columns


func _backspace() -> void:
	if cursor_col <= 0:
		cursor_col = 0
		return
	var target := mini(cursor_col - 1, cols - 1)
	var base := get_row_base(cursor_row)
	if target > 0 and _chars[base + target] == WIDE_CONTINUATION:
		target -= 1
	cursor_col = maxi(target, 0)


func _tab_forward() -> void:
	var target := mini((floori(cursor_col / float(TAB_WIDTH)) + 1) * TAB_WIDTH, cols - 1)
	var base := get_row_base(cursor_row)
	if target > 0 and _chars[base + target] == WIDE_CONTINUATION:
		target -= 1
	cursor_col = target


func _clear_overlapping_wide(index: int) -> void:
	var base := get_row_base(cursor_row)
	var col := index - base
	if _chars[index] == WIDE_CONTINUATION:
		if col > 0:
			_clear_cell(index - 1)
		_clear_cell(index)
		return
	if TerminalWidth.columns(_chars[index]) == 2 and col + 1 < cols:
		_clear_cell(index + 1)


func _write_cell_at(index: int, code: int, style: TerminalStyle, extra_attrs: int) -> void:
	_chars[index] = code
	_fg[index] = style.fg
	_bg[index] = style.bg
	_attrs[index] = _style_attrs(style) | extra_attrs


func _clear_cell(index: int) -> void:
	_chars[index] = SPACE
	_fg[index] = TerminalPalette.default_fg()
	_bg[index] = TerminalPalette.default_bg()
	_attrs[index] = 0


func _style_attrs(style: TerminalStyle) -> int:
	var attrs := 0
	if style.bold:
		attrs |= ATTR_BOLD
	if style.underline:
		attrs |= ATTR_UNDERLINE
	if style.reverse:
		attrs |= ATTR_REVERSE
	return attrs


func _repair_wide_cells() -> void:
	for row in rows:
		var base := get_row_base(row)
		for col in cols:
			var index := base + col
			var code := _chars[index]
			if code == WIDE_CONTINUATION:
				if col == 0 or TerminalWidth.columns(_chars[index - 1]) != 2:
					_clear_cell(index)
				continue
			if TerminalWidth.columns(code) == 2:
				if col + 1 >= cols or _chars[index + 1] != WIDE_CONTINUATION:
					_clear_cell(index)
