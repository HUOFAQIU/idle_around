class_name BattleEventBus extends RefCounted

signal emitted(event: BattleEvent)
@warning_ignore("unused_signal")
signal unit_asc_ready(unit: BattleUnit)
@warning_ignore("unused_signal")
signal soul_runtime_created(unit: BattleUnit, ability: ChargedAbility, runtime: SoulRuntime)


func emit_event(
	category: String,
	type: String,
	fields: Dictionary = {},
	importance: String = BattleEvent.IMPORTANCE_IMPORTANT
) -> void:
	emitted.emit(BattleEvent.new(category, type, fields, importance))
