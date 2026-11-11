@tool
class_name PlayerStatsAttributeSet extends AttributeSet

var max_health: AttributeData = AttributeData.new(500.0)
var health: AttributeData = AttributeData.new(500.0)
## 己方魂灵的直接伤害加成（固定值）；健身房等被动魂灵会加这个属性
var damage_bonus: AttributeData = AttributeData.new(0.0)
## 当前灼烧层数；每 0.5 秒按整数层数结算一次，然后衰减 3%
var burn: AttributeData = AttributeData.new(0.0)
## 当前护盾值；优先承受伤害，无上限、无持续时间
var shield: AttributeData = AttributeData.new(0.0)
## 当前剧毒值；每秒结算一次，不衰减，无视护盾
var poison: AttributeData = AttributeData.new(0.0)
## 当前生命再生值；每秒恢复等量生命，不衰减，溢出丢弃
var regen: AttributeData = AttributeData.new(0.0)


## The safety pipeline: floors integer stats and clamps them before they are officially changed.
## 计算层允许小数；所有战斗属性写入前在这里统一向下取整，作为最后一道兜底。
func pre_attribute_change(attribute_name: String, proposed_value: float) -> float:
	match attribute_name:
		"health":
			return floorf(clampf(proposed_value, 0.0, max_health.current_value))
		"max_health", "damage_bonus":
			return floorf(proposed_value)
		"burn", "shield", "poison", "regen":
			return maxf(floorf(proposed_value), 0.0)

	return proposed_value


## The reaction pipeline: Handles moving goalposts (e.g. MaxHealth dropping below Health).
func post_attribute_change(asc: Node, attribute_name: String, old_value: float, new_value: float) -> void:
	match attribute_name:
		"max_health":
			if health.current_value > new_value:
				asc._apply_attribute_change("health", new_value - health.current_value)
