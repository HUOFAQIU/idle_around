extends RefCounted

const MAP: GDScript = preload("res://Scripts/test_api/map.gd")
const ARGS: GDScript = preload("res://Scripts/commands/actions/action_args.gd")

const USAGE_ADD := "map.add [map_id] [slot]"
const USAGE_START := "map.start <slot>"


static func list(_args: PackedStringArray) -> Dictionary:
	return CommandResult.ok(MAP.get_map_ids())


static func add(args: PackedStringArray) -> Dictionary:
	var map_id: StringName = &"forest_map"
	var slot := -1
	if not args.is_empty():
		map_id = StringName(args[0])
	if args.size() > 1:
		var parsed: Dictionary = ARGS.int_arg(args[1], USAGE_ADD)
		if not parsed.ok:
			return parsed
		slot = int(parsed.value)
	var placed: int = MAP.add_map_to_board(map_id, slot)
	if placed < 0:
		return CommandResult.fail("放置失败：地图不存在或地图板已满")
	return CommandResult.ok(placed)


static func state(_args: PackedStringArray) -> Dictionary:
	return CommandResult.ok(MAP.get_map_board_state())


static func start(args: PackedStringArray) -> Dictionary:
	var check: Dictionary = ARGS.require(args, 1, USAGE_START)
	if not check.ok:
		return check
	var parsed: Dictionary = ARGS.int_arg(args[0], USAGE_START)
	if not parsed.ok:
		return parsed
	if not MAP.click_map_start_button(int(parsed.value)):
		return CommandResult.fail("开战失败：该槽没有地图")
	return CommandResult.ok(true)
