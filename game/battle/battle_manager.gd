## 战场：单位登记、刷怪心跳、实时移动、空间索引、战斗日志。
##
## 它不认地图节点本身，只借一张地图做“格子 → 像素”的换算 ——
## 战斗逻辑算的是像素位置，地图只负责把格子画出来。
##
## 实时制：怪物由本类统一驱动，向角色直线移动；跨入新格子时发 moved 事件。
## 只有角色进入怪物的攻击范围后，怪物大脑才开始跑（魂灵才开始充能）。
##
## 没有胜负：怪一直刷，角色倒下就发信号，由外面决定怎么重来。

class_name BattleManager extends Node

## 任一单位改变格子时转发；触发型被动用它监听“敌方移动”。
signal unit_moved(unit: BattleUnit, from_cell: Vector2i, to_cell: Vector2i)

## 刷怪间隔（秒）
const SPAWN_INTERVAL : float = 1
## 只在距离角色这么多格以外刷怪
const SPAWN_MIN_DISTANCE : int = 10
## 掉落进哪个仓库容器
const DROP_CONTAINER : String = "inventory_0"
## 移动按实例 ID 分片：至少 6 片（10Hz），怪物越多分得越细，
## 保证每帧大约只更新 MOVE_BUDGET_PER_FRAME 个移动体；速度按同样的倍数补偿。
const MIN_MOVE_SLICES : int = 6
## 每帧最多驱动多少个怪物的移动
const MOVE_BUDGET_PER_FRAME : int = 200
## 空间索引的格子边长（像素）；只用于“附近有哪些单位”的查询
const BUCKET_PX : float = 64.0

## 单位坐标 → 像素坐标要用的地图
var map: TileMapLayer
## 刷怪回调，签名 func(cell: Vector2i)。谁建怪、怪长什么样，是游戏侧的事
var spawn_enemy: Callable = Callable()
## 角色（目前只有它一个 PLAYER 单位）
var player: BattleUnit

var units: Array[BattleUnit] = []
## 按阵营分桶，目标选择不再遍历全场
var players: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var is_running: bool = false

## 相邻格中心的像素距离；TargetRule 的 max_range 用它换算成像素
var cell_size_px: float = 32.0

## 全局随机数：选目标、刷怪都走它
var rng := RandomNumberGenerator.new()

## UI 日志接收器，签名：func(line: String, color: String)
var log_sink: Callable = Callable()

var _start_msec: int = 0
var _spawn_accum: float = 0.0
## 预先算好的可刷怪格子（地图是静态的，开战时算一次即可）
var _spawn_cells: Array[Vector2i] = []
## 空间索引：格子键 → 该格内的单位
var _buckets: Dictionary = {}
## 单位实例 ID → 所在空间格的键，移动时用来快速换桶
var _bucket_of_unit: Dictionary = {}
## 当前移动分片
var _move_slice: int = 0


func setup() -> void:
	_start_msec = Time.get_ticks_msec()
	_measure_cell_size()


func add_unit(unit: BattleUnit) -> void:
	units.append(unit)
	if unit.team == BattleUnit.Team.PLAYER:
		players.append(unit)
	else:
		enemies.append(unit)
	_register_bucket(unit)

	unit.died.connect(_on_unit_died)
	unit.moved.connect(_on_unit_moved)
	# 战斗中才入场的单位从 0 开始充能，不然一入场就是满充能
	if is_running:
		unit.brain.begin_charge()
	# 怪物在攻击范围外不跑大脑：魂灵不充能、不施放（即时制设计）
	if unit.team == BattleUnit.Team.ENEMY and unit.brain != null:
		unit.brain.set_physics_process(false)


func _on_unit_moved(unit: BattleUnit, from_cell: Vector2i, to_cell: Vector2i) -> void:
	unit_moved.emit(unit, from_cell, to_cell)


func start_battle() -> void:
	is_running = true
	_start_msec = Time.get_ticks_msec()
	_spawn_accum = 0.0
	_rebuild_spawn_cells()
	log_line("========== 战斗开始 ==========", "yellow")
	for unit in units:
		log_line("%s  HP %.0f"
			% [unit.unit_name, unit.health_attr.current_value], "white")

	# 开局：所有能力从 0 开始充能
	for unit in units:
		unit.brain.begin_charge()


## 战斗心跳：刷怪 + 驱动怪物移动
func _process(delta: float) -> void:
	if not is_running:
		return
	_spawn_accum += delta
	if _spawn_accum >= SPAWN_INTERVAL:
		_spawn_accum -= SPAWN_INTERVAL
		spawn_one()


func _physics_process(delta: float) -> void:
	if not is_running or player == null or player.is_dead:
		return
	var slices := maxi(
		MIN_MOVE_SLICES,
		int(ceil(float(enemies.size()) / float(MOVE_BUDGET_PER_FRAME)))
	)
	_move_slice = (_move_slice + 1) % slices
	for unit in enemies:
		if unit == null or unit.is_dead:
			continue
		if unit.get_instance_id() % slices != _move_slice:
			continue
		_tick_enemy_movement(unit, delta, slices)


