extends HBoxContainer

@onready var button: Button = $Button
@onready var button_2: Button = $Button2
@onready var button_6: Button = $Button6


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# button：主界面贴到工作区左下角
	button.pressed.connect(_on_button_pressed)
	# button_2：主窗口（整个应用）置顶
	var main_pinned := WindowPinSettings.load_pin(WindowPinSettings.MAIN_WINDOW_ID)
	get_window().always_on_top = main_pinned
	button_2.toggle_mode = true
	button_2.button_pressed = main_pinned
	button_2.tooltip_text = "主窗口置顶 / 取消置顶"
	button_2.toggled.connect(_on_button_2_toggled)
	var pressed_style := button_2.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	pressed_style.bg_color = GameColors.to_color(GameColors.ACCENT)
	button_2.add_theme_stylebox_override("pressed", pressed_style)
	button_2.add_theme_stylebox_override("hover_pressed", pressed_style)
	button_2.add_theme_color_override("font_pressed_color", GameColors.to_color(GameColors.ACCENT_TEXT))
	button_2.add_theme_color_override("font_hover_pressed_color", GameColors.to_color(GameColors.ACCENT_TEXT))
	# button_6：主界面贴到工作区右下角
	button_6.pressed.connect(_on_button_6_pressed)
	_move_pet_panel(false)


func _on_button_pressed() -> void:
	_move_pet_panel(false)


func _on_button_2_toggled(on: bool) -> void:
	get_window().always_on_top = on
	WindowPinSettings.save_pin(WindowPinSettings.MAIN_WINDOW_ID, on)


func _on_button_6_pressed() -> void:
	_move_pet_panel(true)


## 主界面现在是单窗口工作区里的浮层，</> 移动它在工作区内的位置。
func _move_pet_panel(to_right: bool) -> void:
	var panel := get_parent() as Control
	if panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var x := float(GameGlobal.WINDOWPOSOFFSET)
	if to_right:
		x = viewport_size.x - panel.size.x - GameGlobal.WINDOWPOSOFFSET
	var y := viewport_size.y - panel.size.y - GameGlobal.WINDOWPOSOFFSET
	panel.position = Vector2(x, y)
