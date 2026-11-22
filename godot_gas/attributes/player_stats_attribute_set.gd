@tool
class_name PlayerStatsAttributeSet extends AttributeSet

var max_health: AttributeData = AttributeData.new(500.0)
var health: AttributeData = AttributeData.new(500.0)
var move_speed: AttributeData = AttributeData.new(11.0)
var damage_bonus: AttributeData = AttributeData.new(0.0)
var burn: AttributeData = AttributeData.new(0.0)
var shield: AttributeData = AttributeData.new(0.0)
var poison: AttributeData = AttributeData.new(0.0)
var regen: AttributeData = AttributeData.new(0.0)


func pre_attribute_change(attribute_name: String, proposed_value: float) -> float:
	match attribute_name:
		"health":
			return floorf(clampf(proposed_value, 0.0, max_health.current_value))
		"max_health", "damage_bonus":
			return floorf(proposed_value)
		"move_speed":
			return maxf(proposed_value, 0.0)
		"burn", "shield", "poison", "regen":
			return maxf(floorf(proposed_value), 0.0)

	return proposed_value


func post_attribute_change(asc: Node, attribute_name: String, _old_value: float, new_value: float) -> void:
	match attribute_name:
		"max_health":
			if health.current_value > new_value:
				asc._apply_attribute_change("health", new_value - health.current_value)
