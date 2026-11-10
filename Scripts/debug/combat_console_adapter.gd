## 战斗日志事件 → 控制台输出；替代原先在 BattleManager 里的 print_rich。
class_name CombatConsoleAdapter extends RefCounted

var enabled: bool = true

var _bus: BattleEventBus


func _init(bus: BattleEventBus) -> void:
	_bus = bus
	if _bus != null:
		_bus.emitted.connect(_on_event)


func _on_event(event: BattleEvent) -> void:
	if not enabled or event.category != BattleEvent.CATEGORY_LOG:
		return
	var text := String(event.fields.get("text", ""))
	var color := String(event.fields.get("color", "white"))
	print_rich("[color=%s]%s[/color]" % [color, text])
