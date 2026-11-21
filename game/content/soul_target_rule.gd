class_name SoulTargetRule extends TargetRuleBase

enum Mode { LEFT, RIGHT, RANDOM, SELF, ALL, BOTH_SIDES }

@export var mode: Mode = Mode.RIGHT
## RANDOM / ALL 时是否包含自己
@export var include_self: bool = false
## RANDOM 时选几个
@export var count: int = 1


func domain() -> Domain:
	return Domain.SOUL


func resolve(caster: ChargedAbility, rng: RandomNumberGenerator) -> Array[ChargedAbility]:
	var result: Array[ChargedAbility] = []
	if caster == null or rng == null:
		return result

	var candidates: Array[ChargedAbility] = []
	for ability in caster.unit_soul_abilities:
		if ability == null:
			continue
		if ability.cooldown <= 0.0:
			continue
		candidates.append(ability)

	match mode:
		Mode.SELF:
			if caster.cooldown > 0.0:
				result.append(caster)
		Mode.LEFT:
			for ability in candidates:
				if ability.soul_container != caster.soul_container:
					continue
				if ability.soul_column + ability.soul_width == caster.soul_column:
					result.append(ability)
					break
		Mode.RIGHT:
			for ability in candidates:
				if ability.soul_container != caster.soul_container:
					continue
				if ability.soul_column == caster.soul_column + caster.soul_width:
					result.append(ability)
					break
		Mode.BOTH_SIDES:
			for ability in candidates:
				if is_adjacent(ability, caster):
					result.append(ability)
		Mode.RANDOM:
			var pool: Array[ChargedAbility] = []
			for ability in candidates:
				if ability == caster and not include_self:
					continue
				pool.append(ability)
			result = _pick_random(pool, count, rng)
		Mode.ALL:
			for ability in candidates:
				if ability == caster and not include_self:
					continue
				result.append(ability)

	return result


static func is_adjacent(a: ChargedAbility, b: ChargedAbility) -> bool:
	if a == null or b == null or a.soul_container != b.soul_container:
		return false
	return (
		a.soul_column + a.soul_width == b.soul_column
		or b.soul_column + b.soul_width == a.soul_column
	)


static func _pick_random(pool: Array[ChargedAbility], n: int, rng: RandomNumberGenerator) -> Array[ChargedAbility]:
	var remaining: Array[ChargedAbility] = []
	remaining.append_array(pool)
	var picked: Array[ChargedAbility] = []
	var draws := mini(n, remaining.size())
	for i in draws:
		if remaining.is_empty():
			break
		var idx := rng.randi_range(0, remaining.size() - 1)
		picked.append(remaining[idx])
		remaining.remove_at(idx)
	return picked
