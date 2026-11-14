class_name PetPanel
extends Control
## 主菜单浮层，现在挂在立方体面 02 的 SubViewport 里。
##
## 只负责把菜单按钮的点击转成 panel_requested；位置由立方体放置层统一管理，
## 不再自己拖动或持久化。

## 菜单要打开的窗口 id，由 Main/control.gd::open_panel() 解析
signal panel_requested(panel_id: StringName)

@onready var _grid: GridContainer = $GridContainer


func _ready() -> void:
	for child in _grid.get_children():
		var button := child as Button
		if button == null:
			continue
		var panel_id : StringName = button.get_meta(&"panel_id", &"")
		if panel_id == &"":
			continue
		button.pressed.connect(_on_button_pressed.bind(panel_id))


func _on_button_pressed(panel_id : StringName) -> void:
	panel_requested.emit(panel_id)
