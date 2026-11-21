class_name BattleClock
extends Node

signal ticked(delta: float)

var manual: bool = false
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


func ticks_for_seconds(seconds: float) -> int:
	return maxi(1, ceili(seconds * float(ticks_per_second)))


func wait_ticks(count: int) -> void:
	for _index in maxi(count, 0):
		await ticked


func wait_seconds(seconds: float) -> void:
	await wait_ticks(ticks_for_seconds(seconds))
