class_name PetPanelSettings
extends RefCounted
## PetPanel 位置持久化。
##
## 文件：user://Settings.cfg
## 段：[pet_panel]，键：position，值：Vector2（主视口坐标）。

const PANEL_SECTION : String = "pet_panel"
const POSITION_KEY : String = "position"
## 没有保存过位置时的返回值
const NO_SAVED_POSITION : Vector2 = Vector2(-1, -1)


static func has_position() -> bool:
	return SettingsFile.has_key(PANEL_SECTION, POSITION_KEY)


static func load_position(default_value : Vector2 = NO_SAVED_POSITION) -> Vector2:
	var value : Variant = SettingsFile.load_value(PANEL_SECTION, POSITION_KEY, default_value)
	return value if value is Vector2 else default_value


static func save_position(position : Vector2) -> bool:
	return SettingsFile.save_value(PANEL_SECTION, POSITION_KEY, position)
