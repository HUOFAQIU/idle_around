class_name WindowPinSettings
extends RefCounted

const PIN_SECTION : String = "window_pins"
const MAIN_WINDOW_ID : String = "main_window"


static func load_pin(window_id : String, default_value : bool = false) -> bool:
	return bool(SettingsFile.load_value(PIN_SECTION, window_id, default_value))


static func save_pin(window_id : String, pinned : bool) -> bool:
	return SettingsFile.save_value(PIN_SECTION, window_id, pinned)
