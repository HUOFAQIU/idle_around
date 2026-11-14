class_name TerminalHistory
extends RefCounted
## 终端回看历史：按行保存滚出屏幕的内容，环形覆盖，容量固定。
##
## 每行仍是并行 Packed 数组；数组按物理行排列，逻辑行用 get_row_base() 换算。
## push_row() 由 TerminalBuffer 在 scroll_up 时调用；渲染器只读。
## pushed 是累计推入行数（容量满后仍增长），供 View 判断新增了多少行。

## 与 TerminalBuffer 对齐的哨兵值；这里单独定义，避免两个类互相引用
const SPACE: int = 32
const WIDE_CONTINUATION: int = -1

var cols: int = 0
var capacity: int = 0
var count: int = 0
var pushed: int = 0

var _start: int = 0
var _chars: PackedInt32Array = PackedInt32Array()
var _fg: PackedColorArray = PackedColorArray()
var _bg: PackedColorArray = PackedColorArray()
var _attrs: PackedByteArray = PackedByteArray()


func _init(initial_cols: int = 80, line_capacity: int = 1000) -> void:
	cols = maxi(initial_cols, 1)
	capacity = maxi(line_capacity, 0)
	_allocate()


## 把一行 cell 追加到历史；容量满时覆盖最旧的行
func push_row(
	chars: PackedInt32Array,
	fg_colors: PackedColorArray,
	bg_colors: PackedColorArray,
	attrs: PackedByteArray,
	source_base: int
) -> void:
	if capacity <= 0:
		return
	var dst_line: int
	if count < capacity:
		dst_line = count
		count += 1
	else:
		dst_line = _start
		_start = (_start + 1) % capacity
	var dst_base := dst_line * cols
	for col in cols:
		_chars[dst_base + col] = chars[source_base + col]
		_fg[dst_base + col] = fg_colors[source_base + col]
		_bg[dst_base + col] = bg_colors[source_base + col]
		_attrs[dst_base + col] = attrs[source_base + col]
	pushed += 1


## 列数变化时重建历史，保留左侧内容；宽字符被截断时清掉孤儿格
func resize_cols(new_cols: int) -> void:
	new_cols = maxi(new_cols, 1)
	if new_cols == cols:
		return
	var old_cols := cols
	var old_count := count
	var old_start := _start
	var old_pushed := pushed
	var old_chars := _chars.duplicate()
	var old_fg := _fg.duplicate()
	var old_bg := _bg.duplicate()
	var old_attrs := _attrs.duplicate()
	cols = new_cols
	_allocate()
	var copy_cols := mini(old_cols, cols)
	for line in old_count:
		var src_base := ((old_start + line) % capacity) * old_cols
		var dst_base := line * cols
		for col in copy_cols:
			_chars[dst_base + col] = old_chars[src_base + col]
			_fg[dst_base + col] = old_fg[src_base + col]
			_bg[dst_base + col] = old_bg[src_base + col]
			_attrs[dst_base + col] = old_attrs[src_base + col]
	count = old_count
	_start = 0
	pushed = old_pushed
	_repair_wide_cells()


func clear() -> void:
	count = 0
	_start = 0
	pushed = 0


## 逻辑行在扁平数组里的起始下标
func get_row_base(logical_row: int) -> int:
	if capacity <= 0 or count <= 0:
		return 0
	var row := clampi(logical_row, 0, count - 1)
	return ((_start + row) % capacity) * cols


func get_chars() -> PackedInt32Array:
	return _chars


func get_fg_colors() -> PackedColorArray:
	return _fg


func get_bg_colors() -> PackedColorArray:
	return _bg


func get_attrs() -> PackedByteArray:
	return _attrs


func _allocate() -> void:
	var cell_count := capacity * cols
	_chars.resize(cell_count)
	_fg.resize(cell_count)
	_bg.resize(cell_count)
	_attrs.resize(cell_count)
	_chars.fill(SPACE)
	_fg.fill(TerminalPalette.default_fg())
	_bg.fill(TerminalPalette.default_bg())
	_attrs.fill(0)
	count = 0
	_start = 0
	pushed = 0


func _repair_wide_cells() -> void:
	for line in count:
		var base := get_row_base(line)
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


func _clear_cell(index: int) -> void:
	_chars[index] = SPACE
	_fg[index] = TerminalPalette.default_fg()
	_bg[index] = TerminalPalette.default_bg()
	_attrs[index] = 0
