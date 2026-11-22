class_name BattleSession extends Node

signal battle_started(battle: BattleManager)
signal battle_ended()
signal player_spawned(unit: BattleUnit)

const REVIVE_DELAY: float = 3.0
const MAP_RESTART_DELAY: float = 5.0
const PLAYER_SCENE := preload("res://game/battle/player.tscn")

var units_root: Node2D
var map: TileMapLayer
var attach_observers: Callable = Callable()

var run_id: int = 0
var player_profile: PlayerProfile
var battle: BattleManager
var slots: Array[SoulSlot] = []
var souls: Array[SoulData] = []

var _map_item: MapItemData
var _map_run: MapRun
var _pending_spawn_ids: Array[StringName] = []
var _map_finished: bool = false
var _manual_time: bool = false
var _map_kills: Dictionary = {}
var _test_monster_id: StringName = &""
var _next_spawn_is_test: bool = false
var _spawn_cells_by_distance: Dictionary = {}


func start(p_slots: Array[SoulSlot], map_item: MapItemData) -> void:
	var manual := _manual_time
	stop()
	_manual_time = manual
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
	battle.clock.manual = _manual_time
	if attach_observers.is_valid():
		attach_observers.call(battle)

	battle.player = _spawn_player()
	player_spawned.emit(battle.player)
	CombatTelemetry.begin_run(run_id, battle, battle.player.loadout)
	CombatTelemetry.watch_unit(battle.player)
	battle.begin()
	_rebuild_spawn_cells()
	battle.log_line("========== 战斗开始 ==========", "yellow")
	for unit in battle.units:
		battle.log_line("%s  HP %.0f" % [unit.unit_name, unit.health_attr.current_value], "white")
	if _map_run != null:
		_enqueue_spawns(_map_run.take_initial_spawns())
	battle.spawn_one()
	battle_started.emit(battle)


func stop() -> void:
	run_id += 1
	_manual_time = false
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


func set_manual_time(enabled: bool) -> bool:
	if battle == null or battle.clock == null or not battle.is_running:
		return false
	_manual_time = enabled
	battle.clock.manual = enabled
	for unit in battle.units:
		if unit != null and unit.asc != null:
			unit.asc.manual_time = enabled
	return true


func step_ticks(count: int) -> bool:
	if battle == null or battle.clock == null or not battle.clock.manual:
		return false
	var delta := battle.clock.tick_seconds
	for _index in maxi(count, 0):
		if battle == null or not is_instance_valid(battle) or not battle.is_running:
			return false
		battle.clock.advance(delta)
		advance(delta)
		battle.advance_units(delta)
		_advance_projectiles(delta)
		battle.advance(delta)
	return true


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


func _physics_process(delta: float) -> void:
	if battle == null or battle.clock == null or battle.clock.manual:
		return
	advance(delta)


func advance(delta: float) -> void:
	if battle == null or not battle.is_running or _map_run == null or _map_finished:
		return
	_enqueue_spawns(_map_run.advance(delta))
	while not _pending_spawn_ids.is_empty():
		battle.spawn_one()
	_check_map_finished()


func _advance_projectiles(delta: float) -> void:
	for projectile in get_tree().get_nodes_in_group(SoulProjectile.GROUP):
		if projectile is SoulProjectile and is_instance_valid(projectile):
			projectile.advance(delta)


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

	unit.add_soul_abilities(souls, slots)

	var granted := 0
	for ability in unit.soul_loadout.abilities:
		if ability != null:
			granted += 1
	if granted == 0:
		battle.log_line("没有装备主动魂灵 —— 角色不会任何技能", "yellow")
	return unit


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
	unit.position += Vector2.from_angle(battle.rng.randf() * TAU) * battle.rng.randf_range(0.0, 12.0)
	battle.add_unit(unit)
	unit.died.connect(_on_enemy_died.bind(monster, is_test))
	CollectionDB.mark_monster_seen(monster)


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


func _rebuild_spawn_cells() -> void:
	_spawn_cells_by_distance.clear()
	if battle == null or battle.grid == null or battle.player == null:
		return
	_spawn_cells_by_distance = battle.grid.cells_by_distance(battle.player_cell())


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


func _on_enemy_died(_unit: BattleUnit, monster: MonsterData, is_test: bool) -> void:
	if is_test or battle == null or not battle.is_running or _map_run == null:
		return
	if monster == null:
		return
	var monster_id: StringName = monster.content_id
	_map_kills[monster_id] = int(_map_kills.get(monster_id, 0)) + 1
	_enqueue_spawns(_map_run.on_monster_killed(monster_id))


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
	@warning_ignore("missing_await")
	_restart_map_later(battle.clock, current_run)


func _on_map_restart_timeout(current_run: int) -> void:
	if current_run != run_id or _map_item == null:
		return
	var next_slots: Array[SoulSlot] = []
	next_slots.append_array(slots)
	start(next_slots, _map_item)


func _restart_map_later(clock: BattleClock, current_run: int) -> void:
	await clock.wait_seconds(MAP_RESTART_DELAY)
	_on_map_restart_timeout(current_run)


func _on_player_died(_unit: BattleUnit) -> void:
	battle.log_line("角色倒下了，%.0f 秒后重来……" % REVIVE_DELAY, "yellow")
	var current_run := run_id
	var next_slots: Array[SoulSlot] = []
	next_slots.append_array(slots)
	var map_item := _map_item
	var clock := battle.clock
	await clock.wait_seconds(REVIVE_DELAY)
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
		"move_speed": unit.get_move_speed(),
		"dead": unit.is_dead,
		"frozen": unit.asc.has_tag(GameplayTags.State_Frozen) if unit.asc != null else false,
		"hasted": unit.asc.has_tag(GameplayTags.State_Hasted) if unit.asc != null else false,
		"slowed": unit.asc.has_tag(GameplayTags.State_Slowed) if unit.asc != null else false,
		"cell": [unit.cell.x, unit.cell.y],
		"position": [unit.position.x, unit.position.y],
		"distance_to_player": distance_to_player,
		"in_attack_range": in_attack_range,
		"souls": soul_names,
	}
