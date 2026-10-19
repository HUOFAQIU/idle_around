## 战斗窗口左下角的角色血条（UI 层）。
## 数据源和单位头顶血条一样，直接接 ASC 的 attribute_changed。

class_name PlayerHealthBar extends Control

const BORDER : float = 1.0
const BORDER_COLOR := Color(0, 0, 0, 0.75)
const BACKGROUND_COLOR := Color(0.22, 0.05, 0.05)
const FILL_COLOR := Color(0.40, 0.85, 0.45)

var _health : AttributeData
var _max_health : AttributeData
var _asc : AbilitySystemComponent
var _ratio : float = 1.0


func _draw() -> void:
	var outer := Rect2(Vector2(-BORDER, -BORDER), size + Vector2(BORDER * 2.0, BORDER * 2.0))
	draw_rect(outer, BORDER_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _ratio, size.y)), FILL_COLOR)


## 接上角色属性；每场战斗重建角色后调用
func bind(health : AttributeData, max_health : AttributeData, asc : AbilitySystemComponent) -> void:
	if _asc != null and is_instance_valid(_asc) and _asc.attribute_changed.is_connected(_on_attribute_changed):
		_asc.attribute_changed.disconnect(_on_attribute_changed)
	_health = health
	_max_health = max_health
	_asc = asc
	asc.attribute_changed.connect(_on_attribute_changed)
	_refresh()


func _on_attribute_changed(attribute_name : String, _old_value : float, _new_value : float, _spec : GameplayEffectSpec) -> void:
	if attribute_name == "health" or attribute_name == "max_health":
		_refresh()


func _refresh() -> void:
	if _health == null or _max_health == null:
		return
	_ratio = clampf(_health.current_value / maxf(_max_health.current_value, 0.001), 0.0, 1.0)
	queue_redraw()
