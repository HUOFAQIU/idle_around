class_name MapTooltip
extends RefCounted
## 地图 tooltip 正文格式化器。
##
## 标题（地图名）由 TooltipWindow 单独显示，这里按 MapData 的刷怪条目生成条件行：
## 时间条目 → 每 N 秒出现X；击杀条目 → 每累计击杀 N X时，出现Y。
## 怪物名从 CollectionDB 解析，缺失时退回 content_id。

## 生成地图 tooltip 正文（不含地图名）
static func build(
	map_item: MapItemData,
	format: TooltipText.Format = TooltipText.Format.PLAIN
) -> String:
	if map_item == null or map_item.map_data == null:
		return TooltipText.EMPTY_TEXT

	var lines := PackedStringArray()
	for entry in map_item.map_data.spawn_entries:
		if entry == null:
			continue
		lines.append(_entry_line(entry))
	if lines.is_empty():
		lines.append(TooltipText.EMPTY_TEXT)
	return TooltipText.render("\n".join(lines), format)


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
