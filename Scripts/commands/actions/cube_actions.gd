extends RefCounted
## cube.* 命令实现；调用 Scripts/test_api/cube.gd，不重复逻辑。

const CUBE: GDScript = preload("res://Scripts/test_api/cube.gd")


static func state(_args: PackedStringArray) -> Dictionary:
	return CommandResult.ok(CUBE.get_cube_state())
