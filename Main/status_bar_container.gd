extends HBoxContainer

@onready var button: Button = $Button
@onready var button_2: Button = $Button2
@onready var button_6: Button = $Button6

var usable: Rect2i = DisplayServer.screen_get_usable_rect()
var win: Vector2i = DisplayServer.window_get_size()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# button
	button.pressed.connect(_on_button_pressed)
	# button_2
	button_2.toggle_mode = true
	button_2.button_pressed = get_window().always_on_top
	button_2.toggled.connect(_on_button_2_toggled)
	var pressed_style := button_2.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color("#3ddc4a")
	button_2.add_theme_stylebox_override("pressed", pressed_style)
	button_2.add_theme_stylebox_override("hover_pressed", pressed_style)
	button_2.add_theme_color_override("font_pressed_color", Color("#062b0a"))
	button_2.add_theme_color_override("font_hover_pressed_color", Color("#062b0a"))
	# button_6
	button_6.pressed.connect(_on_button_6_pressed)

 
func _on_button_pressed() -> void:
	# 左下角：x 贴左边(usable.position.x)，y 贴可用区域底边减去窗口高度
	var pos := Vector2i(usable.position.x + GameGlobal.WINDOWPOSOFFSET, usable.position.y + usable.size.y - win.y - GameGlobal.WINDOWPOSOFFSET)
	DisplayServer.window_set_position(pos)


func _on_button_2_toggled(on: bool) -> void:
	get_window().always_on_top = on


func _on_button_6_pressed() -> void:
	var pos := Vector2i(usable.position.x + usable.size.x - win.x - GameGlobal.WINDOWPOSOFFSET, usable.position.y + usable.size.y - win.y - GameGlobal.WINDOWPOSOFFSET)
	DisplayServer.window_set_position(pos)
