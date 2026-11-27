extends ScenarioCase


func case_name() -> StringName:
	return &"battle_kong_lang_gas"


func run(ctx: ScenarioContext) -> void:
	var host := Node.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)

	var units_root := Node.new()
	units_root.name = "UnitsRoot"
	host.add_child(units_root)

	var session := BattleSession.new()
	session.name = "TestBattleSession"
	session.units_root = units_root
	host.add_child(session)
	await tree.process_frame

	var cue_dirs: Array[float] = []
	var cue_tags: Array[String] = []
	session.attach_observers = func(b: BattleManager) -> void:
		b.events.emitted.connect(func(ev: BattleEvent) -> void:
			if ev.category == BattleEvent.CATEGORY_CUE and ev.type == "hit_cue":
				cue_tags.append(String(ev.fields.get("cue_tag", "")))
				cue_dirs.append(float(ev.fields.get("direction", 0.0)))
		)

	var kong_lang := CollectionDB.get_soul(&"kong_lang_soul")
	ctx.check(kong_lang != null, "已加载恐狼魂灵")
	var map_item := MapCatalog.make_map_item(MapCatalog.FOREST_MAP_ID)
	ctx.check(map_item != null, "已加载森林地图")
	if kong_lang == null or map_item == null:
		host.queue_free()
		return

	var soul_copy := kong_lang.make_instance() as SoulData
	soul_copy.emotions = {&"cooldown": 80, &"cast_times": 60, &"damage": 40}
	var slots := SoulSlot.virtual_slots([soul_copy])
	session.start(slots, map_item)
	session.set_manual_time(true)

	var battle := session.battle
	ctx.check(battle != null and battle.player != null, "GAS 会话与玩家创建成功")
	ctx.check(battle.enemies.size() >= 1, "地图开局刷出首只怪物")
	if battle == null or battle.player == null or battle.enemies.is_empty():
		session.stop()
		host.queue_free()
		return

	var enemy := battle.enemies[0]
	ctx.equal(
		enemy.asc.process_mode,
		Node.PROCESS_MODE_DISABLED,
		"射程外且无持续效果时怪物 ASC 自动休眠"
	)

	enemy.position = battle.player.position + Vector2(20.0, 0.0)
	battle.spatial.update(enemy)
	var hp_before := enemy.health_attr.current_value

	for _tick in range(420):
		session.step_ticks(1)
		if cue_dirs.size() >= 2:
			break

	ctx.check(
		enemy.is_dead or enemy.health_attr.current_value < hp_before,
		"恐狼通过 GAS 自动施法命中并造成伤害"
	)
	ctx.check(cue_tags.size() >= 2, "恐狼多重触发发出至少 2 次命中 Cue 事件")
	if cue_tags.size() >= 2:
		ctx.equal(cue_tags[0], "Cue.Combat.ClawSlash", "命中 Cue 标签为恐狼爪痕")
		ctx.check(cue_dirs[0] * cue_dirs[1] < 0.0, "恐狼连击爪痕方向左右交替")

	session.stop()
	host.queue_free()
	await tree.process_frame
