extends ScenarioCase

const MONSTER_ID: StringName = &"snake_monster"
const MONSTER_NAME: String = "蛇"


func case_name() -> StringName:
	return &"battle_movement_status"


func needs_main_scene() -> bool:
	return true


func run(ctx: ScenarioContext) -> void:
	ctx.check(TestAPI.start_battle(), "开始战斗")
	ctx.check(TestAPI.pause_battle(), "切换手动时间")
	ctx.check(TestAPI.spawn_monster(MONSTER_ID), "刷蛇")

	var monster := CollectionDB.get_monster(MONSTER_ID)
	ctx.check(monster != null, "怪物数据存在")
	if monster == null:
		TestAPI.stop_battle()
		return

	var base := TestAPI.get_move_speed(MONSTER_NAME)
	ctx.near(base, monster.move_speed, 0.01, "怪物移速写入属性")

	ctx.check(TestAPI.apply_haste(MONSTER_NAME, 1.0), "施加迅捷")
	ctx.near(TestAPI.get_move_speed(MONSTER_NAME), base * 1.5, 0.01, "迅捷 ×1.5")

	ctx.check(TestAPI.apply_slow(MONSTER_NAME, 3.0), "施加迟缓")
	ctx.near(TestAPI.get_move_speed(MONSTER_NAME), base, 0.01, "迅捷与迟缓抵消")

	ctx.check(TestAPI.step_battle(_ticks(1.2)), "步进 1.2 秒")
	ctx.near(TestAPI.get_move_speed(MONSTER_NAME), base * 0.5, 0.01, "迅捷到期后只剩迟缓")

	ctx.check(TestAPI.step_battle(_ticks(2.0)), "步进 2 秒")
	ctx.near(TestAPI.get_move_speed(MONSTER_NAME), base, 0.01, "迟缓到期后恢复")

	ctx.check(TestAPI.apply_haste(MONSTER_NAME, 1.0), "再次施加迅捷")
	ctx.check(TestAPI.step_battle(_ticks(0.5)), "步进 0.5 秒")
	ctx.check(TestAPI.apply_haste(MONSTER_NAME, 1.0), "刷新迅捷")
	ctx.check(TestAPI.step_battle(_ticks(0.75)), "步进 0.75 秒")
	ctx.near(TestAPI.get_move_speed(MONSTER_NAME), base * 1.5, 0.01, "重复施加只刷新时长")
	ctx.check(TestAPI.step_battle(_ticks(0.5)), "步进到刷新后的到期")
	ctx.near(TestAPI.get_move_speed(MONSTER_NAME), base, 0.01, "刷新到期后恢复")

	TestAPI.stop_battle()


func _ticks(seconds: float) -> int:
	return int(ceil(seconds * 60.0))
