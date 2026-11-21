@tool
extends VBoxContainer
## 编辑器色板：按 GameColors.GROUPS 展示色卡，
## 并附同色别名、状态词映射和终端色板。
##
## 由 EngineTools/color_catalog/plugin.gd 实例化到编辑器主屏幕；
## 也可在任意编辑器场景里直接使用。
## 色值来自 GameColorCatalog，本文件不保存任何颜色。

const CATALOG : GDScript = preload("res://Scripts/game_color_catalog.gd")
const GAME_COLORS : GDScript = preload("res://Scripts/game_colors.gd")

const SWATCH_SIZE : Vector2 = Vector2(22, 22)
const CARD_MIN_WIDTH : float = 160.0
const REFRESH_INTERVAL : float = 0.5
const COPY_FEEDBACK_SECONDS : float = 1.5
const HINT_TEXT : String = "点击色卡复制引用；GameColors 卡片复制常量名，终端卡片复制色值。"

## 参与自动刷新的脚本；保存后色板会重建
const WATCHED_PATHS : Array[String] = [
	"res://Scripts/game_colors.gd",
	"res://Scripts/game_color_catalog.gd",
	"res://Scripts/terminal/terminal_palette.gd",
]

var _count_label : Label
var _status_label : Label
var _content : VBoxContainer
var _checker : Texture2D
var _refresh_timer : Timer
var _copy_timer : Timer
var _last_mtimes : Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_checker = _make_checker_texture()
	_build_header()
	_build_scroll()
	_rebuild()

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = REFRESH_INTERVAL
	_refresh_timer.timeout.connect(_check_for_changes)
	add_child(_refresh_timer)
	_refresh_timer.start()

	visibility_changed.connect(_on_visibility_changed)


func _build_header() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	add_child(header)

	var title := Label.new()
	title.text = "色板"
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 12)
	_count_label.modulate = Color(1, 1, 1, 0.65)
	header.add_child(_count_label)

	_status_label = Label.new()
	_status_label.text = HINT_TEXT
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.modulate = Color(1, 1, 1, 0.65)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_status_label)

	var refresh := Button.new()
	refresh.text = "刷新"
	refresh.tooltip_text = "重新读取 GameColors / TerminalPalette"
	refresh.pressed.connect(_rebuild)
	header.add_child(refresh)

	_copy_timer = Timer.new()
	_copy_timer.one_shot = true
	_copy_timer.wait_time = COPY_FEEDBACK_SECONDS
	_copy_timer.timeout.connect(_on_copy_timeout)
	add_child(_copy_timer)


func _build_scroll() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)


## 重建全部内容；只读取目录数据，不修改任何颜色
func _rebuild() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_update_count()
	for group in CATALOG.groups():
		_add_group(String(group["title"]), group["colors"])
	_add_aliases()
	_add_status()
	_add_terminal()
	_add_ungrouped()
	_add_problems()
	_record_mtimes()


func _update_count() -> void:
	var stats: Dictionary = CATALOG.stats()
	var terminal: Dictionary = CATALOG.terminal_palette()
	var terminal_count: int = terminal["colors"].size() + terminal["defaults"].size()
	_count_label.text = "GameColors %d 常量 / %d 唯一色值 · 终端 %d 色" % [
		stats["constants"],
		stats["unique"],
		terminal_count,
	]


func _add_group(title: String, colors: Array) -> void:
	if colors.is_empty():
		return
	_add_section_title(title)
	var flow := _make_flow()
	for entry in colors:
		var color_name := String(entry["name"])
		var hex := String(entry["hex"])
		flow.add_child(
			_make_color_card(color_name, hex, entry["color"], "GameColors.%s" % color_name)
		)
	_content.add_child(flow)


func _add_aliases() -> void:
	var entries: Array = CATALOG.aliases()
	if entries.is_empty():
		return
	_add_section_title("同色别名")
	var flow := _make_flow()
	for entry in entries:
		var names: Array = entry["names"]
		var title := " / ".join(PackedStringArray(names))
		var hex := String(entry["hex"])
		flow.add_child(_make_color_card(title, hex, entry["color"], hex))
	_content.add_child(flow)


func _add_status() -> void:
	var entries: Array = CATALOG.status_entries()
	if entries.is_empty():
		return
	_add_section_title("状态词映射（GameColors.STATUS）")
	var flow := _make_flow()
	for entry in entries:
		flow.add_child(_make_color_card(
			String(entry["name"]),
			String(entry["hex"]),
			entry["color"],
			String(entry["hex"]),
		))
	_content.add_child(flow)


