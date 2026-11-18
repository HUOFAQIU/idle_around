class_name CompletionPanel
extends Control
## 命令补全候选浮层：自绘列表，不抢输入焦点。
##
## TerminalWindow 负责键位和替换文本；这里只管候选、选中行和鼠标点击。

signal candidate_chosen(text: String)

const MAX_VISIBLE_ROWS: int = 8
const ROW_PADDING: float = 8.0
const TEXT_PADDING: float = 8.0
const MIN_ROW_HEIGHT: float = 22.0
const BORDER_WIDTH: int = 1

var font: Font
var font_size: int = 16

var _candidates := PackedStringArray()
var _selected: int = 0
## 第一行可见候选在 _candidates 里的下标
var _scroll: int = 0
## 抬头的 usage + summary；空字符串时不画
var _hint: String = ""


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	visible = false


## 打开并替换候选；width 跟随输入框，hint 显示在候选上方
func show_candidates(candidates: PackedStringArray, width: float, hint := "") -> void:
	if candidates.is_empty():
		hide_panel()
		return
	_candidates = candidates
	_hint = hint
	_selected = 0
	_scroll = 0
	var rows := mini(candidates.size(), MAX_VISIBLE_ROWS)
	size = Vector2(width, _rows_top() + _row_height() * rows + ROW_PADDING)
	visible = true
	queue_redraw()


func hide_panel() -> void:
	visible = false
	_candidates = PackedStringArray()
	_hint = ""
	_selected = 0
	_scroll = 0


func is_open() -> bool:
	return visible and not _candidates.is_empty()


func move_selection(delta: int) -> void:
	if _candidates.is_empty():
		return
	_selected = clampi(_selected + delta, 0, _candidates.size() - 1)
	_keep_selected_visible()
	queue_redraw()


func selected_text() -> String:
	if _candidates.is_empty():
		return ""
	return _candidates[_selected]


func _draw() -> void:
	if _candidates.is_empty():
		return
	var row_height := _row_height()
	var draw_font := _draw_font()
	var text_color := TerminalPalette.default_fg()
	var selected_bg := TerminalPalette.color(6)
	var selected_fg := TerminalPalette.default_bg()
	draw_rect(Rect2(Vector2.ZERO, size), TerminalPalette.default_bg(), true)
	draw_rect(Rect2(Vector2.ZERO, size), TerminalPalette.color(8), false, BORDER_WIDTH)
	if not _hint.is_empty():
		var hint_baseline := ROW_PADDING
		hint_baseline += (row_height - draw_font.get_height(font_size)) * 0.5
		hint_baseline += draw_font.get_ascent(font_size)
		draw_string(
			draw_font,
			Vector2(TEXT_PADDING, hint_baseline),
			_hint,
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - TEXT_PADDING * 2.0,
			font_size,
			TerminalPalette.color(8)
		)
		draw_line(
			Vector2(0.0, ROW_PADDING + _header_height()),
			Vector2(size.x, ROW_PADDING + _header_height()),
			TerminalPalette.color(8)
		)
	var visible_rows := mini(_candidates.size() - _scroll, MAX_VISIBLE_ROWS)
	for row in visible_rows:
		var index := _scroll + row
		var row_rect := Rect2(
			Vector2(BORDER_WIDTH, _rows_top() + row * row_height),
			Vector2(size.x - BORDER_WIDTH * 2.0, row_height)
		)
		if index == _selected:
			draw_rect(row_rect, selected_bg, true)
		var baseline := row_rect.position.y
		baseline += (row_height - draw_font.get_height(font_size)) * 0.5
		baseline += draw_font.get_ascent(font_size)
		draw_string(
			draw_font,
			Vector2(TEXT_PADDING, baseline),
			_candidates[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - TEXT_PADDING * 2.0,
			font_size,
			selected_fg if index == _selected else text_color
		)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_LEFT:
			var row := _row_at(button.position.y)
			if row >= 0:
				candidate_chosen.emit(_candidates[_scroll + row])
				accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-1)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(1)
			accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var row := _row_at(motion.position.y)
		if row >= 0 and _scroll + row != _selected:
			_selected = _scroll + row
			queue_redraw()


## 本地 y 坐标 → 可见行号；不在候选行上返回 -1
func _row_at(local_y: float) -> int:
	var offset := local_y - _rows_top()
	if offset < 0.0:
		return -1
	var row := int(floor(offset / _row_height()))
	if row < 0 or row >= mini(_candidates.size() - _scroll, MAX_VISIBLE_ROWS):
		return -1
	return row


func _scroll_by(delta: int) -> void:
	var max_scroll := maxi(_candidates.size() - MAX_VISIBLE_ROWS, 0)
	var next := clampi(_scroll + delta, 0, max_scroll)
	if next == _scroll:
		return
	_scroll = next
	_selected = clampi(_selected, _scroll, _last_visible_index())
	queue_redraw()


func _keep_selected_visible() -> void:
	if _selected < _scroll:
		_scroll = _selected
	elif _selected > _last_visible_index():
		_scroll = _selected - MAX_VISIBLE_ROWS + 1
	_scroll = clampi(_scroll, 0, maxi(_candidates.size() - MAX_VISIBLE_ROWS, 0))


## 当前可见的最后一行的绝对下标
func _last_visible_index() -> int:
	return mini(_scroll + MAX_VISIBLE_ROWS - 1, _candidates.size() - 1)


func _row_height() -> float:
	return maxf(ceilf(_draw_font().get_height(font_size)) + 8.0, MIN_ROW_HEIGHT)


## 抬头占一行；没有 hint 时为 0
func _header_height() -> float:
	return _row_height() if not _hint.is_empty() else 0.0


## 候选行的起点：顶部留白 + 抬头 + 1px 分隔线
func _rows_top() -> float:
	if _hint.is_empty():
		return ROW_PADDING
	return ROW_PADDING + _header_height() + 1.0


func _draw_font() -> Font:
	return font if font != null else ThemeDB.fallback_font
