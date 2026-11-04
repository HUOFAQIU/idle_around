## 一支投射物：朝"发射那一刻记下的坐标"直飞，沿途碰到谁就算打中谁，
## 谁也没碰到就飞过去自己消失 —— 空箭是设计的一部分，不是异常。
##
## 它不算伤害。命中后只把"打到了谁"报回去，结算仍然走 GAS 的效果管线
## （技能那边拿到结果再建 Spec 结算）。
##
## 外观（贴图/区域）配在 soul_projectile.tscn 上；颜色统一从 GameColors 取。

class_name SoulProjectile extends Sprite2D

## 飞完了。hit_unit 为 null 表示这一支飞空了
signal finished(projectile: SoulProjectile, hit_unit: BattleUnit)

## 默认飞行速度（像素/秒）；技能可以覆盖
const DEFAULT_SPEED : float = 420.0
## 离单位多近算打中。单位贴图是 32×32（半径 16），箭自己也是 32×32 ——
## 半径小于 16 的话，画面上两个图都叠上了判定却说没碰到，看着就是"打中了不掉血"。
## 所以这里要大于贴图半径，宁可判定松一点
const HIT_RADIUS : float = 20.0
## 飞这么久还没打中就自己消失
const MAX_LIFE : float = 3.0

var _direction : Vector2 = Vector2.ZERO
var _caster : BattleUnit
var _battle : BattleManager
var _life : float = 0.0
var _done : bool = false
var _speed : float = DEFAULT_SPEED


## 摆好起点和朝向。aim_position 是"选择目标时"的坐标，之后目标走开也不管
func setup(caster: BattleUnit, aim_position: Vector2, speed: float = DEFAULT_SPEED) -> void:
	_caster = caster
	_battle = caster.battle
	_speed = speed if speed > 0.0 else DEFAULT_SPEED
	position = caster.position
	
	var aim_offset := aim_position - caster.position
	if aim_offset.length_squared() > 0.0001:
		_direction = aim_offset.normalized()
		# 图里的箭头是朝上的，转成朝飞行方向
		rotation = _direction.angle() + PI / 2.0


func _ready() -> void:
	modulate = GameColors.to_color(GameColors.PROJECTILE)


func _process(delta: float) -> void:
	if _done:
		return
	# 战斗结束/重开时 BattleManager 可能已释放；箭自毁，避免访问失效引用
	if not is_instance_valid(_battle) or not _battle.is_running:
		_finish(null)
		return

	_life += delta
	if _life >= MAX_LIFE:
		_finish(null)
		return
	
	# 一小步一小步往前挪着查命中：一帧能飞出去好几像素，
	# 分步查才不会直接从单位身上穿过去
	var distance := _speed * delta
	while distance > 0.0:
		var step := minf(distance, HIT_RADIUS * 0.5)
		position += _direction * step
		distance -= step
	
		var hit := _find_hit()
		if hit:
			_finish(hit)
			return


## 撞到谁了：不同阵营、还活着、离得够近。碰到谁算谁，不挑原来瞄的是哪个。
## 只查空间索引里的附近单位，不遍历全场。
func _find_hit() -> BattleUnit:
	if not is_instance_valid(_battle) or not is_instance_valid(_caster):
		return null
	for unit in _battle.units_near(position, HIT_RADIUS):
		if unit == _caster or unit.is_dead:
			continue
		if unit.team == _caster.team:
			continue
		return unit
	return null


func _finish(hit_unit: BattleUnit) -> void:
	_done = true
	finished.emit(self, hit_unit)
	queue_free()
