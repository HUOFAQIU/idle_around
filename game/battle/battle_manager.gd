## 战场门面：把单位名册、空间索引、地图适配、刷怪、掉落和移动调度串起来。
##
## 具体职责已拆给协作者：
##   UnitRegistry      单位名册与阵营分桶
##   UnitSpatialIndex  附近单位查询
##   BattleGrid        格子 ↔ 像素换算
##   LootRoller        掉落判定（入包动作由 BattleSession 注入）
##
## 刷怪时机由地图会话（MapRun）决定，本类只保留 spawn_one() 门面。
##
## 实时制：怪物由本类统一驱动，向角色直线移动；跨入新格子时发 moved 事件。
## 只有角色进入怪物的攻击范围后，怪物大脑才开始跑（魂灵才开始充能）。
##
## 本类不判断地图完成；完成/自动重开由 BattleSession 和 MapRun 处理。

class_name BattleManager extends Node

## 移动按实例 ID 分片：每物理帧最多只驱动 MOVE_BUDGET_PER_FRAME 个移动体；
## 怪物少时不分片（逐物理帧移动，视觉顺滑），多了才分片；速度按同样的倍数补偿。
## 每物理帧最多驱动多少个怪物的移动
const MOVE_BUDGET_PER_FRAME : int = 200
## tick 末阶段的物理处理优先级；必须晚于单位大脑和投射物（默认 0）
const TICK_END_PHYSICS_PRIORITY : int = 128

## 单位坐标 → 像素坐标要用的地图
var map: TileMapLayer
## 刷怪回调，签名 func()。谁建怪、怪长什么样，是游戏侧的事
var spawn_enemy: Callable = Callable()
## 掉落入包动作，签名 func(item: ItemData) -> bool；由 BattleSession 注入
var loot_sink: Callable = Callable()
## 角色（目前只有它一个 PLAYER 单位）
var player: BattleUnit
var is_running: bool = false

## 战斗事件总线：模拟层只发事件，遥测/日志/控制台各自订阅
var events: BattleEventBus = BattleEventBus.new()

## 全局随机数：选目标、刷怪、掉落都走它
var rng := RandomNumberGenerator.new()

var registry: UnitRegistry = UnitRegistry.new()
var spatial: UnitSpatialIndex = UnitSpatialIndex.new()
var grid: BattleGrid

## 单位名册与单元格尺寸的只读视图；供外部代码查询
var units: Array[BattleUnit]:
	get:
		return registry.units
var players: Array[BattleUnit]:
	get:
		return registry.players
var enemies: Array[BattleUnit]:
	get:
		return registry.enemies
## 相邻格中心的像素距离；TargetRule 的 max_range 用它换算成像素
var cell_size_px: float:
	get:
		return grid.cell_size_px if grid != null else 32.0

var _loot: LootRoller
## 已完成的物理 tick 数；战斗仿真的唯一时间基准
var _tick_count: int = 0
var _move_slice: int = 0
## 广播型触发器事件的监听者：事件标签 → 确实带该触发器的单位
var _trigger_listeners: Dictionary = {}


func setup() -> void:
	# 固定 tick 末阶段：必须晚于单位大脑和投射物，才能在同一 tick 内统一 flush 触发器
	process_physics_priority = TICK_END_PHYSICS_PRIORITY
	_tick_count = 0
	grid = BattleGrid.new(map)
	_loot = LootRoller.new(events, loot_sink)


func add_unit(unit: BattleUnit) -> void:
	registry.add(unit)
	spatial.register(unit)
	events.emit_event(BattleEvent.CATEGORY_BATTLE, "unit_added", {
		"actor_unit": unit,
		"cell": [unit.cell.x, unit.cell.y],
		"souls": unit.loadout.map(func(runtime): return runtime.display_name() if runtime != null else ""),
	}, BattleEvent.IMPORTANCE_DETAIL)

	unit.died.connect(_on_unit_died)
	unit.moved.connect(_on_unit_moved)
	# 战斗中才入场的单位从 0 开始充能，不然一入场就是满充能
	if is_running:
		unit.brain.begin_charge()
	# 怪物在攻击范围外不跑大脑：魂灵不充能、不施放（即时制设计）
	if unit.team == BattleUnit.Team.ENEMY and unit.brain != null:
		unit.brain.set_physics_process(false)


## 只在有监听者时派发“敌方移动”，不再让所有单位各接一次全局信号
func _on_unit_moved(unit: BattleUnit, from_cell: Vector2i, to_cell: Vector2i) -> void:
	for listener in trigger_listeners(GameplayTags.Event_Movement_UnitMoved):
		listener.on_enemy_moved(unit, from_cell, to_cell)


## 单位声明/撤销对某个广播型触发器事件的关注
func set_trigger_listener(unit: BattleUnit, event_tag: StringName, enabled: bool) -> void:
	var listeners: Array = _trigger_listeners.get(event_tag, [])
	var index := listeners.find(unit)
	if enabled and index == -1:
		listeners.append(unit)
	elif not enabled and index >= 0:
		listeners.remove_at(index)
	_trigger_listeners[event_tag] = listeners


## 某类广播事件的监听者快照；跳过已死亡/已释放的单位
func trigger_listeners(event_tag: StringName) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	var listeners: Array = _trigger_listeners.get(event_tag, [])
	for item in listeners:
		var unit := item as BattleUnit
		if unit != null and is_instance_valid(unit) and not unit.is_dead:
			result.append(unit)
	return result


