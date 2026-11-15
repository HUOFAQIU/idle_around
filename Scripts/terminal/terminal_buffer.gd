class_name TerminalBuffer
extends RefCounted
## 字符网格数据。只保存字符与样式，不负责绘制。
##
## 每格用并行数组存储，避免一格一个 Object；扁平索引 = 物理行 * cols + col。
## 行以环形方式保存：_row_start 是逻辑第 0 行对应的物理行，上滚只移动它并清空
## 新底行，不再整屏复制。读逻辑行时用 get_row_base(row) 换算起始下标。
## 字符宽度由 TerminalWidth 决定：双宽字符占两格，第二格写 WIDE_CONTINUATION；
## 组合字符（宽度 0）暂时跳过，不参与渲染。
## 转义序列不在这里解析：ESC 会像其他控制字符一样被忽略，调用方直接给样式。

const ATTR_BOLD: int = 1 << 0
const ATTR_UNDERLINE: int = 1 << 1
const ATTR_REVERSE: int = 1 << 2
## 该格是双宽字符的第一格
const ATTR_WIDE: int = 1 << 3

## 双宽字符的第二格；渲染器跳过，背景/样式仍按同一格处理
const WIDE_CONTINUATION: int = -1

const SPACE: int = 32
const NEWLINE: int = 10
const CARRIAGE_RETURN: int = 13
const BACKSPACE: int = 8
const TAB: int = 9
const TAB_WIDTH: int = 8

var cols: int = 0
var rows: int = 0
## 光标允许停在 cols（最后一列的“待换行”状态），下一次写字符才换行
var cursor_col: int = 0
var cursor_row: int = 0

var _chars: PackedInt32Array = PackedInt32Array()
var _fg: PackedColorArray = PackedColorArray()
var _bg: PackedColorArray = PackedColorArray()
var _attrs: PackedByteArray = PackedByteArray()
## 逻辑第 0 行在扁平数组里的物理行号
var _row_start: int = 0
## 滚出屏幕的行；容量默认 1000 行
var _history: TerminalHistory


func _init(initial_cols: int = 80, initial_rows: int = 24, history_limit: int = 1000) -> void:
	_history = TerminalHistory.new(maxi(initial_cols, 1), history_limit)
	resize(initial_cols, initial_rows)


## 重设尺寸；保留左上角内容，光标夹到新范围内
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
	# Packed 数组是按引用传递的，resize 前必须 duplicate，否则旧数组会被一起改掉
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
	# 窄列可能把双宽字符的续格截掉，清掉这些孤儿格
	_repair_wide_cells()
	# _allocate() 里的 clear() 会把光标归零，这里恢复并按新尺寸夹紧
	cursor_col = clampi(old_cursor_col, 0, cols - 1)
	cursor_row = clampi(old_cursor_row, 0, rows - 1)


## 清空屏幕、历史和光标
func clear() -> void:
	_clear_screen()
	if _history != null:
		_history.clear()


## 只清屏幕，保留历史；resize 分配新数组时用
func _clear_screen() -> void:
	_chars.fill(SPACE)
	_fg.fill(TerminalPalette.default_fg())
	_bg.fill(TerminalPalette.default_bg())
	_attrs.fill(0)
	_row_start = 0
	cursor_col = 0
	cursor_row = 0


## 写一段文本；\n、\r、\t、\b 按终端习惯处理
func write_text(text: String, style: TerminalStyle = null) -> void:
	var cell_style := style if style != null else TerminalStyle.new()
	for i in text.length():
		_write_codepoint(text.unicode_at(i), cell_style)


## 写一行并换行
func write_line(text: String, style: TerminalStyle = null) -> void:
	write_text(text, style)
	newline()


## 光标换到下一行；到底部时整屏上滚
func newline() -> void:
	cursor_col = 0
	cursor_row += 1
	if cursor_row >= rows:
		scroll_up(1)
		cursor_row = rows - 1


## 向上滚动 count 行，底部补空行；滚出的顶部行写入历史
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


## 逻辑行在扁平数组里的起始下标；渲染器按逻辑行读取时用
func get_row_base(row: int) -> int:
	if rows <= 0:
		return 0
	return ((_row_start + row) % rows) * cols


## 渲染器直接读取并行数组；约定只读，不要修改。
## 数组按物理行排列，逻辑行用 get_row_base(row) 取起始下标。
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
				# 组合字符暂不渲染，避免占用一格
				return
			_write_cell(code, columns, style)


func _write_cell(code: int, columns: int, style: TerminalStyle) -> void:
	# 1 列的终端放不下双宽字符，退化成单宽
	if columns == 2 and cols < 2:
		columns = 1
	# 双宽字符只剩最后一格时先换行，不能把续格拆到下一行
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


## 覆盖某个格之前，把它所属的双宽字符连同另一格一起清掉，避免留下半个字
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


## resize 后清理被截断的双宽字符/孤立续格
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
