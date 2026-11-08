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
## 旧版键是窗口节点名；首次读取时迁移到稳定 ID
const LEGACY_PIN_KEYS: Dictionary = {
	"main_window": "MainWindow",
	"character_window": "CharacterWindow",
	"equipment_window": "EquipmentWindow",
	"inventory_window": "InventoryWindow",
	"battle_window": "BattleWindow",
	"shop_window": "ShopWindow",
	"collection_window": "CollectionWindow",
	"debug_window": "DebugWindow",
	"info_window": "InfoWindow",
	"mod_window": "ModWindow",
}


static func load_pin(window_id: String, default_value: bool = false) -> bool:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Settings: 读取 %s 失败（%d）" % [SETTINGS_PATH, err])
	if config.has_section_key(PIN_SECTION, window_id):
		return bool(config.get_value(PIN_SECTION, window_id, default_value))

	var legacy_key := String(LEGACY_PIN_KEYS.get(window_id, ""))
	if legacy_key.is_empty() or not config.has_section_key(PIN_SECTION, legacy_key):
		return default_value

	var value := bool(config.get_value(PIN_SECTION, legacy_key, default_value))
	config.set_value(PIN_SECTION, window_id, value)
	config.erase_section_key(PIN_SECTION, legacy_key)
	var save_err := config.save(SETTINGS_PATH)
	if save_err != OK:
		push_warning("Settings: 迁移置顶键失败（%d）：%s → %s" % [save_err, legacy_key, window_id])
	return value


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
