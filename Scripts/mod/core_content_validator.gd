class_name CoreContentValidator
extends RefCounted
## 校验内置 core mod 的 manifest 与磁盘内容是否一致。
##
## 只检查 base_mods/core/mod.json 和内容文件的对应关系；
## 资源类型、内部引用是否可加载仍由 ModLoader 在启动时检查。

## 用 preload 而不是全局类名，保证 modkit 的 --script 无头模式能解析
const ContentNamingUtil: GDScript = preload("res://Scripts/mod/content_naming.gd")

const CORE_ID: String = "core"
const CORE_ROOT: String = "res://base_mods/core"
const MANIFEST_PATH: String = CORE_ROOT + "/mod.json"
const SOUL_SUFFIXES: Array[String] = ["_soul.tres"]
## 新怪物用 _monster；_data 是旧版 core 的兼容后缀
const MONSTER_SUFFIXES: Array[String] = ["_monster.tres", "_data.tres"]
const CUE_SUFFIXES: Array[String] = [".tscn"]


## 返回错误列表；空数组表示 manifest 与内容文件一致
static func validate() -> Array[String]:
	var errors: Array[String] = []
	var manifest := _load_manifest(errors)
	if manifest.is_empty():
		return errors
	_validate_identity(manifest, errors)
	var content := _content_section(manifest, errors)
	if content.is_empty():
		return errors
	_validate_kind(content, "souls", "id", "path", CORE_ROOT.path_join("souls"), SOUL_SUFFIXES, "soul", errors)
	_validate_kind(content, "monsters", "id", "path", CORE_ROOT.path_join("monsters"), MONSTER_SUFFIXES, "monster", errors)
	_validate_kind(content, "cues", "tag", "scene", CORE_ROOT.path_join("cues"), CUE_SUFFIXES, "cue", errors)
	_validate_soul_skills(content, errors)
	return errors


