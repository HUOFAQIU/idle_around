class_name PetPanelContent
extends FaceContent

signal panel_requested(panel_id: StringName)

@onready var _pet_panel: PetPanel = $PetPanel


func _ready() -> void:
	_pet_panel.panel_requested.connect(_on_panel_requested)


func content_id() -> StringName:
	return &"pet_panel"


func _on_panel_requested(panel_id: StringName) -> void:
	panel_requested.emit(panel_id)
