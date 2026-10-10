## 战场：阵营名单、全局随机数（可复现）、战斗日志、胜负判定。
##
## 实时秒表模型下这里不驱动技能计时——每个单位的冷却由框架自己走，
## BattleManager 只负责"谁在场上、谁倒下了、谁赢了"。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name BattleManager extends Node

## 战斗结束（winner 为 BattleUnit.Team；-1 = 同归于尽）
signal battle_ended(winner_team: int)

var units: Array[BattleUnit] = []
var is_running: bool = false

## 全局随机数：带种子 → 同一场战斗完全可复现（方便回放与调试）
var rng := RandomNumberGenerator.new()

## UI 日志接收器，签名：func(line: String, color: String)
var log_sink: Callable = Callable()

var _start_msec: int = 0


func setup(random_seed: int = 20261009) -> void:
	rng.seed = random_seed
	_start_msec = Time.get_ticks_msec()


func add_unit(unit: BattleUnit) -> void:
	units.append(unit)
	unit.died.connect(_on_unit_died)


func start_battle() -> void:
	is_running = true
	_start_msec = Time.get_ticks_msec()
	log_line("========== 战斗开始 ==========", "yellow")
	for unit in units:
		log_line("%s（%s）  HP %.0f  攻击 %.0f"
			% [unit.unit_name,
				"我方" if unit.team == BattleUnit.Team.PLAYER else "敌方",
				unit.hp_attr.current_value,
				unit.asc.get_attribute("atk").current_value], "white")
	
	# 开局蓄力：所有技能同时开始各自的倒计时，时间到才能释放
	for unit in units:
		unit.brain.begin_charge()


func get_alive(team: BattleUnit.Team) -> Array[BattleUnit]:
	var alive: Array[BattleUnit] = []
	for unit in units:
		if unit.team == team and not unit.is_dead:
			alive.append(unit)
	return alive


#region 日志
func elapsed_seconds() -> float:
	return (Time.get_ticks_msec() - _start_msec) / 1000.0


func log_line(text: String, color: String = "white") -> void:
	var line := "[%5.2fs] %s" % [elapsed_seconds(), text]
	if log_sink.is_valid():
		log_sink.call(line, color)
	print_rich("[color=%s]%s[/color]" % [color, line])


## 施法报幕："勇者 施放【斩击】→ 哥布林A、哥布林B"
func log_cast(caster: BattleUnit, skill: SkillDefinition, groups: Array) -> void:
	log_line("%s 施放【%s】→ %s" % [caster.unit_name, skill.display_name, _format_targets(groups)], "#6fb7ff")


func _format_targets(groups: Array) -> String:
	var counts: Dictionary = {}
	var order: Array = []
	for group in groups:
		for unit in group:
			if not counts.has(unit.unit_name):
				counts[unit.unit_name] = 0
				order.append(unit.unit_name)
			counts[unit.unit_name] += 1
	var parts: Array[String] = []
	for name in order:
		parts.append(name if counts[name] == 1 else "%s ×%d" % [name, counts[name]])
	return "、".join(parts)
#endregion


func _on_unit_died(_unit: BattleUnit) -> void:
	if not is_running:
		return

	var players := get_alive(BattleUnit.Team.PLAYER).size()
	var enemies := get_alive(BattleUnit.Team.ENEMY).size()
	if players > 0 and enemies > 0:
		return

	is_running = false
	var winner := -1
	if players > 0:
		winner = BattleUnit.Team.PLAYER
	elif enemies > 0:
		winner = BattleUnit.Team.ENEMY

	if winner == -1:
		log_line("========== 战斗结束：同归于尽（用时 %.1f 秒）==========" % elapsed_seconds(), "yellow")
	else:
		log_line("========== 战斗结束：%s 获胜（用时 %.1f 秒）=========="
			% ["我方" if winner == BattleUnit.Team.PLAYER else "敌方", elapsed_seconds()], "yellow")
	battle_ended.emit(winner)
