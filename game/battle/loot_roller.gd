class_name LootRoller extends RefCounted

var _events: BattleEventBus
var _deliver: Callable


func _init(events: BattleEventBus, deliver: Callable) -> void:
	_events = events
	_deliver = deliver


func roll(
	unit: BattleUnit,
	rng: RandomNumberGenerator,
	rarity: int = SoulEmotion.DEFAULT_RARITY
) -> void:
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
		var item: ItemData = entry.item
		if item is SoulData:
			var soul := (item as SoulData).make_instance() as SoulData
			SoulEmotionRoller.roll(soul, rarity, rng)
			item = soul
		var added: bool = _deliver.call(item) if _deliver.is_valid() else false
		_events.emit_event(BattleEvent.CATEGORY_BATTLE, "drop", {
			"actor_unit": unit,
			"item": item.item_name,
			"chance": entry.chance,
			"success": added,
		}, BattleEvent.IMPORTANCE_IMPORTANT)
