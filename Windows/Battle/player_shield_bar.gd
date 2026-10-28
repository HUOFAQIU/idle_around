## 战斗窗口左下角的角色护盾条。
##
## 护盾不按比例缩短：只要有护盾就显示整条黄色背景，
## 中间显示当前护盾数值；护盾为 0 时整条隐藏。

class_name PlayerShieldBar extends Control

const BORDER : float = 1.0
const BORDER_COLOR := Color(0, 0, 0, 0.75)
const BACKGROUND_COLOR := Color(0.22, 0.18, 0.03)
const FILL_COLOR := Color(1.0, 0.85, 0.10)

var _shield : AttributeData
var _asc : AbilitySystemComponent

@onready var _value_label : Label = $ValueLabel


func _draw() -> void:
	var outer := Rect2(Vector2(-BORDER, -BORDER), size + Vector2(BORDER * 2.0, BORDER * 2.0))
	draw_rect(outer, BORDER_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), FILL_COLOR)


## 接上角色护盾；每场战斗重建角色后调用
func bind(shield : AttributeData, asc : AbilitySystemComponent) -> void:
	if _asc != null and is_instance_valid(_asc) and _asc.attribute_changed.is_connected(_on_attribute_changed):
		_asc.attribute_changed.disconnect(_on_attribute_changed)
	_shield = shield
	_asc = asc
	asc.attribute_changed.connect(_on_attribute_changed)
	_refresh()


func _on_attribute_changed(attribute_name : String, _old_value : float, _new_value : float, _spec : GameplayEffectSpec) -> void:
	if attribute_name == "shield":
		_refresh()


func _refresh() -> void:
	if _shield == null:
		return
	var value := maxf(_shield.current_value, 0.0)
	visible = value > 0.0
	if _value_label != null:
		_value_label.text = "%d" % roundi(value)
	queue_redraw()
