extends ScenarioCase


func case_name() -> StringName:
	return &"battle_run"


func needs_main_scene() -> bool:
	return true


func run(ctx: ScenarioContext) -> void:
	ctx.check(TestAPI.start_battle(), "开始战斗")
	ctx.check(TestAPI.pause_battle(), "切换手动时间")

	var state := TestAPI.get_battle_state()
	ctx.check(bool(state["running"]), "战斗处于运行状态")
	var player: Dictionary = state["player"]
	ctx.check(not player.is_empty() and float(player["hp"]) > 0.0, "玩家已生成且有生命值")
	ctx.check(not (state["enemies"] as Array).is_empty(), "初始敌人已生成")
	ctx.check(String(state["map_id"]) != "", "战斗绑定了地图")

	ctx.check(TestAPI.step_battle(120), "手动推进 120 tick")
	ctx.equal(TestAPI.get_battle_tick(), 120, "战斗 tick")
	state = TestAPI.get_battle_state()
	ctx.near(float(state["elapsed"]), 2.0, 0.01, "战斗时间")
	var enemy_count := (state["enemies"] as Array).size()

	ctx.check(TestAPI.damage_unit("enemy", 1000000.0), "对敌人注入致命伤害")
	await (Engine.get_main_loop() as SceneTree).process_frame

	state = TestAPI.get_battle_state()
	ctx.equal((state["enemies"] as Array).size(), enemy_count - 1, "敌人死亡后离场")
	var kills := 0
	for count in (state["map_kills"] as Dictionary).values():
		kills += int(count)
	ctx.equal(kills, 1, "击杀计入地图击杀数")

	TestAPI.stop_battle()
	ctx.check(not bool(TestAPI.get_battle_state()["running"]), "停止战斗")
