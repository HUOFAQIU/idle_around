class_name MapTooltip
extends RefCounted

static func build(
	map_item: MapItemData,
	format: TooltipText.Format = TooltipText.Format.PLAIN
) -> String:
	if map_item == null or map_item.map_data == null:
		return TooltipText.EMPTY_TEXT

	var data := map_item.map_data
	var lines := PackedStringArray()
	if data.level_range.y > 0:
		lines.append("等级：Lv %d - %d" % [data.level_range.x, data.level_range.y])
	lines.append("稀有度：%s" % SoulEmotion.rarity_name(data.rarity))
	if data.uses_tiered_spawns():
		lines.append("小怪：共 %d 只（%s）" % [data.mob_total, _pool_names(data.mob_pool)])
		if data.elite_every_mob_kills > 0 and not data.elite_pool.is_empty():
			lines.append("精英：每击杀 %d 只小怪刷新（%s）" % [
				data.elite_every_mob_kills,
				_pool_names(data.elite_pool),
			])
		if data.boss_entry != null and not data.boss_entry.monster_id.is_empty():
			lines.append("首领：击杀全部小怪后刷新 %s" % _monster_name(data.boss_entry.monster_id))
	else:
		for entry in data.spawn_entries:
			if entry == null:
				continue
			lines.append(_entry_line(entry))
	if lines.is_empty():
		lines.append(TooltipText.EMPTY_TEXT)
	return TooltipText.render("\n".join(lines), format)


static func _pool_names(pool: Array[MapSpawnPoolEntry]) -> String:
	var names := PackedStringArray()
	for entry in pool:
		if entry == null or entry.monster_id.is_empty():
			continue
		names.append(_monster_name(entry.monster_id))
	return "、".join(names)


static func _entry_line(entry: MapSpawnEntry) -> String:
	var monster_name := _monster_name(entry.monster_id)
	match entry.condition:
		MapSpawnEntry.Condition.TIME_INTERVAL:
			return "每 %s 秒出现%s" % [
				TooltipText.format_number(entry.interval_seconds),
				monster_name,
			]
		MapSpawnEntry.Condition.KILL_COUNT:
			return "每累计击杀 %d %s时，出现%s" % [
				entry.kill_threshold,
				_monster_name(entry.kill_monster_id),
				monster_name,
			]
	return ""


static func _monster_name(monster_id: StringName) -> String:
	var monster := CollectionDB.get_monster(monster_id)
	if monster == null or monster.display_name.is_empty():
		return String(monster_id)
	return monster.display_name
