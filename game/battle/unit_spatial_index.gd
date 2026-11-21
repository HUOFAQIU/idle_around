class_name UnitSpatialIndex extends RefCounted

const BUCKET_PX: float = 64.0

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
