extends Resource
class_name MapSpawnPoolEntry

## 刷出的怪物 content_id
@export var monster_id: StringName = &""
## 随机抽取权重（需大于 0）
@export_range(0.01, 1000.0, 0.1) var weight: float = 1.0
## 刷出等级区间 [min, max]，需落在所属地图 level_range 内
@export var level_range: Vector2i = Vector2i(1, 1)


func roll_level(rng: RandomNumberGenerator) -> int:
	var low := maxi(level_range.x, 1)
	var high := maxi(level_range.y, low)
	if rng == null or low == high:
		return low
	return rng.randi_range(low, high)


func collect_problems(
	problems: Array[String],
	map_level_range: Vector2i,
	label: String
) -> void:
	if monster_id.is_empty():
		problems.append("%s 缺少 monster_id" % label)
	if weight <= 0.0:
		problems.append("%s（%s）：weight 必须大于 0" % [label, monster_id])
	if level_range.x < 1 or level_range.y < level_range.x:
		problems.append("%s（%s）：level_range 非法 %s" % [label, monster_id, level_range])
	elif (
		map_level_range.x >= 1
		and map_level_range.y >= map_level_range.x
		and (level_range.x < map_level_range.x or level_range.y > map_level_range.y)
	):
		problems.append(
			"%s（%s）：等级区间 %s 超出地图等级范围 %s"
			% [label, monster_id, level_range, map_level_range]
		)
