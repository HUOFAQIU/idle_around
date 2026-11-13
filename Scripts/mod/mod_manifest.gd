class_name ModManifest
extends RefCounted
## mod.json 的解析与基础校验。
##
## 只校验格式和字段；内容路径是否存在、资源类型是否正确由 ModLoader 在挂载后检查。

const SUPPORTED_SCHEMA: int = 1
const ID_PATTERN: String = "^[a-z][a-z0-9_]{2,63}$"
## 已知顶层字段；出现其他字段时只警告，不阻止加载
const KNOWN_KEYS: Array[String] = [
	"schema", "id", "name", "version", "author", "description",
	"game_version", "load_after", "dependencies", "content_namespace",
	"content_root", "content", "overrides",
]

var id: StringName = &""
var name: String = ""
var version: String = "0.0.0"
var author: String = ""
var description: String = ""
var game_version_min: String = ""
var game_version_max: String = ""
var load_after: Array[StringName] = []
var dependencies: Array[StringName] = []
## 内容 ID 命名空间：mod = <mod_id>:<local_id>，global = 直接使用 ID。
## global 只允许内置 mod 使用。
var content_namespace: String = "mod"
## 内置 mod 的内容根目录；空 = res://base_mods/<mod_id>/。
## 只允许内置 mod 使用，第三方 mod 必须把内容放在自己的命名空间目录下。
var content_root: String = ""
## 原样保存 content 段；souls / monsters / vessels / cues 的路径由 ModLoader 解析
var content: Dictionary = {}
var overrides: Array[String] = []
var errors: Array[String] = []
var warnings: Array[String] = []


## 读取并校验 mod.json；失败时 errors 里是原因
func load_from_file(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("mod.json 读取失败：%s" % path)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		errors.append("mod.json 不是合法 JSON 对象：%s" % path)
		return false
	return _apply(parsed as Dictionary)


static func is_valid_id(value: String) -> bool:
	var regex := RegEx.create_from_string(ID_PATTERN)
	return regex.search(value) != null


## 比较点分版本；缺省段按 0 处理
static func compare_versions(a: String, b: String) -> int:
	var a_parts := _version_parts(a)
	var b_parts := _version_parts(b)
	var count := maxi(a_parts.size(), b_parts.size())
	for i in count:
		var a_value := a_parts[i] if i < a_parts.size() else 0
		var b_value := b_parts[i] if i < b_parts.size() else 0
		if a_value < b_value:
			return -1
		if a_value > b_value:
			return 1
	return 0


## min / max 都包含边界；空字符串表示不限制
static func version_in_range(version: String, min_version: String, max_version: String) -> bool:
	if not min_version.is_empty() and compare_versions(version, min_version) < 0:
		return false
	if not max_version.is_empty() and compare_versions(version, max_version) > 0:
		return false
	return true


func _apply(data: Dictionary) -> bool:
	for key in data.keys():
		if not KNOWN_KEYS.has(String(key)):
			warnings.append("未知 manifest 字段：%s" % key)
	var schema := int(data.get("schema", SUPPORTED_SCHEMA))
	if schema != SUPPORTED_SCHEMA:
		errors.append("manifest schema %d 不受支持（当前 %d）" % [schema, SUPPORTED_SCHEMA])
		return false

	var raw_id := String(data.get("id", ""))
	if not is_valid_id(raw_id):
		errors.append("mod id 不合法：%s" % raw_id)
		return false
	id = StringName(raw_id)

	name = String(data.get("name", raw_id))
	version = String(data.get("version", "0.0.0"))
	author = String(data.get("author", ""))
	description = String(data.get("description", ""))
	load_after = _to_string_name_array(data.get("load_after", []))
	dependencies = _to_string_name_array(data.get("dependencies", []))
	overrides = _to_string_array(data.get("overrides", []))

	content_namespace = String(data.get("content_namespace", "mod"))
	if content_namespace != "mod" and content_namespace != "global":
		errors.append("content_namespace 只能是 mod 或 global：%s" % content_namespace)
		return false

	content_root = String(data.get("content_root", "")).simplify_path()
	if not content_root.is_empty():
		if not content_root.begins_with("res://"):
			errors.append("content_root 必须是 res:// 路径：%s" % content_root)
			return false
		if not content_root.ends_with("/"):
			content_root += "/"

	var game_version: Variant = data.get("game_version", {})
	if game_version is Dictionary:
		var version_data := game_version as Dictionary
		game_version_min = String(version_data.get("min", ""))
		game_version_max = String(version_data.get("max", ""))

	var content_data: Variant = data.get("content", {})
	if content_data is Dictionary:
		content = content_data as Dictionary
	elif content_data != null:
		errors.append("content 必须是对象")
		return false

	return errors.is_empty()


static func _to_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item in value:
			var text := String(item)
			if not text.is_empty():
				result.append(StringName(text))
	return result


static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result


static func _version_parts(value: String) -> Array[int]:
	var result: Array[int] = []
	for part in value.split("."):
		var digits := ""
		for character in part:
			if character >= "0" and character <= "9":
				digits += character
			else:
				break
		result.append(int(digits) if not digits.is_empty() else 0)
	return result
