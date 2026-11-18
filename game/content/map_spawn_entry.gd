extends Resource
## 地图刷怪条目：按时间配额刷，或按击杀另一种怪的条件刷。
##
## 时间条目（TIME_INTERVAL）按 interval_seconds 一只一只刷，总数由 count 限定；
## 击杀条目（KILL_COUNT）没有独立配额，每累计击杀 kill_threshold 只
## kill_monster_id，就刷出一只 monster_id。怪物名和 tooltip 文案由 MapData 解析。
class_name MapSpawnEntry

enum Condition {
	TIME_INTERVAL,
	KILL_COUNT,
}

## 刷怪条件
@export var condition: Condition = Condition.TIME_INTERVAL
## 刷出的怪物 content_id
@export var monster_id: StringName = &""
## TIME_INTERVAL：整张图总共刷多少只；KILL_COUNT 不使用
@export var count: int = 0
## TIME_INTERVAL：每隔多少秒刷一只
@export var interval_seconds: float = 1.0
## KILL_COUNT：击杀哪种怪
@export var kill_monster_id: StringName = &""
## KILL_COUNT：每累计击杀多少只，刷出一只
@export var kill_threshold: int = 1


## 把配置问题写进 problems；MapCatalog 和 TestAPI 共用
func collect_problems(problems: Array[String]) -> void:
	if monster_id.is_empty():
		problems.append("刷怪条目缺少 monster_id")
	match condition:
		Condition.TIME_INTERVAL:
			if count <= 0:
				problems.append("%s：时间刷怪 count 必须大于 0" % monster_id)
			if interval_seconds <= 0.0:
				problems.append("%s：时间刷怪 interval_seconds 必须大于 0" % monster_id)
		Condition.KILL_COUNT:
			if kill_monster_id.is_empty():
				problems.append("%s：击杀条件缺少 kill_monster_id" % monster_id)
			if kill_threshold <= 0:
				problems.append("%s：击杀条件 kill_threshold 必须大于 0" % monster_id)
