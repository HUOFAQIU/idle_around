class_name CharacterSelectContent
extends FaceContent
## 面 04 内容：角色选择网格。
##
## 角色列表来自 CharacterCatalog；空位保留为禁用按钮，点击角色只发出请求，
## 创建存档和面切换由 GameFlow 决定。

signal character_requested(character_id: StringName)

const GRID_CELLS: int = 9

var _buttons: Dictionary = {}

@onready var _grid: GridContainer = $Grid


func _ready() -> void:
	_build()


func content_id() -> StringName:
	return &"character_select"


## 测试/调试：走与鼠标点击相同的按钮信号
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
			# 空角色位只作视觉占位，不拦鼠标，拖动仍可旋转立方体
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(button)


func _on_character_pressed(character_id: StringName) -> void:
	character_requested.emit(character_id)
