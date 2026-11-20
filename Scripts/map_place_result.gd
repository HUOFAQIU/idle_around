class_name MapPlaceResult
extends RefCounted
## MapBoard 放置意图的结果；slot_index 仅在 PLACED 时有效。

enum Status {
	PLACED,
	QUEUED,
	REJECTED,
}

var status: Status = Status.REJECTED
var item: MapItemData
var slot_index: int = -1


func _init(p_status: Status, p_item: MapItemData = null, p_slot_index: int = -1) -> void:
	status = p_status
	item = p_item
	slot_index = p_slot_index


static func placed(p_item: MapItemData, p_slot_index: int) -> MapPlaceResult:
	return MapPlaceResult.new(Status.PLACED, p_item, p_slot_index)


static func queued(p_item: MapItemData) -> MapPlaceResult:
	return MapPlaceResult.new(Status.QUEUED, p_item)


static func rejected(p_item: MapItemData = null) -> MapPlaceResult:
	return MapPlaceResult.new(Status.REJECTED, p_item)
