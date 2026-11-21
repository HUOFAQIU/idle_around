class_name PlayerStatusBar extends Control

const BORDER : float = 1.0

var _border_color : Color = GameColors.to_color(GameColors.BAR_BORDER)
var _background_color : Color = GameColors.to_color(GameColors.STATUS_BAR_BG)

## 监听的属性名：shield / regen / burn / poison
@export var attribute_name: String = "shield"
## 整条填充色；默认是护盾色
@export var fill_color: Color = GameColors.to_color(GameColors.SHIELD)

var _attribute : AttributeData
var _asc : AbilitySystemComponent

@onready var _value_label : Label = $ValueLabel


func _draw() -> void:
	var outer := Rect2(Vector2(-BORDER, -BORDER), size + Vector2(BORDER * 2.0, BORDER * 2.0))
	draw_rect(outer, _border_color)
	draw_rect(Rect2(Vector2.ZERO, size), _background_color)
	draw_rect(Rect2(Vector2.ZERO, size), fill_color)


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
		_value_label.text = "%d" % floori(value)
	queue_redraw()
