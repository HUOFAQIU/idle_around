## 掉落判定：每项掉落各掷一次骰子。
##
## 入包动作由外部注入（BattleWindow 接 Warehouse.add_item），
## 本类不直接依赖仓库；日志仍通过 log_line 回调交给战斗叙事。
class_name LootRoller extends RefCounted

var _events: BattleEventBus
var _deliver: Callable
var _log_line: Callable


func _init(events: BattleEventBus, deliver: Callable, log_line: Callable) -> void:
	_events = events
	_deliver = deliver
	_log_line = log_line


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
		if not _log_line.is_valid():
			continue
		if added:
			_log_line.call("%s 掉落了【%s】" % [unit.unit_name, entry.item.item_name], "#ffd866")
		else:
			_log_line.call("仓库已满，【%s】掉落丢失" % entry.item.item_name, "yellow")
