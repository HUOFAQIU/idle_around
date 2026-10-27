@tool
class_name PlayerStatsAttributeSet extends AttributeSet

var max_health: AttributeData = AttributeData.new(500.0)
var health: AttributeData = AttributeData.new(500.0)
## 己方魂灵的直接伤害加成（固定值）；健身房等被动魂灵会加这个属性
var damage_bonus: AttributeData = AttributeData.new(0.0)


## The safety pipeline: Clamps stats before they are officially changed.
func pre_attribute_change(attribute_name: String, proposed_value: float) -> float:
	match attribute_name:
		"health":
			return clamp(proposed_value, 0.0, max_health.current_value)

	return proposed_value


## The reaction pipeline: Handles moving goalposts (e.g. MaxHealth dropping below Health).
func post_attribute_change(asc: Node, attribute_name: String, old_value: float, new_value: float) -> void:
	match attribute_name:
		"max_health":
			if health.current_value > new_value:
				asc._apply_attribute_change("health", new_value - health.current_value)
