class_name CubeOrientation
extends Node3D

signal settled

enum State {
	IDLE,
	DRAGGING,
	INERTIA,
	ALIGNING,
}

const ROTATION_PER_PIXEL := 0.0055
const MAX_ANGULAR_SPEED := 7.0
const INERTIA_DAMPING := 4.0
const INERTIA_SOFT_STOP_SPEED := 1.2
const INERTIA_LOW_SPEED_DAMPING := 6.0
const INERTIA_STOP_SPEED := 0.06
const RELEASE_VELOCITY_WINDOW_US := 90_000
const ALIGN_MAX_ANGLE_DEG := 60.0
const SNAP_MIN_DURATION := 0.28
const SNAP_MAX_DURATION := 0.55

var _state: State = State.IDLE
var _faces: Array[Face3D] = []
var _angular_velocity := Vector2.ZERO
var _last_drag_usec: int = 0
var _snap_from := Quaternion.IDENTITY
var _snap_to := Quaternion.IDENTITY
var _snap_elapsed: float = 0.0
var _snap_duration: float = 0.4


func _ready() -> void:
	for child in get_children():
		if child is Face3D:
			_faces.append(child)


func _process(delta: float) -> void:
	match _state:
		State.INERTIA:
			_process_inertia(delta)
		State.ALIGNING:
			_process_alignment(delta)


func is_rotating() -> bool:
	return _state != State.IDLE


func begin_drag() -> void:
	_state = State.DRAGGING
	_angular_velocity = Vector2.ZERO
	_last_drag_usec = Time.get_ticks_usec()


func drag_by(relative: Vector2) -> void:
	if _state != State.DRAGGING or relative.is_zero_approx():
		return
	_rotate_in_camera_space(relative * ROTATION_PER_PIXEL)
	_track_angular_velocity(relative)
	_last_drag_usec = Time.get_ticks_usec()


func end_drag() -> void:
	if _state != State.DRAGGING:
		return
	if Time.get_ticks_usec() - _last_drag_usec > RELEASE_VELOCITY_WINDOW_US:
		_angular_velocity = Vector2.ZERO
	if _angular_velocity.length() < INERTIA_STOP_SPEED:
		_begin_alignment()
	else:
		_state = State.INERTIA


func stop_rotation() -> void:
	_state = State.IDLE
	_angular_velocity = Vector2.ZERO


func rotate_to_face(face_index: int) -> bool:
	var camera := _get_camera()
	if camera == null:
		return false
	var face := _find_face(face_index)
	if face == null:
		return false
	_begin_snap(_alignment_quaternion(camera, face).normalized())
	return true


func snap_face_to_camera(face_index: int) -> bool:
	var camera := _get_camera()
	if camera == null:
		return false
	var face := _find_face(face_index)
	if face == null:
		return false
	stop_rotation()
	quaternion = _alignment_quaternion(camera, face).normalized()
	return true


func _process_inertia(delta: float) -> void:
	_rotate_in_camera_space(_angular_velocity * delta)
	var speed_ratio := clampf(
			_angular_velocity.length() / INERTIA_SOFT_STOP_SPEED, 0.0, 1.0)
	var slow_factor := 1.0 - speed_ratio
	var low_speed_bonus := INERTIA_LOW_SPEED_DAMPING * slow_factor * slow_factor
	var damping := INERTIA_DAMPING + low_speed_bonus
	_angular_velocity *= exp(-damping * delta)
	if _angular_velocity.length() <= INERTIA_STOP_SPEED:
		_begin_alignment()


func _track_angular_velocity(relative: Vector2) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := maxf(float(now - _last_drag_usec) / 1_000_000.0, 0.001)
	var instant_velocity := relative / elapsed * ROTATION_PER_PIXEL
	_angular_velocity = _angular_velocity.lerp(instant_velocity, 0.42)
	_angular_velocity = _angular_velocity.limit_length(MAX_ANGULAR_SPEED)


func _rotate_in_camera_space(angles: Vector2) -> void:
	var camera := _get_camera()
	if camera == null:
		return
	var yaw := Quaternion(camera.global_basis.y.normalized(), angles.x)
	var pitch := Quaternion(camera.global_basis.x.normalized(), angles.y)
	quaternion = (yaw * pitch * quaternion).normalized()


func _begin_alignment() -> void:
	var camera := _get_camera()
	if camera == null or _faces.is_empty():
		_finish_motion()
		return

	var to_camera := (camera.global_position - global_position).normalized()
	var best_face := _find_best_face(to_camera)
	var best_alignment := best_face.global_basis.z.normalized().dot(to_camera)
	if best_alignment < cos(deg_to_rad(ALIGN_MAX_ANGLE_DEG)):
		_finish_motion()
		return

	var target_quaternion := _alignment_quaternion(camera, best_face)
	_begin_snap(target_quaternion)


func _begin_snap(target_quaternion: Quaternion) -> void:
	stop_rotation()
	_snap_from = quaternion
	_snap_to = target_quaternion
	_snap_elapsed = 0.0

	var angle := _snap_from.angle_to(_snap_to)
	_snap_duration = clampf(0.12 + angle * 0.22, SNAP_MIN_DURATION, SNAP_MAX_DURATION)
	if angle < 0.002:
		quaternion = _snap_to
		_finish_motion()
		return

	_state = State.ALIGNING


func _find_best_face(to_camera: Vector3) -> Face3D:
	var best_face := _faces[0]
	var best_alignment := -INF

	for face in _faces:
		var alignment := face.global_basis.z.normalized().dot(to_camera)
		if alignment > best_alignment:
			best_alignment = alignment
			best_face = face

	return best_face


func _find_face(face_index: int) -> Face3D:
	for face in _faces:
		if face.face_index == face_index:
			return face
	return null


func _alignment_quaternion(camera: Camera3D, face: Face3D) -> Quaternion:
	var to_camera := (camera.global_position - global_position).normalized()
	var camera_up := camera.global_basis.y.normalized()
	var target_up := camera_up - to_camera * camera_up.dot(to_camera)
	if target_up.length_squared() < 0.0001:
		var fallback_up := Vector3.UP
		if absf(to_camera.dot(Vector3.UP)) > 0.99:
			fallback_up = Vector3.RIGHT
		target_up = fallback_up - to_camera * fallback_up.dot(to_camera)
	target_up = target_up.normalized()

	var target_normal := to_camera
	var target_right := target_up.cross(target_normal).normalized()
	var target_basis := Basis(target_right, target_up, target_normal)

	var face_basis := face.transform.basis.orthonormalized()
	var global_target_basis := (target_basis * face_basis.transposed()).orthonormalized()

	var parent := get_parent_node_3d()
	if parent != null:
		var parent_basis := parent.global_basis.orthonormalized()
		global_target_basis = (parent_basis.inverse() * global_target_basis).orthonormalized()

	return global_target_basis.get_rotation_quaternion().normalized()


func _process_alignment(delta: float) -> void:
	_snap_elapsed += delta
	var weight := clampf(_snap_elapsed / _snap_duration, 0.0, 1.0)
	var eased_weight := weight * weight * (3.0 - 2.0 * weight)
	quaternion = _snap_from.slerp(_snap_to, eased_weight).normalized()
	if weight >= 1.0:
		quaternion = _snap_to
		_finish_motion()


func _finish_motion() -> void:
	_state = State.IDLE
	_angular_velocity = Vector2.ZERO
	settled.emit()


func _get_camera() -> Camera3D:
	return get_viewport().get_camera_3d()
