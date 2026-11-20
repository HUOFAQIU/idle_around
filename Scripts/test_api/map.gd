extends RefCounted
## TestAPI 地图 / 数量石域：地图清单、地图板与 05 面交互。
##
## 对外入口仍是 res://Scripts/test_api.gd 的 TestAPI。

const CUBE: GDScript = preload("res://Scripts/test_api/cube.gd")

static func get_map_ids() -> Array[StringName]:
	return MapCatalog.get_map_ids()


## 检查 core 地图配置：字段、怪物 id、数量石模板
static func validate_maps() -> Array[String]:
	return MapCatalog.collect_problems()


static func add_map_to_warehouse(map_id : StringName = MapCatalog.FOREST_MAP_ID) -> bool:
	var item := MapCatalog.make_map_item(map_id)
	if item == null:
		push_warning("TestAPI：地图不存在 %s" % map_id)
		return false
	return Warehouse.add_item(item)


static func add_quantity_stone_to_warehouse() -> bool:
	var stone := MapCatalog.make_quantity_stone()
	if stone == null:
		push_warning("TestAPI：数量石资源缺失")
		return false
	return Warehouse.add_item(stone)


## 地图板快照：8 个槽的地图 id/名字 + 中心待放地图
static func get_map_board_state() -> Dictionary:
	var slots : Array = []
	for index in MapBoard.SLOT_COUNT:
		var item := MapBoard.get_slot(index)
		slots.append({
			"slot": index,
			"occupied": item != null,
			"map_id": String(item.map_id()) if item != null else "",
			"name": item.item_name if item != null else "",
		})
	var pending := MapBoard.get_pending()
	return {
		"slots": slots,
		"pending": {
			"occupied": pending != null,
			"map_id": String(pending.map_id()) if pending != null else "",
			"name": pending.item_name if pending != null else "",
		},
	}


## 直接往地图板放一张地图；不传槽位时用顺时针第一个空槽
static func add_map_to_board(
	map_id : StringName = MapCatalog.FOREST_MAP_ID,
	slot_index : int = -1
) -> int:
	var item := MapCatalog.make_map_item(map_id)
	if item == null:
		push_warning("TestAPI：地图不存在 %s" % map_id)
		return -1
	if slot_index < 0:
		return MapBoard.place(item)
	return slot_index if MapBoard.place_at(slot_index, item) else -1


## 走 MapBoard.submit：有空槽放入，满则进中心待放槽
static func submit_map_to_board(map_id : StringName = MapCatalog.FOREST_MAP_ID) -> Dictionary:
	var item := MapCatalog.make_map_item(map_id)
	if item == null:
		push_warning("TestAPI：地图不存在 %s" % map_id)
		return {"status": "rejected", "slot": -1, "map_id": String(map_id)}
	return _place_result_dict(MapBoard.submit(item))


## 中心待放地图进场；返回状态与槽位
static func settle_pending_map() -> Dictionary:
	return _place_result_dict(MapBoard.settle_pending())


## 走 ⬇ 的退回仓库流程；仓库满时返回 false 且地图留在板上
static func eject_map_from_board(slot_index : int) -> bool:
	return MapBoard.eject(slot_index)


## 走 05 面的按钮点击流程：打开战斗窗口并按这张图开战
static func start_map_battle_from_board(slot_index : int) -> bool:
	var content := CUBE.face_content(GameFlow.FACE_MAP) as MapBoardContent
	if content == null:
		push_warning("TestAPI：找不到地图板内容")
		return false
	if not content.activate_map_button(slot_index):
		return false
	return true


## 走 05 面中心槽的点击流程：把手上的地图放进地图板
static func click_map_drop_slot() -> bool:
	var content := CUBE.face_content(GameFlow.FACE_MAP) as MapBoardContent
	if content == null or not GBIS.moving_item_service.is_dragging():
		return false
	content.activate_drop_slot()
	return true


static func _place_result_dict(result: MapPlaceResult) -> Dictionary:
	return {
		"status": _place_status_name(result.status),
		"slot": result.slot_index,
		"map_id": String(result.item.map_id()) if result.item != null else "",
	}


static func _place_status_name(status: MapPlaceResult.Status) -> String:
	match status:
		MapPlaceResult.Status.PLACED:
			return "placed"
		MapPlaceResult.Status.QUEUED:
			return "queued"
		_:
			return "rejected"
