class_name ModPaths extends RefCounted

const BUILTIN_MODS_DIR: String = "res://base_mods"
const USER_MODS_DIR: String = "user://mods"
const RES_MODS_DIR: String = "res://mods"
const CONFIG_PATH: String = "user://mods.cfg"
const CORE_ROOT: String = "res://base_mods/core"
const MANIFEST_FILE: String = "mod.json"


static func builtin_mod_dir(mod_id: StringName) -> String:
	return BUILTIN_MODS_DIR + "/" + String(mod_id) + "/"


static func user_mod_dir(mod_id: StringName) -> String:
	return USER_MODS_DIR + "/" + String(mod_id) + "/"


static func res_mod_dir(mod_id: StringName) -> String:
	return RES_MODS_DIR + "/" + String(mod_id) + "/"
