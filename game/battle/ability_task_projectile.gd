class_name AbilityTask_Projectile extends AbilityTask

signal projectile_landed(hit_unit: BattleUnit)

var _hit_count : int = 0
var _pending : int = 0


func execute(
	caster: BattleUnit,
	targets: Array[BattleUnit],
	speed: float = SoulProjectile.DEFAULT_SPEED
) -> void:
	if is_aborted:
		return
	if caster == null or caster.battle == null or targets.is_empty():
		finish_task(0)
		return

	_hit_count = 0
	_pending = 0

	for target in targets:
		if target == null:
			continue
		var projectile := SoulProjectile.new()
		projectile.setup(caster, target.position, speed)
		projectile.finished.connect(_on_projectile_finished)
		caster.battle.add_projectile(projectile)
		_pending += 1

	if _pending == 0:
		finish_task(0)


func _on_projectile_finished(_projectile: SoulProjectile, hit_unit: BattleUnit) -> void:
	if hit_unit:
		_hit_count += 1
	projectile_landed.emit(hit_unit)
	_pending -= 1
	if _pending <= 0 and not is_aborted:
		finish_task(_hit_count)
