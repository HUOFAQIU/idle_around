## 一场战斗的会话：创建/销毁 BattleManager、生成玩家与怪物、地图刷怪、复活重开。
##
## BattleWindow 只负责 UI：会话通过信号通知它什么时候该绑血条、开关扫描线。
## 场景节点、地图、观察者挂载都由窗口注入，避免会话反向依赖窗口。
## 刷怪由 MapRun 按地图配置产生，本类只负责把怪物 id 变成战斗单位。
class_name BattleSession extends Node

## 新一场开始（单位已生成、刷怪已启动）
signal battle_started(battle: BattleManager)
## 本场结束（清场完成，battle 已释放）
signal battle_ended()
## 玩家单位已生成；窗口用它绑血条
signal player_spawned(unit: BattleUnit)

## 角色倒下后多久重开一整场
const REVIVE_DELAY: float = 3.0
## 地图全清后多久自动重开
const MAP_RESTART_DELAY: float = 5.0
## 玩家单位：配置好的场景，开战时直接实例化
const PLAYER_SCENE := preload("res://game/content/Player/player.tscn")

## 单位节点容器（与地图同坐标系）
var units_root: Node2D
## 格子 → 像素换算用的地图
var map: TileMapLayer
## 观察者挂载回调，签名 func(battle: BattleManager)；必须在生成单位之前调用
var attach_observers: Callable = Callable()

## 当前场次；重开/关窗时自增，用来作废还没执行的复活/重开等待
var run_id: int = 0
## 本场使用的角色档案；为空时由 GameFlow 提供当前会话角色
var player_profile: PlayerProfile
var battle: BattleManager
## 本场装备的魂灵位置；关战后再开新场前一直保留
var slots: Array[SoulSlot] = []
## 与 slots 同下标的魂灵
var souls: Array[SoulData] = []

## 本场地图；为空时不会刷怪
var _map_item: MapItemData
## 地图刷怪进度
var _map_run: MapRun
## 已产生、等 BattleManager.spawn_one() 消费的怪物 id
var _pending_spawn_ids: Array[StringName] = []
## 地图完成标记；完成后等待 5 秒重开
var _map_finished: bool = false
## 本场按 content_id 统计的击杀数（测试/调试用）
var _map_kills: Dictionary = {}
## 测试接口：下一次刷怪强制使用这个 ID，刷出后清空
var _test_monster_id: StringName = &""
## 本次取怪是否来自测试接口；测试怪不计入地图击杀
var _next_spawn_is_test: bool = false
## 距离 → 该环的已使用格子；开战时按玩家所在格缓存一次
var _spawn_cells_by_distance: Dictionary = {}


## 清掉上一场，按地图配置重新开一场
func start(p_slots: Array[SoulSlot], map_item: MapItemData) -> void:
	stop()
	run_id += 1
	slots = p_slots
	_map_item = map_item
	_map_run = MapRun.new(map_item.map_data) if map_item != null else null
	souls.clear()
	for slot in slots:
		if slot != null:
			souls.append(slot.soul)

	battle = BattleManager.new()
	battle.name = "BattleManager"
	add_child(battle)
	battle.map = map
	battle.spawn_enemy = _spawn_enemy
	battle.loot_sink = Warehouse.add_item
	battle.setup()
	if attach_observers.is_valid():
		attach_observers.call(battle)

	battle.player = _spawn_player()
	player_spawned.emit(battle.player)
	CombatTelemetry.begin_run(run_id, battle, battle.player.loadout)
	CombatTelemetry.watch_unit(battle.player)
	battle.start_battle()
	_rebuild_spawn_cells()
	battle.log_line("========== 战斗开始 ==========", "yellow")
	for unit in battle.units:
		battle.log_line("%s  HP %.0f" % [unit.unit_name, unit.health_attr.current_value], "white")
	# 立刻先来一只，不然开战还得对着空场等第一拍
	if _map_run != null:
		_enqueue_spawns(_map_run.take_initial_spawns())
	battle.spawn_one()
	battle_started.emit(battle)


