class_name FloatingMotion
extends Node3D
## 立方体整体的漂浮运动，只影响位置，不参与旋转逻辑。

@export var bob_height: float = 0.03
@export var bob_speed: float = 1.15
@export var sway_width: float = 0.008
@export var sway_speed: float = 0.55

var _base_position: Vector3
var _elapsed: float = 0.0


func _ready() -> void:
	_base_position = position


func _process(delta: float) -> void:
	_elapsed += delta
	position = _base_position + Vector3(
			sin(_elapsed * sway_speed) * sway_width,
			sin(_elapsed * bob_speed) * bob_height,
			0.0,
	)


func get_base_position() -> Vector3:
	return _base_position


func set_base_position(base_position: Vector3) -> void:
	_base_position = base_position
