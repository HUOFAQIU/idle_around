extends RefCounted


static func get_emotion_ids() -> Array[StringName]:
	return SoulEmotion.IDS.duplicate()


static func get_emotion_ranges(soul_id: StringName) -> Dictionary:
	var soul := CollectionDB.get_soul(soul_id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % soul_id)
		return {}
	var result := {}
	for id in SoulEmotion.ordered_ids(soul.emotion_ranges):
		var bounds: Variant = SoulEmotion.dict_get(soul.emotion_ranges, id, null)
		if bounds is Vector2:
			result[String(id)] = [(bounds as Vector2).x, (bounds as Vector2).y]
	return result


static func get_effective_emotion_ids(soul_id: StringName) -> Array[StringName]:
	var soul := CollectionDB.get_soul(soul_id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % soul_id)
		return []
	return SoulEmotion.effective_ids(soul.emotion_ranges)


static func roll_soul_emotions(
	soul_id: StringName,
	rarity: int = SoulEmotion.DEFAULT_RARITY,
	rng_seed: int = 0
) -> Dictionary:
	var soul := CollectionDB.get_soul(soul_id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % soul_id)
		return {}
	var instance := soul.make_instance() as SoulData
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	SoulEmotionRoller.roll(instance, rarity, rng)
	return _snapshot(instance)


static func roll_loot_soul_emotions(
	soul_id: StringName,
	rarity: int = SoulEmotion.DEFAULT_RARITY,
	rng_seed: int = 0
) -> Dictionary:
	var soul := CollectionDB.get_soul(soul_id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % soul_id)
		return {}
	var entry := DropEntry.new()
	entry.item = soul
	entry.chance = 1.0
	var unit := BattleUnit.new()
	unit.drops.append(entry)
	var delivered: Array[ItemData] = []
	var deliver := func(item: ItemData) -> bool:
		delivered.append(item)
		return true
	var roller := LootRoller.new(BattleEventBus.new(), deliver)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	roller.roll(unit, rng, rarity)
	unit.free()
	if delivered.is_empty():
		return {}
	return _snapshot(delivered[0] as SoulData)


static func roll_soul_to_warehouse(
	soul_id: StringName,
	rarity: int = SoulEmotion.DEFAULT_RARITY,
	rng_seed: int = -1
) -> Dictionary:
	var soul := CollectionDB.get_soul(soul_id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % soul_id)
		return {}
	var instance := soul.make_instance() as SoulData
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	SoulEmotionRoller.roll(instance, clampi(rarity, 1, 5), rng)
	if not Warehouse.add_item(instance):
		return {}
	return _snapshot(instance)


static func apply_soul_emotions(soul_id: StringName, emotions: Dictionary) -> Dictionary:
	var soul := CollectionDB.get_soul(soul_id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % soul_id)
		return {}
	var instance := soul.make_instance() as SoulData
	instance.emotions = _normalize(emotions)
	return _snapshot(instance)


static func get_soul_tooltip_text_with_emotions(
	soul_id: StringName, emotions: Dictionary
) -> String:
	var soul := CollectionDB.get_soul(soul_id)
	if soul == null:
		push_warning("TestAPI：魂灵不存在 %s" % soul_id)
		return ""
	var instance := soul.make_instance() as SoulData
	instance.emotions = _normalize(emotions)
	return "%s\n%s" % [instance.item_name, SoulTooltip.build(instance, TooltipText.Format.PLAIN)]


static func check_soul_emotion_roundtrip(
	soul_id: StringName,
	rarity: int = SoulEmotion.DEFAULT_RARITY,
	rng_seed: int = 0
) -> Dictionary:
	var rolled := roll_soul_emotions(soul_id, rarity, rng_seed)
	var soul := CollectionDB.get_soul(soul_id)
	if soul == null or rolled.is_empty():
		return {"ok": false, "checks": []}
	var instance := soul.make_instance() as SoulData
	instance.emotions = _normalize(rolled.get("emotions", {}))
	var record := SaveCodec.encode_item(instance)
	var restored := SaveCodec.decode_item(record) as SoulData
	var checks: Array[Dictionary] = []
	var before := _snapshot(instance)
	var after := _snapshot(restored)
	_check(
		checks,
		"情绪随存档往返",
		before["emotions"] == after["emotions"] and before["values"] == after["values"],
		{"before": before["emotions"], "after": after["emotions"]}
	)
	var passed := true
	for check in checks:
		if not bool(check["passed"]):
			passed = false
	return {"ok": passed, "checks": checks}


static func _snapshot(soul: SoulData) -> Dictionary:
	var emotions := {}
	for id in SoulEmotion.ordered_ids(soul.emotions):
		emotions[String(id)] = SoulEmotionValues.share(soul, id)
	var values := {}
	for id in SoulEmotion.ordered_ids(soul.emotion_ranges):
		if SoulEmotion.dict_get(soul.emotions, id, null) == null:
			continue
		values[String(id)] = SoulEmotionValues.value(soul, id)
	return {
		"emotions": emotions,
		"values": values,
		"damage": SoulEmotionValues.damage_base(soul),
		"cooldown": SoulEmotionValues.cooldown_seconds(soul),
		"cast_times": SoulEmotionValues.cast_times(soul),
	}


static func _normalize(emotions: Dictionary) -> Dictionary:
	var result := {}
	for key in emotions:
		var id := StringName(String(key))
		if not SoulEmotion.is_valid(id):
			continue
		var value := clampi(int(emotions[key]), 0, 100)
		if value > 0:
			result[id] = value
	return result


static func _check(
	checks: Array[Dictionary],
	name: String,
	passed: bool,
	detail: Variant = ""
) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
