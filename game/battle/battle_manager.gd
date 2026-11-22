class_name BattleManager extends Node

const MOVE_BUDGET_PER_FRAME : int = 200
const TICK_END_PHYSICS_PRIORITY : int = 128

var map: TileMapLayer
var spawn_enemy: Callable = Callable()
var loot_sink: Callable = Callable()
var player: BattleUnit
var is_running: bool = false

var events: BattleEventBus = BattleEventBus.new()

var clock: BattleClock

var rng := RandomNumberGenerator.new()

var registry: UnitRegistry = UnitRegistry.new()
var spatial: UnitSpatialIndex = UnitSpatialIndex.new()
var grid: BattleGrid

var units: Array[BattleUnit]:
	get:
		return registry.units
var players: Array[BattleUnit]:
	get:
		return registry.players
var enemies: Array[BattleUnit]:
	get:
		return registry.enemies
var cell_size_px: float:
	get:
		return grid.cell_size_px if grid != null else 32.0

var _loot: LootRoller
var _tick_count: int = 0
var _move_slice: int = 0
var _trigger_listeners: Dictionary = {}


func setup() -> void:
	process_physics_priority = TICK_END_PHYSICS_PRIORITY
	_tick_count = 0
	clock = BattleClock.new()
	clock.name = "BattleClock"
	add_child(clock)
	grid = BattleGrid.new(map)
	_loot = LootRoller.new(events, loot_sink)


func add_unit(unit: BattleUnit) -> void:
	registry.add(unit)
	spatial.register(unit)
	events.emit_event(BattleEvent.CATEGORY_BATTLE, "unit_added", {
		"actor_unit": unit,
		"cell": [unit.cell.x, unit.cell.y],
		"souls": unit.loadout.map(func(runtime): return runtime.display_name() if runtime != null else ""),
	}, BattleEvent.IMPORTANCE_DETAIL)

	unit.died.connect(_on_unit_died)
	unit.moved.connect(_on_unit_moved)
	if is_running:
		unit.brain.begin_charge()
	if unit.team == BattleUnit.Team.ENEMY and unit.brain != null:
		unit.brain.set_physics_process(false)
	if clock != null and unit.asc != null:
		unit.asc.manual_time = clock.manual


func _on_unit_moved(unit: BattleUnit, from_cell: Vector2i, to_cell: Vector2i) -> void:
	for listener in trigger_listeners(GameplayTags.Event_Movement_UnitMoved):
		listener.on_enemy_moved(unit, from_cell, to_cell)


func set_trigger_listener(unit: BattleUnit, event_tag: StringName, enabled: bool) -> void:
	var listeners: Array = _trigger_listeners.get(event_tag, [])
	var index := listeners.find(unit)
	if enabled and index == -1:
		listeners.append(unit)
	elif not enabled and index >= 0:
		listeners.remove_at(index)
	_trigger_listeners[event_tag] = listeners


func trigger_listeners(event_tag: StringName) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	var listeners: Array = _trigger_listeners.get(event_tag, [])
	for item in listeners:
		var unit := item as BattleUnit
		if unit != null and is_instance_valid(unit) and not unit.is_dead:
			result.append(unit)
	return result


func begin() -> void:
	is_running = true
	_tick_count = 0

	for unit in units:
		unit.brain.begin_charge()


func _physics_process(delta: float) -> void:
	if clock != null and clock.manual:
		return
	advance(delta)


func advance(delta: float) -> void:
	if not is_running or player == null or player.is_dead:
		return
	var slices := maxi(
		1,
		int(ceil(float(registry.enemies.size()) / float(MOVE_BUDGET_PER_FRAME)))
	)
	_move_slice = (_move_slice + 1) % slices
	for unit in registry.enemies:
		if unit == null or unit.is_dead:
			continue
		if unit.get_instance_id() % slices != _move_slice:
			continue
		_tick_enemy_movement(unit, delta, slices)

	_tick_count += 1
	_flush_brain_activations()


func advance_units(delta: float) -> void:
	for unit in registry.units.duplicate():
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.asc != null and unit.asc.manual_time:
			unit.asc.advance_time(delta)
		if not unit.is_dead and unit.brain != null:
			unit.brain.advance()


func _flush_brain_activations() -> void:
	for unit in registry.units.duplicate():
		if not is_running:
			return
		if unit == null or not is_instance_valid(unit) or unit.is_dead:
			continue
		if unit.brain != null:
			unit.brain.flush_pending_activations()


func _tick_enemy_movement(unit: BattleUnit, _delta: float, slices: int) -> void:
	if unit.brain == null:
		return
	var to_player := player.position - unit.position
	var distance := to_player.length()
	if distance <= unit.attack_range:
		unit.velocity = Vector2.ZERO
		if not unit.brain.is_physics_processing():
			unit.brain.set_physics_process(true)
			events.emit_event(BattleEvent.CATEGORY_BATTLE, "enemy_in_range", {
				"actor_unit": unit,
				"distance": distance,
			}, BattleEvent.IMPORTANCE_DETAIL)
		return

	if unit.brain.is_physics_processing():
		unit.brain.set_physics_process(false)
		events.emit_event(BattleEvent.CATEGORY_BATTLE, "enemy_out_of_range", {
			"actor_unit": unit,
			"distance": distance,
		}, BattleEvent.IMPORTANCE_DETAIL)
	if unit.is_unit_frozen():
		unit.velocity = Vector2.ZERO
		return
	if distance <= 0.001:
		return

	unit.velocity = to_player / distance * unit.get_move_speed() * float(slices)
	unit.move_and_slide()
	spatial.update(unit)

	var new_cell := grid.world_to_cell(unit.position)
	if new_cell != unit.cell:
		var from_cell := unit.cell
		unit.cell = new_cell
		unit.moved.emit(unit, from_cell, new_cell)
		events.emit_event(BattleEvent.CATEGORY_BATTLE, "moved", {
			"actor_unit": unit,
			"from": [from_cell.x, from_cell.y],
			"to": [new_cell.x, new_cell.y],
		}, BattleEvent.IMPORTANCE_DETAIL)


func cell_to_world(cell: Vector2i) -> Vector2:
	return grid.cell_to_world(cell)


func player_cell() -> Vector2i:
	if player == null:
		return Vector2i.ZERO
	return grid.world_to_cell(player.position)


func units_of_team(team: BattleUnit.Team) -> Array[BattleUnit]:
	return registry.of_team(team)


func enemy_count() -> int:
	return registry.enemy_count()


func units_near(pos: Vector2, radius: float) -> Array[BattleUnit]:
	return spatial.near(pos, radius)


func spawn_one() -> void:
	if spawn_enemy.is_valid():
		spawn_enemy.call()


func tick_count() -> int:
	return _tick_count


func tick_seconds() -> float:
	return clock.tick_seconds


func ticks_for_seconds(seconds: float) -> int:
	return clock.ticks_for_seconds(seconds)


func elapsed_seconds() -> float:
	return float(_tick_count) * tick_seconds()


func log_line(text: String, color: String = "white") -> void:
	var line := "[%5.2fs] %s" % [elapsed_seconds(), text]
	events.emit_event(
		BattleEvent.CATEGORY_LOG,
		"line",
		{"text": line, "color": color},
		BattleEvent.IMPORTANCE_IMPORTANT
	)


func _on_unit_died(unit: BattleUnit) -> void:
	if unit == player:
		is_running = false
		return
	spatial.unregister(unit)
	registry.remove(unit)
	_loot.roll(unit, rng)
	unit.cleanup_asc()
	unit.queue_free()