## 一个怪物的移动拍：进范围就停并唤醒大脑，否则朝角色直线走。
func _tick_enemy_movement(unit: BattleUnit, delta: float, slices: int) -> void:
	if unit.brain == null:
		return
	var to_player := player.position - unit.position
	var distance := to_player.length()
	if distance <= unit.attack_range:
		unit.velocity = Vector2.ZERO
		if not unit.brain.is_physics_processing():
			unit.brain.set_physics_process(true)
		return

	if unit.brain.is_physics_processing():
		unit.brain.set_physics_process(false)
	# 单位级冻结：不充能、不释放、不移动（魂灵级冻结只停魂灵，见 ChargedAbility）
	if unit.is_unit_frozen():
		unit.velocity = Vector2.ZERO
		return
	if distance <= 0.001:
		return

	# 时间分片：本帧一次走 slices 拍的距离
	unit.velocity = to_player / distance * unit.move_speed * float(slices)
	unit.move_and_slide()
	_update_bucket(unit)

	# 实时移动里“跨格”才发 moved：蹈火术这类按格触发的被动保持原来的节奏
	var new_cell := map.local_to_map(unit.position)
	if new_cell != unit.cell:
		var from_cell := unit.cell
		unit.cell = new_cell
		unit.moved.emit(unit, from_cell, new_cell)


#region 坐标与索引
func cell_to_world(cell: Vector2i) -> Vector2:
	return map.map_to_local(cell)


## 角色在哪一格（只用于刷怪和调试）
func player_cell() -> Vector2i:
	if player == null:
		return Vector2i.ZERO
	return map.local_to_map(player.position)


## 指定阵营的全部存活单位（返回内部数组，调用方不要原地修改）
func units_of_team(team: BattleUnit.Team) -> Array[BattleUnit]:
	return players if team == BattleUnit.Team.PLAYER else enemies


func enemy_count() -> int:
	return enemies.size()


## 距离 pos 半径 radius 内的所有单位；走空间索引，不遍历全场
func units_near(pos: Vector2, radius: float) -> Array[BattleUnit]:
	var result : Array[BattleUnit] = []
	var key_radius := int(ceil(radius / BUCKET_PX))
	var center := _bucket_key(pos)
	for bx in range(center.x - key_radius, center.x + key_radius + 1):
		for by in range(center.y - key_radius, center.y + key_radius + 1):
			var bucket = _buckets.get(Vector2i(bx, by))
			if bucket == null:
				continue
			for unit in bucket:
				if unit != null and not unit.is_dead and pos.distance_to(unit.position) <= radius:
					result.append(unit)
	return result


func _measure_cell_size() -> void:
	if map == null:
		return
	var origin := map.map_to_local(Vector2i.ZERO)
	var right := map.map_to_local(Vector2i(1, 0))
	cell_size_px = maxf(origin.distance_to(right), 1.0)


func _bucket_key(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / BUCKET_PX), floori(pos.y / BUCKET_PX))


func _register_bucket(unit: BattleUnit) -> void:
	var key := _bucket_key(unit.position)
	var bucket : Array = _buckets.get(key, [])
	bucket.append(unit)
	_buckets[key] = bucket
	_bucket_of_unit[unit.get_instance_id()] = key


func _unregister_bucket(unit: BattleUnit) -> void:
	var id := unit.get_instance_id()
	if not _bucket_of_unit.has(id):
		return
	var key : Vector2i = _bucket_of_unit[id]
	_bucket_of_unit.erase(id)
	var bucket : Array = _buckets.get(key, [])
	bucket.erase(unit)
	if bucket.is_empty():
		_buckets.erase(key)
	else:
		_buckets[key] = bucket


func _update_bucket(unit: BattleUnit) -> void:
	var id := unit.get_instance_id()
	var new_key := _bucket_key(unit.position)
	if _bucket_of_unit.get(id) == new_key:
		return
	_unregister_bucket(unit)
	_register_bucket(unit)
#endregion


#region 刷怪
## 立刻在远处刷一只（挑得到位置才刷）
func spawn_one() -> void:
	if not spawn_enemy.is_valid() or _spawn_cells.is_empty():
		return
	spawn_enemy.call(_spawn_cells.pick_random())


## 距离角色 SPAWN_MIN_DISTANCE 格以外的所有地图格；地图静态，开战时算一次
func _rebuild_spawn_cells() -> void:
	_spawn_cells.clear()
	if map == null:
		return
	var center := player_cell()
	for cell in map.get_used_cells():
		if Hex.distance(cell, center) > SPAWN_MIN_DISTANCE:
			_spawn_cells.append(cell)
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
	_unregister_bucket(unit)
	units.erase(unit)
	enemies.erase(unit)
	_roll_drops(unit)
	unit.cleanup_asc()
	unit.queue_free()
