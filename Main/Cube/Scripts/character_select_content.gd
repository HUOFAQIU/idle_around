class_name CharacterSelectContent
extends FaceContent

signal character_requested(character_id: StringName)

const GRID_CELLS: int = 9

var _buttons: Dictionary = {}

@onready var _grid: GridContainer = $Grid


func _ready() -> void:
	_build()


func content_id() -> StringName:
	return &"character_select"


func activate_character(character_id: StringName) -> bool:
	var button := _buttons.get(character_id) as Button
	if button == null:
		return false
	button.pressed.emit()
	return true


func _build() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var characters := CharacterCatalog.all()
	if characters.size() > GRID_CELLS:
		push_warning(
				"CharacterSelectContent：角色数 %d 超过 3×3 网格上限 %d，超出部分不会显示"
				% [characters.size(), GRID_CELLS])
	for index in GRID_CELLS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(80, 80)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 16)
		if index < characters.size():
			var character := characters[index]
			button.text = character.display_name
			button.pressed.connect(_on_character_pressed.bind(character.id))
			_buttons[character.id] = button
		else:
			button.disabled = true
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(button)


func _on_character_pressed(character_id: StringName) -> void:
	character_requested.emit(character_id)
