## 战斗属性集：hp / max_hp / atk 三个属性。
##
## 演示 AttributeSet 的两个钩子：
##   pre_attribute_change  → 把 hp 钳制在 [0, max_hp]（所以伤害不会把血打成负数）
##   （post_attribute_change 需要联动时再重写，本案例不需要）
##
## @meta_addon: GodotGAS
## @meta_license: MIT

@tool
class_name BattleAttributeSet extends AttributeSet

var max_hp: AttributeData = AttributeData.new(100.0)
var hp: AttributeData = AttributeData.new(100.0)
var atk: AttributeData = AttributeData.new(10.0)


## 写入前拦截：hp 永远落在 [0, max_hp] 区间内。
func pre_attribute_change(attribute_name: String, proposed_value: float) -> float:
	if attribute_name == "hp":
		return clampf(proposed_value, 0.0, max_hp.current_value)
	return proposed_value
