## 自动施法大脑：充能模型。
##
## 每个单位一个大脑，每物理帧：
##   1. 给没在施法中的能力累加充能（1/60 秒/帧）
##   2. 充满后向框架的"门卫"问一次能不能放
## 门卫（can_activate_ability）负责花费、施法条件标签、是否正在施法等检查。
##
## 冰冻期间：自身不充能，也不能释放；外部充能（Charge 效果）仍然可以直接
## 调用 add_charge() 把充能加满，解冻后下一帧立刻释放。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name BattleBrain extends Node

## 冰冻标签；Freeze 效果实现后由它负责挂/摘
const FROZEN_TAG : StringName = &"State.Frozen"

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


func _physics_process(delta: float) -> void:
	if unit.is_dead or unit.battle == null or not unit.battle.is_running:
		return
	var frozen := unit.asc.has_tag(FROZEN_TAG)
	for ability in abilities:
		var charged := ability as ChargedAbility
		# 冰冻时自身不充能；施法期间也不充能（冷却从释放后开始算）
		if charged != null and not ability.is_active and not frozen:
			charged.add_charge(delta)
		if frozen:
			continue
		if charged != null and not charged.is_ready():
			continue
		if unit.asc.can_activate_ability(ability):
			ability.try_activate()  # 开火即忘，技能内部自己 await