func start_battle() -> void:
	is_running = true
	_tick_count = 0

	# 开局：所有能力从 0 开始充能
	for unit in units:
		unit.brain.begin_charge()


func _physics_process(delta: float) -> void:
	if not is_running or player == null or player.is_dead:
		return
	var slices := maxi(
		1,
		int(ceil(float(registry.enemies.size()) / float(MOVE_BUDGET_PER_FRAME)))
	)
	_move_slice = (_move_slice + 1) % slices
	for unit in registry.enemies:
		if unit == null or unit.is_dead:
			continue
		if unit.get_instance_id() % slices != _move_slice:
			continue
		_tick_enemy_movement(unit, delta, slices)

	_tick_count += 1
	_flush_brain_activations()


## 跨单位触发器在本 tick 末统一释放；单位自己的 Brain 已在它的物理帧末 flush 过。
## 必须在所有单位大脑之后运行，否则本 tick 新充能的能力会被拖到下一 tick。
func _flush_brain_activations() -> void:
	for unit in registry.units.duplicate():
		if not is_running:
			return
		if unit == null or not is_instance_valid(unit) or unit.is_dead:
			continue
		if unit.brain != null:
			unit.brain.flush_pending_activations()


## 一个怪物的移动拍：进范围就停并唤醒大脑，否则朝角色直线走。
func _tick_enemy_movement(unit: BattleUnit, _delta: float, slices: int) -> void:
	if unit.brain == null:
		return
	var to_player := player.position - unit.position
	var distance := to_player.length()
	if distance <= unit.attack_range:
		unit.velocity = Vector2.ZERO
		if not unit.brain.is_physics_processing():
			unit.brain.set_physics_process(true)
			events.emit_event(BattleEvent.CATEGORY_BATTLE, "enemy_in_range", {
				"actor_unit": unit,
				"distance": distance,
			}, BattleEvent.IMPORTANCE_DETAIL)
		return

	if unit.brain.is_physics_processing():
		unit.brain.set_physics_process(false)
		events.emit_event(BattleEvent.CATEGORY_BATTLE, "enemy_out_of_range", {
			"actor_unit": unit,
			"distance": distance,
		}, BattleEvent.IMPORTANCE_DETAIL)
	# 单位级冻结：不充能、不释放、不移动（魂灵级冻结只停魂灵，见 ChargedAbility）
	if unit.is_unit_frozen():
		unit.velocity = Vector2.ZERO
		return
	if distance <= 0.001:
		return

	# 时间分片：本 tick 一次走 slices 拍的距离
	unit.velocity = to_player / distance * unit.move_speed * float(slices)
	unit.move_and_slide()
	spatial.update(unit)

	# 实时移动里“跨格”才发 moved：蹈火术这类按格触发的被动保持原来的节奏
	var new_cell := grid.world_to_cell(unit.position)
	if new_cell != unit.cell:
		var from_cell := unit.cell
		unit.cell = new_cell
		unit.moved.emit(unit, from_cell, new_cell)
		events.emit_event(BattleEvent.CATEGORY_BATTLE, "moved", {
			"actor_unit": unit,
			"from": [from_cell.x, from_cell.y],
			"to": [new_cell.x, new_cell.y],
		}, BattleEvent.IMPORTANCE_DETAIL)


#region 坐标与索引
func cell_to_world(cell: Vector2i) -> Vector2:
	return grid.cell_to_world(cell)


## 角色在哪一格（只用于刷怪和调试）
func player_cell() -> Vector2i:
	if player == null:
		return Vector2i.ZERO
	return grid.world_to_cell(player.position)


## 指定阵营的全部存活单位（返回内部数组，调用方不要原地修改）
func units_of_team(team: BattleUnit.Team) -> Array[BattleUnit]:
	return registry.of_team(team)


func enemy_count() -> int:
	return registry.enemy_count()


## 距离 pos 半径 radius 内的所有单位；走空间索引，不遍历全场
func units_near(pos: Vector2, radius: float) -> Array[BattleUnit]:
	return spatial.near(pos, radius)
#endregion


#region 刷怪
## 立刻刷一只；具体刷谁、刷在哪由会话注入的 spawn_enemy 决定
func spawn_one() -> void:
	if spawn_enemy.is_valid():
		spawn_enemy.call()
#endregion


#region 时间
## 已完成的物理 tick 数
func tick_count() -> int:
	return _tick_count


## 一个战斗物理 tick 的秒数；战斗内所有固定时长都按它换算
static func tick_seconds() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


## 秒 → 物理 tick 数（向上取整，至少 1）
static func ticks_for_seconds(seconds: float) -> int:
	return maxi(1, ceili(seconds * Engine.physics_ticks_per_second))


func elapsed_seconds() -> float:
	return float(_tick_count) * tick_seconds()
#endregion


#region 日志
func log_line(text: String, color: String = "white") -> void:
	var line := "[%5.2fs] %s" % [elapsed_seconds(), text]
	events.emit_event(
		BattleEvent.CATEGORY_LOG,
		"line",
		{"text": line, "color": color},
		BattleEvent.IMPORTANCE_IMPORTANT
	)


#endregion


## 有单位倒下：角色倒下只停战斗（重开由 BattleSession 监听 died 处理）；怪倒下就从名册里划掉、清掉节点
func _on_unit_died(unit: BattleUnit) -> void:
	if unit == player:
		is_running = false
		return
	spatial.unregister(unit)
	registry.remove(unit)
	_loot.roll(unit, rng)
	unit.cleanup_asc()
	unit.queue_free()
