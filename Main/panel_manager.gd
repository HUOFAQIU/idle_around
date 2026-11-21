class_name PanelManager
extends Node

static var instance : PanelManager

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


func toggle(panel : BaseWindow) -> void:
	if panel == null:
		return
	if panel.visible:
		panel.hide()
		return
	panel.open_window()


func raise(panel : BaseWindow) -> void:
	if panel == null or not panel.is_visible_in_tree():
		return
	panel.move_to_front()
	_active = panel


func is_active(panel : BaseWindow) -> bool:
	return panel != null and panel.is_visible_in_tree() and _active == panel


func get_active() -> BaseWindow:
	return _active


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


func hide_all() -> void:
	for panel in _registered.keys():
		var window := panel as BaseWindow
		if window != null:
			window.hide()


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
	var mouse_position := get_viewport().get_mouse_position()
	var cube_surface := CubeInputSurface.instance
	if cube_surface != null and cube_surface.contains_screen_point(mouse_position):
		return
	var panel := get_top_panel_at(mouse_position)
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
