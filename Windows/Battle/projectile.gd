class_name Projectile
extends Sprite2D

## 投射物在 tokens.png 里的位置
const TEXTURE := preload("res://Assets/tokens.png")
const REGION := Rect2(0, 32, 32, 32)
const COLOR := Color(1.0, 0.85, 0.30)
const SPEED : float = 300.0
## 飞这么久还没打中就自己消失
const LIFE : float = 3.0
## 离怪物多近算打中
const HIT_RADIUS : float = 14.0

## 打中怪物时发出
signal hit(monster: Monster)

## 发射那一刻定下的方向，之后直着飞、不追人
var _direction : Vector2 = Vector2.ZERO
## 场上的怪物容器，用来做命中判定
var _monsters : Node2D = null
var _life : float = 0.0


func _ready() -> void:
	texture = TEXTURE
	region_enabled = true
	region_rect = REGION
	modulate = COLOR


func setup(p_direction: Vector2, p_monsters: Node2D) -> void:
	_direction = p_direction.normalized()
	_monsters = p_monsters
	# 图里的箭头是朝上的，转成朝飞行方向
	rotation = _direction.angle() + PI / 2.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	_life += delta
	if _fly(SPEED * delta):
		return
	if _life >= LIFE:
		queue_free()


# 往前飞一段，一小步一小步地查有没有撞上怪；撞到就发信号、自毁，返回 true
# 分成小步是因为帧一卡，一帧能飞出去几十像素，会直接从怪物身上穿过去
func _fly(distance: float) -> bool:
	while distance > 0.0:
		var step := minf(distance, HIT_RADIUS * 0.5)
		position += _direction * step
		distance -= step

		var target := _find_hit()
		if target:
			hit.emit(target)
			queue_free()
			return true
	return false


func _find_hit() -> Monster:
	if _monsters == null:
		return null
	for node in _monsters.get_children():
		if node.is_queued_for_deletion():
			continue
		var monster := node as Monster
		if monster and position.distance_to(monster.position) <= HIT_RADIUS:
			return monster
	return null
