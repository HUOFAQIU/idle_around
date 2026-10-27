## 自动施法大脑：充能模型。
##
## 每个单位一个大脑，每物理帧：
##   1. 先给所有能力结算状态（加速/减速）和自然充能（按 1/120 秒刻度）
##   2. 再按魂灵栏从左到右的顺序，把充满的能力放出去
## 门卫（can_activate_ability）负责花费、施法条件标签、是否正在施法等检查。
##
## 基础刻度 = 120 / physics_ticks_per_second × time_scale：
## 60 FPS、1x 时每帧 2 刻度；减速 1 刻度，加速 4 刻度。
## 先充能再统一释放：本帧新加的加速，下一帧才影响充能，避免连锁施法。
## 冰冻期间：自身不充能，也不能释放；外部充能（Charge 效果）仍然可以直接
## 调用 add_charge() 把充能加满，解冻后下一帧立刻释放。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name BattleBrain extends Node

## 冰冻标签；唯一来源在 ChargedAbility，这里保留别名方便阅读
const FROZEN_TAG : StringName = ChargedAbility.FROZEN_TAG

## 本单位的技能（AutoCastAbility 节点，已授予给 ASC）
var unit: BattleUnit
var abilities: Array[GameplayAbility] = []


## 直接挂一个能力（不走 SkillDefinition 的，比如移动）
func add_ability(ability: GameplayAbility) -> void:
	unit.asc.grant_ability(ability)
	abilities.append(ability)


## 开局：所有能力从 0 开始充能
func begin_charge() -> void:
	for ability in abilities:
		var charged := ability as ChargedAbility
		if charged:
			charged.reset_charge()


func _physics_process(_delta: float) -> void:
	if unit.is_dead or unit.battle == null or not unit.battle.is_running:
		return

	var frozen := unit.asc.has_tag(FROZEN_TAG)
	# 不用 _delta：物理帧是固定步长，掉帧时引擎会补跑多个 tick；
	# 这里显式按 tick 频率和 time_scale 算“每 tick 固定刻度”。
	var base_units := int(round(
		float(ChargedAbility.UNITS_PER_SECOND)
		/ float(Engine.physics_ticks_per_second)
		* Engine.time_scale
	))

	# 第一段：所有魂灵先结算状态和自然充能。
	# 先充能再统一释放，避免“左边一放加速、右边同一帧连锁放”。
	for ability in abilities:
		var charged := ability as ChargedAbility
		if charged == null:
			continue
		for status_name in charged.tick_status(base_units):
			unit.battle.log_line("%s 的状态【%s】结束" % [ability.ability_name, status_name], "gray")
		# 冰冻时自身不充能；投射物飞行等施法过程不阻塞冷却
		if not frozen:
			charged.tick_charge(base_units)

	if frozen:
		return

	# 第二段：按数组顺序释放 —— 数组已按魂灵栏从左到右排好
	for ability in abilities:
		if unit.is_dead or unit.battle == null or not unit.battle.is_running:
			return
		var charged := ability as ChargedAbility
		if charged != null and not charged.is_ready():
			continue
		if unit.asc.can_activate_ability(ability):
			ability.try_activate()  # 开火即忘，技能内部自己 await
