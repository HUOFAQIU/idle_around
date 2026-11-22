extends ScenarioCase

const VESSEL_ID: StringName = &"mei_you_deng_vessel"
const SOUL_ID: StringName = &"sheng_suo_soul"
const MONSTER_ID: StringName = &"snake_monster"
const MONSTER_NAME: String = "蛇"
const SOUL_NAME: String = "绳索"
const SWIFT_UNIT: GameplayEffect = preload("res://base_mods/core/effects/swift_unit.tres")
const SLUGGISH_UNIT: GameplayEffect = preload("res://base_mods/core/effects/sluggish_unit.tres")
const FREEZE_UNIT: GameplayEffect = preload("res://base_mods/core/effects/freeze_unit.tres")


func case_name() -> StringName:
	return &"battle_rope_slow"


func needs_main_scene() -> bool:
	return true


func run(ctx: ScenarioContext) -> void:
	ctx.check(TestAPI.add_vessel(VESSEL_ID), "入仓魂器")
	ctx.check(TestAPI.equip_vessel(VESSEL_ID), "装备魂器")
	ctx.check(TestAPI.add_soul(SOUL_ID), "入仓绳索")
	ctx.check(TestAPI.vessel_add_soul(SOUL_ID), "放入魂器")

	var tooltip := TestAPI.get_soul_tooltip_text(SOUL_ID)
	ctx.check(tooltip.contains("[小型]"), "tooltip 尺寸")
	ctx.check(tooltip.contains("攻击距离，5"), "tooltip 攻击距离")
	ctx.check(tooltip.contains("( 4 秒 )"), "tooltip 冷却")
	ctx.check(tooltip.contains("迟缓一个怪物 2 秒"), "tooltip 效果时长")

	ctx.near(SWIFT_UNIT.duration, 1.0, 0.001, "迅捷默认 1 秒")
	ctx.near(SLUGGISH_UNIT.duration, 1.0, 0.001, "迟缓默认 1 秒")
	ctx.near(FREEZE_UNIT.duration, 1.0, 0.001, "冻结默认 1 秒")

	ctx.check(TestAPI.start_battle(), "开始战斗")
	ctx.check(TestAPI.pause_battle(), "切换手动时间")
	await _clear_enemies(ctx)
	ctx.check((TestAPI.get_battle_state()["enemies"] as Array).is_empty(), "场上没有其他敌人")

	ctx.check(TestAPI.spawn_monster(MONSTER_ID), "刷远处蛇")
	var player_cell: Array = (TestAPI.get_battle_state()["player"] as Dictionary)["cell"]
	ctx.check(
		TestAPI.move_unit_to_cell(
			MONSTER_NAME, Vector2i(int(player_cell[0]) + 8, int(player_cell[1]))
		),
		"远处蛇移出 5 格"
	)
	ctx.check(TestAPI.spawn_monster(MONSTER_ID), "刷近处蛇")
	ctx.equal(_snakes().size(), 2, "场上有两只蛇")

	var monster := CollectionDB.get_monster(MONSTER_ID)
	ctx.check(monster != null, "怪物数据存在")
	if monster == null:
		TestAPI.stop_battle()
		return
	var base := monster.move_speed

	ctx.check(TestAPI.charge_soul(SOUL_NAME, 4.0), "充满绳索")
	ctx.check(TestAPI.step_battle(1), "步进一帧触发释放")

	var near := _nearest_snake()
	var far := _farthest_snake()
	ctx.check(bool(near.get("sluggish", false)), "近处蛇迟缓")
	ctx.near(float(near.get("move_speed", 0.0)), base * 0.5, 0.01, "近处蛇移速 ×0.5")
	ctx.check(not bool(far.get("sluggish", false)), "远处蛇不迟缓")
	ctx.near(float(far.get("move_speed", 0.0)), base, 0.01, "远处蛇移速不变")

	ctx.check(TestAPI.step_battle(_ticks(2.1)), "步进 2.1 秒")
	near = _nearest_snake()
	ctx.check(not bool(near.get("sluggish", false)), "迟缓到期")
	ctx.near(float(near.get("move_speed", 0.0)), base, 0.01, "到期后移速恢复")

	TestAPI.stop_battle()


func _clear_enemies(ctx: ScenarioContext) -> void:
	for _index in 20:
		if (TestAPI.get_battle_state()["enemies"] as Array).is_empty():
			return
		if not TestAPI.damage_unit("enemy", 1000000.0):
			break
		await (Engine.get_main_loop() as SceneTree).process_frame
	ctx.check((TestAPI.get_battle_state()["enemies"] as Array).is_empty(), "清空初始敌人")


func _snakes() -> Array:
	var result: Array = []
	for enemy in TestAPI.get_battle_state()["enemies"] as Array:
		if String(enemy.get("name", "")) == MONSTER_NAME:
			result.append(enemy)
	return result


func _nearest_snake() -> Dictionary:
	var best: Dictionary = {}
	for snake in _snakes():
		if (
			best.is_empty()
			or float(snake.get("distance_to_player", INF))
			< float(best.get("distance_to_player", INF))
		):
			best = snake
	return best


func _farthest_snake() -> Dictionary:
	var worst: Dictionary = {}
	for snake in _snakes():
		if (
			worst.is_empty()
			or float(snake.get("distance_to_player", -1.0))
			> float(worst.get("distance_to_player", -1.0))
		):
			worst = snake
	return worst


func _ticks(seconds: float) -> int:
	return int(ceil(seconds * 60.0))