## 关窗/重开：作废复活等待，清掉所有单位和运行时状态
func stop() -> void:
	run_id += 1
	CombatTelemetry.end_run("clear")
	SoulRuntimeDB.clear()
	for child in units_root.get_children():
		if child is BattleUnit:
			(child as BattleUnit).cleanup_asc()
		child.queue_free()
	if battle != null:
		battle.queue_free()
		battle = null
	_map_item = null
	_map_run = null
	_pending_spawn_ids.clear()
	_map_finished = false
	_map_kills.clear()
	_test_monster_id = &""
	_next_spawn_is_test = false
	battle_ended.emit()


## 测试：立刻在远处空位刷一只指定怪物
func spawn_monster_for_test(monster_id: StringName) -> bool:
	if battle == null or not battle.is_running:
		return false
	if CollectionDB.get_monster(monster_id) == null:
		return false
	var before := battle.units.size()
	_test_monster_id = monster_id
	battle.spawn_one()
	if battle.units.size() > before:
		return true
	_test_monster_id = &""
	return false


## 当前战斗快照；没有战斗时 running = false
func get_state() -> Dictionary:
	var state := {
		"running": false,
		"elapsed": 0.0,
		"player": {},
		"enemies": [],
		"player_souls": [],
		"map_id": "",
		"map_finished": false,
		"map": {},
		"map_kills": {},
		"pending_spawns": 0,
	}
	if battle == null:
		return state

	state["running"] = battle.is_running
	state["elapsed"] = battle.elapsed_seconds()
	state["player"] = _unit_state(battle.player)
	state["map_id"] = _map_run.state().get("map_id", "") if _map_run != null else ""
	state["map_finished"] = _map_finished
	state["map"] = _map_run.state() if _map_run != null else {}
	state["pending_spawns"] = _pending_spawn_ids.size()
	var kills := {}
	for id in _map_kills:
		kills[String(id)] = _map_kills[id]
	state["map_kills"] = kills

	var enemies : Array = []
	for unit in battle.units:
		if unit != battle.player:
			enemies.append(_unit_state(unit))
	state["enemies"] = enemies

	var player_souls : Array = []
	var player := battle.player
	if player != null and player.soul_loadout != null:
		for runtime in player.soul_loadout.runtimes:
			if runtime == null:
				continue
			var ability: ChargedAbility = runtime.ability
			player_souls.append({
				"name": runtime.display_name(),
				"cooldown": ability.cooldown if ability != null else 0.0,
				"charge_ratio": ability.charge_ratio() if ability != null else 0.0,
				"charge_seconds": ability.charge_seconds() if ability != null else 0.0,
				"haste": ability.haste_seconds() if ability != null else 0.0,
				"slow": ability.slow_seconds() if ability != null else 0.0,
				"freeze": ability.freeze_seconds() if ability != null else 0.0,
				"frozen": ability.is_frozen() if ability != null else false,
				"active": ability.is_active if ability != null else false,
				"activation_lock": ability.activation_lock_seconds() if ability != null else 0.0,
			})
	state["player_souls"] = player_souls
	return state


## 每帧推进地图刷怪；完成判定放在刷怪之后
func _process(delta: float) -> void:
	if battle == null or not battle.is_running or _map_run == null or _map_finished:
		return
	_enqueue_spawns(_map_run.tick(delta))
	while not _pending_spawn_ids.is_empty():
		battle.spawn_one()
	_check_map_finished()


#region 生成
## 角色：站在战场中心，技能全部来自装备上的魂灵
## 注意是"一颗魂灵一个技能"：同一颗魂灵装两把也要各算各的冷却，不能去重
func _spawn_player() -> BattleUnit:
	var passive_effects := SoulLoadout.collect_passive_effects(souls)
	var unit := PLAYER_SCENE.instantiate() as BattleUnit
	var profile := player_profile
	if profile == null:
		profile = GameFlow.get_player_profile()
	unit.unit_name = profile.display_name
	unit.max_health = profile.max_health
	units_root.add_child(unit)
	unit.setup_from_scene(battle, passive_effects)
	unit.set_cell(Vector2i.ZERO)
	unit.died.connect(_on_player_died)
	battle.add_unit(unit)

	# 魂灵 → 技能 + 运行期状态：和怪物走同一条 SoulLoadout 管线
	unit.add_soul_abilities(souls, slots)

	var granted := 0
	for ability in unit.soul_loadout.abilities:
		if ability != null:
			granted += 1
	if granted == 0:
		battle.log_line("没有装备主动魂灵 —— 角色不会任何技能", "yellow")
	return unit


