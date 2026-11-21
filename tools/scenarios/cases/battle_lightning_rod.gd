extends ScenarioCase

const VESSEL_ID: StringName = &"mei_you_deng_vessel"
const SOUL_ID: StringName = &"bi_lei_zhen_soul"
const MONSTER_ID: StringName = &"snake_monster"
const MONSTER_NAME: String = "蛇"
const SNAKE_SOUL_NAME: String = "毒牙"
const FREEZE_DAMAGE: float = 60.0


func case_name() -> StringName:
	return &"battle_lightning_rod"


func needs_main_scene() -> bool:
	return true


func run(ctx: ScenarioContext) -> void:
	ctx.check(TestAPI.add_vessel(VESSEL_ID), "入仓魂器")
	ctx.check(TestAPI.equip_vessel(VESSEL_ID), "装备魂器")
	ctx.check(TestAPI.add_soul(SOUL_ID), "入仓避雷针")
	ctx.check(TestAPI.vessel_add_soul(SOUL_ID), "放入魂器")

	var tooltip := TestAPI.get_soul_tooltip_text(SOUL_ID)
	ctx.check(tooltip.contains("[大型][武器]"), "tooltip 显示尺寸与武器类型")
	ctx.check(tooltip.contains("攻击距离，10"), "tooltip 攻击距离")

	ctx.check(TestAPI.start_battle(), "开始战斗")
	ctx.check(TestAPI.pause_battle(), "切换手动时间")
	ctx.check(TestAPI.spawn_monster(MONSTER_ID), "刷蛇")

	var before := _enemy_hp(MONSTER_NAME)
	ctx.check(before > 0.0, "蛇已生成")
	ctx.check(TestAPI.apply_freeze(MONSTER_NAME), "冻结蛇")
	ctx.near(_enemy_hp(MONSTER_NAME), before - FREEZE_DAMAGE, 0.5, "冻结触发伤害")

	var player_cell: Array = (TestAPI.get_battle_state()["player"] as Dictionary)["cell"]
	ctx.check(
		TestAPI.move_unit_to_cell(MONSTER_NAME, Vector2i(int(player_cell[0]) + 12, int(player_cell[1]))),
		"移到 12 格外"
	)
	var far_hp := _enemy_hp(MONSTER_NAME)
	ctx.check(TestAPI.apply_freeze(MONSTER_NAME), "再冻结")
	ctx.near(_enemy_hp(MONSTER_NAME), far_hp, 0.5, "超出射程不触发")

	ctx.check(TestAPI.move_unit_to_cell(MONSTER_NAME, Vector2i(int(player_cell[0]) + 2, int(player_cell[1]))), "移回射程内")
	var slow_hp := _enemy_hp(MONSTER_NAME)
	ctx.check(TestAPI.apply_soul_slow(SNAKE_SOUL_NAME, 1.0, MONSTER_NAME), "减速敌方魂灵")
	ctx.near(_enemy_hp(MONSTER_NAME), maxf(slow_hp - FREEZE_DAMAGE, 0.0), 0.5, "减速触发伤害")

	TestAPI.stop_battle()


func _enemy_hp(name: String) -> float:
	var state := TestAPI.get_battle_state()
	for enemy in state["enemies"] as Array:
		if String(enemy["name"]) == name:
			return float(enemy["hp"])
	return -1.0
