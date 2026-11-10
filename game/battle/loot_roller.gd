## 掉落判定：每项掉落各掷一次骰子。
##
## 入包动作由外部注入（BattleSession 接 Warehouse.add_item），
## 本类不直接依赖仓库；日志由 CombatNarrator 订阅 battle/drop 事件生成。
class_name LootRoller extends RefCounted

var _events: BattleEventBus
var _deliver: Callable


func _init(events: BattleEventBus, deliver: Callable) -> void:
	_events = events
	_deliver = deliver


func roll(unit: BattleUnit, rng: RandomNumberGenerator) -> void:
	for entry in unit.drops:
		if entry == null or entry.item == null:
			continue
		if rng.randf() > entry.chance:
			_events.emit_event(BattleEvent.CATEGORY_BATTLE, "drop_roll", {
				"actor_unit": unit,
				"item": entry.item.item_name,
				"chance": entry.chance,
				"success": false,
			}, BattleEvent.IMPORTANCE_DETAIL)
			continue
		var added: bool = _deliver.call(entry.item) if _deliver.is_valid() else false
		_events.emit_event(BattleEvent.CATEGORY_BATTLE, "drop", {
			"actor_unit": unit,
			"item": entry.item.item_name,
			"chance": entry.chance,
			"success": added,
		}, BattleEvent.IMPORTANCE_IMPORTANT)
