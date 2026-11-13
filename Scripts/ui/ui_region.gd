class_name UiRegion
extends RefCounted
## 把若干轴对齐矩形合成一个窗口鼠标区域多边形。
##
## Windows 上 mouse_passthrough_polygon 只接受一个多边形，而且区域外不绘制。
## 多个不相连的 UI 区域用 2px 宽的走廊连成一棵树，走廊落在透明空地上，
## 不会挡视线；点击只在走廊的 2px 宽度上被拦截。

const CORRIDOR_HALF_WIDTH : float = 1.0


static func build(rects : Array[Rect2]) -> PackedVector2Array:
	var valid : Array[Rect2] = []
	for rect in rects:
		var rounded := Rect2(rect.position.round(), rect.size.round())
		if rounded.size.x >= 1.0 and rounded.size.y >= 1.0:
			valid.append(rounded)
	if valid.is_empty():
		return PackedVector2Array()
	if valid.size() == 1:
		return _rect_polygon(valid[0])

	valid.sort_custom(
		func(a : Rect2, b : Rect2) -> bool:
			var a_center := a.get_center()
			var b_center := b.get_center()
			if not is_equal_approx(a_center.x, b_center.x):
				return a_center.x < b_center.x
			return a_center.y < b_center.y
	)

	var current := _rect_polygon(valid[0])
	var previous_center := valid[0].get_center()
	for index in range(1, valid.size()):
		var center := valid[index].get_center()
		var corridor := _corridor(previous_center, center)
		if corridor.size() >= 3:
			current = _largest(Geometry2D.merge_polygons(current, corridor), current)
		current = _largest(Geometry2D.merge_polygons(current, _rect_polygon(valid[index])), current)
		previous_center = center
	return current


static func full_window(area : Vector2) -> PackedVector2Array:
	return _rect_polygon(Rect2(Vector2.ZERO, area))


## Geometry2D / CreatePolygonRgn 约定外轮廓为顺时针（屏幕坐标 y 向下）
static func _rect_polygon(rect : Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.position.x, rect.end.y),
		rect.end,
		Vector2(rect.end.x, rect.position.y),
	])


static func _corridor(from : Vector2, to : Vector2) -> PackedVector2Array:
	var delta := to - from
	if delta.length_squared() < 0.25:
		return PackedVector2Array()
	var normal := Vector2(-delta.y, delta.x).normalized() * CORRIDOR_HALF_WIDTH
	return PackedVector2Array([
		from + normal,
		to + normal,
		to - normal,
		from - normal,
	])


## 取合并结果里面积最大的多边形；孔洞会被填掉（窗口区域只接受一个轮廓）
static func _largest(polygons : Array[PackedVector2Array], fallback : PackedVector2Array) -> PackedVector2Array:
	var best := fallback
	var best_area := 0.0
	for polygon in polygons:
		var area := absf(_signed_area(polygon))
		if area > best_area:
			best = polygon
			best_area = area
	return best


static func _signed_area(polygon : PackedVector2Array) -> float:
	var area := 0.0
	var count := polygon.size()
	for index in count:
		var current := polygon[index]
		var next := polygon[(index + 1) % count]
		area += current.x * next.y - next.x * current.y
	return area * 0.5
