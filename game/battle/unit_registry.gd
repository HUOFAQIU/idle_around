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


func of_team(team: BattleUnit.Team) -> Array[BattleUnit]:
	return players if team == BattleUnit.Team.PLAYER else enemies


func enemy_count() -> int:
	return enemies.size()


func clear() -> void:
	units.clear()
	players.clear()
	enemies.clear()
