## 地图适配：格子 ↔ 像素换算、格子尺寸、已使用格查询。
##
## 战斗逻辑只认像素位置；这个类把 TileMapLayer 的坐标能力收在一起，
## BattleManager 和 EnemySpawner 共用，不直接碰地图节点。
class_name BattleGrid extends RefCounted

const MIN_CELL_SIZE_PX: float = 1.0

var map: TileMapLayer
## 相邻格中心的像素距离；TargetRule 的 max_range 用它换算成像素
var cell_size_px: float = 32.0


func _init(p_map: TileMapLayer = null) -> void:
	map = p_map
	_measure_cell_size()


func cell_to_world(cell: Vector2i) -> Vector2:
	return map.map_to_local(cell)


func world_to_cell(pos: Vector2) -> Vector2i:
	return map.local_to_map(pos)


func used_cells() -> Array[Vector2i]:
	if map == null:
		return []
	return map.get_used_cells()


## 距离 anchor 至少 min_distance 格的所有已使用格子（六边形距离）
func cells_at_least(anchor: Vector2i, min_distance: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if map == null:
		return result
	for cell in map.get_used_cells():
		if Hex.distance(cell, anchor) >= min_distance:
			result.append(cell)
	return result


func _measure_cell_size() -> void:
	if map == null:
		return
	var origin := map.map_to_local(Vector2i.ZERO)
	var right := map.map_to_local(Vector2i(1, 0))
	cell_size_px = maxf(origin.distance_to(right), MIN_CELL_SIZE_PX)
