extends RefCounted
## soul.* 命令实现；调用 Scripts/test_api/inventory.gd，不重复逻辑。

const INVENTORY: GDScript = preload("res://Scripts/test_api/inventory.gd")
const ARGS: GDScript = preload("res://Scripts/commands/actions/action_args.gd")

const USAGE_ADD := "soul.add <soul_id> [container]"


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
