class_name MapRun
extends RefCounted

class EntryRuntime extends RefCounted:
	var entry: MapSpawnEntry
	var spawned: int = 0
	var kill_progress: int = 0
	var timer: float = 0.0


var map_data: MapData
var _entries: Array[EntryRuntime] = []


func _init(p_map_data: MapData) -> void:
	map_data = p_map_data
	if map_data == null:
		return
	for entry in map_data.spawn_entries:
		if entry == null:
			continue
		var runtime := EntryRuntime.new()
		runtime.entry = entry
		_entries.append(runtime)


func take_initial_spawns() -> Array[StringName]:
	var due: Array[StringName] = []
	for runtime in _entries:
		if runtime.entry.condition != MapSpawnEntry.Condition.TIME_INTERVAL:
			continue
		if runtime.spawned >= _effective_count(runtime.entry):
			continue
		runtime.spawned += 1
		due.append(runtime.entry.monster_id)
		break
	return due


func advance(delta: float) -> Array[StringName]:
	var due: Array[StringName] = []
	for runtime in _entries:
		if runtime.entry.condition != MapSpawnEntry.Condition.TIME_INTERVAL:
			continue
		var interval := runtime.entry.interval_seconds
		if interval <= 0.0:
			continue
		var total := _effective_count(runtime.entry)
		if runtime.spawned >= total:
			continue
		runtime.timer += delta
		while runtime.timer >= interval and runtime.spawned < total:
			runtime.timer -= interval
			runtime.spawned += 1
			due.append(runtime.entry.monster_id)
	return due


func on_monster_killed(monster_id: StringName) -> Array[StringName]:
	var due: Array[StringName] = []
	for runtime in _entries:
		if runtime.entry.condition != MapSpawnEntry.Condition.KILL_COUNT:
			continue
		if runtime.entry.kill_monster_id != monster_id:
			continue
		var threshold := runtime.entry.kill_threshold
		if threshold <= 0:
			continue
		runtime.kill_progress += 1
		while runtime.kill_progress >= threshold:
			runtime.kill_progress -= threshold
			due.append(runtime.entry.monster_id)
	return due


func is_finished() -> bool:
	if map_data == null:
		return true
	for runtime in _entries:
		if runtime.entry.condition != MapSpawnEntry.Condition.TIME_INTERVAL:
			continue
		if runtime.spawned < _effective_count(runtime.entry):
			return false
	return true


func state() -> Dictionary:
	var entries: Array = []
	for runtime in _entries:
		entries.append({
			"monster_id": String(runtime.entry.monster_id),
			"condition": (
				"time"
				if runtime.entry.condition == MapSpawnEntry.Condition.TIME_INTERVAL
				else "kill"
			),
			"spawned": runtime.spawned,
			"count": _effective_count(runtime.entry),
			"kill_progress": runtime.kill_progress,
			"kill_threshold": runtime.entry.kill_threshold,
		})
	return {
		"map_id": String(map_data.content_id) if map_data != null else "",
		"entries": entries,
	}


func _effective_count(entry: MapSpawnEntry) -> int:
	return maxi(entry.count, 0)
