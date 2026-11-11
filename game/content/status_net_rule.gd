class_name StatusNetRule
extends RefCounted
## 剧毒与再生的净值规则：两者直接相减，数值多的一方生效。
##
## 只比较整数层数，不改动属性本身；状态标签和状态条仍保留各自原值。
## `poison_minus_regen()` 返回剧毒多出的差值，`regen_minus_poison()` 返回再生多出的差值。

## 剧毒减再生；正数表示剧毒更多
static func poison_minus_regen(asc: AbilitySystemComponent) -> int:
	return _stacks(asc, "poison") - _stacks(asc, "regen")


## 再生减剧毒；正数表示再生更多
static func regen_minus_poison(asc: AbilitySystemComponent) -> int:
	return _stacks(asc, "regen") - _stacks(asc, "poison")


static func _stacks(asc: AbilitySystemComponent, attribute_name: String) -> int:
	if asc == null:
		return 0
	var attr := asc.get_attribute(attribute_name)
	if attr == null:
		return 0
	return floori(maxf(attr.current_value, 0.0))
