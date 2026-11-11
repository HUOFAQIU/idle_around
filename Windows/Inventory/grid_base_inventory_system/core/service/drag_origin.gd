extends RefCounted
## 拖拽来源；取消时按来源把物品放回去。
class_name DragOrigin

enum Kind {
	NONE,
	GRID,
	SLOT,
}

var kind: Kind = Kind.NONE
var container_name: String = ""
var grid: Vector2i = Vector2i.ZERO
var slot_name: String = ""


## 从容器格子拿起；source_grid 是物品左上角所在格
static func from_grid(source_container: String, source_grid: Vector2i) -> DragOrigin:
	var origin := DragOrigin.new()
	origin.kind = Kind.GRID
	origin.container_name = source_container
	origin.grid = source_grid
	return origin


## 从装备槽拿起
static func from_slot(source_slot: String) -> DragOrigin:
	var origin := DragOrigin.new()
	origin.kind = Kind.SLOT
	origin.slot_name = source_slot
	return origin


## 分割等没有原格的拖拽；取消时保持原样
static func none() -> DragOrigin:
	return DragOrigin.new()
