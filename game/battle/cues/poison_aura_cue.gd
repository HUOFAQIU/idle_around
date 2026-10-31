class_name PoisonAuraCue
extends GameplayCueNotify
## 剧毒状态光环：中毒期间持续冒墨绿气泡，效果结束后淡出回池。

const FADE_TIME : float = 0.25

@onready var bubbles : CPUParticles2D = $Bubbles

var _tween : Tween


func play_cue() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	bubbles.visible = true
	bubbles.modulate.a = 1.0
	bubbles.emitting = true
	bubbles.restart()


func end_cue() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	bubbles.emitting = false
	_tween = create_tween()
	_tween.tween_property(bubbles, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(finish_cue)
