extends RefCounted
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


static func from_grid(source_container: String, source_grid: Vector2i) -> DragOrigin:
	var origin := DragOrigin.new()
	origin.kind = Kind.GRID
	origin.container_name = source_container
	origin.grid = source_grid
	return origin


static func from_slot(source_slot: String) -> DragOrigin:
	var origin := DragOrigin.new()
	origin.kind = Kind.SLOT
	origin.slot_name = source_slot
	return origin


static func none() -> DragOrigin:
	return DragOrigin.new()
