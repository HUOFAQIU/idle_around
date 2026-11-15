class_name GameColorCatalog
extends RefCounted
## 色板目录：从 GameColors 和 TerminalPalette 派生只读数据。
##
## 编辑器色板 Dock 与 TestAPI 共用这里的分组、别名和校验逻辑；
## 颜色值仍以 GameColors / TerminalPalette 为准，这里不保存任何色值。

## 用 preload 而不是全局类名，保证 --script 无头模式也能解析。
const GAME_COLORS_SCRIPT : GDScript = preload("res://Scripts/game_colors.gd")
const TERMINAL_PALETTE_SCRIPT : GDScript = preload("res://Scripts/terminal/terminal_palette.gd")


## 按 GameColors.GROUPS 返回分组；每组含 title 和 colors（name/hex/color）
static func groups() -> Array[Dictionary]:
	var constants := _game_constants()
	var raw_groups: Dictionary = constants.get("GROUPS", {})
	var result: Array[Dictionary] = []
	for title in raw_groups:
		var entries: Array[Dictionary] = []
		for name in raw_groups[title]:
			var hex := _hex_of_constant(String(name), constants)
			if hex.is_empty():
				continue
			entries.append(_entry(String(name), hex))
		result.append({"title": String(title), "colors": entries})
	return result


## 同色别名：同一个色值被多个常量使用时，返回 {hex, color, names}
static func aliases() -> Array[Dictionary]:
	var constants := _game_constants()
	var by_key: Dictionary = {}
	var hexes: Dictionary = {}
	var primary := _primary_colors(constants)
	for name in primary:
		_add_alias(by_key, hexes, String(name), String(primary[name]))
	var color_constants := _color_constants(constants)
	for name in color_constants:
		_add_alias(by_key, hexes, String(name), String(color_constants[name]))
	var result: Array[Dictionary] = []
	for key in by_key:
		var names: Array = by_key[key]
		if names.size() < 2:
			continue
		var hex: String = hexes[key]
		result.append({"hex": hex, "color": Color.html(hex), "names": names})
	return result


## GameColors 中未出现在 GROUPS 的颜色常量；每项含 name/hex/color
static func ungrouped() -> Array[Dictionary]:
	var constants := _game_constants()
	var grouped := _grouped_names(constants)
	var primary := _primary_colors(constants)
	var result: Array[Dictionary] = []
	for name in primary:
		if grouped.has(name):
			continue
		result.append(_entry(String(name), String(primary[name])))
	return result


## GameColors.STATUS：显示名 → 颜色；每项含 name/hex/color
static func status_entries() -> Array[Dictionary]:
	var constants := _game_constants()
	var status: Dictionary = constants.get("STATUS", {})
	var result: Array[Dictionary] = []
	for label in status:
		var hex := String(status[label])
		if not Color.html_is_valid(hex):
			continue
		result.append(_entry(String(label), hex))
	return result


## 终端 16 色 + 默认前景/背景；与 GameColors 是两套独立色板
static func terminal_palette() -> Dictionary:
	var constants := TERMINAL_PALETTE_SCRIPT.get_script_constant_map()
	var colors: Array[Dictionary] = []
	var raw_colors: Array = constants.get("COLORS", [])
	for index in raw_colors.size():
		colors.append(_entry("ANSI %d" % index, String(raw_colors[index])))
	var defaults: Array[Dictionary] = []
	for key in ["DEFAULT_FG", "DEFAULT_BG"]:
		var hex := String(constants.get(key, ""))
		if not Color.html_is_valid(hex):
			continue
		var label := "默认前景" if key == "DEFAULT_FG" else "默认背景"
		defaults.append(_entry(label, hex))
	return {"colors": colors, "defaults": defaults}


## 常量数量与唯一色值数量（含 Color 常量别名）
static func stats() -> Dictionary:
	var constants := _game_constants()
	var primary := _primary_colors(constants)
	var color_constants := _color_constants(constants)
	var unique: Dictionary = {}
	for name in primary:
		unique[_color_key(String(primary[name]))] = true
	for name in color_constants:
		unique[_color_key(String(color_constants[name]))] = true
	return {
		"constants": primary.size() + color_constants.size(),
		"unique": unique.size(),
	}


## 返回分组配置的问题；空数组表示所有颜色常量都已归类
static func validate() -> Array[String]:
	var constants := _game_constants()
	var raw_groups: Dictionary = constants.get("GROUPS", {})
	var problems: Array[String] = []
	var seen: Dictionary = {}
	for title in raw_groups:
		for name in raw_groups[title]:
			var key := String(name)
			if not constants.has(key):
				problems.append("分组「%s」引用了不存在的常量 %s" % [title, key])
				continue
			var value: Variant = constants[key]
			if not (value is String and Color.html_is_valid(value)):
				problems.append("分组「%s」的 %s 不是十六进制颜色常量" % [title, key])
				continue
			if seen.has(key):
				problems.append("颜色常量 %s 被重复归类：%s、%s" % [key, seen[key], title])
				continue
			seen[key] = String(title)
	var primary := _primary_colors(constants)
	var primary_keys: Dictionary = {}
	for name in primary:
		if not seen.has(name):
			problems.append("颜色常量 %s 未归类" % name)
		primary_keys[_color_key(String(primary[name]))] = true
	var color_constants := _color_constants(constants)
	for name in color_constants:
		if not primary_keys.has(_color_key(String(color_constants[name]))):
			problems.append("Color 常量 %s 没有对应的字符串颜色常量" % name)
	return problems


static func _game_constants() -> Dictionary:
	return GAME_COLORS_SCRIPT.get_script_constant_map()


## 值是可解析的十六进制字符串的常量 → name: hex
static func _primary_colors(constants: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for name in constants:
		var value: Variant = constants[name]
		if value is String and Color.html_is_valid(value):
			result[String(name)] = String(value)
	return result


## Color 类型的常量（构造默认参数用的别名）→ name: hex
static func _color_constants(constants: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for name in constants:
		var value: Variant = constants[name]
		if value is Color:
			result[String(name)] = (value as Color).to_html()
	return result


static func _hex_of_constant(name: String, constants: Dictionary) -> String:
	var value: Variant = constants.get(name)
	if value is String and Color.html_is_valid(value):
		return String(value)
	return ""


static func _grouped_names(constants: Dictionary) -> Dictionary:
	var raw_groups: Dictionary = constants.get("GROUPS", {})
	var result: Dictionary = {}
	for title in raw_groups:
		for name in raw_groups[title]:
			result[String(name)] = true
	return result


static func _add_alias(by_key: Dictionary, hexes: Dictionary, name: String, hex: String) -> void:
	var key := _color_key(hex)
	if not by_key.has(key):
		by_key[key] = []
		hexes[key] = hex
	by_key[key].append(name)


static func _color_key(hex: String) -> String:
	return Color.html(hex).to_html()


static func _entry(name: String, hex: String) -> Dictionary:
	return {"name": name, "hex": hex, "color": Color.html(hex)}
