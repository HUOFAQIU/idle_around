## 魂灵目标规则（数据资源）。
##
## 给“加速/减速/冻结/充能”这类以魂灵为目标的技能用：
##   LEFT / RIGHT  同一部位行内、紧邻的魂灵；中间空一格不算相邻
##   BOTH_SIDES    同一部位行内、左右两侧紧邻的魂灵（各最多一个）
##   RANDOM        从有冷却的魂灵里随机
##   SELF          自己
##   ALL           全部有冷却的魂灵
##
## 目标只从施法者所属单位的魂灵栏里选：玩家来自装备容器，
## 怪物来自 MonsterData.soul_entries 生成的虚拟魂灵栏。

class_name SoulTargetRule extends TargetRuleBase

enum Mode { LEFT, RIGHT, RANDOM, SELF, ALL, BOTH_SIDES }

## 选择方式
@export var mode: Mode = Mode.RIGHT
## RANDOM / ALL 时是否包含自己
@export var include_self: bool = false
## RANDOM 时选几个
@export var count: int = 1


## 解析出本次要施加状态的魂灵能力。
## rng 用战斗的全局随机源，保证可复现。
func resolve(caster: ChargedAbility, rng: RandomNumberGenerator) -> Array[ChargedAbility]:
	var result: Array[ChargedAbility] = []
	if caster == null or rng == null:
		return result

	var candidates: Array[ChargedAbility] = []
	for ability in caster.soul_loadout:
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
				if ability.soul_container != caster.soul_container:
					continue
				var is_left := ability.soul_column + ability.soul_width == caster.soul_column
				var is_right := ability.soul_column == caster.soul_column + caster.soul_width
				if is_left or is_right:
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


## 从池子里随机抽 n 个（不重复）
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
