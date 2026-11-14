class_name PanelManager
extends Node
## 面板置顶与激活状态。所有 BaseWindow 都是主视口里的 Control，
## 不再有原生窗口焦点，点谁谁在前由这里统一处理。
##
## 面板必须是本节点父级的直接子节点；运行期新增的直接子节点会自动登记。

static var instance : PanelManager

## 当前激活面板；战斗坐标 tooltip 等按它判断优先级
var _active : BaseWindow
var _registered : Dictionary = {}


func _ready() -> void:
	instance = self
	var parent := get_parent()
	if parent == null:
		return
	parent.child_entered_tree.connect(_on_child_entered_tree)
	for child in parent.get_children():
		_register_panel(child)


func _exit_tree() -> void:
	if instance == self:
		instance = null


## 主界面按钮用：开着就关，关着就打开
func toggle(panel : BaseWindow) -> void:
	if panel == null:
		return
	if panel.visible:
		panel.hide()
		return
	panel.open_window()


## 置顶并设为激活面板
func raise(panel : BaseWindow) -> void:
	if panel == null or not panel.is_visible_in_tree():
		return
	panel.move_to_front()
	_active = panel


func is_active(panel : BaseWindow) -> bool:
	return panel != null and panel.is_visible_in_tree() and _active == panel


func get_active() -> BaseWindow:
	return _active


## 鼠标位置下最上层的可见面板；按子节点顺序判断遮挡
func get_top_panel_at(global_position : Vector2) -> BaseWindow:
	var parent := get_parent()
	if parent == null:
		return null
	var children := parent.get_children()
	for index in range(children.size() - 1, -1, -1):
		var child := children[index]
		if child is BaseWindow:
			var panel := child as BaseWindow
			if panel.is_visible_in_tree() and panel.get_global_rect().has_point(global_position):
				return panel
	return null


## 所有可见面板的全局矩形；供 OverlayPassthrough 收集命中区域
func get_visible_panel_rects() -> Array[Rect2]:
	var result : Array[Rect2] = []
	var parent := get_parent()
	if parent == null:
		return result
	for child in parent.get_children():
		if child is BaseWindow:
			var panel := child as BaseWindow
			if panel.is_visible_in_tree():
				result.append(panel.get_global_rect())
	return result


func _input(event : InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	var panel := get_top_panel_at(get_viewport().get_mouse_position())
	if panel != null:
		raise(panel)


func _register_panel(node : Node) -> void:
	if not node is BaseWindow:
		return
	var panel := node as BaseWindow
	if _registered.has(panel):
		return
	_registered[panel] = true
	panel.visibility_changed.connect(_on_panel_visibility_changed.bind(panel))
	panel.tree_exiting.connect(_unregister_panel.bind(panel))
	if panel.is_visible_in_tree():
		raise(panel)


func _unregister_panel(panel : BaseWindow) -> void:
	_registered.erase(panel)


func _on_child_entered_tree(node : Node) -> void:
	_register_panel(node)


func _on_panel_visibility_changed(panel : BaseWindow) -> void:
	if panel.is_visible_in_tree():
		raise(panel)
		return
	if _active != panel:
		return
	_active = null
	var parent := get_parent()
	if parent == null:
		return
	var children := parent.get_children()
	for index in range(children.size() - 1, -1, -1):
		var child := children[index]
		if child is BaseWindow and (child as BaseWindow).is_visible_in_tree():
			_active = child as BaseWindow
			return
