class_name MapRun
extends RefCounted

var map_data: MapData
var _mob_spawned: int = 0
var _mob_killed: int = 0
var _mob_timer: float = 0.0
var _elite_kill_progress: int = 0
var _elite_spawned: int = 0
var _boss_spawned: bool = false
var _boss_killed: bool = false


func _init(p_map_data: MapData) -> void:
	map_data = p_map_data


func take_initial_spawns(rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	if map_data == null or _mob_spawned >= map_data.mob_total:
		return due
	var req := _pick_from_pool(map_data.mob_pool, rng)
	if not req.is_empty():
		_mob_spawned += 1
		due.append(req)
	return due


func advance(delta: float, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	if map_data == null:
		return due
	var interval := map_data.mob_interval_seconds
	if interval <= 0.0 or _mob_spawned >= map_data.mob_total:
		return due
	_mob_timer += delta
	while _mob_timer >= interval and _mob_spawned < map_data.mob_total:
		_mob_timer -= interval
		var req := _pick_from_pool(map_data.mob_pool, rng)
		if req.is_empty():
			break
		_mob_spawned += 1
		due.append(req)
	return due


func on_monster_killed(
	_monster_id: StringName,
	tier: int = MonsterData.Tier.MOB,
	rng: RandomNumberGenerator = null
) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	if map_data == null:
		return due
	if tier == MonsterData.Tier.MOB:
		_mob_killed += 1
		if map_data.elite_every_mob_kills > 0 and not map_data.elite_pool.is_empty():
			_elite_kill_progress += 1
			while _elite_kill_progress >= map_data.elite_every_mob_kills:
				_elite_kill_progress -= map_data.elite_every_mob_kills
				var elite_req := _pick_from_pool(map_data.elite_pool, rng)
				if not elite_req.is_empty():
					_elite_spawned += 1
					due.append(elite_req)
		if _mob_killed >= map_data.mob_total and map_data.boss_entry != null and not _boss_spawned:
			_boss_spawned = true
			due.append({
				"monster_id": map_data.boss_entry.monster_id,
				"level": map_data.boss_entry.roll_level(rng),
			})
	elif tier == MonsterData.Tier.BOSS:
		_boss_killed = true
	return due


func is_finished() -> bool:
	if map_data == null:
		return true
	if _mob_spawned < map_data.mob_total or _mob_killed < map_data.mob_total:
		return false
	if map_data.boss_entry != null and not _boss_killed:
		return false
	return true


func progress() -> Vector2i:
	if map_data == null:
		return Vector2i.ZERO
	return Vector2i(_mob_spawned, map_data.mob_total)


func state() -> Dictionary:
	if map_data == null:
		return {}
	return {
		"map_id": String(map_data.content_id),
		"level_range": [map_data.level_range.x, map_data.level_range.y],
		"mob_spawned": _mob_spawned,
		"mob_killed": _mob_killed,
		"mob_total": map_data.mob_total,
		"elite_spawned": _elite_spawned,
		"boss_spawned": _boss_spawned,
		"boss_killed": _boss_killed,
	}


func _pick_from_pool(
	pool: Array[MapSpawnPoolEntry],
	rng: RandomNumberGenerator
) -> Dictionary:
	var total_weight := 0.0
	for entry in pool:
		if entry != null and not entry.monster_id.is_empty() and entry.weight > 0.0:
			total_weight += entry.weight
	if total_weight <= 0.0:
		return {}
	var roll := rng.randf() * total_weight if rng != null else 0.0
	var acc := 0.0
	var chosen: MapSpawnPoolEntry = null
	for entry in pool:
		if entry == null or entry.monster_id.is_empty() or entry.weight <= 0.0:
			continue
		acc += entry.weight
		chosen = entry
		if roll <= acc:
			break
	if chosen == null:
		return {}
	return {
		"monster_id": chosen.monster_id,
		"level": chosen.roll_level(rng),
	}
