class_name StatusNetRule
extends RefCounted

static func poison_minus_regen(asc: AbilitySystemComponent) -> int:
	return _stacks(asc, "poison") - _stacks(asc, "regen")


static func regen_minus_poison(asc: AbilitySystemComponent) -> int:
	return _stacks(asc, "regen") - _stacks(asc, "poison")


static func _stacks(asc: AbilitySystemComponent, attribute_name: String) -> int:
	if asc == null:
		return 0
	var attr := asc.get_attribute(attribute_name)
	if attr == null:
		return 0
	return floori(maxf(attr.current_value, 0.0))
