extends Node

signal runtime_registered(runtime: SoulRuntime)
signal runtime_unregistered(runtime: SoulRuntime)

var _by_soul_instance: Dictionary = {}
var _runtimes: Array[SoulRuntime] = []


func register(runtime: SoulRuntime) -> void:
	if runtime == null or runtime.soul == null:
		return
	var key := runtime.soul.get_instance_id()
	var existing: SoulRuntime = _by_soul_instance.get(key)
	if existing != null:
		unregister(existing)
	_by_soul_instance[key] = runtime
	_runtimes.append(runtime)
	runtime_registered.emit(runtime)


func unregister(runtime: SoulRuntime) -> void:
	if runtime == null or not _runtimes.has(runtime):
		return
	if runtime.soul != null:
		_by_soul_instance.erase(runtime.soul.get_instance_id())
	_runtimes.erase(runtime)
	runtime_unregistered.emit(runtime)


func clear() -> void:
	for runtime in _runtimes.duplicate():
		runtime_unregistered.emit(runtime)
	_by_soul_instance.clear()
	_runtimes.clear()


func get_runtime(soul: SoulData) -> SoulRuntime:
	if soul == null:
		return null
	return _by_soul_instance.get(soul.get_instance_id())


func all() -> Array[SoulRuntime]:
	return _runtimes.duplicate()


func player_runtimes() -> Array[SoulRuntime]:
	var result: Array[SoulRuntime] = []
	for runtime in _runtimes:
		if is_instance_valid(runtime.owner_unit) and runtime.owner_unit.team == BattleUnit.Team.PLAYER:
			result.append(runtime)
	return result
