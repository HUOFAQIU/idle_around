extends RefCounted

const COMMON: GDScript = preload("res://Scripts/test_api/common.gd")

static func set_window_pinned(window_name : String, pinned : bool) -> bool:
	if window_name != "MainWindow":
		return false
	var main := _main_window()
	if main == null:
		return false
	main.always_on_top = pinned
	WindowPinSettings.save_pin(WindowPinSettings.MAIN_WINDOW_ID, pinned)
	_sync_main_pin_button(pinned)
	return true


static func is_window_pinned(window_name : String) -> bool:
	if window_name != "MainWindow":
		return false
	var main := _main_window()
	return main != null and main.always_on_top


static func get_window_pin_states() -> Dictionary:
	var result := {}
	var main := _main_window()
	if main != null:
		result["MainWindow"] = main.always_on_top
	return result


static func get_cube_screen_position() -> Vector2:
	var placement := _cube_placement()
	return placement.get_screen_center() if placement != null else Vector2(-1, -1)


static func set_cube_screen_position(target_position : Vector2) -> bool:
	var placement := _cube_placement()
	if placement == null:
		return false
	placement.set_screen_center(target_position)
	return true


static func get_active_panel_name() -> String:
	var manager := PanelManager.instance
	if manager == null:
		return ""
	var panel := manager.get_active()
	return String(panel.name) if panel != null else ""


static func get_visible_panel_rects() -> Array[Rect2]:
	var result : Array[Rect2] = []
	var manager := PanelManager.instance
	if manager != null:
		result = manager.get_visible_panel_rects()
	return result


static func _main_window() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root as Window


static func _cube_placement() -> CubePlacement:
	return COMMON.find_node_in_scene(CubePlacement) as CubePlacement


static func _sync_main_pin_button(pinned : bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var status := tree.root.find_child("StatusBarContainer", true, false)
	if status == null:
		return
	var button := status.get_node_or_null("Button2")
	if button is Button:
		(button as Button).set_pressed_no_signal(pinned)
