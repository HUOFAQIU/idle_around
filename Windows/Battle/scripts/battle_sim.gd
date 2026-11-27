class_name BattleSim
extends Node3D

signal battle_logged(line: String, color: String)

const MAX_MONS := 2000
const BATCH_CAP := 512
const GRID_CELL := 1.25
const SWING_IMPACT_U := 0.52
const LOGIC_TO_3D_SCALE := 0.095
const SPARK_GOLD := Color(2.4, 1.7, 0.6)
const SPARK_BLOOD := Color(2.0, 0.65, 0.45)
const SOLDIER_SHATTER := Color(0.55, 0.68, 0.92)


class MobState:
	var batch_key: String = ""
	var visual_scale: float = 1.0
	var hit_height: float = 0.6
	var debris_color: Color = Color(0.55, 0.52, 0.48, 1.0)
	var pos := Vector3.ZERO
	var yaw: float = 0.0
	var hp: float = 1.0
	var max_hp: float = 1.0
	var move_speed: float = 2.6
	var damage: float = 6.0
	var attack_cooldown: float = 0.95
	var attack_reach: float = 1.35
	var anim_phase: float = 0.0
	var swing: float = 0.0
	var hit_pending: bool = false
	var flash: float = 0.0
	var attack_cd: float = 0.3
	var is_moving: bool = true


@export_group("Monster Archetypes")
## 独立调试无 MapItemData 时使用的原型怪物预设列表
@export var mob_archetypes: Array[BattleMobArchetype] = []

@export_group("Wave & Spawning")
## 原型模式下怪物外圈刷出最小半径（米）
@export_range(10.0, 40.0, 0.5) var spawn_radius_min: float = 19.5
## 原型模式下怪物外圈刷出最大半径（米）
@export_range(15.0, 45.0, 0.5) var spawn_radius_max: float = 23.5
## 原型模式下每波持续时长（秒）
@export_range(5.0, 60.0, 1.0) var wave_duration_sec: float = 20.0
## 原型模式下开局预刷怪物数量
@export_range(0, 50, 1) var initial_monster_count: int = 12

@export_group("Soldier")
## 原型模式下中心士兵最大生命值
@export var soldier_max_hp: float = 360.0
## 原型模式下中心士兵自动攻击半径（米）
@export var soldier_range: float = 2.65
## 原型模式下中心士兵单次挥剑伤害
@export var soldier_dmg: float = 30.0
## 原型模式下中心士兵攻击间隔（秒）
@export var soldier_atk_period: float = 0.56
## 原型模式下单次挥剑最多劈砍目标数
@export_range(1, 10, 1) var soldier_max_cleave: int = 4

var soldier_pos := Vector3.ZERO
var soldier_yaw: float = 0.0
var soldier_hp: float = 360.0
var soldier_cd: float = 0.0
var soldier_swing: float = 0.0
var soldier_hit_pending: bool = false
var soldier_flash: float = 0.0
var soldier_dead: bool = false
var soldier_respawn_t: float = 0.0

var wave: int = 1
var kills: int = 0
var elapsed: float = 0.0
var shake_mag: float = 0.0
var shake_offset := Vector2.ZERO
var map_clear_restart_t: float = 0.0
var _spawn_cd: float = 0.45

var muted: bool:
	get: return _sfx.muted

var perf_sim_ms: float = 0.0
var perf_batch_ms: float = 0.0

var mons: Array[MobState] = []
var _grid: Dictionary = {}

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
	_ensure_default_archetypes()
	_sfx.init(self, ["sword", "clash", "hit", "kill", "horn", "ui_click"], 10)
	_fx.init(self)

	_renderer.init(self, mat_unit)
	var soldier_mesh := load("res://Windows/Battle/assets/models/footman_s.res") as Mesh
	_renderer.register_batch("soldier", soldier_mesh, 2)
	for arch in mob_archetypes:
		if arch != null:
			_renderer.register_batch(arch.id, arch.mesh, BATCH_CAP)

	_units_root = Node.new()
	_units_root.name = "BattleUnitsRoot"
	add_child(_units_root)

	_session = BattleSession.new()
	_session.name = "BattleSession"
	_session.units_root = _units_root
	_session.spawn_radius_min_logic = spawn_radius_min / LOGIC_TO_3D_SCALE
	_session.spawn_radius_max_logic = spawn_radius_max / LOGIC_TO_3D_SCALE
	_session.attach_observers = _attach_session_observers
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
	if _is_session_mode():
		return _session.battle.enemy_count() if _session.battle != null else 0
	return mons.size()


