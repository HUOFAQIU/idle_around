class_name SoulProjectile extends RefCounted

signal finished(projectile: SoulProjectile, hit_unit: BattleUnit)

const DEFAULT_SPEED : float = 420.0
const HIT_RADIUS : float = 20.0
const MAX_LIFE : float = 3.0

var position : Vector2 = Vector2.ZERO
var rotation : float = 0.0
var modulate : Color = Color.WHITE

var _direction : Vector2 = Vector2.ZERO
var _caster : BattleUnit
var _battle : BattleManager
var _life : float = 0.0
var _done : bool = false
var _speed : float = DEFAULT_SPEED


func setup(caster: BattleUnit, aim_position: Vector2, speed: float = DEFAULT_SPEED) -> void:
	_caster = caster
	_battle = caster.battle
	_speed = speed if speed > 0.0 else DEFAULT_SPEED
	position = caster.position
	modulate = GameColors.to_color(GameColors.PROJECTILE)

	var aim_offset := aim_position - caster.position
	if aim_offset.length_squared() > 0.0001:
		_direction = aim_offset.normalized()
		rotation = _direction.angle() + PI / 2.0


func is_active() -> bool:
	return not _done


func advance(delta: float) -> void:
	if _done:
		return
	if not is_instance_valid(_battle) or not _battle.is_running:
		_finish(null)
		return

	_life += delta
	if _life >= MAX_LIFE:
		_finish(null)
		return

	var distance := _speed * delta
	while distance > 0.0:
		var step := minf(distance, HIT_RADIUS * 0.5)
		position += _direction * step
		distance -= step

		var hit := _find_hit()
		if hit:
			_finish(hit)
			return


func _find_hit() -> BattleUnit:
	if not is_instance_valid(_battle) or not is_instance_valid(_caster):
		return null
	for unit in _battle.units_near(position, HIT_RADIUS):
		if unit == _caster or unit.is_dead:
			continue
		if unit.team == _caster.team:
			continue
		return unit
	return null


func _finish(hit_unit: BattleUnit) -> void:
	_done = true
	finished.emit(self, hit_unit)
