class_name Monster
extends Sprite2D

## 怪物在 tokens.png 里的位置
const TEXTURE := preload("res://Assets/tokens.png")
const REGION := Rect2(64, 0, 32, 32)
const COLOR := Color(0.92, 0.30, 0.30)
const MAX_HP : int = 100
## 往相邻格挪一格花多久
const STEP_TIME : float = 0.15

var hp : int = MAX_HP
## 现在在哪一格
var cell : Vector2i = Vector2i.ZERO


func _ready() -> void:
	texture = TEXTURE
	region_enabled = true
	region_rect = REGION
	modulate = COLOR


## 挪到相邻的一格
func step_to(p_cell: Vector2i, p_position: Vector2) -> void:
	cell = p_cell
	create_tween().tween_property(self, "position", p_position, STEP_TIME)


## 挨打，返回这一下有没有把它打死
func take_damage(amount: int) -> bool:
	hp -= amount
	_flash()
	return hp <= 0


func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.05)
	tween.tween_property(self, "modulate", COLOR, 0.12)
