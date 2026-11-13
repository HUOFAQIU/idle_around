## 玩家魂灵运行期注册表（Autoload：SoulRuntimeDB）。
##
## 按 SoulData 实例查玩家装备的 SoulRuntime：装备栏 ItemView 用它刷新徽章/扫描线，
## 调试窗口用它列当前装备、战斗统计。怪物魂灵可能被多只怪共享同一份 SoulData，
## 因此不注册到这里；调试快照直接读 BattleUnit.loadout。
## 战斗结束由 BattleSession 统一 clear()。
extends Node

signal runtime_registered(runtime: SoulRuntime)
signal runtime_unregistered(runtime: SoulRuntime)

## SoulData 实例 id → SoulRuntime
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


## 战斗结束/重开：所有运行期状态失效
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
