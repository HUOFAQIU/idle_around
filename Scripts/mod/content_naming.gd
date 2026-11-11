class_name ContentNaming
extends RefCounted
## 内容 ID 与 GAS 标签的命名规则、派生工具。
##
## 资源 ID（content_id / local_id）用小写 snake_case；GAS 标签每一段用 PascalCase，
## 因为 GameplayTagRegistry 只接受 `^[A-Z][a-zA-Z0-9]*(\.[A-Z][a-zA-Z0-9]*)*$`。
## 技能 ID 存的是 ability_tag 的后缀（不含 "Skill."），所以也遵循标签格式：
##   core/global: <PascalName>                 例如 ChangGong
##   mod:         Mod.<PascalModId>.<PascalName> 例如 Mod.ExampleSouls.FireWolf

const LOCAL_ID_PATTERN: String = "^[a-z][a-z0-9_]*$"
const TAG_PATTERN: String = "^[A-Z][a-zA-Z0-9]*(\\.[A-Z][a-zA-Z0-9]*)*$"
const SOUL_SUFFIX: String = "_soul"
const MONSTER_SUFFIX: String = "_monster"
## 第三方技能 ID 的固定前缀；core 不使用
const MOD_TAG_PREFIX: String = "Mod."


static func is_valid_local_id(value: String) -> bool:
	return _matches(LOCAL_ID_PATTERN, value)


static func is_valid_tag(value: String) -> bool:
	return _matches(TAG_PATTERN, value)


## snake_case → PascalCase；只用于生成 GAS 标签段
static func to_pascal(value: String) -> String:
	var result := ""
	for part in value.split("_", false):
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result


## content_id → 本地 ID：去掉 "<mod_id>:" 前缀
static func local_id_of(content_id: StringName, mod_id: StringName) -> String:
	var text := String(content_id)
	if mod_id.is_empty():
		return text
	var prefix := String(mod_id) + ":"
	return text.trim_prefix(prefix) if text.begins_with(prefix) else text


## 去掉可识别的类型后缀，得到命名主干
static func strip_kind_suffix(local_id: String) -> String:
	for suffix in [SOUL_SUFFIX, MONSTER_SUFFIX]:
		if local_id.ends_with(suffix) and local_id.length() > suffix.length():
			return local_id.trim_suffix(suffix)
	return local_id


## 技能 ID（ability_tag 的后缀）
static func skill_suffix(mod_id: StringName, content_id: StringName, global_namespace: bool) -> String:
	var local_id := strip_kind_suffix(local_id_of(content_id, mod_id))
	var pascal_name := to_pascal(local_id)
	if global_namespace:
		return pascal_name
	return "%s%s.%s" % [MOD_TAG_PREFIX, to_pascal(String(mod_id)), pascal_name]


## 技能 ID 是否属于对应命名空间；core 不允许占用 Mod.*
static func is_skill_suffix_allowed(suffix: String, mod_id: StringName, global_namespace: bool) -> bool:
	if not is_valid_tag(suffix):
		return false
	if global_namespace:
		return not suffix.begins_with(MOD_TAG_PREFIX)
	return suffix.begins_with("%s%s." % [MOD_TAG_PREFIX, to_pascal(String(mod_id))])


static func _matches(pattern: String, value: String) -> bool:
	if value.is_empty():
		return false
	return RegEx.create_from_string(pattern).search(value) != null
