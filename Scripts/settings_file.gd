class_name SettingsFile
extends RefCounted

const SETTINGS_PATH : String = "user://Settings.cfg"


static func load_value(section : String, key : String, default_value : Variant) -> Variant:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Settings: 读取 %s 失败（%d）" % [SETTINGS_PATH, err])
	if not config.has_section_key(section, key):
		return default_value
	return config.get_value(section, key, default_value)


static func has_key(section : String, key : String) -> bool:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	return config.has_section_key(section, key)


static func save_value(section : String, key : String, value : Variant) -> bool:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(section, key, value)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Settings: 写入 %s 失败（%d）" % [SETTINGS_PATH, err])
		return false
	return true
