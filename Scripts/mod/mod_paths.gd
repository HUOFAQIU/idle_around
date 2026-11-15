class_name ModPaths extends RefCounted
## mod 目录与文件名的唯一来源；其他脚本不要再拼裸路径。
##
## 路径约定见 DOC/架构/Mod系统.md。

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
