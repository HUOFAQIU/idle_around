class_name BurnCue
extends GameplayCueNotify
## 灼烧状态光环：持续期间一直冒火，效果结束后淡出回池。

const FADE_TIME : float = 0.25

@onready var flame : CPUParticles2D = $Flame
@onready var embers : CPUParticles2D = $Embers

var _tween : Tween


func play_cue() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_reset_particles(flame)
	_reset_particles(embers)


func end_cue() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	flame.emitting = false
	embers.emitting = false
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(flame, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_property(embers, "modulate:a", 0.0, FADE_TIME)
	_tween.chain().tween_callback(finish_cue)


func _reset_particles(particles : CPUParticles2D) -> void:
	particles.visible = true
	particles.modulate.a = 1.0
	particles.emitting = true
	particles.restart()