## 怪物：场景只负责战斗表现；先取地图队列里的怪，再按它的 spawn_distances 选格
func _spawn_enemy() -> void:
	var monster := _take_next_monster()
	if monster == null:
		return
	var is_test := _next_spawn_is_test
	var cells := _pick_spawn_cell(monster)
	if cells.is_empty():
		return
	var cell: Vector2i = cells[0]
	var unit := monster.battle_scene.instantiate() as BattleUnit
	if unit == null:
		push_warning("见闻：怪物场景根节点不是 BattleUnit")
		return
	unit.unit_name = monster.display_name
	unit.max_health = monster.max_health
	unit.attack_range = monster.attack_range
	unit.move_speed = monster.move_speed
	unit.drops = monster.drop_entries()
	unit.souls = monster.soul_list()
	var body := unit.get_node_or_null("Body") as Sprite2D
	if body != null and monster.icon != null:
		body.texture = monster.icon
		body.region_enabled = false
	units_root.add_child(unit)
	unit.setup_from_scene(battle)
	unit.set_cell(cell)
	# 同一格刷出来的怪加一点随机偏移，避免完全重叠；碰撞体负责其余的推开
	unit.position += Vector2.from_angle(battle.rng.randf() * TAU) * battle.rng.randf_range(0.0, 12.0)
	battle.add_unit(unit)
	unit.died.connect(_on_enemy_died.bind(monster, is_test))
	CollectionDB.mark_monster_seen(monster)


## 取下一只怪：测试强制 ID 优先，其次地图待刷队列
func _take_next_monster() -> MonsterData:
	_next_spawn_is_test = false
	if not _test_monster_id.is_empty():
		var forced := CollectionDB.get_monster(_test_monster_id)
		_test_monster_id = &""
		_next_spawn_is_test = true
		return forced
	while not _pending_spawn_ids.is_empty():
		var monster_id: StringName = _pending_spawn_ids.pop_front()
		var monster := CollectionDB.get_monster(monster_id)
		if monster != null:
			return monster
	return null


func _enqueue_spawns(monster_ids: Array[StringName]) -> void:
	for monster_id in monster_ids:
		_pending_spawn_ids.append(monster_id)


## 开战时按玩家所在格把地图格子按距离分环，之后每次刷怪直接查表
func _rebuild_spawn_cells() -> void:
	_spawn_cells_by_distance.clear()
	if battle == null or battle.grid == null or battle.player == null:
		return
	_spawn_cells_by_distance = battle.grid.cells_by_distance(battle.player_cell())


## 把怪物的 spawn_distances 对应的环合并成候选格，再随机选一格。
## 请求的距离都没有格子时，退到离任意请求距离最近的有格环；整张图没格子才放弃。
func _pick_spawn_cell(monster: MonsterData) -> Array[Vector2i]:
	var wanted: Array[int] = monster.spawn_distances.duplicate()
	if wanted.is_empty():
		wanted.append(3)
	var candidates: Array[Vector2i] = []
	for distance in wanted:
		if _spawn_cells_by_distance.has(distance):
			candidates.append_array(_spawn_cells_by_distance[distance])
	if candidates.is_empty():
		candidates = _nearest_spawn_cells(wanted)
	if candidates.is_empty():
		return []
	var picked: Array[Vector2i] = []
	picked.append(candidates[battle.rng.randi_range(0, candidates.size() - 1)])
	return picked


