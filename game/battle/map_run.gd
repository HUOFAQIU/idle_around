class_name MapRun
extends RefCounted
## 一张地图的运行期刷怪状态。
##
## 只决定「什么时候该刷哪只怪」，不碰节点、不选格：
## BattleSession 每物理帧把 advance()/on_monster_killed() 返回的怪物 id 入队，
## 再通过 BattleManager.spawn_one() 消费。完成判定只看时间条目配额刷完。
## 击杀条目没有独立配额，由击杀进度驱动。

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


## 开战立刻刷的一只（沿用现有战斗的即时开怪）；只取第一个时间条目
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


## 推进时间条目；返回这一拍到期的怪物 id
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


## 记录一次怪物死亡；返回因此到期的怪物 id
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


## 时间条目全部刷完就完成；击杀条目不再产生新怪，不阻塞完成
func is_finished() -> bool:
	if map_data == null:
		return true
	for runtime in _entries:
		if runtime.entry.condition != MapSpawnEntry.Condition.TIME_INTERVAL:
			continue
		if runtime.spawned < _effective_count(runtime.entry):
			return false
	return true


## 测试/调试快照
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


## 数量石以后只乘时间条目的总数量；当前固定返回配置值
func _effective_count(entry: MapSpawnEntry) -> int:
	return maxi(entry.count, 0)
