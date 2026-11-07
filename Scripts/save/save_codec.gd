class_name SaveCodec
extends RefCounted
## 存档编解码：物品 <-> JSON 记录。
##
## 只存 content_id（core / mod manifest ID）和格子锚点；
## 静态数据从资源重建。新增物品类型时在这里加 kind 分支，并保证能按 ID 找回原资源。

const KIND_SOUL: String = "soul"


## 物品 -> 存档记录；不认识的类型返回空字典
static func encode_item(item: ItemData) -> Dictionary:
	if item == null:
		return {}
	if item is SoulData:
		var soul := item as SoulData
		# content_id 在加载时写入并随 duplicate() 保留；旧档/老资源没有时按名字兜底
		var id: StringName = soul.content_id
		if id.is_empty():
			id = CollectionDB.get_soul_id_by_name(soul.item_name)
		if id.is_empty():
			push_warning("存档：魂灵没有 content_id「%s」" % soul.item_name)
			return {}
		return {
			"kind": KIND_SOUL,
			"id": String(id),
			"name": soul.item_name,
		}
	push_warning("存档：未知物品类型「%s」" % item.item_name)
	return {}


## 存档记录 -> 新的物品实例；找不到资源时返回 null
static func decode_item(record: Dictionary) -> ItemData:
	var kind := String(record.get("kind", ""))
	if kind != KIND_SOUL:
		push_warning("存档：未知物品 kind「%s」" % kind)
		return null
	var id := StringName(String(record.get("id", "")))
	var soul := CollectionDB.get_soul(id)
	if soul == null and record.has("name"):
		var fallback_id := CollectionDB.get_soul_id_by_name(String(record["name"]))
		soul = CollectionDB.get_soul(fallback_id)
	if soul == null:
		push_warning("存档：找不到魂灵「%s」" % id)
		return null
	return soul.duplicate() as ItemData


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


## 一组占用格 -> 左上角锚点
static func anchor_of(grids: Array[Vector2i]) -> Vector2i:
	var anchor := grids[0]
	for grid in grids:
		anchor.x = mini(anchor.x, grid.x)
		anchor.y = mini(anchor.y, grid.y)
	return anchor


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