static func _load_manifest(errors: Array[String]) -> Dictionary:
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	if text.is_empty():
		errors.append("读取失败：%s" % MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		errors.append("不是合法 JSON 对象：%s" % MANIFEST_PATH)
		return {}
	return parsed as Dictionary


static func _validate_identity(manifest: Dictionary, errors: Array[String]) -> void:
	var id := String(manifest.get("id", ""))
	if id != CORE_ID:
		errors.append("id 应为 %s，实际为 %s" % [CORE_ID, id])
	var content_namespace := String(manifest.get("content_namespace", "mod"))
	if content_namespace != "global":
		errors.append("content_namespace 应为 global，实际为 %s" % content_namespace)


static func _content_section(manifest: Dictionary, errors: Array[String]) -> Dictionary:
	var content: Variant = manifest.get("content", {})
	if not content is Dictionary:
		errors.append("content 必须是对象")
		return {}
	return content as Dictionary


static func _validate_kind(
	content: Dictionary,
	key: String,
	id_key: String,
	path_key: String,
	dir: String,
	suffixes: Array[String],
	id_kind: String,
	errors: Array[String]
) -> void:
	var raw_entries: Variant = content.get(key, [])
	if not raw_entries is Array:
		errors.append("content.%s 必须是数组" % key)
		return

	var actual := _collect_files(dir, suffixes, errors)
	var declared_ids: Dictionary[String, bool] = {}
	var declared_paths: Dictionary[String, bool] = {}
	for raw_entry in raw_entries:
		if not raw_entry is Dictionary:
			errors.append("content.%s 条目必须是对象" % key)
			continue
		var entry := raw_entry as Dictionary
		var id := String(entry.get(id_key, ""))
		if id.is_empty():
			errors.append("content.%s 条目缺少 %s" % [key, id_key])
		elif declared_ids.has(id):
			errors.append("content.%s 的 %s 重复：%s" % [key, id_key, id])
		else:
			declared_ids[id] = true
			_validate_entry_id(id_kind, id, errors)

		var raw_path := String(entry.get(path_key, ""))
		if raw_path.is_empty():
			errors.append("content.%s 条目缺少 %s：%s" % [key, path_key, id])
			continue
		var path := _resolve_path(CORE_ROOT, raw_path)
		if path.is_empty() or not path.begins_with(dir + "/"):
			errors.append("content.%s 路径越界：%s" % [key, raw_path])
			continue
		if not _has_suffix(path, suffixes):
			errors.append("content.%s 路径后缀应为 %s：%s" % [key, " / ".join(suffixes), path])
		if not FileAccess.file_exists(path):
			errors.append("content.%s 文件不存在：%s" % [key, path])
		if declared_paths.has(path):
			errors.append("content.%s 路径重复：%s" % [key, path])
		else:
			declared_paths[path] = true

	for path in actual:
		if not declared_paths.has(path):
			errors.append("content.%s 缺少 manifest 条目：%s" % [key, path])


static func _validate_entry_id(id_kind: String, id: String, errors: Array[String]) -> void:
	match id_kind:
		"soul":
			if not ContentNamingUtil.is_valid_local_id(id):
				errors.append("魂灵 ID 不合法（小写 snake_case）：%s" % id)
			elif not ContentNamingUtil.is_soul_local_id(id):
				errors.append("魂灵 ID 应以 %s 结尾：%s" % [ContentNamingUtil.SOUL_SUFFIX, id])
		"monster":
			if not ContentNamingUtil.is_valid_local_id(id):
				errors.append("怪物 ID 不合法（小写 snake_case）：%s" % id)
			elif not ContentNamingUtil.is_monster_local_id(id, true):
				errors.append("怪物 ID 应以 %s 结尾（旧内容可用 %s）：%s" % [
					ContentNamingUtil.MONSTER_SUFFIX,
					ContentNamingUtil.LEGACY_MONSTER_SUFFIX,
					id,
				])
		"cue":
			if not ContentNamingUtil.is_valid_tag(id):
				errors.append("Cue 标签不是合法 GAS 标签：%s" % id)


## core 魂灵技能 ID 必须由 content_id 派生，避免同一个 Skill.<id> 被顶掉或拼写漂移
static func _validate_soul_skills(content: Dictionary, errors: Array[String]) -> void:
	var raw_entries: Variant = content.get("souls", [])
	if not raw_entries is Array:
		return
	for raw_entry in raw_entries:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var content_id := String(entry.get("id", ""))
		var raw_path := String(entry.get("path", ""))
		if content_id.is_empty() or raw_path.is_empty():
			continue
		var path := _resolve_path(CORE_ROOT, raw_path)
		if not FileAccess.file_exists(path):
			continue
		var skill_path := _skill_path_from_soul(path)
		if skill_path.is_empty():
			continue
		var skill := ResourceLoader.load(skill_path)
		if skill == null:
			errors.append("魂灵 %s 的技能资源加载失败：%s" % [content_id, skill_path])
			continue
		var expected: String = ContentNamingUtil.skill_suffix(&"", StringName(content_id), true)
		var actual := String(skill.get("id"))
		if actual.is_empty():
			errors.append("魂灵 %s 的技能 id 为空，应为 %s" % [content_id, expected])
		elif actual != expected:
			errors.append("魂灵 %s 的技能 id 应为 %s，实际为 %s" % [content_id, expected, actual])


## 从魂灵 .tres 文本里读 `skill = ExtResource("<id>")`，再找到对应的 ext_resource 路径。
## 不直接加载 SoulData：ItemData 引用 GBIS 等 autoload，modkit 的 --script 模式编译不了。
static func _skill_path_from_soul(soul_path: String) -> String:
	var text := FileAccess.get_file_as_string(soul_path)
	if text.is_empty():
		return ""
	var skill_ref := RegEx.create_from_string("(?m)^skill\\s*=\\s*ExtResource\\(\"([^\"]+)\"\\)").search(text)
	if skill_ref == null:
		return ""
	var ref_id := skill_ref.get_string(1)
	var ext := RegEx.create_from_string(
		"(?m)^\\[ext_resource[^\\]]*path=\"([^\"]+)\"[^\\]]*id=\"%s\"\\]" % ref_id
	).search(text)
	return ext.get_string(1) if ext != null else ""


static func _resolve_path(root: String, raw_path: String) -> String:
	if raw_path.begins_with("res://"):
		return raw_path.simplify_path()
	return root.path_join(raw_path).simplify_path()


static func _collect_files(dir: String, suffixes: Array[String], errors: Array[String]) -> Array[String]:
	var result: Array[String] = []
	if DirAccess.open(dir) == null:
		errors.append("目录不存在：%s" % dir)
		return result
	_collect_files_recursive(dir, suffixes, result)
	result.sort()
	return result


static func _collect_files_recursive(dir: String, suffixes: Array[String], result: Array[String]) -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return
	access.list_dir_begin()
	var entry_name := access.get_next()
	while not entry_name.is_empty():
		if not entry_name.begins_with("."):
			var path := dir.path_join(entry_name)
			if access.current_is_dir():
				_collect_files_recursive(path, suffixes, result)
			elif _has_suffix(entry_name, suffixes):
				result.append(path)
		entry_name = access.get_next()
	access.list_dir_end()


static func _has_suffix(file_name: String, suffixes: Array[String]) -> bool:
	for suffix in suffixes:
		if file_name.ends_with(suffix):
			return true
	return false
