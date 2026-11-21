class_name UnitHealthBar extends Node2D

const SIZE := Vector2(28.0, 5.0)
const BORDER := 1.0

var _background_color : Color = GameColors.to_color(GameColors.BAR_BG)
var _fill_color : Color = GameColors.to_color(GameColors.HEALTH_FILL)
var _ratio := 1.0
var _health: AttributeData
var _max_health: AttributeData


func bind(health: AttributeData, max_health: AttributeData, asc: AbilitySystemComponent, fill_color: Color) -> void:
	_health = health
	_max_health = max_health
	_fill_color = fill_color
	asc.attribute_changed.connect(_on_attribute_changed)
	_refresh()


func _on_attribute_changed(attribute_name: String, _old_value: float, _new_value: float, _spec: GameplayEffectSpec) -> void:
	if attribute_name == "health" or attribute_name == "max_health":
		_refresh()


func _refresh() -> void:
	_ratio = clampf(_health.current_value / maxf(_max_health.current_value, 0.001), 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var outer := Rect2(
		-SIZE.x / 2.0 - BORDER,
		-BORDER,
		SIZE.x + BORDER * 2.0,
		SIZE.y + BORDER * 2.0
	)
	draw_rect(outer, GameColors.to_color(GameColors.BAR_BORDER))
	draw_rect(Rect2(-SIZE.x / 2.0, 0.0, SIZE.x, SIZE.y), _background_color)
	draw_rect(Rect2(-SIZE.x / 2.0, 0.0, SIZE.x * _ratio, SIZE.y), _fill_color)
