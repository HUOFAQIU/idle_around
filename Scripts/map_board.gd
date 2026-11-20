extends Node
## 05 面地图板（Autoload：MapBoard）。
##
## 持有 8 个已放置地图和 1 个中心待放地图；只做状态，不碰 UI。
## 面内容监听 board_changed 重建按钮；退回仓库直接走 Warehouse.add_item。
## 槽位 0..7 从左上角起顺时针（3×3 网格的 0,1,2,5,8,7,6,3）。
## 存档由 MapBoardSaveParticipant 负责；战斗运行期状态不在这里。

## 地图板任何变化（放置、取下、待放变化）
signal board_changed
## 某个已放置地图被取下；战斗窗口据此停掉对应战斗
signal item_removed(slot_index: int)

const SLOT_COUNT: int = 8

## 已放置地图；空槽为 null
var _slots: Array[MapItemData] = []
## 中心槽里的待放地图；8 格满时留在这里
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


## 顺时针第一个空槽；全满返回 -1
func first_empty_slot() -> int:
	for index in SLOT_COUNT:
		if _slots[index] == null:
			return index
	return -1


func can_place() -> bool:
	return first_empty_slot() >= 0


## 放进第一个空槽；返回槽位，满时返回 -1
func place(item: MapItemData) -> int:
	var slot_index := first_empty_slot()
	if slot_index < 0 or item == null:
		return -1
	_slots[slot_index] = item
	board_changed.emit()
	return slot_index


## 放进指定空槽；测试和存档恢复用
func place_at(slot_index: int, item: MapItemData) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT or item == null:
		return false
	if _slots[slot_index] != null:
		return false
	_slots[slot_index] = item
	board_changed.emit()
	return true


## 提交一张地图：有空槽放第一个空槽，满则进中心待放槽；
## 中心已有待放时拒绝，物品仍归调用方。
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


## 中心待放地图进场：有空槽就原子地放入并清空中心槽。
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


## 从槽位取下；不负责去处，退回仓库用 eject
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


## 退回仓库；仓库满时地图留在原槽并返回 false
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


## 清空地图板；新档、切档和读档前使用
func clear() -> void:
	var changed := _pending != null
	_pending = null
	for index in SLOT_COUNT:
		if _slots[index] != null:
			changed = true
		_slots[index] = null
	if changed:
		board_changed.emit()


## 存档恢复：整体替换，不逐项发 item_removed
func restore(slots: Array[MapItemData], pending: MapItemData) -> void:
	_slots.resize(SLOT_COUNT)
	for index in SLOT_COUNT:
		_slots[index] = slots[index] if index < slots.size() else null
	_pending = pending
	board_changed.emit()
