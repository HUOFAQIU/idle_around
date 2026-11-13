class_name WindowPinSettings
extends RefCounted
## 主窗口置顶状态持久化。
##
## 文件：user://Settings.cfg
## 段：[window_pins]，键：main_window，值：bool。
## 单窗口模式下只有整个应用可以置顶，面板不再各自持久化置顶状态。

const PIN_SECTION : String = "window_pins"
## 主窗口的稳定键
const MAIN_WINDOW_ID : String = "main_window"


static func load_pin(window_id : String, default_value : bool = false) -> bool:
	return bool(SettingsFile.load_value(PIN_SECTION, window_id, default_value))


static func save_pin(window_id : String, pinned : bool) -> bool:
	return SettingsFile.save_value(PIN_SECTION, window_id, pinned)
