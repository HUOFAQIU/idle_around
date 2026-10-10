## 技能的目标选择规则（数据资源）。
##
## 把"技能描述"翻译成结构化字段，例如：
##   "随机斩击2名敌人"        → mode = RANDOM, count = 2, camp = ENEMY
##   "随机攻击2次"            → mode = REPEAT, count = 2
##   "治疗血量最低的友方"     → mode = LOWEST_HP_PERCENT, count = 1, camp = ALLY
##   "对全体敌人"             → mode = ALL, camp = ENEMY
##
## 本类不碰任何框架内部状态，只用公开接口读取战场名单。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name TargetRule extends Resource

enum Mode {
	RANDOM,             ## 随机 count 个（不重复）
	REPEAT,             ## 随机 count 次（可重复，每次独立结算）
	LOWEST_HP_PERCENT,  ## 血量百分比最低的 count 个
	ALL,                ## 全部
}

enum Camp {
	ENEMY,  ## 敌方
	ALLY,   ## 友方
	SELF,   ## 自己
}

@export var mode: Mode = Mode.RANDOM
@export var count: int = 1
@export var camp: Camp = Camp.ENEMY

## camp = ALLY 时是否允许选中自己（"治疗最残血的友方（含自己）"）
@export var include_self: bool = true


## 解析出"施加批次"：Array[Array[BattleUnit]]
##
## 一个批次 = 一次 apply_effect_to_targets = 一份 Spec：
##   RANDOM / LOWEST_HP_PERCENT / ALL → 只产生 1 个批次（一次打多个目标）
##   REPEAT → 产生 count 个批次，每批 1 个目标（独立随机、独立结算，可重复命中同一目标）
##
## 记住：框架的 get_target_nodes() 会去重，所以"随机打2次同一目标"必须像
## REPEAT 这样拆成多个批次分别施加，才能拿到两次独立的暴击/飘字/日志。
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

	# 1. 圈定候选名单：阵营正确 + 还活着（死亡单位带 State.Dead 标签，用字段查同样效果）
	var wanted_team: BattleUnit.Team = caster.team
	if camp == Camp.ENEMY:
		wanted_team = BattleUnit.Team.ENEMY if caster.team == BattleUnit.Team.PLAYER else BattleUnit.Team.PLAYER

	var candidates: Array = []
	for unit in battle.units:
		if unit.is_dead or unit.team != wanted_team:
			continue
		if unit == caster and not include_self:
			continue
		candidates.append(unit)

	if candidates.is_empty():
		return groups

	# 2. 按规则挑选（随机数走 battle.rng，带种子 → 整场战斗可复现）
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
				return a.hp_percent() < b.hp_percent())
			groups.append(sorted.slice(0, mini(count, sorted.size())))

	return groups


## 从候选池随机抽取。with_replacement = true 时允许同一目标被抽中多次。
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
