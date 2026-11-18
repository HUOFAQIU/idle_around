extends RefCounted
## save.* 命令实现；调用 Scripts/test_api/save.gd，不重复逻辑。

const SAVE: GDScript = preload("res://Scripts/test_api/save.gd")
const ARGS: GDScript = preload("res://Scripts/commands/actions/action_args.gd")

const USAGE_LOAD := "save.load <slot>"


static func new_game(args: PackedStringArray) -> Dictionary:
	var character_id: StringName = &"small_coal_lamp"
	if not args.is_empty():
		character_id = StringName(args[0])
	if not SAVE.new_game(character_id):
		return CommandResult.fail("新游戏失败：角色不存在或流程状态不对")
	return CommandResult.ok(true)


static func load(args: PackedStringArray) -> Dictionary:
	var check: Dictionary = ARGS.require(args, 1, USAGE_LOAD)
	if not check.ok:
		return check
	var parsed: Dictionary = ARGS.int_arg(args[0], USAGE_LOAD)
	if not parsed.ok:
		return parsed
	if not SAVE.load_save_slot(int(parsed.value)):
		return CommandResult.fail("读档失败：槽位不存在或存档不可读")
	return CommandResult.ok(true)


static func now(_args: PackedStringArray) -> Dictionary:
	if not SAVE.save_now():
		return CommandResult.fail("保存失败：没有活动槽")
	return CommandResult.ok(true)
