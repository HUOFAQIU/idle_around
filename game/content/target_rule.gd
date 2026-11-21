## @meta_addon: GodotGAS
## @meta_license: MIT

class_name TargetRule extends TargetRuleBase

enum Mode {
	RANDOM,
	REPEAT,
	LOWEST_HP_PERCENT,
	NEAREST,
	ALL,
}

enum Camp {
	ENEMY,
	ALLY,
	SELF,
}

@export var mode: Mode = Mode.RANDOM
@export var count: int = 1
@export var camp: Camp = Camp.ENEMY

## 选取范围：只挑离自己 max_range 格以内的目标。0 = 不限。
## 实时制下距离按像素算，格数用 BattleManager.cell_size_px 换算。
## （效果本身可能打空、投射物可能飞歪，那是后面的事 —— 这里只决定"瞄谁"）
@export var max_range: int = 0

## camp = ALLY 时是否允许选中自己（"治疗最残血的友方（含自己）"）
@export var include_self: bool = false


func domain() -> Domain:
	return Domain.UNIT


func max_range_cells() -> int:
	return max_range


func resolve(caster_asc: AbilitySystemComponent, battle: BattleManager) -> Array:
	var groups: Array = []
	if caster_asc == null or battle == null:
		return groups

	var caster := caster_asc.get_parent() as BattleUnit
	if caster == null:
		return groups

	if camp == Camp.SELF:
		if not caster.is_dead:
			groups.append([caster])
		return groups

	var wanted_team: BattleUnit.Team = caster.team
	if camp == Camp.ENEMY:
		wanted_team = BattleUnit.opposing_team(caster.team)

	var candidates: Array = []
	var source: Array[BattleUnit]
	if max_range > 0:
		source = battle.units_near(caster.position, float(max_range) * battle.cell_size_px)
	else:
		source = battle.units_of_team(wanted_team)
	for unit in source:
		if unit.is_dead or unit.team != wanted_team:
			continue
		if unit == caster and not include_self:
			continue
		candidates.append(unit)

	if candidates.is_empty():
		return groups

	match mode:
		Mode.ALL:
			groups.append(candidates)
		Mode.RANDOM:
			groups.append(_pick_random(candidates, count, battle.rng, false))
		Mode.REPEAT:
			for i in count:
				var picked := _pick_random(candidates, 1, battle.rng, true)
				if not picked.is_empty():
					groups.append(picked)
		Mode.LOWEST_HP_PERCENT:
			var sorted := candidates.duplicate()
			sorted.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
				return a.health_percent() < b.health_percent())
			groups.append(sorted.slice(0, mini(count, sorted.size())))
		Mode.NEAREST:
			if count <= 1:
				var nearest: BattleUnit = null
				var nearest_distance := INF
				for unit in candidates:
					var distance := caster.position.distance_squared_to(unit.position)
					if distance < nearest_distance:
						nearest_distance = distance
						nearest = unit
				if nearest != null:
					groups.append([nearest])
			else:
				var sorted := candidates.duplicate()
				sorted.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
					return (
						caster.position.distance_squared_to(a.position)
						< caster.position.distance_squared_to(b.position)
					))
				groups.append(sorted.slice(0, mini(count, sorted.size())))

	return groups


static func _pick_random(candidates: Array, n: int, rng: RandomNumberGenerator, with_replacement: bool) -> Array:
	var pool := candidates.duplicate()
	var picked: Array = []
	var draws := n if with_replacement else mini(n, pool.size())
	for i in draws:
		if pool.is_empty():
			break
		var idx := rng.randi_range(0, pool.size() - 1)
		picked.append(pool[idx])
		if not with_replacement:
			pool.remove_at(idx)
	return picked
