extends RefCounted

const BATTLE: GDScript = preload("res://scripts/test_api/battle.gd")
const ARGS: GDScript = preload("res://scripts/commands/actions/action_args.gd")

const USAGE_START := "battle.start [map_id]"
const USAGE_SPAWN := "battle.spawn <monster_id>"
const USAGE_DAMAGE := "battle.damage <target> <amount>"


static func start(args: PackedStringArray) -> Dictionary:
	var started := false
	if args.is_empty():
		started = BATTLE.start_battle()
	else:
		started = BATTLE.start_battle(StringName(args[0]))
	if not started:
		return CommandResult.fail("开战失败：找不到战斗窗口或地图")
	return CommandResult.ok(true)


static func stop(_args: PackedStringArray) -> Dictionary:
	BATTLE.stop_battle()
	return CommandResult.ok()


static func state(_args: PackedStringArray) -> Dictionary:
	return CommandResult.ok(BATTLE.get_battle_state())


static func spawn(args: PackedStringArray) -> Dictionary:
	var check: Dictionary = ARGS.require(args, 1, USAGE_SPAWN)
	if not check.ok:
		return check
	if not BATTLE.spawn_monster(StringName(args[0])):
		return CommandResult.fail("刷怪失败：怪物不存在或战斗未运行")
	return CommandResult.ok(true)


static func damage(args: PackedStringArray) -> Dictionary:
	var check: Dictionary = ARGS.require(args, 2, USAGE_DAMAGE)
	if not check.ok:
		return check
	var amount: Dictionary = ARGS.float_arg(args[1], USAGE_DAMAGE)
	if not amount.ok:
		return amount
	if not BATTLE.damage_unit(args[0], float(amount.value)):
		return CommandResult.fail("伤害失败：目标不存在或数值无效")
	return CommandResult.ok(true)
