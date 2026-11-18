class_name SaveCodec
extends RefCounted
## 存档编解码：物品 <-> JSON 记录。
##
## 只存 content_id（core / mod manifest ID）和格子锚点；
## 静态数据从资源重建。新增物品类型时在这里加 kind 分支，并保证能按 ID 找回原资源。
##
## 魂器额外保存内部魂灵：contents 数组里的记录和容器记录格式相同，
## 但锚点是相对魂器内部容器的坐标。读档时按锚点放回；找不到的魂灵记录
## 交给调用方保留到 orphaned，避免读档丢物品。

const KIND_SOUL: String = "soul"
const KIND_VESSEL: String = "vessel"
const KIND_MAP: String = "map"
const KIND_STONE: String = "stone"


## 物品 -> 存档记录；不认识的类型返回空字典
static func encode_item(item: ItemData) -> Dictionary:
	if item == null:
		return {}
	if item is SoulData:
		var soul := item as SoulData
		# content_id 在加载时写入并随 duplicate() 保留；name 只用于排查
		var id: StringName = soul.content_id
		if id.is_empty():
			push_warning("存档：魂灵没有 content_id「%s」" % soul.item_name)
			return {}
		return {
			"kind": KIND_SOUL,
			"id": String(id),
			"name": soul.item_name,
		}
	if item is SoulVesselData:
		var vessel := item as SoulVesselData
		var vessel_id: StringName = vessel.content_id
		if vessel_id.is_empty():
			push_warning("存档：魂器没有 content_id「%s」" % vessel.item_name)
			return {}
		return {
			"kind": KIND_VESSEL,
			"id": String(vessel_id),
			"name": vessel.item_name,
			"contents": _encode_contents(vessel),
		}
	if item is MapItemData:
		var map_item := item as MapItemData
		var map_id: StringName = map_item.map_id()
		if map_id.is_empty():
			push_warning("存档：地图没有 content_id「%s」" % map_item.item_name)
			return {}
		return {
			"kind": KIND_MAP,
			"id": String(map_id),
			"name": map_item.item_name,
		}
	if item is QuantityStoneData:
		var stone := item as QuantityStoneData
		var stone_id: StringName = stone.content_id
		if stone_id.is_empty():
			push_warning("存档：数量石没有 content_id「%s」" % stone.item_name)
			return {}
		return {
			"kind": KIND_STONE,
			"id": String(stone_id),
			"name": stone.item_name,
		}
	push_warning("存档：未知物品类型「%s」" % item.item_name)
	return {}


## 存档记录 -> 新的物品实例；找不到资源时返回 null。
## orphans 非空时，魂器内部无法还原的魂灵记录会以原始 Dictionary 追加进去。
static func decode_item(record: Dictionary, orphans: Array = []) -> ItemData:
	var kind := String(record.get("kind", ""))
	var id := StringName(String(record.get("id", "")))
	if kind == KIND_SOUL:
		var soul := CollectionDB.get_soul(id)
		if soul == null:
			push_warning("存档：找不到魂灵「%s」" % id)
			return null
		return soul.make_instance()
	if kind == KIND_VESSEL:
		var vessel := CollectionDB.get_vessel(id)
		if vessel == null:
			push_warning("存档：找不到魂器「%s」" % id)
			return null
		var instance := vessel.make_instance() as SoulVesselData
		_decode_contents(instance, record.get("contents", []), orphans)
		return instance
	if kind == KIND_MAP:
		var map_item := MapCatalog.make_map_item(id)
		if map_item == null:
			push_warning("存档：找不到地图「%s」" % id)
			return null
		return map_item
	if kind == KIND_STONE:
		if id != MapCatalog.QUANTITY_STONE_ID:
			push_warning("存档：找不到数量石「%s」" % id)
			return null
		var stone := MapCatalog.make_quantity_stone()
		if stone == null:
			push_warning("存档：数量石资源缺失")
			return null
		return stone
	push_warning("存档：未知物品 kind「%s」" % kind)
	return null


## 整个容器 -> 按锚点排序的记录数组
static func encode_container(container: ContainerData) -> Array:
	var records: Array = []
	for item in container.items:
		var record := encode_item(item)
		if record.is_empty():
			continue
		var grids := container.find_grids_by_item_data(item)
		if grids.is_empty():
			continue
		var anchor := anchor_of(grids)
		record["at"] = [anchor.x, anchor.y]
		records.append(record)
	records.sort_custom(sort_records)
	return records


## 魂器内部容器 -> 记录数组；锚点相对内部容器
static func _encode_contents(vessel: SoulVesselData) -> Array:
	var records: Array = []
	var contents := vessel.ensure_contents()
	for item in contents.items:
		var record := encode_item(item)
		if record.is_empty():
			continue
		var grids := contents.find_grids_by_item_data(item)
		if grids.is_empty():
			continue
		var anchor := anchor_of(grids)
		record["at"] = [anchor.x, anchor.y]
		records.append(record)
	records.sort_custom(sort_records)
	return records


## 把存档里的内部魂灵放回魂器；放不下的原始记录交给调用方保留
static func _decode_contents(vessel: SoulVesselData, raw_records: Variant, orphans: Array) -> void:
	if not raw_records is Array:
		return
	var records: Array = []
	for record in raw_records as Array:
		if record is Dictionary:
			records.append(record)
	records.sort_custom(sort_records)
	var contents := vessel.ensure_contents()
	for record in records:
		var record_data := record as Dictionary
		var item := decode_item(record_data, orphans)
		if item == null:
			_append_orphan(orphans, record_data)
			continue
		if not contents.try_add_to_grid(item, anchor_from_record(record_data)).is_empty():
			continue
		if not contents.add_item(item).is_empty():
			continue
		_append_orphan(orphans, record_data)


static func _append_orphan(orphans: Array, record: Dictionary) -> void:
	orphans.append(record.duplicate(true))


## 一组占用格 -> 左上角锚点；实际算法在 ContainerData，存档层只做转发
static func anchor_of(grids: Array[Vector2i]) -> Vector2i:
	return ContainerData.anchor_of(grids)


## 存档记录 -> 锚点；格式不对时返回 (-1, -1)，让调用方走第一个空位兜底
static func anchor_from_record(record: Dictionary) -> Vector2i:
	var at: Variant = record.get("at", [])
	if not at is Array or (at as Array).size() < 2:
		return Vector2i(-1, -1)
	return Vector2i(int((at as Array)[0]), int((at as Array)[1]))


## 读档顺序：先上后下、先左后右，保证多格物品在原布局里能依次放下
static func sort_records(a: Dictionary, b: Dictionary) -> bool:
	var a_anchor := anchor_from_record(a)
	var b_anchor := anchor_from_record(b)
	if a_anchor.y == b_anchor.y:
		return a_anchor.x < b_anchor.x
	return a_anchor.y < b_anchor.y
