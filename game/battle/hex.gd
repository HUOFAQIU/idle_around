## 六边形格子的纯数学：距离换算。
##
## 战场用 pointy-top + odd-r 偏移坐标（和 TileMapLayer 的排布一致）。
## 这里不碰任何节点，只算坐标 —— 选目标和距离换算都靠它。
##
## 注意：坐标里是有负数的（棋盘以中心为原点），所以别拿 0 当"没有格子"。

class_name Hex extends RefCounted


## 两格之间隔了几步
static func distance(a: Vector2i, b: Vector2i) -> int:
	var a_cube := _to_cube(a)
	var b_cube := _to_cube(b)
	return max(absi(a_cube.x - b_cube.x), absi(a_cube.y - b_cube.y), absi(a_cube.z - b_cube.z))


## 偏移坐标 → 立方坐标，取三个轴的最大差就是距离
static func _to_cube(coord: Vector2i) -> Vector3i:
	# 这里的整除是故意的：y - (y & 1) 一定是偶数（减掉奇偶位就成双了），
	# 除以 2 丢不了小数。分析器看不出这一层，所以手动消警
	@warning_ignore("integer_division")
	var q := coord.x - (coord.y - (coord.y & 1)) / 2
	var r := coord.y
	return Vector3i(q, r, -q - r)
