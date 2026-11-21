class_name ScenarioCase
extends RefCounted


func case_name() -> StringName:
	return &""


func needs_main_scene() -> bool:
	return false


func run(_ctx: ScenarioContext) -> void:
	pass
