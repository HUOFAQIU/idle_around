## 刷怪计时器：每 interval 秒通知一次。
##
## 选哪只怪、刷在离角色几格由游戏侧决定；本类只负责计时和回调，
## 不依赖 MonsterData / 地图，避免把内容规则塞进运行时计时器。
class_name EnemySpawner extends RefCounted

const DEFAULT_INTERVAL: float = 1.0

## 刷怪间隔（秒）
var interval: float = DEFAULT_INTERVAL
## 刷怪回调，签名 func()；谁建怪、刷在哪由游戏侧决定
var spawn_enemy: Callable = Callable()

var _accum: float = 0.0


## 战斗心跳：累计到间隔就通知一次
func tick(delta: float) -> void:
	_accum += delta
	if _accum < interval:
		return
	_accum -= interval
	spawn_one()


## 立刻通知一次（没有回调时忽略）
func spawn_one() -> void:
	if spawn_enemy.is_valid():
		spawn_enemy.call()
