class_name PetPanel
extends Control

signal panel_requested(panel_id: StringName)

@onready var _grid: GridContainer = $GridContainer


func press_button(panel_id: StringName) -> bool:
	for child in _grid.get_children():
		var button := child as PanelMenuButton
		if button == null or button.panel_id != panel_id:
			continue
		button.pressed.emit()
		return true
	return false


func _ready() -> void:
	for child in _grid.get_children():
		var button := child as PanelMenuButton
		if button == null or button.panel_id == &"":
			continue
		button.pressed.connect(_on_button_pressed.bind(button.panel_id))


func _on_button_pressed(panel_id: StringName) -> void:
	panel_requested.emit(panel_id)
