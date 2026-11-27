class_name BattleGrid extends RefCounted

const DEFAULT_CELL_SIZE_PX: float = 32.0

var cell_size_px: float = DEFAULT_CELL_SIZE_PX


func _init(p_cell_size_px: float = DEFAULT_CELL_SIZE_PX) -> void:
	cell_size_px = maxf(p_cell_size_px, 1.0)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * cell_size_px, float(cell.y) * cell_size_px)


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / cell_size_px), floori(pos.y / cell_size_px))
