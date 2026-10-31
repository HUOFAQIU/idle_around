class_name PoisonSplashCue
extends GameplayCueNotify
## 剧毒施加瞬间：墨绿液滴向四周溅开，软圆环扩散后淡出。

## 圆环扩散/淡出时长；必须小于场景上的 destroy_delay
const RING_TIME : float = 0.28

@onready var ring : Sprite2D = $Ring
@onready var splash : CPUParticles2D = $Splash

var _tween : Tween


## 对象池复用时先复位上一次播放留下的状态，再开新补间
func play_cue() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	ring.visible = true
	ring.scale = Vector2(0.45, 0.45)
	ring.modulate = Color(0.18, 0.55, 0.24, 0.95)

	splash.visible = true
	splash.modulate.a = 1.0
	splash.emitting = true
	splash.restart()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(ring, "scale", Vector2(1.6, 1.6), RING_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(ring, "modulate:a", 0.0, RING_TIME)
