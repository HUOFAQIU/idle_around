class_name ScenarioContext
extends RefCounted

var checks: int = 0
var failures: PackedStringArray = PackedStringArray()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func equal(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s：实际 %s，期望 %s" % [message, actual, expected])


func near(actual: float, expected: float, epsilon: float, message: String) -> void:
	check(
		absf(actual - expected) <= epsilon,
		"%s：实际 %s，期望 %s ± %s" % [message, actual, expected, epsilon]
	)
