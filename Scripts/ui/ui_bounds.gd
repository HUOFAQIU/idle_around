class_name UiBounds
extends RefCounted


static func clamp_position(target : Vector2, control_size : Vector2, area : Vector2) -> Vector2:
	var max_position := (area - control_size).max(Vector2.ZERO)
	return target.clamp(Vector2.ZERO, max_position)
