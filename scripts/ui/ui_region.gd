class_name UiRegion
extends RefCounted

const CORRIDOR_HALF_WIDTH: float = 1.0
const MIN_RECT_SIZE: float = 1.0


static func build(
		base_polygon: PackedVector2Array,
		rects: Array[Rect2],
		padding: float,
		area: Rect2,
		rect_padding: float = -1.0,
) -> PackedVector2Array:
	var shapes: Array[PackedVector2Array] = []
	var anchor := Vector2.ZERO
	var has_base := false

	var base := _clockwise(base_polygon)
	if base.size() >= 3:
		var expanded := Geometry2D.offset_polygon(base, padding)
		var clipped := _clip_to_area(_largest(expanded), area)
		if clipped.size() >= 3:
			shapes.append(_clockwise(clipped))
			anchor = _bounds_center(clipped)
			has_base = true

	var rect_margin := rect_padding if rect_padding >= 0.0 else padding
	for rect in rects:
		var clipped_rect := rect.grow(rect_margin).intersection(area)
		var rounded := Rect2(clipped_rect.position.round(), clipped_rect.size.round())
		if rounded.size.x < MIN_RECT_SIZE or rounded.size.y < MIN_RECT_SIZE:
			continue
		shapes.append(_rect_polygon(rounded))

	if shapes.is_empty():
		return PackedVector2Array()
	if shapes.size() == 1:
		return _clockwise(shapes[0])

	if not has_base:
		anchor = _bounds_center(shapes[0])

	var current := shapes[0]
	for index in range(1, shapes.size()):
		var center := _bounds_center(shapes[index])
		var corridor := _corridor(anchor, center)
		if corridor.size() >= 3:
			current = _union(current, _clockwise(corridor))
		current = _union(current, _clockwise(shapes[index]))

	return _clockwise(current)


static func full_window(area: Vector2) -> PackedVector2Array:
	return _rect_polygon(Rect2(Vector2.ZERO, area))


static func minimal_region() -> PackedVector2Array:
	return _rect_polygon(Rect2(Vector2.ZERO, Vector2.ONE))


static func _union(first: PackedVector2Array, second: PackedVector2Array) -> PackedVector2Array:
	var merged := _largest(Geometry2D.merge_polygons(first, second))
	if merged.size() >= 3:
		return merged
	return first


static func _clip_to_area(polygon: PackedVector2Array, area: Rect2) -> PackedVector2Array:
	if polygon.size() < 3:
		return PackedVector2Array()
	var clipped := Geometry2D.intersect_polygons(polygon, _rect_polygon(area))
	return _largest(clipped)


static func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.position.x, rect.end.y),
		rect.end,
		Vector2(rect.end.x, rect.position.y),
	])


static func _corridor(from: Vector2, to: Vector2) -> PackedVector2Array:
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


static func _largest(polygons: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := 0.0
	for polygon in polygons:
		var cleaned := _clean(polygon)
		if cleaned.size() < 3:
			continue
		var area := absf(_signed_area(cleaned))
		if area > best_area:
			best = cleaned
			best_area = area
	return best


static func _clockwise(polygon: PackedVector2Array) -> PackedVector2Array:
	var cleaned := _clean(polygon)
	if cleaned.size() >= 3 and not Geometry2D.is_polygon_clockwise(cleaned):
		cleaned.reverse()
	return cleaned


static func _clean(polygon: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in polygon:
		if result.is_empty() or not result[result.size() - 1].is_equal_approx(point):
			result.append(point)
	if result.size() >= 2 and result[0].is_equal_approx(result[result.size() - 1]):
		result.remove_at(result.size() - 1)
	return result


static func _bounds_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for index in range(1, polygon.size()):
		bounds = bounds.expand(polygon[index])
	return bounds.get_center()


static func _signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	var count := polygon.size()
	for index in count:
		var current := polygon[index]
		var next := polygon[(index + 1) % count]
		area += current.x * next.y - next.x * current.y
	return area * 0.5
