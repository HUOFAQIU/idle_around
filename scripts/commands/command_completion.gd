class_name CommandCompletion
extends RefCounted

const PARSER: GDScript = preload("res://scripts/commands/command_parser.gd")
const CATALOG: GDScript = preload("res://scripts/commands/command_catalog.gd")


static func complete(line: String, caret: int = -1) -> Dictionary:
	var span: Dictionary = PARSER.token_at(line, caret)
	var start := int(span.get("start", 0))
	var end := int(span.get("end", start))
	var pos := clampi(caret if caret >= 0 else line.length(), 0, line.length())
	var prefix := line.substr(start, pos - start)
	var result := {
		"ok": true,
		"start": start,
		"end": end,
		"prefix": prefix,
		"token_index": int(span.get("index", 0)),
		"candidates": PackedStringArray(),
		"common_prefix": "",
		"usage": "",
		"summary": "",
		"error": "",
	}
	if bool(span.get("quoted", false)):
		result["ok"] = false
		result["error"] = "带引号的 token 不补全"
		return result
	var candidates := PackedStringArray()
	if int(result["token_index"]) == 0:
		candidates = _filter(CATALOG.command_names(), prefix)
	else:
		var command := _command_before(line, start)
		var entry: Dictionary = CATALOG.get_entry(command)
		result["usage"] = String(entry.get("usage", ""))
		result["summary"] = String(entry.get("summary", ""))
		candidates = _argument_candidates(entry, int(result["token_index"]), prefix)
	result["candidates"] = candidates
	result["common_prefix"] = _common_prefix(candidates)
	return result


static func _argument_candidates(
	entry: Dictionary, token_index: int, prefix: String
) -> PackedStringArray:
	var completers: Array = entry.get("complete", [])
	var arg_index := token_index - 1
	if arg_index < 0 or arg_index >= completers.size():
		return PackedStringArray()
	var completer: Callable = completers[arg_index]
	if not completer.is_valid():
		return PackedStringArray()
	return _filter(_to_packed(completer.call()), prefix)


static func _command_before(line: String, token_start: int) -> String:
	var parsed: Dictionary = PARSER.parse(line.substr(0, token_start))
	if not bool(parsed.get("ok", false)):
		return ""
	return String(parsed.get("command", ""))


static func _filter(candidates: PackedStringArray, prefix: String) -> PackedStringArray:
	var result := PackedStringArray()
	for candidate in candidates:
		if prefix.is_empty() or candidate.begins_with(prefix):
			result.append(candidate)
	result.sort()
	return result


static func _common_prefix(candidates: PackedStringArray) -> String:
	if candidates.is_empty():
		return ""
	var prefix := candidates[0]
	for candidate in candidates:
		while not candidate.begins_with(prefix):
			prefix = prefix.substr(0, prefix.length() - 1)
			if prefix.is_empty():
				return ""
	return prefix


static func _to_packed(raw: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if raw is Array or raw is PackedStringArray:
		for item in raw:
			result.append(String(item))
	return result
