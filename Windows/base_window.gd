class_name BaseWindow
extends Window

## 打开时摆在屏幕哪儿；x 或 y 是负数表示「居中」（就按 popup_centered 来）
@export var open_position : Vector2i = Vector2i(-1, -1)

## 置顶状态持久化 ID；留空时用脚本文件名（如 character_window）。
## 节点改名不影响设置；脚本改名或换脚本时显式填写。
@export var window_id : StringName = &""

## 顶部置顶栏
const PIN_ROW_HEIGHT : int = 28
const PIN_BUTTON_SIZE : Vector2i = Vector2i(24, 22)
const PIN_BUTTON_MARGIN : int = 4

## 玩家选择的置顶状态；持久化到 user://Settings.cfg
var _pinned : bool = false
var _pin_button : Button
## 顶部置顶栏 + 下方内容区
var _ui_root : VBoxContainer
var _content_root : Control
## 原窗口内容是否已经挪进 _content_root
var _wrapped : bool = false


func _ready() -> void:
	unresizable = true
	#popup_window = true
	minimize_disabled = true
	maximize_disabled = true

	close_requested.connect(
		func ():
			self.hide()
	)

	_pinned = WindowPinSettings.load_pin(String(get_pin_key()))
	_build_pin_row()
	# 子类 _ready() 在 super() 之后继续加内容，等本帧结束再统一挪进内容区。
	call_deferred("_wrap_content")
	if visible:
		_apply_pin_state()


## 打开：写了 open_position 就摆在那儿，没写就居中
## （由 `control.gd::popup_window()` 调；别直接 popup_centered()，那会把位置覆盖掉）
func open_window() -> void:
	_wrap_content()
	var pinned := _pinned
	if pinned:
		# popup() 会设 transient；置顶窗口不能 transient，这里先临时取消置顶
		always_on_top = false
	if open_position.x < 0 or open_position.y < 0:
		popup_centered()
	else:
		popup(Rect2i(open_position, _popup_size()))
	if pinned:
		_apply_pin_state()


## popup() 会连尺寸一起定，所以别把窗口缩得比内容还小
func _popup_size() -> Vector2i:
	var need := Vector2i(get_contents_minimum_size().ceil())
	return Vector2i(maxi(size.x, need.x), maxi(size.y, need.y))


## 设置本窗口置顶；会写入 user://Settings.cfg
func set_pinned(on: bool) -> void:
	_pinned = on
	if _pin_button != null:
		_pin_button.set_pressed_no_signal(on)
	_apply_pin_state()
	WindowPinSettings.save_pin(String(get_pin_key()), on)


func is_pinned() -> bool:
	return _pinned


## 置顶设置键：优先用显式 window_id，否则用脚本文件名
func get_pin_key() -> StringName:
	if not window_id.is_empty():
		return window_id
	var window_script: Script = get_script()
	if window_script != null and not window_script.resource_path.is_empty():
		return StringName(window_script.resource_path.get_file().get_basename())
	return StringName(name)


func _apply_pin_state() -> void:
	if _pinned:
		if visible:
			transient = false
			always_on_top = true
	else:
		always_on_top = false
		if visible:
			transient = true


#region 顶部置顶栏与内容下移
func _build_pin_row() -> void:
	_ui_root = VBoxContainer.new()
	_ui_root.name = "PinUI"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_theme_constant_override("separation", 0)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)

	var bar := HBoxContainer.new()
	bar.name = "PinBar"
	bar.custom_minimum_size = Vector2i(0, PIN_ROW_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	_pin_button = Button.new()
	_pin_button.name = "PinButton"
	_pin_button.text = "T"
	_pin_button.toggle_mode = true
	_pin_button.focus_mode = Control.FOCUS_NONE
	_pin_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_pin_button.tooltip_text = "置顶 / 取消置顶"
	_pin_button.custom_minimum_size = PIN_BUTTON_SIZE
	_pin_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pin_button.add_theme_font_size_override("font_size", 12)
	var pressed_style := _pin_button.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	if pressed_style != null:
		pressed_style.bg_color = GameColors.to_color(GameColors.ACCENT)
		_pin_button.add_theme_stylebox_override("pressed", pressed_style)
		_pin_button.add_theme_stylebox_override("hover_pressed", pressed_style)
		_pin_button.add_theme_color_override("font_pressed_color", GameColors.to_color(GameColors.ACCENT_TEXT))
		_pin_button.add_theme_color_override("font_hover_pressed_color", GameColors.to_color(GameColors.ACCENT_TEXT))
	bar.add_child(_pin_button)

	var right_space := Control.new()
	right_space.custom_minimum_size = Vector2i(PIN_BUTTON_MARGIN, 0)
	right_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(right_space)

	_content_root = Control.new()
	_content_root.name = "ContentRoot"
	_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_content_root)

	_pin_button.set_pressed_no_signal(_pinned)
	_pin_button.toggled.connect(_on_pin_toggled)


## 把窗口原有内容挪到顶部置顶栏下方，并给窗口补上这一行的高度。
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
	size.y += PIN_ROW_HEIGHT
	min_size.y += PIN_ROW_HEIGHT


## CanvasLayer 的 Control 直接按 viewport 定位，不继承内容区的位置。
## 只推顶边锚定的 Control：底部血条仍然贴着窗口底部。
func _shift_canvas_layer_top(layer: CanvasLayer) -> void:
	for child in layer.get_children():
		if not child is Control:
			continue
		var control := child as Control
		if not is_zero_approx(control.anchor_top):
			continue
		control.offset_top += PIN_ROW_HEIGHT
		if is_zero_approx(control.anchor_bottom):
			control.offset_bottom += PIN_ROW_HEIGHT


func _on_pin_toggled(on: bool) -> void:
	set_pinned(on)
#endregion
