## 六边形格子的纯数学：距离、邻居。
##
## 战场用 pointy-top + odd-r 偏移坐标（和 TileMapLayer 的排布一致）。
## 这里不碰任何节点，只算坐标 —— 选目标、寻路都靠它。
##
## 注意：坐标里是有负数的（棋盘以中心为原点），所以别拿 0 当"没有格子"。

class_name Hex extends RefCounted

## 六个邻居的偏移。odd-r：奇数行整体右移半格，所以两行的邻居表不一样
const EVEN_ROW_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const ODD_ROW_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]


## 两格之间隔了几步
static func distance(a: Vector2i, b: Vector2i) -> int:
	var a_cube := _to_cube(a)
	var b_cube := _to_cube(b)
	return max(absi(a_cube.x - b_cube.x), absi(a_cube.y - b_cube.y), absi(a_cube.z - b_cube.z))


## 这一格的六个邻居（不检查是否在地图上、有没有被占）
static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var offsets := ODD_ROW_OFFSETS if (cell.y & 1) == 1 else EVEN_ROW_OFFSETS
	var result: Array[Vector2i] = []
	for offset in offsets:
		result.append(cell + offset)
	return result


## 偏移坐标 → 立方坐标，取三个轴的最大差就是距离
static func _to_cube(coord: Vector2i) -> Vector3i:
	var q := coord.x - (coord.y - (coord.y & 1)) / 2
	var r := coord.y
	return Vector3i(q, r, -q - r)
