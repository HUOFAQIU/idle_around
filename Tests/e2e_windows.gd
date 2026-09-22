extends Control

## E2E：窗口打开在哪儿
##   跑法：godot --path . res://Tests/e2e_windows.tscn
##   产物：Tests/shots/*.png + Tests/shots/report.txt
##
## 点的是真按钮（走 control.gd 的回调），判定只看用户看得见的东西：窗口开没开、开在屏幕哪儿。

var kit := E2EKit.new("windows")
var app : Control
var character : Window
var inv : Window


func _ready() -> void:
	app = load("res://control.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame

	await _step_character_at_position()
	await _step_toggle_keeps_position()
	await _step_other_windows_still_centered()

	kit.finish("窗口打开位置 E2E")
	get_tree().quit()


func _step_character_at_position() -> void:
	kit.note("步骤 1：点「人物」按钮 —— 人物窗口该开在 (1310, 160)，尺寸不变")
	_click_main("Button")
	await get_tree().process_frame
	await get_tree().process_frame
	character = app.get_node("CharacterWindow")
	kit.check("人物窗口打开了", character.visible, true)
	kit.check("开在 (1310, 160)", character.position, Vector2i(1310, 160))
	kit.check("尺寸还是 300×300", character.size, Vector2i(300, 300))
	await kit.shot(character, "01_人物窗口", "人物窗口现在是个空壳，图就是一片灰——它的价值是「窗口真的开了」；开在哪由上面的坐标断言管")


func _step_toggle_keeps_position() -> void:
	kit.note("步骤 2：再点一次该收起来，第三次点开还得在原位")
	_click_main("Button")
	await get_tree().process_frame
	kit.check("再点一次收起来了", character.visible, false)
	_click_main("Button")
	await get_tree().process_frame
	await get_tree().process_frame
	kit.check("再打开还在 (1310, 160)", character.position, Vector2i(1310, 160))


func _step_other_windows_still_centered() -> void:
	kit.note("步骤 3：没写 open_position 的窗口照旧居中开（拿仓库验）")
	_click_main("Button3")
	await get_tree().process_frame
	await get_tree().process_frame
	inv = app.get_node("InventoryWindow")
	kit.check("仓库窗口打开了", inv.visible, true)

	var screen := DisplayServer.screen_get_usable_rect()
	var want := Vector2(screen.position) + Vector2(screen.size) / 2.0
	var got := Vector2(inv.position) + Vector2(inv.size) / 2.0
	print("   屏幕可用区中心=", want, " 仓库窗口中心=", got)
	# 容差给 40 像素：Godot 居中时算的是带标题栏的整窗，客户区会低二十来像素，属正常
	kit.check("仓库开在屏幕中间（差 40 像素以内）", got.distance_to(want) < 40.0, true)
	await kit.shot(inv, "02_仓库仍居中", "仓库窗口还是屏幕正中，没被这次改动带偏")


func _click_main(button_name: String) -> void:
	(app.get_node("GridContainer/" + button_name) as Button).pressed.emit()
