class_name BattleSim
extends Node3D

signal battle_logged(line: String, color: String)

const BATCH_CAP := 1024
const LOGIC_TO_3D_SCALE := 0.095

@export_group("Wave & Spawning")
## 怪物外圈刷出最小半径（米）
@export_range(10.0, 40.0, 0.5) var spawn_radius_min: float = 19.5
## 怪物外圈刷出最大半径（米）
@export_range(15.0, 45.0, 0.5) var spawn_radius_max: float = 23.5

var soldier_pos := Vector3.ZERO
var soldier_yaw: float = 0.0
var soldier_hp: float = 100.0
var soldier_max_hp: float = 100.0
var soldier_swing: float = 0.0
var soldier_flash: float = 0.0
var soldier_dead: bool = false
var soldier_respawn_t: float = 0.0

var kills: int = 0
var elapsed: float = 0.0
var shake_mag: float = 0.0
var shake_offset := Vector2.ZERO
var map_clear_restart_t: float = 0.0

var muted: bool:
	get: return _sfx.muted

var perf_sim_ms: float = 0.0
var perf_batch_ms: float = 0.0

var _session: BattleSession
var _units_root: Node
var _map_item: MapItemData
var _equipped_slots: Array[SoulSlot] = []
var _paused: bool = false
var _observers: Array[RefCounted] = []

var _sfx := BattleSfxPool.new()
var _fx := BattleFxPool.new()
var _renderer := BattleUnitBatchRenderer.new()
var _height_fn: Callable = Callable()


func init_game(mat_unit: ShaderMaterial, height_fn: Callable = Callable()) -> void:
	_height_fn = height_fn
	_sfx.init(self, ["sword", "clash", "hit", "kill", "horn", "ui_click"], 10)
	_fx.init(self)

	_renderer.init(self, mat_unit)
	var soldier_mesh := load("res://windows/Battle/assets/models/footman_s.res") as Mesh
	_renderer.register_batch("soldier", soldier_mesh, 2)

	_units_root = Node.new()
	_units_root.name = "BattleUnitsRoot"
	add_child(_units_root)

	_session = BattleSession.new()
	_session.name = "BattleSession"
	_session.units_root = _units_root
	_session.spawn_radius_min_logic = spawn_radius_min / LOGIC_TO_3D_SCALE
	_session.spawn_radius_max_logic = spawn_radius_max / LOGIC_TO_3D_SCALE
	_session.attach_observers = _attach_session_observers
	_session.loot_sink = Warehouse.add_item
	_session.on_monster_seen = CollectionDB.mark_monster_seen
	add_child(_session)

	reset_run(true)


func get_battle_session() -> BattleSession:
	return _session


func set_paused(is_paused: bool) -> void:
	if _paused == is_paused:
		return
	_paused = is_paused
	if _session != null and _session.battle != null and _session.battle.is_running:
		_session.set_manual_time(is_paused)


func start_session(map_item: MapItemData, soul_slots: Array[SoulSlot] = []) -> void:
	_map_item = map_item
	_equipped_slots = soul_slots.duplicate()
	reset_run(false)


func stop_session() -> void:
	_observers.clear()
	if _session != null:
		_session.stop()
	_fx.clear()


func toggle_mute() -> void:
	_sfx.toggle_mute()


func play_ui_click() -> void:
	_sfx.play("ui_click", 0.65)


func get_gpu_unit_count() -> int:
	return _renderer.get_total_visible_units()


func get_enemy_count() -> int:
	if _is_session_mode() and _session.battle != null:
		return _session.battle.enemy_count()
	return 0


func get_progress_label() -> String:
	if not _is_session_mode():
		return "IDLE"
	var progress := _session.get_map_progress()
	return "%d/%d" % [progress.x, progress.y] if progress.y > 0 else "MAP"


func get_hp_bar_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not _is_session_mode() or _session.battle == null:
		return entries
	for unit in _session.battle.enemies:
		if unit == null or unit.is_dead or unit.health_attr == null or unit.max_health_attr == null:
			continue
		var hp := unit.health_attr.current_value
		var mhp := unit.max_health_attr.current_value
		if hp >= mhp - 0.01:
			continue
		entries.append({
			"pos": _unit_pos_3d(unit) + Vector3(0.0, unit.hit_height + 0.45, 0.0),
			"hp": hp,
			"max_hp": mhp,
		})
	return entries


func height_at(x: float, z: float) -> float:
	if _height_fn.is_valid():
		return float(_height_fn.call(x, z))
	return 0.0


func collect_trample_targets() -> Array[Vector4]:
	var targets: Array[Vector4] = []
	if not soldier_dead:
		targets.append(Vector4(soldier_pos.x, soldier_pos.y, soldier_pos.z, 1.35))
	if not _is_session_mode() or _session.battle == null:
		return targets
	var enemies := _session.battle.enemies
	var en_n := enemies.size()
	var en_step := maxi(1, int(float(en_n) / 63.0))
	var en_i := 0
	while en_i < en_n and targets.size() < 64:
		var u := enemies[en_i]
		if u != null and not u.is_dead:
			var p3 := _unit_pos_3d(u)
			targets.append(Vector4(p3.x, p3.y, p3.z, maxf(0.45, u.body_radius * LOGIC_TO_3D_SCALE * 1.15)))
		en_i += en_step
	return targets