func _add_terminal() -> void:
	var palette: Dictionary = CATALOG.terminal_palette()
	var colors: Array = palette["colors"]
	var defaults: Array = palette["defaults"]
	if colors.is_empty() and defaults.is_empty():
		return
	_add_section_title("终端色板（TerminalPalette，独立系统）")
	var flow := _make_flow()
	for entry in colors:
		flow.add_child(_make_color_card(
			String(entry["name"]),
			String(entry["hex"]),
			entry["color"],
			String(entry["hex"]),
		))
	_content.add_child(flow)
	if defaults.is_empty():
		return
	var defaults_flow := _make_flow()
	for entry in defaults:
		defaults_flow.add_child(_make_color_card(
			String(entry["name"]),
			String(entry["hex"]),
			entry["color"],
			String(entry["hex"]),
		))
	_content.add_child(defaults_flow)


func _add_ungrouped() -> void:
	var entries: Array = CATALOG.ungrouped()
	if entries.is_empty():
		return
	_add_section_title("未归类（请加入 GameColors.GROUPS）", true)
	var flow := _make_flow()
	for entry in entries:
		var color_name := String(entry["name"])
		var hex := String(entry["hex"])
		flow.add_child(
			_make_color_card(color_name, hex, entry["color"], "GameColors.%s" % color_name)
		)
	_content.add_child(flow)


func _add_problems() -> void:
	var problems: Array = CATALOG.validate()
	if problems.is_empty():
		return
	var shown := false
	for problem in problems:
		if String(problem).contains("未归类"):
			continue
		if not shown:
			_add_section_title("分组校验问题", true)
			shown = true
		var label := Label.new()
		label.text = "⚠ " + String(problem)
		label.add_theme_color_override("font_color", _danger_color())
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(label)


func _add_section_title(text: String, warning: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	if warning:
		label.add_theme_color_override("font_color", _danger_color())
	_content.add_child(label)


func _make_flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	return flow


func _make_color_card(title: String, hex: String, color: Color, copy_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_MIN_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.tooltip_text = "%s\n%s\n点击复制 %s" % [title, hex, copy_text]
	panel.gui_input.connect(_on_card_gui_input.bind(copy_text))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	box.add_child(_make_swatch(color))

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 0)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(text_box)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var hex_label := Label.new()
	hex_label.text = _display_hex(hex)
	hex_label.add_theme_font_size_override("font_size", 11)
	hex_label.modulate = Color(1, 1, 1, 0.65)
	hex_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(hex_label)

	return panel


func _make_swatch(color: Color) -> Control:
	var swatch := Control.new()
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var checker := TextureRect.new()
	checker.texture = _checker
	checker.stretch_mode = TextureRect.STRETCH_TILE
	checker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	checker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.add_child(checker)

	var fill := ColorRect.new()
	fill.color = color
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.add_child(fill)
	return swatch


func _make_checker_texture() -> Texture2D:
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var light := Color(0.72, 0.72, 0.72)
	var dark := Color(0.52, 0.52, 0.52)
	for y in 16:
		for x in 16:
			image.set_pixel(x, y, light if ((x >> 3) + (y >> 3)) % 2 == 0 else dark)
	return ImageTexture.create_from_image(image)


func _display_hex(hex: String) -> String:
	var color := Color.html(hex)
	if color.a < 1.0:
		return "%s  a=%.2f" % [hex, color.a]
	return hex


func _danger_color() -> Color:
	return Color.html(String(GAME_COLORS.DANGER))


func _on_card_gui_input(event: InputEvent, copy_text: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	DisplayServer.clipboard_set(copy_text)
	_status_label.text = "已复制 %s" % copy_text
	_copy_timer.start()


func _on_copy_timeout() -> void:
	_status_label.text = HINT_TEXT


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_check_for_changes()


func _check_for_changes() -> void:
	if not is_visible_in_tree():
		return
	for path in WATCHED_PATHS:
		if FileAccess.get_modified_time(path) != _last_mtimes.get(path, -1):
			_rebuild()
			return


func _record_mtimes() -> void:
	for path in WATCHED_PATHS:
		_last_mtimes[path] = FileAccess.get_modified_time(path)
