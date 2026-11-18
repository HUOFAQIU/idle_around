extends RefCounted
## debug.* 命令实现；调用 Scripts/test_api/debug.gd，不重复逻辑。

const DEBUG: GDScript = preload("res://Scripts/test_api/debug.gd")


static func state(_args: PackedStringArray) -> Dictionary:
	return CommandResult.ok(DEBUG.get_debug_snapshot())
