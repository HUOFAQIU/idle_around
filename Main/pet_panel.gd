class_name PetPanel
extends Control
## 立方体面 02 的主菜单，挂在面内容的 SubViewport 里。
##
## 只负责把菜单按钮的点击转成 panel_requested；位置由立方体放置层统一管理，
## 自己不做拖动或持久化。

## 菜单要打开的窗口 id，由 Main/control.gd::open_panel() 解析
signal panel_requested(panel_id: StringName)

@onready var _grid: GridContainer = $GridContainer


## 模拟点击指定 id 的菜单按钮，找不到返回 false。
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
