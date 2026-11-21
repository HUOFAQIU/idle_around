class_name BattleLogAdapter extends RefCounted

var _sink: Callable


func _init(bus: BattleEventBus, sink: Callable) -> void:
	_sink = sink
	if bus != null:
		bus.emitted.connect(_on_event)


func _on_event(event: BattleEvent) -> void:
	if event.category != BattleEvent.CATEGORY_LOG or not _sink.is_valid():
		return
	_sink.call(
		String(event.fields.get("text", "")),
		String(event.fields.get("color", "white"))
	)
