## 战斗事件 → CombatTelemetry 的转接器。
##
## 只做转发与 GAS 信号绑定，不参与战斗判定；是否真正记录由
## CombatTelemetry.enabled 决定，关掉录制后 record() 自己提前返回。
class_name CombatTelemetryAdapter extends RefCounted

var _bus: BattleEventBus


func _init(bus: BattleEventBus) -> void:
	_bus = bus
	if _bus == null:
		return
	_bus.unit_asc_ready.connect(_on_unit_asc_ready)
	_bus.soul_runtime_created.connect(_on_soul_runtime_created)
	_bus.emitted.connect(_on_event)


func _on_unit_asc_ready(unit: BattleUnit) -> void:
	CombatTelemetry.bind_unit(unit)


func _on_soul_runtime_created(
	unit: BattleUnit,
	ability: ChargedAbility,
	runtime: SoulRuntime
) -> void:
	CombatTelemetry.bind_ability(ability, unit, runtime)


func _on_event(event: BattleEvent) -> void:
	CombatTelemetry.record(event.category, event.type, event.fields, event.importance)
