## 战斗窗口左下角的角色血条（UI 层）。
## 数据源和单位头顶血条一样，直接接 ASC 的 attribute_changed。

class_name PlayerHealthBar extends Control

const BORDER : float = 1.0

var _border_color : Color = GameColors.to_color(GameColors.BAR_BORDER)
var _background_color : Color = GameColors.to_color(GameColors.BAR_BG)
var _fill_color : Color = GameColors.to_color(GameColors.HEALTH_FILL)
var _health : AttributeData
var _max_health : AttributeData
var _asc : AbilitySystemComponent
var _ratio : float = 1.0

@onready var _value_label : Label = $ValueLabel


func _draw() -> void:
	var outer := Rect2(Vector2(-BORDER, -BORDER), size + Vector2(BORDER * 2.0, BORDER * 2.0))
	draw_rect(outer, _border_color)
	draw_rect(Rect2(Vector2.ZERO, size), _background_color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _ratio, size.y)), _fill_color)


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
	if _value_label != null:
		_value_label.text = "%d/%d" % [roundi(_health.current_value), roundi(_max_health.current_value)]
	queue_redraw()
