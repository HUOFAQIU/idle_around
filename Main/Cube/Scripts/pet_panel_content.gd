class_name PetPanelContent
extends FaceContent
## 面 02 内容：PetPanel 主菜单。
##
## 只把菜单的 panel_requested 往立方体外壳外转发；打开哪个窗口由主场景装配决定。

signal panel_requested(panel_id: StringName)

@onready var _pet_panel: PetPanel = $PetPanel


func _ready() -> void:
	_pet_panel.panel_requested.connect(_on_panel_requested)


func _on_panel_requested(panel_id: StringName) -> void:
	panel_requested.emit(panel_id)
