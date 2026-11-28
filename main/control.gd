class_name GameUI
extends Control

const DEFAULT_PANEL_SPECS := {
	&"character": {
		"scene": "res://windows/Character/character_window.tscn",
		"destroy_on_close": true,
	},
	&"inventory": {
		"scene": "res://windows/Inventory/inventory_window.tscn",
		"open_position": Vector2i(735, 20),
	},
	&"battle": {"scene": "res://windows/Battle/battle_window.tscn"},
	&"shop": {"scene": "res://windows/Shop/shop_window.tscn"},
	&"collection": {
		"scene": "res://windows/Collection/collection_window.tscn",
		"destroy_on_close": true,
	},
	&"debug": {
		"scene": "res://windows/Debug/debug_window.tscn",
		"open_position": Vector2i(200, 80),
		"destroy_on_close": true,
	},
	&"terminal": {"scene": "res://windows/Terminal/terminal_window.tscn"},
	&"mod": {
		"script": "res://windows/ModWindow/mod_window.gd",
		"node_name": "ModWindow",
		"rect": Rect2(0.0, 36.0, 640.0, 356.0),
		"destroy_on_close": true,
	},
}

var _panel_specs: Dictionary = DEFAULT_PANEL_SPECS.duplicate(true)
var _panels: Dictionary = {}
var _overlays: Array[Dictionary] = []

@onready var panel_manager: PanelManager = $PanelManager


func _ready() -> void:
	var tooltip := get_node_or_null("TooltipLayer/TooltipWindow") as Control
	if tooltip != null:
		register_overlay(tooltip, true)
	var item_window := get_node_or_null("DragLayer/ItemWindow") as Control
	if item_window != null:
		register_overlay(item_window, false)


func register_panel_spec(panel_id: StringName, spec: Dictionary) -> void:
	if panel_id.is_empty():
		return
	_panel_specs[panel_id] = spec.duplicate(true)


func register_overlay(control: Control, locks_passthrough: bool = false) -> void:
	if control == null:
		return
	for entry in _overlays:
		if entry["node"] == control:
			entry["locks"] = locks_passthrough
			return
	_overlays.append({"node": control, "locks": locks_passthrough})
	control.tree_exiting.connect(unregister_overlay.bind(control))


func unregister_overlay(control: Control) -> void:
	for i in range(_overlays.size() - 1, -1, -1):
		if _overlays[i]["node"] == control:
			_overlays.remove_at(i)


func get_passthrough_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if panel_manager != null:
		rects.append_array(panel_manager.get_visible_panel_rects())
	for entry in _overlays:
		var node := entry["node"] as Control
		if node != null and is_instance_valid(node) and node.is_visible_in_tree():
			rects.append(node.get_global_rect())
	return rects


func should_lock_passthrough() -> bool:
	for entry in _overlays:
		if not bool(entry["locks"]):
			continue
		var node := entry["node"] as Control
		if node != null and is_instance_valid(node) and node.is_visible_in_tree():
			return true
	return false


func get_panel(panel_id: StringName) -> BaseWindow:
	var existing := _panels.get(panel_id) as BaseWindow
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		return existing
	return null


func preload_panel(panel_id: StringName) -> void:
	if get_panel(panel_id) != null or not _panel_specs.has(panel_id):
		return
	var spec: Dictionary = _panel_specs[panel_id]
	var scene_path := String(spec.get("scene", ""))
	if scene_path.is_empty():
		return
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(scene_path)


func ensure_panel(panel_id: StringName) -> BaseWindow:
	var existing := get_panel(panel_id)
	if existing != null:
		return existing
	if not _panel_specs.has(panel_id):
		return null
	var spec: Dictionary = _panel_specs[panel_id]
	var created := _instantiate_panel(spec)
	if created == null:
		return null
	if spec.has("open_position"):
		created.open_position = spec["open_position"]
	created.destroy_on_close = bool(spec.get("destroy_on_close", false))
	created.visible = false
	created.tree_exiting.connect(_on_panel_exiting.bind(panel_id, created))
	add_child(created)
	_panels[panel_id] = created
	return created


func open_panel(panel_id: StringName) -> void:
	var existing := get_panel(panel_id)
	if existing != null and existing.visible:
		close_panel(panel_id)
		return
	panel_manager.open(ensure_panel(panel_id))


func close_panel(panel_id: StringName) -> void:
	var existing := get_panel(panel_id)
	if existing != null:
		existing.request_close()


func destroy_panel(panel_id: StringName) -> void:
	var existing := get_panel(panel_id)
	if existing == null:
		return
	_panels.erase(panel_id)
	existing.hide()
	existing.queue_free()


func close_all_panels() -> void:
	panel_manager.hide_all()


func _on_panel_exiting(panel_id: StringName, panel: BaseWindow) -> void:
	if _panels.get(panel_id) == panel:
		_panels.erase(panel_id)


func _instantiate_panel(spec: Dictionary) -> BaseWindow:
	var scene_path := String(spec.get("scene", ""))
	if not scene_path.is_empty():
		var packed := _load_lazy_scene(scene_path)
		return packed.instantiate() as BaseWindow if packed != null else null
	var script_path := String(spec.get("script", ""))
	if script_path.is_empty():
		return null
	var panel_script := load(script_path) as Script
	if panel_script == null:
		return null
	var ctrl := Control.new()
	var node_name := String(spec.get("node_name", ""))
	if not node_name.is_empty():
		ctrl.name = node_name
	if spec.has("rect"):
		var rect: Rect2 = spec["rect"]
		ctrl.offset_left = rect.position.x
		ctrl.offset_top = rect.position.y
		ctrl.offset_right = rect.position.x + rect.size.x
		ctrl.offset_bottom = rect.position.y + rect.size.y
	ctrl.set_script(panel_script)
	return ctrl as BaseWindow


func _load_lazy_scene(path: String) -> PackedScene:
	var status := ResourceLoader.load_threaded_get_status(path)
	if status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return ResourceLoader.load_threaded_get(path) as PackedScene
	return load(path) as PackedScene
