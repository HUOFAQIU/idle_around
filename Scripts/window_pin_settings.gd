class_name WindowPinSettings
extends RefCounted
## 窗口置顶状态持久化。
##
## 文件：user://Settings.cfg
## 段：[window_pins]，键：BaseWindow.get_pin_key()（默认脚本文件名，如 character_window）
## 或 MAIN_WINDOW_ID（主窗口），值：bool。

const SETTINGS_PATH: String = "user://Settings.cfg"
const PIN_SECTION: String = "window_pins"
## 主窗口不是 BaseWindow，单独占一个稳定键
const MAIN_WINDOW_ID: String = "main_window"


static func load_pin(window_id: String, default_value: bool = false) -> bool:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Settings: 读取 %s 失败（%d）" % [SETTINGS_PATH, err])
	return bool(config.get_value(PIN_SECTION, window_id, default_value))


static func save_pin(window_id: String, pinned: bool) -> bool:
	var config := ConfigFile.new()
	# 文件不存在或格式坏掉时按空配置处理，写入时保留同文件里的其他段。
	config.load(SETTINGS_PATH)
	config.set_value(PIN_SECTION, window_id, pinned)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Settings: 写入 %s 失败（%d）" % [SETTINGS_PATH, err])
		return false
	return true
