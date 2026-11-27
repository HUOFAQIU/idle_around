extends HBoxContainer

@onready var button_2: Button = $Button2


func _ready() -> void:
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


func _on_button_2_toggled(on: bool) -> void:
	get_window().always_on_top = on
	WindowPinSettings.save_pin(WindowPinSettings.MAIN_WINDOW_ID, on)
