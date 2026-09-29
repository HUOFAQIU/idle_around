extends Control

## E2E：窗口打开在哪儿
##   跑法：godot --path . res://Tests/e2e_windows.tscn
##   产物：Tests/shots/*.png + Tests/shots/report.txt
##
## 点的是真按钮（走 control.gd 的回调），判定只看用户看得见的东西：窗口开没开、开在屏幕哪儿。

var kit := E2EKit.new("windows")
var app : Control
var character : Window
var inv : BaseWindow
## 仓库在 control.tscn 里配的位置，验兜底时先清掉、验完还原
const INV_POS : Vector2i = Vector2i(1683, 291)


func _ready() -> void:
	app = load("res://control.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame

	await _step_character_at_position()
	await _step_toggle_keeps_position()
	await _step_configured_positions()
	await _step_centered_fallback()

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


func _step_configured_positions() -> void:
	kit.note("步骤 3：配了 open_position 的窗口，就开在配的地方")
	_click_main("Button3")
	await get_tree().process_frame
	await get_tree().process_frame
	inv = app.get_node("InventoryWindow")
	kit.check("仓库窗口打开了", inv.visible, true)
	kit.check("仓库开在配的 (1683, 291)", inv.position, INV_POS)
	await kit.shot(inv, "02_仓库开在配的位置", "仓库窗口摆在 (1683, 291)——它在 control.tscn 里配了 open_position，所以不居中")
	_click_main("Button3")
	await get_tree().process_frame

	_click_main("Button2")
	await get_tree().process_frame
	await get_tree().process_frame
	var equip := app.get_node("EquipmentWindow") as Window
	kit.check("装备窗口打开了", equip.visible, true)
	kit.check("装备开在配的 (1266, 150)", equip.position, Vector2i(1266, 150))
	await kit.shot(equip, "03_装备开在配的位置", "装备窗口摆在 (1266, 150)——同样是 config 说的算，不是居中")
	_click_main("Button2")
	await get_tree().process_frame


## 四个窗口现在都配了 open_position，没有「没配」的真窗口了。
## 所以这里把仓库的配置临时清成 (-1, -1) 再开一次 —— 走的是真按钮、真 popup_window、真 open_window，
## 只是那个字段换了个值，验的是「没配就居中」这条兜底分支还在。
func _step_centered_fallback() -> void:
	kit.note("步骤 4：没配 open_position 就居中开（临时清掉仓库的配置来验这条兜底分支）")
	inv = app.get_node("InventoryWindow")
	inv.open_position = Vector2i(-1, -1)

	_click_main("Button3")
	await get_tree().process_frame
	await get_tree().process_frame
	kit.check("仓库窗口打开了", inv.visible, true)

	var screen := DisplayServer.screen_get_usable_rect()
	var want := Vector2(screen.position) + Vector2(screen.size) / 2.0
	var got := Vector2(inv.position) + Vector2(inv.size) / 2.0
	print("   屏幕可用区中心=", want, " 仓库窗口中心=", got)
	# 容差给 40 像素：Godot 居中时算的是带标题栏的整窗，客户区会低二十来像素，属正常
	kit.check("清掉配置后开在屏幕中间（差 40 像素以内）", got.distance_to(want) < 40.0, true)
	await kit.shot(inv, "04_没配位置就居中", "同一扇仓库窗口，配置清掉之后再开就回到屏幕正中——兜底分支还活着")

	inv.open_position = INV_POS


func _click_main(button_name: String) -> void:
	(app.get_node("GridContainer/" + button_name) as Button).pressed.emit()
