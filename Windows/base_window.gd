class_name BaseWindow
extends Window

## 打开时摆在主视口哪儿；x 或 y 是负数表示「居中」（就按 popup_centered 来）
@export var open_position : Vector2i = Vector2i(-1, -1)

## 顶部标题栏
const TITLE_BAR_HEIGHT : int = 28
const TITLE_BUTTON_SIZE : Vector2i = Vector2i(24, 22)
const TITLE_BUTTON_MARGIN : int = 4
const TITLE_FONT_SIZE : int = 12

## 标题栏 + 下方内容区
var _ui_root : VBoxContainer
var _title_bar : HBoxContainer
var _title_label : Label
var _close_button : Button
var _content_root : Control
## 原窗口内容是否已经挪进 _content_root
var _wrapped : bool = false
## 标题栏拖动状态
var _dragging : bool = false
var _drag_start_mouse : Vector2 = Vector2.ZERO
var _drag_start_position : Vector2i = Vector2i.ZERO


func _ready() -> void:
	# 嵌入子窗口默认也带一层 Godot 自绘的窗口装饰（居中标题 + 关闭按钮），
	# 会和 BaseWindow 自己的标题栏叠成两层；标题栏完全由 BaseWindow 负责。
	borderless = true
	close_requested.connect(
		func ():
			self.hide()
	)
	_build_title_bar()
	title_changed.connect(_sync_title)
	visibility_changed.connect(_on_visibility_changed)
	# 子类 _ready() 在 super() 之后继续加内容，等本帧结束再统一挪进内容区。
	call_deferred("_wrap_content")
	_sync_title()


## 打开：写了 open_position 就摆在那儿，没写就居中
## 嵌入子窗口的坐标相对主视口，超出主视口的部分会被夹回来。
func open_window() -> void:
	_wrap_content()
	var target_size := _popup_size()
	size = target_size
	if open_position.x < 0 or open_position.y < 0:
		popup_centered()
	else:
		position = _clamp_position(open_position)
		popup(Rect2i(position, target_size))
	_sync_title()
	grab_focus()
	call_deferred("_grow_to_content")


## 子类在 _ready() 的 super() 之后调用：把按钮加进标题栏，排在关闭按钮左侧。
## 会自动套用关闭按钮的字号、高度、光标和按下高亮。
func add_title_bar_button(button: Button) -> void:
	if _title_bar == null:
		push_warning("BaseWindow：标题栏尚未创建，add_title_bar_button 必须在 super() 之后调用")
		return
	_style_title_bar_button(button)
	_title_bar.add_child(button)
	_title_bar.move_child(button, _close_button.get_index())


#region 标题栏与内容下移
func _build_title_bar() -> void:
	_ui_root = VBoxContainer.new()
	_ui_root.name = "TitleUI"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_theme_constant_override("separation", 0)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)

	_title_bar = HBoxContainer.new()
	_title_bar.name = "TitleBar"
	_title_bar.custom_minimum_size = Vector2i(0, TITLE_BAR_HEIGHT)
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.gui_input.connect(_on_title_bar_gui_input)
	_ui_root.add_child(_title_bar)

	var title_margin := MarginContainer.new()
	title_margin.name = "TitleMargin"
	title_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_margin.add_theme_constant_override("margin_left", 6)
	_title_bar.add_child(title_margin)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title_margin.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "×"
	_close_button.tooltip_text = "关闭"
	_close_button.custom_minimum_size = TITLE_BUTTON_SIZE
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_title_bar_button(_close_button)
	_close_button.pressed.connect(hide)
	_title_bar.add_child(_close_button)

	var right_space := Control.new()
	right_space.custom_minimum_size = Vector2i(TITLE_BUTTON_MARGIN, 0)
	right_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_bar.add_child(right_space)

	_content_root = Control.new()
	_content_root.name = "ContentRoot"
	_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_content_root)


## 标题栏按钮的统一外观：字号、手型光标、垂直居中和按下高亮
func _style_title_bar_button(button: Button) -> void:
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


## 把窗口原有内容挪到标题栏下方，并给窗口补上这一行的高度。
## CanvasLayer 不参与 Control 布局，单独把自己的顶层 Control 往下推。
func _wrap_content() -> void:
	if _wrapped or _content_root == null:
		return
	_wrapped = true
	for child in get_children():
		if child == _ui_root:
			continue
		if child is CanvasLayer:
			_shift_canvas_layer_top(child as CanvasLayer)
			continue
		remove_child(child)
		_content_root.add_child(child)
	size.y += TITLE_BAR_HEIGHT
	min_size.y += TITLE_BAR_HEIGHT


