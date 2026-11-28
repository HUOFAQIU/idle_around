class_name MapCatalog
extends RefCounted

const FOREST_MAP_ID: StringName = &"forest_map"
const QUANTITY_STONE_ID: StringName = &"quantity_stone"


static func get_map(id: StringName) -> MapData:
	return ModLoader.get_map(id)


static func get_map_ids() -> Array[StringName]:
	return ModLoader.get_map_ids()


static func make_map_item(id: StringName) -> MapItemData:
	var map_data := get_map(id)
	if map_data == null:
		return null
	var item := MapItemData.new()
	item.map_data = map_data
	item.content_id = map_data.content_id
	item.item_name = "地图：%s" % map_data.display_name
	item.icon = map_data.icon
	item.columns = 2
	item.rows = 2
	item.category = "MAP"
	return item


static func make_quantity_stone() -> QuantityStoneData:
	var template := _quantity_stone_template()
	if template == null:
		return null
	var instance := template.make_instance()
	return instance as QuantityStoneData


static func get_quantity_stone_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in ModLoader.get_item_entries():
		if entry.resource is QuantityStoneData:
			ids.append(entry.content_id)
	return ids


static func collect_problems() -> Array[String]:
	var problems: Array[String] = []
	for id in get_map_ids():
		var map_data := get_map(id)
		if map_data == null:
			problems.append("地图资源打不开：%s" % id)
			continue
		problems.append_array(map_data.collect_problems())
		if map_data.uses_tiered_spawns():
			_check_pool_monsters(problems, id, map_data.mob_pool, "小怪池")
			_check_pool_monsters(problems, id, map_data.elite_pool, "精英池")
			if map_data.boss_entry != null and not map_data.boss_entry.monster_id.is_empty():
				if ModLoader.get_monster(map_data.boss_entry.monster_id) == null:
					problems.append("%s：首领怪物不存在 %s" % [id, map_data.boss_entry.monster_id])
		else:
			for entry in map_data.spawn_entries:
				if entry == null:
					continue
				if ModLoader.get_monster(entry.monster_id) == null:
					problems.append("%s：怪物不存在 %s" % [id, entry.monster_id])
				if entry.condition == MapSpawnEntry.Condition.KILL_COUNT \
						and ModLoader.get_monster(entry.kill_monster_id) == null:
					problems.append("%s：击杀条件怪物不存在 %s" % [id, entry.kill_monster_id])
	if _quantity_stone_template() == null:
		problems.append("数量石资源未注册：%s" % QUANTITY_STONE_ID)
	return problems


static func _check_pool_monsters(
	problems: Array[String],
	map_id: StringName,
	pool: Array[MapSpawnPoolEntry],
	label: String
) -> void:
	for entry in pool:
		if entry == null or entry.monster_id.is_empty():
			continue
		if ModLoader.get_monster(entry.monster_id) == null:
			problems.append("%s：%s怪物不存在 %s" % [map_id, label, entry.monster_id])


static func _quantity_stone_template() -> QuantityStoneData:
	return ModLoader.get_item(QUANTITY_STONE_ID) as QuantityStoneData
