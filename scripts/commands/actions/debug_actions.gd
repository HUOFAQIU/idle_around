extends RefCounted

const DEBUG: GDScript = preload("res://scripts/test_api/debug.gd")


static func state(_args: PackedStringArray) -> Dictionary:
	return CommandResult.ok(DEBUG.get_debug_snapshot())
