## 移动能力：每 X 秒朝目标走一格。
##
## 为什么移动要做成"能力"而不是一个定时器循环：节奏（走多快）就是它的
## cooldown_effect（蓄力效果），和技能共用框架同一套冷却机制。这样将来想要
## "定身""减速""不同怪不同速度"，要么改数据、要么给单位挂个标签写进
## activation_query，这里一行都不用动。
##
## 走哪一格交给 HexStep —— 换寻路算法只改那边。

class_name MoveAbility extends GameplayAbility

## 走到离目标多近就停下（1 = 贴身，站着不动开始咬）
const STOP_DISTANCE : int = 1


func _activate_ability() -> bool:
	var unit := owner_asc.get_parent() as BattleUnit
	if unit == null or unit.battle == null:
		return false

	# 先提交冷却：走不动（被堵住）也照常消耗这一拍，下一拍再看
	commit_ability()

	var goal := unit.battle.player_cell()
	if Hex.distance(unit.cell, goal) <= STOP_DISTANCE:
		return true

	var occupied := unit.battle.occupied_cells(unit)
	var next := HexStep.next_step(unit.cell, goal, occupied, unit.battle.is_walkable)
	if next != unit.cell:
		unit.move_to_cell(next)
	return true
