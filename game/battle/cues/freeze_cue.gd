class_name FreezeCue
extends GameplayCueNotify

const FADE_TIME : float = 0.25
const HALO_SCALE : Vector2 = Vector2(0.75, 0.55)

@onready var halo : Sprite2D = $Halo
@onready var frost : CPUParticles2D = $Frost

var _tween : Tween
var _pulse_time : float = 0.0
var _ending : bool = false


func play_cue() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_ending = false
	_pulse_time = 0.0
	halo.visible = true
	halo.modulate.a = 0.65
	halo.scale = HALO_SCALE
	frost.visible = true
	frost.modulate.a = 1.0
	frost.emitting = true
	frost.restart()


func _process(delta: float) -> void:
	if _ending:
		return
	_pulse_time += delta
	var wave := sin(_pulse_time * 3.0)
	halo.scale = HALO_SCALE * (0.94 + wave * 0.06)
	halo.modulate.a = 0.6 + wave * 0.1


func end_cue() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_ending = true
	frost.emitting = false
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(frost, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_property(halo, "modulate:a", 0.0, FADE_TIME)
	_tween.chain().tween_callback(finish_cue)
