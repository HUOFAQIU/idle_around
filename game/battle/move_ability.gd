## 移动能力：每 X 秒朝目标走一格。
##
## 节奏（走多快）来自 cooldown_effect 的 duration，和技能共用同一套充能模型。
## 将来想要"定身""减速""不同怪不同速度"，由 BattleBrain 控制充能倍率或挂标签。
##
## 走哪一格交给 HexStep —— 换寻路算法只改那边。

class_name MoveAbility extends ChargedAbility

## 走到离目标多近就停下（1 = 贴身，站着不动开始咬）
const STOP_DISTANCE : int = 1


func _ready() -> void:
	super()
	# 冷却效果只作为时长数据，读完就清空，不挂到 ASC
	setup_cooldown_from_effect(cooldown_effect)
	cooldown_effect = null


func _activate_ability() -> bool:
	var unit := owner_asc.get_parent() as BattleUnit
	if unit == null or unit.battle == null:
		return false

	# 先清空充能：走不动（被堵住）也照常消耗这一拍，下一拍再看
	commit_cost()
	reset_charge()

	var goal := unit.battle.player_cell()
	if Hex.distance(unit.cell, goal) <= STOP_DISTANCE:
		return true

	var occupied := unit.battle.occupied_cells(unit)
	var next := HexStep.next_step(unit.cell, goal, occupied, unit.battle.is_walkable)
	if next != unit.cell:
		unit.move_to_cell(next)
	return true
