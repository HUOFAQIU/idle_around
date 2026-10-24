## 战场：单位登记、刷怪心跳、坐标换算、战斗日志。
##
## 它不认地图节点本身，只借一张地图做"格子 → 像素"的换算 ——
## 战斗逻辑算的是格子坐标，地图只负责把格子画出来。
##
## 没有胜负：怪一直刷，角色倒下就发信号，由外面决定怎么重来。

class_name BattleManager extends Node

## 刷怪间隔（秒）
const SPAWN_INTERVAL : float = 0.2
## 只在这个距离之外刷怪
const SPAWN_MIN_DISTANCE : int = 10
## 掉落进哪个仓库容器
const DROP_CONTAINER : String = "inventory_0"

## 单位坐标 → 像素坐标要用的地图
var map: TileMapLayer
## 刷怪回调，签名 func(cell: Vector2i)。谁建怪、怪长什么样，是游戏侧的事
var spawn_enemy: Callable = Callable()
## 角色（目前只有它一个 PLAYER 单位）
var player: BattleUnit

var units: Array[BattleUnit] = []
var is_running: bool = false

## 全局随机数：选目标、刷怪都走它
var rng := RandomNumberGenerator.new()

## UI 日志接收器，签名：func(line: String, color: String)
var log_sink: Callable = Callable()

var _start_msec: int = 0
var _spawn_accum: float = 0.0


func setup() -> void:
	_start_msec = Time.get_ticks_msec()


func add_unit(unit: BattleUnit) -> void:
	units.append(unit)
	unit.died.connect(_on_unit_died)
	# 战斗中才入场的单位（比如后面刷出来的怪）也要从这一刻开始走冷却，
	# 不然它们身上没有冷却标签，开场第一帧就会把所有能力全放一遍
	if is_running:
		unit.brain.begin_charge()


func start_battle() -> void:
	is_running = true
	_start_msec = Time.get_ticks_msec()
	_spawn_accum = 0.0
	log_line("========== 战斗开始 ==========", "yellow")
	for unit in units:
		log_line("%s  HP %.0f"
			% [unit.unit_name, unit.health_attr.current_value], "white")

	# 开局冷却：所有能力同时开始各自的倒计时，时间到才能释放
	for unit in units:
		unit.brain.begin_charge()


## 刷怪心跳：每隔 SPAWN_INTERVAL 在远处补一只
func _process(delta: float) -> void:
	if not is_running:
		return
	_spawn_accum += delta
	if _spawn_accum >= SPAWN_INTERVAL:
		_spawn_accum -= SPAWN_INTERVAL
		spawn_one()


#region 坐标与占位
## 格子 → 像素（单位节点跟地图挂在同一个坐标系下）
func cell_to_world(cell: Vector2i) -> Vector2:
	return map.map_to_local(cell)


## 角色在哪一格
func player_cell() -> Vector2i:
	return player.cell if player else Vector2i.ZERO


## 除了 except 之外，场上单位占着的格子
func occupied_cells(except: BattleUnit = null) -> Dictionary:
	var occupied := {}
	for unit in units:
		if unit == except or unit.is_dead:
			continue
		occupied[unit.cell] = true
	return occupied


## 这一格能不能站（在地图图块上就算能站）
func is_walkable(cell: Vector2i) -> bool:
	return map.get_cell_source_id(cell) != -1
#endregion


#region 刷怪
## 立刻在远处刷一只（挑得到位置才刷）
func spawn_one() -> void:
	if not spawn_enemy.is_valid():
		return
	var candidates := _free_spawn_cells()
	if candidates.is_empty():
		return
	spawn_enemy.call(candidates.pick_random())


## 距离角色 10 格以外、没被占、且在地图上的格子
func _free_spawn_cells() -> Array[Vector2i]:
	var taken := occupied_cells()
	var cells : Array[Vector2i] = []
	for cell in map.get_used_cells():
		if Hex.distance(cell, player_cell()) > SPAWN_MIN_DISTANCE and not taken.has(cell):
			cells.append(cell)
	return cells
#endregion


#region 日志
func elapsed_seconds() -> float:
	return (Time.get_ticks_msec() - _start_msec) / 1000.0


func log_line(text: String, color: String = "white") -> void:
	var line := "[%5.2fs] %s" % [elapsed_seconds(), text]
	if log_sink.is_valid():
		log_sink.call(line, color)
	print_rich("[color=%s]%s[/color]" % [color, line])


## 施法报幕："长弓 施放【长弓】→ 蛇、蛇、蛇"
func log_cast(caster: BattleUnit, skill_name: String, groups: Array) -> void:
	log_line("%s 施放【%s】→ %s" % [caster.unit_name, skill_name, _format_targets(groups)], "#6fb7ff")


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
	
	for unit_name in order:
		parts.append(unit_name if counts[unit_name] == 1 else "%s ×%d" % [unit_name, counts[unit_name]])
	return "、".join(parts)
#endregion


## 每项掉落各掷一次骰子；测试阶段仓库满了就丢
func _roll_drops(unit: BattleUnit) -> void:
	for entry in unit.drops:
		if entry == null or entry.item == null:
			continue
		if rng.randf() > entry.chance:
			continue
		if GBIS.add_item(DROP_CONTAINER, entry.item):
			log_line("%s 掉落了【%s】" % [unit.unit_name, entry.item.item_name], "#ffd866")
		else:
			log_line("仓库已满，【%s】掉落丢失" % entry.item.item_name, "yellow")


## 有单位倒下：角色倒下就发信号让外面重开；怪倒下就从名册里划掉、清掉节点
func _on_unit_died(unit: BattleUnit) -> void:
	if unit == player:
		is_running = false
		return
	_roll_drops(unit)
	units.erase(unit)
	unit.queue_free()
