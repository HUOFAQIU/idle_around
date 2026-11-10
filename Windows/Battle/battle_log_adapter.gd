## 战斗日志事件 → UI 接收器（BattleWindow 传入 InfoWindow.append_line）。
##
## 与遥测/控制台适配器并列，都只订阅事件，模拟层不需要知道窗口存在。
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