## 打开后下一帧按内容最小尺寸向上撑（只增不减）。必须等窗口可见、内容
## 完成布局后再量：RichTextLabel 的 fit_content 在宽度为 0 时会算出巨大的
## 最小高度，提前量会把窗口错误地撑满整个工作区。
func _grow_to_content() -> void:
	# 再等一帧：刚 popup 的这一帧内容还没布局，RichTextLabel 在宽度 0 时
	# 会报出巨大的最小高度，必须等宽度确定后再量。
	await get_tree().process_frame
	if not visible or _content_root == null:
		return
	var content_min := Vector2.ZERO
	for child in _content_root.get_children():
		if child is Control:
			content_min = content_min.max((child as Control).get_combined_minimum_size())
	var wanted := Vector2i(
		maxi(size.x, int(ceilf(content_min.x))),
		maxi(size.y, int(ceilf(content_min.y)) + TITLE_BAR_HEIGHT)
	)
	var bounds := _parent_viewport_size()
	wanted = Vector2i(mini(wanted.x, bounds.x), mini(wanted.y, bounds.y))
	if wanted != size:
		size = wanted
		position = _clamp_position(position)


## CanvasLayer 的 Control 直接按 viewport 定位，不继承内容区的位置。
## 只推顶边锚定的 Control：底部血条仍然贴着窗口底部。
func _shift_canvas_layer_top(layer: CanvasLayer) -> void:
	for child in layer.get_children():
		if not child is Control:
			continue
		var control := child as Control
		if not is_zero_approx(control.anchor_top):
			continue
		control.offset_top += TITLE_BAR_HEIGHT
		if is_zero_approx(control.anchor_bottom):
			control.offset_bottom += TITLE_BAR_HEIGHT


func _sync_title() -> void:
	if _title_label == null:
		return
	var display := title
	if display.is_empty():
		display = String(name)
	if _title_label.text != display:
		_title_label.text = display


func _popup_size() -> Vector2i:
	var need := Vector2i(get_contents_minimum_size().ceil())
	var wanted := Vector2i(maxi(size.x, need.x), maxi(size.y, need.y))
	var bounds := _parent_viewport_size()
	return Vector2i(mini(wanted.x, bounds.x), mini(wanted.y, bounds.y))


func _parent_viewport_size() -> Vector2i:
	var parent := get_parent()
	if parent == null:
		return Vector2i(1600, 960)
	var viewport := parent.get_viewport()
	if viewport == null:
		return Vector2i(1600, 960)
	return Vector2i(viewport.get_visible_rect().size)


func _clamp_position(target : Vector2i) -> Vector2i:
	var bounds := _parent_viewport_size()
	var max_pos := Vector2i(maxi(bounds.x - size.x, 0), maxi(bounds.y - size.y, 0))
	return target.clamp(Vector2i.ZERO, max_pos)


func _main_viewport_mouse_position() -> Vector2:
	var parent := get_parent()
	if parent == null:
		return Vector2.ZERO
	return parent.get_viewport().get_mouse_position()


func _on_title_bar_gui_input(event : InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_button.pressed:
		_start_drag()
	else:
		_stop_drag()
	_title_bar.accept_event()


func _on_visibility_changed() -> void:
	if not visible:
		_stop_drag()


func _start_drag() -> void:
	if _dragging:
		return
	_dragging = true
	_drag_start_mouse = _main_viewport_mouse_position()
	_drag_start_position = position
	grab_focus()
	if not get_tree().process_frame.is_connected(_update_drag):
		get_tree().process_frame.connect(_update_drag)


## 拖动期间每帧读主视口鼠标，不依赖标题栏的 motion 事件：
## 鼠标快速拖出嵌入窗口边缘时，子窗口可能收不到 motion。
func _update_drag() -> void:
	if not _dragging:
		_stop_drag()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_drag()
		return
	var mouse := _main_viewport_mouse_position()
	position = _clamp_position(_drag_start_position + Vector2i(mouse - _drag_start_mouse))


func _stop_drag() -> void:
	_dragging = false
	var tree := get_tree()
	if tree != null and tree.process_frame.is_connected(_update_drag):
		tree.process_frame.disconnect(_update_drag)
#endregion
