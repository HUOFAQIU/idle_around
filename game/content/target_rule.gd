## 技能的目标选择规则（数据资源）。
##
## 把"技能描述"翻译成结构化字段，例如：
##   "随机斩击2名敌人"        → mode = RANDOM, count = 2, camp = ENEMY
##   "随机攻击2次"            → mode = REPEAT, count = 2
##   "治疗血量最低的友方"     → mode = LOWEST_HP_PERCENT, count = 1, camp = ALLY
##   "对 10 格内最近的 3 个敌人" → mode = NEAREST, count = 3, camp = ENEMY, max_range = 10
##   "对全体敌人"             → mode = ALL, camp = ENEMY
##
## 本类不碰任何框架内部状态，只用公开接口读取战场名单。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name TargetRule extends TargetRuleBase

enum Mode {
	RANDOM,             ## 随机 count 个（不重复）
	REPEAT,             ## 随机 count 次（可重复，每次独立结算）
	LOWEST_HP_PERCENT,  ## 血量百分比最低的 count 个
	NEAREST,            ## 离自己最近的 count 个
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


## 解析出"施加批次"：Array[Array[BattleUnit]]
##
## 一个批次 = 一次目标解析 = 一组目标：
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
		wanted_team = BattleUnit.opposing_team(caster.team)

	var candidates: Array = []
	# 有范围限制时走空间索引，只查附近；不限范围时才遍历该阵营名单
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

	# 2. 按规则挑选（随机数走 battle.rng）
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
				# 只要最近一个时用单次扫描，避免为一次选目标排序整个敌人名单
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
