extends RefCounted

const CUBE: GDScript = preload("res://Scripts/test_api/cube.gd")


static func state(_args: PackedStringArray) -> Dictionary:
	return CommandResult.ok(CUBE.get_cube_state())
