class_name ContentNaming
extends RefCounted

const LOCAL_ID_PATTERN: String = "^[a-z][a-z0-9_]*$"
const TAG_PATTERN: String = "^[A-Z][a-zA-Z0-9]*(\\.[A-Z][a-zA-Z0-9]*)*$"
const SOUL_SUFFIX: String = "_soul"
const MONSTER_SUFFIX: String = "_monster"
const VESSEL_SUFFIX: String = "_vessel"
const MOD_TAG_PREFIX: String = "Mod."


static func is_valid_local_id(value: String) -> bool:
	return _matches(LOCAL_ID_PATTERN, value)


static func is_valid_tag(value: String) -> bool:
	return _matches(TAG_PATTERN, value)


static func to_pascal(value: String) -> String:
	var result := ""
	for part in value.split("_", false):
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result


static func local_id_of(content_id: StringName, mod_id: StringName) -> String:
	var text := String(content_id)
	if mod_id.is_empty():
		return text
	var prefix := String(mod_id) + ":"
	return text.trim_prefix(prefix) if text.begins_with(prefix) else text


static func strip_kind_suffix(local_id: String) -> String:
	for suffix in [SOUL_SUFFIX, MONSTER_SUFFIX, VESSEL_SUFFIX]:
		if local_id.ends_with(suffix) and local_id.length() > suffix.length():
			return local_id.trim_suffix(suffix)
	return local_id


static func skill_suffix(mod_id: StringName, content_id: StringName, global_namespace: bool) -> String:
	var local_id := strip_kind_suffix(local_id_of(content_id, mod_id))
	var pascal_name := to_pascal(local_id)
	if global_namespace:
		return pascal_name
	return "%s%s.%s" % [MOD_TAG_PREFIX, to_pascal(String(mod_id)), pascal_name]


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
