class_name CommandRegistry
extends RefCounted

const PARSER: GDScript = preload("res://scripts/commands/command_parser.gd")
const CATALOG: GDScript = preload("res://scripts/commands/command_catalog.gd")
const COMPLETION: GDScript = preload("res://scripts/commands/command_completion.gd")


static func run(line: String) -> Dictionary:
	var parsed: Dictionary = PARSER.parse(line)
	if not bool(parsed.get("ok", false)):
		return CommandResult.fail(String(parsed.get("error", "解析失败")))
	var command: String = String(parsed.get("command", ""))
	if command.is_empty():
		return CommandResult.fail("命令为空")
	var args: PackedStringArray = parsed.get("args", PackedStringArray())
	if command == "help":
		return CommandResult.ok(help(args[0] if not args.is_empty() else ""))
	if command == "clear":
		return CommandResult.ok()
	if command == "echo":
		return CommandResult.ok(" ".join(args))
	var entry: Dictionary = CATALOG.get_entry(command)
	if entry.is_empty():
		return CommandResult.fail("未知命令：%s（用 help 查看）" % command)
	var handler: Callable = entry.get("handler")
	if not handler.is_valid():
		return CommandResult.fail("命令没有实现：%s" % command)
	var result := _normalize(handler.call(args))
	if not bool(result.get("ok", false)) and not String(result.get("error", "")).contains("usage:"):
		result["error"] = "%s\nusage: %s" % [result.get("error", ""), entry.get("usage", command)]
	return result


static func help(command := "") -> String:
	var entries: Dictionary = CATALOG.all_entries()
	if not command.is_empty():
		if not entries.has(command):
			return "未知命令：%s" % command
		var entry: Dictionary = entries[command]
		return "%s\n%s" % [entry.get("usage", command), entry.get("summary", "")]
	var names: Array = entries.keys()
	names.sort()
	var lines := PackedStringArray()
	for name in names:
		var entry: Dictionary = entries[name]
		lines.append("%-24s %s" % [entry.get("usage", name), entry.get("summary", "")])
	return "\n".join(lines)


static func command_names() -> PackedStringArray:
	return CATALOG.command_names()


static func complete(line: String, caret: int = -1) -> Dictionary:
	return COMPLETION.complete(line, caret)


static func _normalize(raw: Variant) -> Dictionary:
	if raw is Dictionary and raw.has("ok") and raw.has("value") and raw.has("error"):
		return {
			"ok": bool(raw.get("ok", false)),
			"value": raw.get("value", null),
			"error": String(raw.get("error", "")),
		}
	return CommandResult.ok(raw)
