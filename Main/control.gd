class_name GameUI
extends Control

const LAZY_SCENE_PANELS := {
	&"battle": "res://Windows/Battle/battle_window.tscn",
	&"shop": "res://Windows/Shop/shop_window.tscn",
	&"collection": "res://Windows/Collection/collection_window.tscn",
	&"debug": "res://Windows/Debug/debug_window.tscn",
	&"terminal": "res://Windows/Terminal/terminal_window.tscn",
}
const MOD_WINDOW_SCRIPT_PATH := "res://Windows/ModWindow/mod_window.gd"

var _panels: Dictionary = {}

@onready var character_window: CharacterWindow = $CharacterWindow
@onready var inventory_window: InventoryWindow = $InventoryWindow
@onready var panel_manager: PanelManager = $PanelManager

# why: 懒加载窗口统一标注为 BaseWindow，避免编译期拉起终端/战斗/测试脚本整条依赖链
var battle_window: BaseWindow:
	get:
		return ensure_panel(&"battle")
var shop_window: BaseWindow:
	get:
		return ensure_panel(&"shop")
var collection_window: BaseWindow:
	get:
		return ensure_panel(&"collection")
var debug_window: BaseWindow:
	get:
		return ensure_panel(&"debug")
var mod_window: BaseWindow:
	get:
		return ensure_panel(&"mod")
var terminal_window: BaseWindow:
	get:
		return ensure_panel(&"terminal")


func _ready() -> void:
	_panels = {
		&"character": character_window,
		&"inventory": inventory_window,
	}


func get_panel(panel_id: StringName) -> BaseWindow:
	var existing := _panels.get(panel_id) as BaseWindow
	if existing != null and is_instance_valid(existing):
		return existing
	return null


func preload_panel(panel_id: StringName) -> void:
	if get_panel(panel_id) != null or not LAZY_SCENE_PANELS.has(panel_id):
		return
	var path := String(LAZY_SCENE_PANELS[panel_id])
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)


func ensure_panel(panel_id: StringName) -> BaseWindow:
	var existing := get_panel(panel_id)
	if existing != null:
		return existing
	var created: BaseWindow = null
	if LAZY_SCENE_PANELS.has(panel_id):
		var packed := _load_lazy_scene(String(LAZY_SCENE_PANELS[panel_id]))
		if packed != null:
			created = packed.instantiate() as BaseWindow
		if created != null and panel_id == &"debug":
			created.open_position = Vector2i(200, 80)
	elif panel_id == &"mod":
		var mod_script := load(MOD_WINDOW_SCRIPT_PATH) as Script
		if mod_script != null:
			var ctrl := Control.new()
			ctrl.name = "ModWindow"
			ctrl.offset_top = 36.0
			ctrl.offset_right = 640.0
			ctrl.offset_bottom = 392.0
			ctrl.set_script(mod_script)
			created = ctrl as BaseWindow
	if created == null:
		return null
	created.visible = false
	add_child(created)
	_panels[panel_id] = created
	return created


func open_panel(panel_id: StringName) -> void:
	panel_manager.toggle(ensure_panel(panel_id))


func close_all_panels() -> void:
	panel_manager.hide_all()


func _load_lazy_scene(path: String) -> PackedScene:
	var status := ResourceLoader.load_threaded_get_status(path)
	if status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return ResourceLoader.load_threaded_get(path) as PackedScene
	return load(path) as PackedScene
