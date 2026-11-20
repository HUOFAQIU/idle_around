class_name BattleClock
extends Node
## 战斗时间源：生产模式按物理帧推进，测试模式由 BattleSession.step_ticks() 手动推进。

signal ticked(delta: float)

## 手动模式：引擎物理帧不再推进，只能显式调用 advance()
var manual: bool = false
## 创建时的物理帧率；一个战斗 tick 的秒数由它决定
var ticks_per_second: int = 60
var tick_seconds: float = 1.0 / 60.0


func _init() -> void:
	process_physics_priority = -128
	ticks_per_second = Engine.physics_ticks_per_second
	tick_seconds = 1.0 / float(ticks_per_second)


func _physics_process(delta: float) -> void:
	if manual:
		return
	advance(delta)


func advance(delta: float) -> void:
	ticked.emit(delta)


## 秒 → tick 数（向上取整，至少 1）
func ticks_for_seconds(seconds: float) -> int:
	return maxi(1, ceili(seconds * float(ticks_per_second)))


func wait_ticks(count: int) -> void:
	for _index in maxi(count, 0):
		await ticked


func wait_seconds(seconds: float) -> void:
	await wait_ticks(ticks_for_seconds(seconds))
