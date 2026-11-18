extends RefCounted
## TestAPI 终端域：终端内容、滚动与 tooltip 显示。
##
## 对外入口仍是 res://Scripts/test_api.gd 的 TestAPI。

const COMMON: GDScript = preload("res://Scripts/test_api/common.gd")
const INVENTORY: GDScript = preload("res://Scripts/test_api/inventory.gd")

static func terminal_write_line(text : String) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.write_line(text)
	return true


static func terminal_write_ansi(text : String) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.write_ansi(text)
	return true


static func terminal_set_content(text : String) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.set_content(PackedStringArray(text.split("\n")))
	return true


static func terminal_set_ansi_content(text : String) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.set_ansi_content(PackedStringArray(text.split("\n")))
	return true


static func terminal_scroll(lines : int) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.scroll_by(lines)
	return true


static func terminal_scroll_to_bottom() -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.scroll_to_bottom()
	return true


static func terminal_clear() -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.clear()
	return true


static func terminal_set_grid(enabled: bool) -> bool:
	var view := _terminal_view()
	if view == null:
		return false
	view.set_debug_grid(enabled)
	return true


static func terminal_snapshot() -> Dictionary:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return {}
	return {
		"cols": view.buffer.cols,
		"rows": view.buffer.rows,
		"cell": view.get_cell_size(),
		"cursor": Vector2i(view.buffer.cursor_col, view.buffer.cursor_row),
		"history": view.get_scrollback_count(),
		"view_offset": view.view_offset,
		"auto_scroll": view.auto_scroll,
		"spans": view.get_span_rects(),
	}


static func tooltip_snapshot() -> Dictionary:
	var tip := TooltipWindow.instance
	if not is_instance_valid(tip) or not tip.visible:
		return {}
	for node in tip.find_children("*", "", true, false):
		if node is TerminalView:
			var view := node as TerminalView
			if view.buffer == null or not view.visible:
				return {}
			return {
				"grid": view.get_grid_size(),
				"debug_grid": view.debug_grid,
				"body_visible": view.visible,
				"tooltip_size": tip.size,
				"spans": view.get_span_rects(),
			}
	return {}


static func show_terminal() -> bool:
	var window := _terminal_window()
	if window == null:
		return false
	if not window.visible:
		window.open_window()
	return true


static func is_terminal_open() -> bool:
	var window := _terminal_window()
	return window != null and window.visible


static func terminal_show_soul_tooltip(
	id : StringName, equipped : bool = false, grid : bool = true
) -> bool:
	var text: String = (
		INVENTORY.get_equipped_soul_tooltip_ansi(id) if equipped
		else INVENTORY.get_soul_tooltip_ansi(id)
	)
	if text.is_empty():
		return false
	return _terminal_show_tooltip(text, grid)


static func terminal_show_vessel_tooltip(id : StringName, grid : bool = true) -> bool:
	var text: String = INVENTORY.get_vessel_tooltip_ansi(id)
	if text.is_empty():
		return false
	return _terminal_show_tooltip(text, grid)


static func terminal_show_equipped_vessel_tooltip(
	slot : int = 0, grid : bool = true
) -> bool:
	var text: String = INVENTORY.get_equipped_vessel_tooltip_ansi(slot)
	if text.is_empty():
		return false
	return _terminal_show_tooltip(text, grid)


## 把标题 + ANSI 正文写进当前 TerminalView；grid 控制调试网格开关
static func _terminal_show_tooltip(text : String, grid : bool) -> bool:
	var view := _terminal_view()
	if view == null or view.buffer == null:
		return false
	view.set_debug_grid(grid)
	view.set_ansi_content(PackedStringArray(text.split("\n")))
	show_terminal()
	return true


static func _terminal_view() -> TerminalView:
	return COMMON.find_node_in_scene(TerminalView) as TerminalView


static func _terminal_window() -> TerminalWindow:
	return COMMON.find_node_in_scene(TerminalWindow) as TerminalWindow
