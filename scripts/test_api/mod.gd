extends RefCounted

const COMMON: GDScript = preload("res://scripts/test_api/common.gd")

static func get_mod_list() -> Array[Dictionary]:
	return ModLoader.get_mod_list()


static func get_mod_errors() -> Array[String]:
	return ModLoader.get_errors()


static func get_mod_warnings() -> Array[String]:
	return ModLoader.get_warnings()


static func is_builtin_mod(mod_id : StringName) -> bool:
	var mod := ModLoader.get_mod(mod_id)
	return mod != null and mod.is_builtin()


static func get_mod_content_ids(mod_id : StringName) -> Dictionary:
	var souls: Array[String] = []
	for entry in ModLoader.get_soul_entries():
		if entry.mod_id == mod_id:
			souls.append(String(entry.content_id))
	var monsters: Array[String] = []
	for entry in ModLoader.get_monster_entries():
		if entry.mod_id == mod_id:
			monsters.append(String(entry.content_id))
	var vessels: Array[String] = []
	for entry in ModLoader.get_vessel_entries():
		if entry.mod_id == mod_id:
			vessels.append(String(entry.content_id))
	var cues: Array[String] = []
	for entry in ModLoader.get_cue_entries():
		if entry.mod_id == mod_id:
			cues.append(String(entry.content_id))
	return {
		"souls": souls,
		"monsters": monsters,
		"vessels": vessels,
		"cues": cues,
	}


static func validate_core_manifest() -> Array[String]:
	return CoreContentValidator.validate()


static func get_mod_cues() -> Array[Dictionary]:
	return ModCueRegistrar.get_mod_cues()


static func is_mod_cue_registered(tag : StringName) -> bool:
	return ModCueRegistrar.is_mod_cue_registered(tag)


static func show_mod_window() -> bool:
	var window := _mod_window()
	if window == null:
		return false
	if not window.visible and not COMMON.show_window(window):
		return false
	window.refresh()
	return true


static func get_mod_window_state() -> Dictionary:
	var window := _mod_window()
	return {} if window == null else window.get_test_state()


static func get_mod_load_order() -> Array[StringName]:
	return ModLoader.get_load_order()


static func get_mod_order() -> Array[StringName]:
	return ModLoader.get_user_order()


static func set_mod_order(ids : Array[StringName]) -> bool:
	return ModLoader.set_mod_order(ids)


static func set_mod_enabled(mod_id : StringName, enabled : bool) -> bool:
	return ModLoader.set_mod_enabled(mod_id, enabled)


static func get_orphaned_records() -> Array[Dictionary]:
	return SaveManager.get_orphaned_records()


static func _mod_window() -> ModWindow:
	var window := COMMON.find_node_in_scene(ModWindow) as ModWindow
	if window != null:
		return window
	var ui := COMMON.find_node_in_scene(GameUI) as GameUI
	return ui.ensure_panel(&"mod") as ModWindow if ui != null else null
