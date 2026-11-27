class_name UnitSpatialIndex extends RefCounted

const BUCKET_PX: float = 28.0
const SOFT_RADIUS_RATIO: float = 0.65
const SOFT_STIFFNESS: float = 1.45
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1),
]

var _buckets: Dictionary = {}
var _bucket_of_unit: Dictionary = {}


func register(unit: BattleUnit) -> void:
	var key := _bucket_key(unit.position)
	var bucket: Array = _buckets.get(key, [])
	bucket.append(unit)
	_buckets[key] = bucket
	_bucket_of_unit[unit.get_instance_id()] = key


func unregister(unit: BattleUnit) -> void:
	var id := unit.get_instance_id()
	if not _bucket_of_unit.has(id):
		return
	var key: Vector2i = _bucket_of_unit[id]
	_bucket_of_unit.erase(id)
	var bucket: Array = _buckets.get(key, [])
	bucket.erase(unit)
	if bucket.is_empty():
		_buckets.erase(key)
	else:
		_buckets[key] = bucket


func update(unit: BattleUnit) -> void:
	var id := unit.get_instance_id()
	var new_key := _bucket_key(unit.position)
	if _bucket_of_unit.get(id) == new_key:
		return
	unregister(unit)
	register(unit)


func near(pos: Vector2, radius: float) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	var key_radius := int(ceil(radius / BUCKET_PX))
	var center := _bucket_key(pos)
	for bx in range(center.x - key_radius, center.x + key_radius + 1):
		for by in range(center.y - key_radius, center.y + key_radius + 1):
			var bucket = _buckets.get(Vector2i(bx, by))
			if bucket == null:
				continue
			for unit in bucket:
				if unit != null and not unit.is_dead and pos.distance_to(unit.position) <= radius:
					result.append(unit)
	return result


func clear() -> void:
	_buckets.clear()
	_bucket_of_unit.clear()


func _bucket_key(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / BUCKET_PX), floori(pos.y / BUCKET_PX))


func compute_separation(
	unit: BattleUnit,
	max_hits: int = 10,
	max_scan: int = 32,
	max_speed: float = 12.0
) -> Vector2:
	var sep := Vector2.ZERO
	var pos := unit.position
	var team := unit.team
	var my_r := unit.body_radius
	var center := _bucket_key(pos)
	var max_sq := max_speed * max_speed
	var hits := 0
	var scanned := 0
	for offset in NEIGHBOR_OFFSETS:
		var bucket = _buckets.get(center + offset)
		if bucket == null:
			continue
		for other in bucket:
			if other == unit or other == null or other.is_dead or other.team != team:
				continue
			scanned += 1
			var min_d: float = (my_r + other.body_radius) * SOFT_RADIUS_RATIO
			var diff: Vector2 = pos - other.position
			var d2 := diff.length_squared()
			if d2 > 0.001 and d2 < min_d * min_d:
				var d := sqrt(d2)
				sep += (diff / d) * (min_d - d) * SOFT_STIFFNESS
				hits += 1
				if hits >= max_hits:
					if sep.length_squared() > max_sq:
						sep = sep.normalized() * max_speed
					return sep
			if scanned >= max_scan:
				if sep.length_squared() > max_sq:
					sep = sep.normalized() * max_speed
				return sep
	if sep.length_squared() > max_sq:
		sep = sep.normalized() * max_speed
	return sep
