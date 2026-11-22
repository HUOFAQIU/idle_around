extends RefCounted

const INVENTORY: GDScript = preload("res://Scripts/test_api/inventory.gd")
const SOUL: GDScript = preload("res://Scripts/test_api/soul.gd")
const ARGS: GDScript = preload("res://Scripts/commands/actions/action_args.gd")

const USAGE_ADD := "soul.add <soul_id> [container]"
const USAGE_ROLL := "soul.roll <soul_id> [rarity]"


static func soul_list(_args: PackedStringArray) -> Dictionary:
	return CommandResult.ok(INVENTORY.get_soul_ids())


static func soul_add(args: PackedStringArray) -> Dictionary:
	var check: Dictionary = ARGS.require(args, 1, USAGE_ADD)
	if not check.ok:
		return check
	var container := args[1] if args.size() > 1 else ""
	if not container.is_empty() and not INVENTORY.has_container(container):
		return CommandResult.fail("容器不存在：%s" % container)
	if not INVENTORY.add_soul(StringName(args[0]), container):
		return CommandResult.fail("放入失败：魂灵不存在或容器放不下")
	return CommandResult.ok(true)


static func soul_roll(args: PackedStringArray) -> Dictionary:
	var check: Dictionary = ARGS.require(args, 1, USAGE_ROLL)
	if not check.ok:
		return check
	var rarity := SoulEmotion.DEFAULT_RARITY
	if args.size() > 1:
		var parsed: Dictionary = ARGS.int_arg(args[1], USAGE_ROLL)
		if not parsed.ok:
			return parsed
		rarity = int(parsed.value)
		if rarity < 1 or rarity > 5:
			return CommandResult.fail("稀有度必须是 1~5\nusage: %s" % USAGE_ROLL)
	var result: Dictionary = SOUL.roll_soul_to_warehouse(StringName(args[0]), rarity)
	if result.is_empty():
		return CommandResult.fail("放入失败：魂灵不存在或仓库放不下")
	return CommandResult.ok(result)
