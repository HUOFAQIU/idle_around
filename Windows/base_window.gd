class_name BaseWindow
extends Control

## 打开时摆在主视口哪儿；x 或 y 是负数表示「居中」
@export var open_position : Vector2i = Vector2i(-1, -1)

const TITLE_BAR_HEIGHT : int = 28
const TITLE_BUTTON_SIZE : Vector2i = Vector2i(24, 22)
const TITLE_BUTTON_MARGIN : int = 4
const TITLE_FONT_SIZE : int = 12
const DEFAULT_BG_COLOR : Color = Color(0.1, 0.1, 0.1, 1.0)

signal title_changed

var title : String = "":
	set(value):
		if title == value:
			return
		title = value
		title_changed.emit()

var _background : Panel
var _ui_root : VBoxContainer
var _title_bar : PanelContainer
var _title_bar_box : HBoxContainer
var _title_label : Label
var _close_button : Button
var _content_root : Control
var _wrapped : bool = false
var _drag : ControlDrag


func _ready() -> void:
	clip_contents = true
	_build_background()
	_build_title_bar()
	title_changed.connect(_sync_title)
	call_deferred("_wrap_content")
	_sync_title()


func _open_window() -> void:
	_wrap_content()
	var target_size := _popup_size()
	size = target_size
	if open_position.x < 0 or open_position.y < 0:
		position = (Vector2(_parent_viewport_size()) - target_size) * 0.5
	else:
		position = _clamp_position(Vector2(open_position))
	visible = true
	call_deferred("_grow_to_content")


func add_title_bar_button(button : Button) -> void:
	if _title_bar == null:
		push_warning("BaseWindow：标题栏尚未创建，add_title_bar_button 必须在 super() 之后调用")
		return
	_style_title_bar_button(button)
	_title_bar_box.add_child(button)
	_title_bar_box.move_child(button, _close_button.get_index())


func _build_background() -> void:
	_background = Panel.new()
	_background.name = "WindowBackground"
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	var style := _background.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = DEFAULT_BG_COLOR
	else:
		style.bg_color = Color(style.bg_color, 1.0)
	_background.add_theme_stylebox_override("panel", style)


func _build_title_bar() -> void:
	_ui_root = VBoxContainer.new()
	_ui_root.name = "TitleUI"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_theme_constant_override("separation", 0)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)

	_title_bar = PanelContainer.new()
	_title_bar.name = "TitleBar"
	_title_bar.custom_minimum_size = Vector2(0, TITLE_BAR_HEIGHT)
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = GameColors.to_color(GameColors.WINDOW_TITLE_BAR)
	title_style.set_content_margin_all(0)
	_title_bar.add_theme_stylebox_override("panel", title_style)
	_ui_root.add_child(_title_bar)

	_title_bar_box = HBoxContainer.new()
	_title_bar_box.name = "TitleBarBox"
	_title_bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_bar.add_child(_title_bar_box)

	_drag = ControlDrag.new()
	_drag.bind(self, _title_bar, get_parent() as Control)

	var title_margin := MarginContainer.new()
	title_margin.name = "TitleMargin"
	title_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_margin.add_theme_constant_override("margin_left", 6)
	_title_bar_box.add_child(title_margin)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_OUTLINE))
	title_margin.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "×"
	_close_button.tooltip_text = "关闭"
	_close_button.custom_minimum_size = TITLE_BUTTON_SIZE
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_title_bar_button(_close_button)
	_close_button.pressed.connect(hide)
	_title_bar_box.add_child(_close_button)

	var right_space := Control.new()
	right_space.custom_minimum_size = Vector2i(TITLE_BUTTON_MARGIN, 0)
	right_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_bar_box.add_child(right_space)

	_content_root = Control.new()
	_content_root.name = "ContentRoot"
	_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_content_root)


func _style_title_bar_button(button : Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	var pressed_style := button.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	if pressed_style == null:
		return
	pressed_style.bg_color = GameColors.to_color(GameColors.ACCENT)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("hover_pressed", pressed_style)
	button.add_theme_color_override("font_pressed_color", GameColors.to_color(GameColors.ACCENT_TEXT))
	button.add_theme_color_override("font_hover_pressed_color", GameColors.to_color(GameColors.ACCENT_TEXT))


func _wrap_content() -> void:
	if _wrapped or _content_root == null:
		return
	_wrapped = true
	for child in get_children():
		if child == _background or child == _ui_root:
			continue
		remove_child(child)
		_content_root.add_child(child)
	size.y += TITLE_BAR_HEIGHT


func _grow_to_content() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not visible or _content_root == null:
		return
	var content_min := _content_min_size()
	var wanted := Vector2(
		maxf(size.x, content_min.x),
		maxf(size.y, content_min.y + TITLE_BAR_HEIGHT)
	)
	var bounds := Vector2(_parent_viewport_size())
	wanted = Vector2(minf(wanted.x, bounds.x), minf(wanted.y, bounds.y))
	if wanted != size:
		size = wanted
		position = _clamp_position(position)


func _content_min_size() -> Vector2:
	var content_min := Vector2.ZERO
	if _content_root == null:
		return content_min
	for child in _content_root.get_children():
		if child is Control:
			content_min = content_min.max((child as Control).get_combined_minimum_size())
	return content_min


func _sync_title() -> void:
	if _title_label == null:
		return
	var display := title
	if display.is_empty():
		display = String(name)
	if _title_label.text != display:
		_title_label.text = display


func _popup_size() -> Vector2:
	var bounds := Vector2(_parent_viewport_size())
	return Vector2(minf(size.x, bounds.x), minf(size.y, bounds.y))


func _parent_viewport_size() -> Vector2i:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2i(1600, 960)
	var visible_size := viewport.get_visible_rect().size
	if visible_size.x <= 1 or visible_size.y <= 1:
		return Vector2i(1600, 960)
	return Vector2i(visible_size)


func _clamp_position(target : Vector2) -> Vector2:
	return UiBounds.clamp_position(target, size, Vector2(_parent_viewport_size()))