func reset_run(silent: bool = false) -> void:
	_fx.clear()
	map_clear_restart_t = 0.0
	soldier_pos = Vector3(0.0, height_at(0.0, 0.0), 0.0)
	soldier_yaw = 0.0
	soldier_swing = 0.0
	soldier_flash = 0.0
	soldier_dead = false
	soldier_respawn_t = 0.0
	kills = 0
	elapsed = 0.0
	shake_mag = 0.0
	shake_offset = Vector2.ZERO
	if not silent:
		_sfx.play("horn", 0.45)

	if _map_item != null and _session != null:
		_session.spawn_radius_min_logic = spawn_radius_min / LOGIC_TO_3D_SCALE
		_session.spawn_radius_max_logic = spawn_radius_max / LOGIC_TO_3D_SCALE
		_session.start(_equipped_slots, _map_item)
		_session.set_manual_time(_paused)
		_sync_soldier_from_session()
		return

	if _session != null:
		_session.stop()


func step_sim(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	elapsed += dt
	shake_mag = maxf(0.0, shake_mag - dt * 3.2)
	var sh := shake_mag * shake_mag * 0.22
	shake_offset = Vector2(sin(elapsed * 47.0), cos(elapsed * 53.0)) * sh if sh > 1e-5 else Vector2.ZERO

	if _is_session_mode():
		_step_session_visuals(dt)
	var ts := Time.get_ticks_usec()
	perf_sim_ms = float(ts - t0) * 0.001
	_render_session_units()
	var projs: Array = _session.battle.projectiles if _is_session_mode() and _session.battle != null else []
	_fx.sync_projectiles(projs, _logic_to_3d)
	_fx.step(dt, height_at)
	perf_batch_ms = float(Time.get_ticks_usec() - ts) * 0.001


func _attach_session_observers(battle: BattleManager) -> void:
	_observers.clear()
	_observers.append(CombatTelemetryAdapter.new(battle.events))
	_observers.append(CombatNarrator.new(battle))
	_observers.append(BattleLogAdapter.new(battle.events, _on_session_log_line))
	_observers.append(Battle3DBridge.new(
		battle,
		_fx,
		_sfx,
		_logic_to_3d,
		_add_camera_shake,
		_on_session_enemy_killed
	))


func _on_session_log_line(text: String, color: String) -> void:
	battle_logged.emit(text, color)


func _add_camera_shake(amount: float, cap: float) -> void:
	shake_mag = minf(cap, shake_mag + amount)


func _on_session_enemy_killed() -> void:
	kills += 1


func _is_session_mode() -> bool:
	return _map_item != null and _session != null


func _logic_to_3d(p: Vector2) -> Vector3:
	var x := p.x * LOGIC_TO_3D_SCALE
	var z := p.y * LOGIC_TO_3D_SCALE
	return Vector3(x, height_at(x, z), z)


func _unit_pos_3d(u: BattleUnit) -> Vector3:
	var x := u.position.x * LOGIC_TO_3D_SCALE
	var z := u.position.y * LOGIC_TO_3D_SCALE
	if u.ground_y_dirty:
		u.cached_ground_y = height_at(x, z)
		u.ground_y_dirty = false
	return Vector3(x, u.cached_ground_y, z)


func _sync_soldier_from_session() -> void:
	if _session == null or _session.battle == null or _session.battle.player == null:
		soldier_dead = true
		return
	var p := _session.battle.player
	soldier_pos = _logic_to_3d(p.position)
	soldier_dead = p.is_dead
	if p.health_attr != null:
		soldier_hp = p.health_attr.current_value
	if p.max_health_attr != null:
		soldier_max_hp = maxf(p.max_health_attr.current_value, 1.0)


func _step_session_visuals(dt: float) -> void:
	_sync_soldier_from_session()
	if _session.battle == null:
		return
	for rt in SoulRuntimeDB.player_runtimes():
		rt.refresh_from_ability()
	var p := _session.battle.player
	if p != null and not p.is_dead:
		p.flash = maxf(0.0, p.flash - dt * 5.0)
		p.swing = maxf(0.0, p.swing - dt * 2.15)
		soldier_yaw = p.yaw
		soldier_swing = p.swing
		soldier_flash = p.flash
	for u in _session.battle.enemies:
		if u == null or u.is_dead:
			continue
		if u.flash > 0.0:
			u.flash = maxf(0.0, u.flash - dt * u.flash_decay)
		if u.swing > 0.0:
			u.swing = maxf(0.0, u.swing - dt * u.attack_anim_speed)


func _render_session_units() -> void:
	_renderer.begin_frame()
	if _is_session_mode() and _session.battle != null:
		var p := _session.battle.player
		if p != null and not p.is_dead:
			_renderer.push_unit("soldier", _logic_to_3d(p.position), p.yaw, 1.18, 0.0, p.swing, p.flash, 0.0)
		for u in _session.battle.enemies:
			if u == null or u.is_dead:
				continue
			if u.batch_key.is_empty():
				u.batch_key = _ensure_monster_batch(u.monster_data)
			if u.batch_key.is_empty():
				continue
			_renderer.push_unit(
				u.batch_key,
				_unit_pos_3d(u),
				u.yaw,
				u.visual_scale,
				u.anim_phase,
				u.swing,
				u.flash,
				1.0 if u.is_moving else 0.0
			)
	_renderer.flush()


func _ensure_monster_batch(data: MonsterData) -> String:
	if data != null and data.mesh_3d != null:
		var key := "monster:" + String(data.content_id)
		if not _renderer.has_batch(key):
			_renderer.register_batch(key, data.mesh_3d, BATCH_CAP, data.anim_config)
		return key
	return ""
