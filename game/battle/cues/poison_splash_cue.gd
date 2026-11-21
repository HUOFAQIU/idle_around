class_name PoisonSplashCue
extends GameplayCueNotify

const RING_TIME : float = 0.28

@onready var ring : Sprite2D = $Ring
@onready var splash : CPUParticles2D = $Splash

var _tween : Tween


func play_cue() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	ring.visible = true
	ring.scale = Vector2(0.45, 0.45)
	ring.modulate = GameColors.to_color(GameColors.POISON_SPLASH)

	splash.visible = true
	splash.modulate.a = 1.0
	splash.emitting = true
	splash.restart()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(ring, "scale", Vector2(1.6, 1.6), RING_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(ring, "modulate:a", 0.0, RING_TIME)
