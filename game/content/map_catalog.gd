class_name MapCatalog
extends RefCounted

const FOREST_MAP_ID: StringName = &"forest_map"
const QUANTITY_STONE_ID: StringName = &"quantity_stone"
const FOREST_MAP_PATH: String = "res://base_mods/core/maps/forest/forest_map.tres"
const QUANTITY_STONE_PATH: String = (
	"res://base_mods/core/items/quantity_stone/quantity_stone.tres"
)

static var _forest_map: MapData
static var _quantity_stone: QuantityStoneData


static func get_map(id: StringName) -> MapData:
	match id:
		FOREST_MAP_ID:
			if _forest_map == null:
				_forest_map = load(FOREST_MAP_PATH) as MapData
			return _forest_map
	return null


static func get_map_ids() -> Array[StringName]:
	return [FOREST_MAP_ID]


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
	return [QUANTITY_STONE_ID]


static func collect_problems() -> Array[String]:
	var problems: Array[String] = []
	for id in get_map_ids():
		var map_data := get_map(id)
		if map_data == null:
			problems.append("地图资源打不开：%s" % id)
			continue
		problems.append_array(map_data.collect_problems())
		for entry in map_data.spawn_entries:
			if entry == null:
				continue
			if CollectionDB.get_monster(entry.monster_id) == null:
				problems.append("%s：怪物不存在 %s" % [id, entry.monster_id])
			if entry.condition == MapSpawnEntry.Condition.KILL_COUNT \
					and CollectionDB.get_monster(entry.kill_monster_id) == null:
				problems.append("%s：击杀条件怪物不存在 %s" % [id, entry.kill_monster_id])
	if _quantity_stone_template() == null:
		problems.append("数量石资源打不开：%s" % QUANTITY_STONE_PATH)
	return problems


static func _quantity_stone_template() -> QuantityStoneData:
	if _quantity_stone == null:
		_quantity_stone = load(QUANTITY_STONE_PATH) as QuantityStoneData
	return _quantity_stone
