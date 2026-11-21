extends Node

const MAIN_SCENE: PackedScene = preload("res://Main/Cube/Scenes/main.tscn")
const CASES: Array[GDScript] = [
	preload("res://tools/scenarios/cases/save_roundtrip.gd"),
	preload("res://tools/scenarios/cases/map_place.gd"),
	preload("res://tools/scenarios/cases/battle_run.gd"),
]

var _total: int = 0
var _failed: int = 0
var _main_loaded: bool = false


func _ready() -> void:
	var requested := OS.get_cmdline_user_args()
	var selected: Array[ScenarioCase] = []
	var matched: Dictionary = {}

	for case_script in CASES:
		var case := case_script.new() as ScenarioCase
		var case_name := String(case.case_name())
		if case_name.is_empty():
			_error("用例没有声明名字：%s" % case_script.resource_path)
			continue
		if not requested.is_empty() and not requested.has(case_name):
			continue
		matched[case_name] = true
		selected.append(case)

	for requested_name in requested:
		if not matched.has(requested_name):
			_error("未知用例：%s" % requested_name)

	for case in selected:
		if case.needs_main_scene() and not _main_loaded:
			await _load_main_scene()
		var context := ScenarioContext.new()
		@warning_ignore("redundant_await")
		await case.run(context)
		_report(case.case_name(), context)

	print("SCENARIO_TOTAL ", _total)
	print("SCENARIO_FAILED ", _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _load_main_scene() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main_loaded = true


func _report(case_name: StringName, context: ScenarioContext) -> void:
	_total += 1
	var failures: PackedStringArray = context.failures.duplicate()
	if context.checks == 0:
		failures.append("用例没有产生任何断言")
	if failures.is_empty():
		print("SCENARIO %s PASS (%d 项断言)" % [case_name, context.checks])
		return
	_failed += 1
	print("SCENARIO %s FAIL (%d 项断言，%d 项失败)" % [case_name, context.checks, failures.size()])
	for message in failures:
		print("  - ", message)


func _error(message: String) -> void:
	print("SCENARIO ERROR ", message)
	_failed += 1
