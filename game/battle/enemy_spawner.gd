## 刷怪器：每 interval 秒在距角色至少 min_distance 格的位置刷一只。
##
## 刷哪只怪由外部注入的 spawn_enemy 决定；本类只负责计时、选格和随机源。
## 可刷格在地图静态时只算一次，开战时由 BattleManager 调 rebuild()。
class_name EnemySpawner extends RefCounted

const DEFAULT_INTERVAL: float = 1.0
const DEFAULT_MIN_DISTANCE: int = 5

## 刷怪间隔（秒）
var interval: float = DEFAULT_INTERVAL
## 只在距离角色至少这么多格的位置刷怪（距离正好等于该值也算）
var min_distance: int = DEFAULT_MIN_DISTANCE
## 刷怪回调，签名 func(cell: Vector2i)；谁建怪、怪长什么样是游戏侧的事
var spawn_enemy: Callable = Callable()
## 选格随机源；为空时退回全局随机
var rng: RandomNumberGenerator

var _accum: float = 0.0
var _spawn_cells: Array[Vector2i] = []


func _init(p_rng: RandomNumberGenerator = null) -> void:
	rng = p_rng


## 重算可刷格；地图静态，开战时算一次即可
func rebuild(grid: BattleGrid, center: Vector2i) -> void:
	_accum = 0.0
	_spawn_cells = grid.cells_at_least(center, min_distance)


## 战斗心跳：累计到间隔就刷一只
func tick(delta: float) -> void:
	_accum += delta
	if _accum < interval:
		return
	_accum -= interval
	spawn_one()


## 立刻刷一只（挑得到位置才刷）
func spawn_one() -> void:
	if not spawn_enemy.is_valid() or _spawn_cells.is_empty():
		return
	var cell: Vector2i
	if rng == null:
		cell = _spawn_cells.pick_random()
	else:
		cell = _spawn_cells[rng.randi_range(0, _spawn_cells.size() - 1)]
	spawn_enemy.call(cell)
