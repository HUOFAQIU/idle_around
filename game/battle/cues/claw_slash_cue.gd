class_name ClawSlashCue
extends GameplayCueNotify

const DIRECTION_KEY : StringName = &"direction"
const POSITION_KEY : StringName = &"position"

@onready var painter : ClawSlashPainter = $Slashes

var _direction : float = 1.0
var _world_position : Variant = null


func execute_cue(target: Node, payload: Dictionary = {}) -> void:
	_direction = -1.0 if float(payload.get(DIRECTION_KEY, 1.0)) < 0.0 else 1.0
	_world_position = payload.get(POSITION_KEY, null)
	super.execute_cue(target, payload)


func play_cue() -> void:
	painter.play(_direction)
	if _world_position is Vector2:
		painter.global_position = _world_position
