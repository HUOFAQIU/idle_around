extends Node

signal board_changed
signal item_removed(slot_index: int)

const SLOT_COUNT: int = 8

var _slots: Array[MapItemData] = []
var _pending: MapItemData


func _ready() -> void:
	_slots.resize(SLOT_COUNT)


func get_slot(slot_index: int) -> MapItemData:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return null
	return _slots[slot_index]


func get_slots() -> Array[MapItemData]:
	return _slots.duplicate()


func get_pending() -> MapItemData:
	return _pending


func first_empty_slot() -> int:
	for index in SLOT_COUNT:
		if _slots[index] == null:
			return index
	return -1


func can_place() -> bool:
	return first_empty_slot() >= 0


func place(item: MapItemData) -> int:
	var slot_index := first_empty_slot()
	if slot_index < 0 or item == null:
		return -1
	_slots[slot_index] = item
	board_changed.emit()
	return slot_index


func place_at(slot_index: int, item: MapItemData) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT or item == null:
		return false
	if _slots[slot_index] != null:
		return false
	_slots[slot_index] = item
	board_changed.emit()
	return true


func submit(item: MapItemData) -> MapPlaceResult:
	if item == null:
		return MapPlaceResult.rejected()
	var slot_index := place(item)
	if slot_index >= 0:
		return MapPlaceResult.placed(item, slot_index)
	if _pending != null:
		return MapPlaceResult.rejected(item)
	set_pending(item)
	return MapPlaceResult.queued(item)


func settle_pending() -> MapPlaceResult:
	if _pending == null:
		return MapPlaceResult.rejected()
	var slot_index := first_empty_slot()
	if slot_index < 0:
		return MapPlaceResult.queued(_pending)
	var item := _pending
	_pending = null
	_slots[slot_index] = item
	board_changed.emit()
	return MapPlaceResult.placed(item, slot_index)


func set_pending(item: MapItemData) -> void:
	if _pending == item:
		return
	_pending = item
	board_changed.emit()


func take_pending() -> MapItemData:
	var item := _pending
	if item == null:
		return null
	_pending = null
	board_changed.emit()
	return item


func take_slot(slot_index: int) -> MapItemData:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return null
	var item := _slots[slot_index]
	if item == null:
		return null
	_slots[slot_index] = null
	item_removed.emit(slot_index)
	board_changed.emit()
	return item


func eject(slot_index: int) -> bool:
	var item := get_slot(slot_index)
	if item == null:
		return false
	if not Warehouse.add_item(item):
		return false
	_slots[slot_index] = null
	item_removed.emit(slot_index)
	board_changed.emit()
	return true


func clear() -> void:
	var changed := _pending != null
	_pending = null
	for index in SLOT_COUNT:
		if _slots[index] != null:
			changed = true
		_slots[index] = null
	if changed:
		board_changed.emit()


func restore(slots: Array[MapItemData], pending: MapItemData) -> void:
	_slots.resize(SLOT_COUNT)
	for index in SLOT_COUNT:
		_slots[index] = slots[index] if index < slots.size() else null
	_pending = pending
	board_changed.emit()
