class_name Hex extends RefCounted


static func distance(a: Vector2i, b: Vector2i) -> int:
	var a_cube := _to_cube(a)
	var b_cube := _to_cube(b)
	return max(absi(a_cube.x - b_cube.x), absi(a_cube.y - b_cube.y), absi(a_cube.z - b_cube.z))


static func _to_cube(coord: Vector2i) -> Vector3i:
	@warning_ignore("integer_division")
	var q := coord.x - (coord.y - (coord.y & 1)) / 2
	var r := coord.y
	return Vector3i(q, r, -q - r)
