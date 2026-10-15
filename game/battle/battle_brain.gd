## 自动施法大脑：实时秒表模型的最简实现。
##
## 每个单位一个大脑，每帧向框架的"门卫"问一次：
##   "这个技能现在能放吗？"
## 门卫（can_activate_ability）会替我们查好：冷却标签、花费、施法条件标签、
## 是否正在施法中、是否被其他技能封锁。能放就 try_activate()，放不了就等下一帧。
##
## 冷却倒计时不需要大脑操心——它由框架的冷却效果在每个 ASC 的 _process 里自己走。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name BattleBrain extends Node

## 本单位的技能（AutoCastAbility 节点，已授予给 ASC）
var unit: BattleUnit
var abilities: Array[GameplayAbility] = []


func setup(p_unit: BattleUnit, skills: Array[SkillDefinition]) -> void:
	unit = p_unit
	for def in skills:
		if def == null:
			continue
		var ability := AutoCastAbility.new()
		ability.apply_definition(def)
		add_ability(ability)


## 直接挂一个能力（不走 SkillDefinition 的，比如移动）
func add_ability(ability: GameplayAbility) -> void:
	unit.asc.grant_ability(ability)
	abilities.append(ability)


## 开局冷却：给每个能力挂上它的冷却效果，倒计时开始走。
## 冷却期间技能被冷却标签挡在门外；倒计时到点、标签脱落，技能才可以释放。
## 释放时 commit_ability() 会重新挂上，进入下一轮 —— 即"每 X 秒释放一次"。
func begin_charge() -> void:
	for ability in abilities:
		var effect := _charge_effect_of(ability)
		if effect:
			unit.asc.apply_gameplay_effect(effect, unit.asc, 1.0)


## 能力的"冷却效果"：技能从数据里取，其它能力就用框架自己的 cooldown_effect 槽位
func _charge_effect_of(ability: GameplayAbility) -> GameplayEffect:
	var auto := ability as AutoCastAbility
	if auto:
		return auto.skill.charge_effect if auto.skill else null
	return ability.cooldown_effect


func _process(_delta: float) -> void:
	if unit.is_dead or unit.battle == null or not unit.battle.is_running:
		return
	for ability in abilities:
		if unit.asc.can_activate_ability(ability):
			ability.try_activate()  # 开火即忘，技能内部自己 await