func get_progress_label() -> String:
	if not _is_session_mode():
		return "W%d" % wave
	var st := _session.get_state()
	var map_st: Dictionary = st.get("map", {})
	var total := 0
	var spawned := 0
	for e in map_st.get("entries", []):
		if String(e.get("condition", "")) == "time":
			total += int(e.get("count", 0))
			spawned += int(e.get("spawned", 0))
	return "%d/%d" % [spawned, total] if total > 0 else "MAP"


func get_hp_bar_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _is_session_mode():
		if _session.battle == null:
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
			if entries.size() >= 48:
				break
		return entries
	for m in mons:
		entries.append({
			"pos": m.pos + Vector3(0.0, m.hit_height + 0.45, 0.0),
			"hp": m.hp,
			"max_hp": m.max_hp,
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
	if _is_session_mode():
		if _session.battle == null:
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
	var n := mons.size()
	var step := maxi(1, int(float(n) / 63.0))
	var i := 0
	while i < n and targets.size() < 64:
		var m := mons[i]
		if m.pos.x * m.pos.x + m.pos.z * m.pos.z < 24.5 * 24.5:
			targets.append(Vector4(m.pos.x, m.pos.y, m.pos.z, 0.95 * m.visual_scale))
		i += step
	return targets


func reset_run(silent: bool = false) -> void:
	mons.clear()
	_fx.clear()
	map_clear_restart_t = 0.0
	soldier_pos = Vector3(0.0, height_at(0.0, 0.0), 0.0)
	soldier_yaw = 0.0
	soldier_hp = soldier_max_hp
	soldier_cd = 0.0
	soldier_swing = 0.0
	soldier_hit_pending = false
	soldier_flash = 0.0
	soldier_dead = false
	soldier_respawn_t = 0.0
	wave = 1
	kills = 0
	elapsed = 0.0
	_spawn_cd = 0.4
	shake_mag = 0.0
	shake_offset = Vector2.ZERO
	if not silent:
		_sfx.play("horn", 0.45)

	if _map_item != null and _session != null:
		_session.start(_equipped_slots, _map_item)
		_session.set_manual_time(_paused)
		_sync_soldier_from_session()
		return

	if _session != null:
		_session.stop()
	for i in range(initial_monster_count):
		var a := TAU * float(i) / float(maxi(initial_monster_count, 1)) + randf_range(-0.18, 0.18)
		_spawn_outer_monster(a, false)
	if not silent:
		battle_logged.emit("[战斗] 新一轮防守开始", "white")


func spawn_stress_wave(count: int = 100) -> void:
	if _is_session_mode():
		for _i in range(count):
			if _session.battle == null or _session.battle.enemy_count() >= MAX_MONS:
				break
			_session.spawn_monster_for_test(&"snake_monster")
		return
	for i in range(count):
		if mons.size() >= MAX_MONS:
			break
		var a := TAU * (float(i) + randf()) / float(maxi(count, 1))
		_spawn_outer_monster(a, true)


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
		_fx.step(dt, height_at)
		perf_batch_ms = float(Time.get_ticks_usec() - ts) * 0.001
		return

	_step_wave_and_spawning(dt)
	if _step_soldier(dt):
		return
	_rebuild_spatial_grid()
	_step_monsters(dt)

	var t1 := Time.get_ticks_usec()
	perf_sim_ms = float(t1 - t0) * 0.001

	_render_units()
	_fx.step(dt, height_at)
	perf_batch_ms = float(Time.get_ticks_usec() - t1) * 0.001


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
	if _session.battle != null:
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
	return mob_archetypes[0].id if not mob_archetypes.is_empty() else ""


func _ensure_default_archetypes() -> void:
	var valid: Array[BattleMobArchetype] = []
	for a in mob_archetypes:
		if a != null:
			valid.append(a)
	mob_archetypes = valid
	if not mob_archetypes.is_empty():
		return
	var default_ids := ["rat", "skel", "slime", "spider", "ghoul", "wolf", "knight", "brute"]
	for mid in default_ids:
		var path := "res://Windows/Battle/assets/mobs/mob_%s.tres" % mid
		if ResourceLoader.exists(path):
			var res := load(path) as BattleMobArchetype
			if res != null:
				mob_archetypes.append(res)


func _step_wave_and_spawning(dt: float) -> void:
	if soldier_dead:
		return
	var next_wave := 1 + int(elapsed / maxf(wave_duration_sec, 1.0))
	if next_wave > wave:
		wave = next_wave
		battle_logged.emit("[波次] 进入第 %d 波" % wave, "yellow")
	_spawn_cd -= dt
	if _spawn_cd <= 0.0:
		var pack := 2 + mini(4, int(float(wave) / 2.0))
		var base_a := randf() * TAU
		for _pi in range(pack):
			_spawn_outer_monster(base_a + randf_range(-0.35, 0.35), false)
		_spawn_cd = maxf(0.24, 1.05 - float(wave - 1) * 0.10) * randf_range(0.75, 1.25)


func _spawn_outer_monster(angle: float = -1.0, all_types: bool = false) -> void:
	if mons.size() >= MAX_MONS or mob_archetypes.is_empty():
		return
	var arch := _pick_archetype(all_types)
	var a := randf() * TAU if angle < 0.0 else angle
	var rad := randf_range(spawn_radius_min, spawn_radius_max)
	var mx := cos(a) * rad
	var mz := sin(a) * rad

	var mob := MobState.new()
	mob.batch_key = arch.id
	mob.visual_scale = arch.visual_scale
	mob.hit_height = arch.hit_height
	mob.debris_color = arch.debris_color
	mob.pos = Vector3(mx, height_at(mx, mz), mz)
	mob.yaw = atan2(-mx, -mz)
	mob.max_hp = arch.max_hp * (1.0 + float(wave - 1) * 0.14)
	mob.hp = mob.max_hp
	mob.move_speed = arch.move_speed
	mob.damage = arch.damage
	mob.attack_cooldown = arch.attack_cooldown
	mob.attack_reach = arch.attack_reach
	mob.anim_phase = randf() * TAU
	mob.attack_cd = randf_range(0.15, 0.55)
	mons.append(mob)


func _pick_archetype(all_types: bool) -> BattleMobArchetype:
	if all_types:
		return mob_archetypes[randi() % mob_archetypes.size()]
	var eligible: Array[BattleMobArchetype] = []
	for a in mob_archetypes:
		if a.unlock_wave <= wave:
			eligible.append(a)
	if eligible.is_empty():
		return mob_archetypes[0]
	return eligible[randi() % eligible.size()]


func _step_soldier(dt: float) -> bool:
	soldier_flash = maxf(0.0, soldier_flash - dt * 5.0)
	soldier_swing = maxf(0.0, soldier_swing - dt * 2.15)
	if soldier_dead:
		soldier_respawn_t -= dt
		if soldier_respawn_t <= 0.0:
			reset_run()
			return true
		return false

	soldier_cd = maxf(0.0, soldier_cd - dt)
	var nearest := _find_nearest_monster()
	if nearest != null:
		var tgt_yaw := atan2(nearest.pos.x, nearest.pos.z)
		var diff := wrapf(tgt_yaw - soldier_yaw, -PI, PI)
		soldier_yaw += clampf(diff, -dt * 12.0, dt * 12.0)

		var d2 := nearest.pos.x * nearest.pos.x + nearest.pos.z * nearest.pos.z
		if d2 <= soldier_range * soldier_range and soldier_cd <= 0.0 and not soldier_hit_pending:
			soldier_cd = soldier_atk_period
			soldier_swing = 1.0
			soldier_hit_pending = true
	else:
		soldier_hp = minf(soldier_max_hp, soldier_hp + dt * 8.0)

	if soldier_hit_pending and (1.0 - soldier_swing) >= SWING_IMPACT_U:
		soldier_hit_pending = false
		_resolve_soldier_strike()
	return false


func _find_nearest_monster() -> MobState:
	var best: MobState = null
	var best_d2 := 999999.0
	for mob in mons:
		var d2 := mob.pos.x * mob.pos.x + mob.pos.z * mob.pos.z
		if d2 < best_d2:
			best_d2 = d2
			best = mob
	return best


func _resolve_soldier_strike() -> void:
	var hit_n := 0
	var r2 := (soldier_range + 0.45) * (soldier_range + 0.45)
	var killed_any := false
	for i in range(mons.size() - 1, -1, -1):
		var mob := mons[i]
		var d2 := mob.pos.x * mob.pos.x + mob.pos.z * mob.pos.z
		if d2 > r2:
			continue
		var ang_to := atan2(mob.pos.x, mob.pos.z)
		if absf(wrapf(ang_to - soldier_yaw, -PI, PI)) >= 1.45 and d2 >= 2.25:
			continue

		mob.hp -= soldier_dmg
		mob.flash = 0.85
		var knock := Vector3(mob.pos.x, 0.0, mob.pos.z).normalized()
		mob.pos.x += knock.x * 0.28
		mob.pos.z += knock.z * 0.28
		var hit_pos := mob.pos + Vector3(0.0, mob.hit_height, 0.0)
		_fx.spawn_sparks(hit_pos, 4, SPARK_GOLD, 4.0)

		if mob.hp <= 0.0:
			kills += 1
			killed_any = true
			_fx.spawn_shatter(mob.pos, mob.visual_scale, mob.debris_color, knock * 2.8)
			shake_mag = minf(0.40, shake_mag + 0.07)
			mons.remove_at(i)

		hit_n += 1
		if hit_n >= soldier_max_cleave:
			break

	if hit_n > 0:
		_sfx.play("sword", 0.48)
		if killed_any:
			_sfx.play("kill", 0.42)
	else:
		_sfx.play("sword", 0.25)


func _rebuild_spatial_grid() -> void:
	_grid.clear()
	var inv_cell := 1.0 / GRID_CELL
	for i in range(mons.size()):
		var mob := mons[i]
		var gx := int(floorf(mob.pos.x * inv_cell))
		var gz := int(floorf(mob.pos.z * inv_cell))
		var key := (gx + 4096) * 8192 + (gz + 4096)
		if _grid.has(key):
			(_grid[key] as Array).append(i)
		else:
			_grid[key] = [i]


func _step_monsters(dt: float) -> void:
	var inv_cell := 1.0 / GRID_CELL
	for i in range(mons.size()):
		var mob := mons[i]
		mob.flash = maxf(0.0, mob.flash - dt * 5.0)
		mob.swing = maxf(0.0, mob.swing - dt * 1.95)
		mob.attack_cd = maxf(0.0, mob.attack_cd - dt)

		var dist := sqrt(mob.pos.x * mob.pos.x + mob.pos.z * mob.pos.z)
		if dist > mob.attack_reach:
			_move_monster_inward(mob, i, dist, dt, inv_cell)
		else:
			_attack_soldier_from_monster(mob)


func _move_monster_inward(mob: MobState, idx: int, dist: float, dt: float, inv_cell: float) -> void:
	mob.hit_pending = false
	var step_d := minf(dist - mob.attack_reach * 0.9, mob.move_speed * dt)
	var mx := mob.pos.x - (mob.pos.x / dist) * step_d
	var mz := mob.pos.z - (mob.pos.z / dist) * step_d

	var sep := _compute_separation(mx, mz, idx, inv_cell)
	mx += sep.x * dt
	mz += sep.y * dt

	mob.pos = Vector3(mx, height_at(mx, mz), mz)
	mob.yaw = atan2(-mx, -mz)
	mob.anim_phase += dt * mob.move_speed * 3.8
	mob.is_moving = true


func _compute_separation(mx: float, mz: float, self_idx: int, inv_cell: float) -> Vector2:
	var gx := int(floorf(mx * inv_cell))
	var gz := int(floorf(mz * inv_cell))
	var sep_x := 0.0
	var sep_z := 0.0
	var checks := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := (gx + dx + 4096) * 8192 + (gz + dz + 4096)
			if not _grid.has(k):
				continue
			var bucket: Array = _grid[k]
			for bi in range(bucket.size()):
				var j: int = bucket[bi]
				if j == self_idx:
					continue
				var other := mons[j]
				var ox := mx - other.pos.x
				var oz := mz - other.pos.z
				var od2 := ox * ox + oz * oz
				if od2 > 0.0001 and od2 < 0.72:
					var od := sqrt(od2)
					var push := (0.85 - od) * 1.45
					sep_x += (ox / od) * push
					sep_z += (oz / od) * push
				checks += 1
				if checks >= 10:
					return Vector2(sep_x, sep_z)
	return Vector2(sep_x, sep_z)


func _attack_soldier_from_monster(mob: MobState) -> void:
	mob.is_moving = false
	mob.yaw = atan2(-mob.pos.x, -mob.pos.z)
	if soldier_dead:
		return

	if mob.attack_cd <= 0.0 and not mob.hit_pending:
		mob.attack_cd = mob.attack_cooldown
		mob.swing = 1.0
		mob.hit_pending = true

	if mob.hit_pending and (1.0 - mob.swing) >= SWING_IMPACT_U:
		mob.hit_pending = false
		soldier_hp = maxf(0.0, soldier_hp - mob.damage)
		soldier_flash = 0.50
		_sfx.play("clash", 0.30)
		_fx.spawn_sparks(soldier_pos + Vector3(0.0, 0.9, 0.0), 3, SPARK_BLOOD, 3.0)
		if soldier_hp <= 0.0:
			soldier_dead = true
			soldier_respawn_t = 2.6
			_fx.spawn_shatter(soldier_pos, 1.2, SOLDIER_SHATTER, Vector3(0.0, 2.5, 0.0))
			_sfx.play("kill", 0.65)
			shake_mag = 0.55


func _render_units() -> void:
	_renderer.begin_frame()
	if not soldier_dead:
		_renderer.push_unit("soldier", soldier_pos, soldier_yaw, 1.18, 0.0, soldier_swing, soldier_flash, 0.0)
	for mob in mons:
		_renderer.push_unit(
			mob.batch_key,
			mob.pos,
			mob.yaw,
			mob.visual_scale,
			mob.anim_phase,
			mob.swing,
			mob.flash,
			1.0 if mob.is_moving else 0.0
		)
	_renderer.flush()
