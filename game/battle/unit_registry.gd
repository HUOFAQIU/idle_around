## 战场单位名册：全部单位 + 按阵营分桶。
##
## 目标选择按阵营拿数组，不再遍历全场；注册表只负责增删和分组，
## 单位生死、节点释放由 BattleManager 决定。
class_name UnitRegistry extends RefCounted

var units: Array[BattleUnit] = []
var players: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []


func add(unit: BattleUnit) -> void:
	units.append(unit)
	if unit.team == BattleUnit.Team.PLAYER:
		players.append(unit)
	else:
		enemies.append(unit)


func remove(unit: BattleUnit) -> void:
	units.erase(unit)
	players.erase(unit)
	enemies.erase(unit)


## 指定阵营的单位数组（返回内部数组，调用方不要原地修改）
func of_team(team: BattleUnit.Team) -> Array[BattleUnit]:
	return players if team == BattleUnit.Team.PLAYER else enemies


func enemy_count() -> int:
	return enemies.size()


func clear() -> void:
	units.clear()
	players.clear()
	enemies.clear()
