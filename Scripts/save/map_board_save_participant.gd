class_name MapBoardSaveParticipant
extends SaveParticipant
## 地图板存档域：8 个已放置地图和中心待放地图。
##
## 地图不在 GBIS 容器里，所以单独保存；读档时找不到地图的原始记录
## 原样带回存档，下次读档再试，避免因为内容暂时缺失而丢地图。
## 战斗内的刷怪进度不保存。

## 读档时无法还原的原始记录；collect 时原样写回
var _orphans: Array[Dictionary] = []


func collect_into(document: Dictionary) -> void:
	var slots: Array = []
	for index in MapBoard.SLOT_COUNT:
		slots.append(_encode(MapBoard.get_slot(index)))
	document[SaveDocument.KEY_MAP_BOARD] = {
		"slots": slots,
		"pending": _encode(MapBoard.get_pending()),
		"orphaned": _orphans.duplicate(true),
	}


func apply_from(document: Dictionary, _has_disk_data: bool) -> bool:
	_orphans.clear()
	var slots: Array[MapItemData] = []
	slots.resize(MapBoard.SLOT_COUNT)
	var pending: MapItemData

	var raw: Variant = document.get(SaveDocument.KEY_MAP_BOARD, {})
	if raw is Dictionary:
		var data := raw as Dictionary
		var raw_slots: Variant = data.get("slots", [])
		if raw_slots is Array:
			var slot_records := raw_slots as Array
			for index in mini(slot_records.size(), MapBoard.SLOT_COUNT):
				slots[index] = _decode(slot_records[index], index, false)
		pending = _decode(data.get("pending", null), -1, true)
		_collect_old_orphans(data.get("orphaned", []))

	pending = _restore_old_orphans(slots, pending)
	MapBoard.restore(slots, pending)
	return false


## 物品 -> 记录；空物品返回 null
static func _encode(item: MapItemData) -> Variant:
	if item == null:
		return null
	var record := SaveCodec.encode_item(item)
	if record.is_empty():
		return null
	return record


## 记录 -> 地图物品；失败时把原始记录收进 _orphans
func _decode(record: Variant, slot_index: int, is_pending: bool) -> MapItemData:
	if not record is Dictionary:
		return null
	var record_data := record as Dictionary
	var item := SaveCodec.decode_item(record_data)
	if item is MapItemData:
		return item as MapItemData
	_append_orphan(record_data, slot_index, is_pending)
	return null


func _collect_old_orphans(raw: Variant) -> void:
	if not raw is Array:
		return
	for entry in raw as Array:
		if entry is Dictionary:
			_orphans.append((entry as Dictionary).duplicate(true))


## 上次读档留下的记录：能找到就放回空位，找不到继续保留
func _restore_old_orphans(
	slots: Array[MapItemData],
	pending: MapItemData,
) -> MapItemData:
	var remaining: Array[Dictionary] = []
	for entry in _orphans:
		var record: Variant = entry.get("record", {})
		var item: ItemData = null
		if record is Dictionary:
			item = SaveCodec.decode_item(record as Dictionary)
		if not item is MapItemData:
			remaining.append(entry)
			continue
		var slot_index := int(entry.get("slot", -1))
		var is_pending := bool(entry.get("pending", false))
		if is_pending and pending == null:
			pending = item as MapItemData
			continue
		if slot_index >= 0 and slot_index < MapBoard.SLOT_COUNT \
				and slots[slot_index] == null:
			slots[slot_index] = item as MapItemData
			continue
		var free_slot := _first_empty(slots)
		if free_slot >= 0:
			slots[free_slot] = item as MapItemData
		elif pending == null:
			pending = item as MapItemData
		else:
			remaining.append(entry)
	_orphans = remaining
	return pending


static func _first_empty(slots: Array[MapItemData]) -> int:
	for index in slots.size():
		if slots[index] == null:
			return index
	return -1


func _append_orphan(record: Dictionary, slot_index: int, is_pending: bool) -> void:
	_orphans.append({
		"slot": slot_index,
		"pending": is_pending,
		"record": record.duplicate(true),
	})