## 找离请求距离最近的有格环
func _nearest_spawn_cells(wanted: Array[int]) -> Array[Vector2i]:
	var best_distance := -1
	var best_delta := 1 << 30
	for key in _spawn_cells_by_distance.keys():
		var available := int(key)
		for requested in wanted:
			var delta := absi(available - requested)
			if delta < best_delta:
				best_delta = delta
				best_distance = available
	if best_distance < 0:
		return []
	var result: Array[Vector2i] = []
	result.append_array(_spawn_cells_by_distance[best_distance])
	return result
#endregion


#region 地图击杀与完成

## 地图刷出的怪死亡：按 content_id 计数，并检查击杀条件是否要刷新怪。
## 测试刷出的怪不计入，避免干扰地图完成。
func _on_enemy_died(_unit: BattleUnit, monster: MonsterData, is_test: bool) -> void:
	if is_test or battle == null or not battle.is_running or _map_run == null:
		return
	if monster == null:
		return
	var monster_id: StringName = monster.content_id
	_map_kills[monster_id] = int(_map_kills.get(monster_id, 0)) + 1
	_enqueue_spawns(_map_run.on_monster_killed(monster_id))


## 时间配额刷完、没有待刷怪、场上没有存活怪 → 地图完成，5 秒后重开
func _check_map_finished() -> void:
	if _map_finished or _map_run == null or battle == null:
		return
	if not _map_run.is_finished() or not _pending_spawn_ids.is_empty():
		return
	for unit in battle.enemies:
		if unit != null and not unit.is_dead:
			return
	_map_finished = true
	battle.log_line("地图完成，%.0f 秒后重新开始……" % MAP_RESTART_DELAY, "yellow")
	var current_run := run_id
	get_tree().create_timer(MAP_RESTART_DELAY).timeout.connect(
		_on_map_restart_timeout.bind(current_run), CONNECT_ONE_SHOT
	)


func _on_map_restart_timeout(current_run: int) -> void:
	if current_run != run_id or _map_item == null:
		return
	var next_slots: Array[SoulSlot] = []
	next_slots.append_array(slots)
	start(next_slots, _map_item)

#endregion


## 角色倒下：停一会儿，然后整场重来；关窗/重开会让 run_id 变化，这次等待作废
func _on_player_died(_unit: BattleUnit) -> void:
	battle.log_line("角色倒下了，%.0f 秒后重来……" % REVIVE_DELAY, "yellow")
	var current_run := run_id
	var next_slots: Array[SoulSlot] = []
	next_slots.append_array(slots)
	var map_item := _map_item
	await get_tree().create_timer(REVIVE_DELAY).timeout
	if current_run != run_id:
		return
	start(next_slots, map_item)


func _unit_state(unit: BattleUnit) -> Dictionary:
	if unit == null:
		return {}
	var soul_names : Array[String] = []
	for soul in unit.souls:
		if soul != null:
			soul_names.append(soul.item_name)
	var regen_attr := unit.asc.get_attribute("regen") if unit.asc != null else null
	var poison_attr := unit.asc.get_attribute("poison") if unit.asc != null else null
	var distance_to_player := -1.0
	var in_attack_range := false
	if battle != null and battle.player != null:
		distance_to_player = unit.distance_to_unit(battle.player)
		in_attack_range = unit.team == BattleUnit.Team.ENEMY and unit.is_in_attack_range(battle.player)
	return {
		"name": unit.unit_name,
		"hp": unit.health_attr.current_value if unit.health_attr != null else 0.0,
		"max_hp": unit.max_health_attr.current_value if unit.max_health_attr != null else 0.0,
		"shield": unit.shield_attr.current_value if unit.shield_attr != null else 0.0,
		"regen": regen_attr.current_value if regen_attr != null else 0.0,
		"poison": poison_attr.current_value if poison_attr != null else 0.0,
		"dead": unit.is_dead,
		"frozen": unit.asc.has_tag(GameplayTags.State_Frozen) if unit.asc != null else false,
		"cell": [unit.cell.x, unit.cell.y],
		"position": [unit.position.x, unit.position.y],
		"distance_to_player": distance_to_player,
		"in_attack_range": in_attack_range,
		"souls": soul_names,
	}
