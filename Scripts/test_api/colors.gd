extends RefCounted
## TestAPI 颜色域：色板取值与校验。
##
## 对外入口仍是 res://Scripts/test_api.gd 的 TestAPI。

## 色板脚本：用于按常量名取色
const GAME_COLORS_SCRIPT : GDScript = preload("res://Scripts/game_colors.gd")
## 色板目录：分组、别名、校验
const GAME_COLOR_CATALOG : GDScript = preload("res://Scripts/game_color_catalog.gd")

static func get_game_color(constant_name : String) -> String:
	var value: Variant = GAME_COLORS_SCRIPT.get_script_constant_map().get(constant_name, "")
	if value is Color:
		return (value as Color).to_html()
	return String(value)


static func get_color_catalog() -> Dictionary:
	return {
		"groups": GAME_COLOR_CATALOG.groups(),
		"aliases": GAME_COLOR_CATALOG.aliases(),
		"ungrouped": GAME_COLOR_CATALOG.ungrouped(),
		"status": GAME_COLOR_CATALOG.status_entries(),
		"terminal": GAME_COLOR_CATALOG.terminal_palette(),
	}


static func validate_color_groups() -> Array[String]:
	return GAME_COLOR_CATALOG.validate()
