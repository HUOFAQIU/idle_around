## 战斗窗口左下角的角色状态条。
##
## 护盾、生命再生、灼烧、剧毒共用这套显示：不按数值比例缩短，
## 只要数值大于 0 就显示整条，中间显示当前数值；为 0 时隐藏。

class_name PlayerStatusBar extends Control

const BORDER : float = 1.0
const BORDER_COLOR := Color(0, 0, 0, 0.75)
const BACKGROUND_COLOR := Color(0.12, 0.12, 0.10)

## 监听的属性名：shield / regen / burn / poison
@export var attribute_name: String = "shield"
## 整条填充色
@export var fill_color: Color = Color(1.0, 0.85, 0.10)

var _attribute : AttributeData
var _asc : AbilitySystemComponent

@onready var _value_label : Label = $ValueLabel


func _draw() -> void:
	var outer := Rect2(Vector2(-BORDER, -BORDER), size + Vector2(BORDER * 2.0, BORDER * 2.0))
	draw_rect(outer, BORDER_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), fill_color)


## 接上角色属性；每场战斗重建角色后调用
func bind(attribute : AttributeData, asc : AbilitySystemComponent) -> void:
	if _asc != null and is_instance_valid(_asc) and _asc.attribute_changed.is_connected(_on_attribute_changed):
		_asc.attribute_changed.disconnect(_on_attribute_changed)
	_attribute = attribute
	_asc = asc
	asc.attribute_changed.connect(_on_attribute_changed)
	_refresh()


func _on_attribute_changed(changed_name : String, _old_value : float, _new_value : float, _spec : GameplayEffectSpec) -> void:
	if changed_name == attribute_name:
		_refresh()


func _refresh() -> void:
	if _attribute == null:
		return
	var value := maxf(_attribute.current_value, 0.0)
	visible = value > 0.0
	if _value_label != null:
		_value_label.text = "%d" % roundi(value)
	queue_redraw()
