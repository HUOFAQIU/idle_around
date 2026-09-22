class_name E2EKit
extends RefCounted

## E2E 工具箱：从**真实入口**（control.tscn）驱动这个游戏，跑完留下可复核的产物。
##
## 鼠标怎么控制（Godot 里没法凭空点人家窗口上的按钮，只能这么来）：
##   1. **光标位置** —— 不动鼠标，把窗口挪到光标底下（`put_cursor_at()`）。
##      这样 App 眼里的「光标在窗口里哪儿」跟真人操作是一回事。
##   2. **按下 / 松开** —— 全局按键状态用 `Input.parse_input_event()` 注入（要等一帧才生效），
##      事件本身用 `Window.push_input()` 投递给那个窗口（控件才收得到）。
##   3. **拖动中移动** —— 还是挪窗口：窗口往左挪一格，光标在窗口里的位置就右移一格。
##
## 产物：`Tests/shots/*.png`（每一步的截图）+ `Tests/shots/report.txt`（步骤、判定、每张图该长什么样）。

const SHOT_ROOT : String = "res://Tests/shots"

## 这个场景的产物目录（按场景分开，免得两个场景的 report.txt 互相覆盖）
var dir : String = SHOT_ROOT
var lines : Array[String] = []
var fails : int = 0


func _init(scenario : String) -> void:
	dir = "%s/%s" % [SHOT_ROOT, scenario]
	DirAccess.make_dir_recursive_absolute(dir)
	# 让 Godot 别把这个目录当资源扫（不然每张截图旁边都会多一个 .import）
	var ignore := FileAccess.open(dir + "/.gdignore", FileAccess.WRITE)
	if ignore:
		ignore.close()


func note(text: String) -> void:
	lines.append("· " + text)
	print("· " + text)


func check(label: String, got, want) -> void:
	var ok : bool = got == want
	if not ok:
		fails += 1
	var line := "%s %s   得到=%s 期望=%s" % ["[OK]  " if ok else "[FAIL]", label, str(got), str(want)]
	lines.append(line)
	print(line)


## 把窗口挪到光标底下，让光标落在窗口内的 want_local 处
func put_cursor_at(win: Window, want_local: Vector2) -> void:
	win.position = DisplayServer.mouse_get_position() - Vector2i(want_local)
	await _frame()
	var actual := Vector2(DisplayServer.mouse_get_position() - win.position)
	check("光标落在窗口内的 %s（想放 %s）" % [str(actual), str(want_local)], actual.is_equal_approx(want_local), true)


## 拖动中改变光标位置：把窗口往反方向挪
func shift_cursor_in(win: Window, delta_local: Vector2) -> void:
	win.position -= Vector2i(delta_local)
	await _frame()
	await _frame()


## 全局左键状态（要等一帧才生效）
func set_button_down(down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = Vector2(150, 150)   # 主窗口正中，那儿没有控件，纯粹为了更新全局状态
	Input.parse_input_event(ev)
	await _frame()


## 把按下 / 松开事件投递给这个窗口（谁在光标底下谁收得到）
func deliver_click(win: Window, down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = down
	ev.position = Vector2(DisplayServer.mouse_get_position() - win.position)
	win.push_input(ev, true)
	await _frame()


## 按住：先让全局状态就位，再投递
func press(win: Window, button := MOUSE_BUTTON_LEFT) -> void:
	await set_button_down(true)
	await deliver_click(win, true, button)


## 松手：事件先到（该收尾的收尾），再放开全局状态
func release(win: Window, button := MOUSE_BUTTON_LEFT) -> void:
	await deliver_click(win, false, button)
	await set_button_down(false)
	await _frame()


## 截图存档；desc 写「这张图该看到什么」，报告里会带上
func shot(win: Window, name: String, desc: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [dir, name]
	win.get_texture().get_image().save_png(path)
	note("截图 %s.png —— %s" % [name, desc])


## 抓一张图，给「有没有留残影」这类逐像素比较用
func grab(win: Window) -> Image:
	await RenderingServer.frame_post_draw
	return win.get_texture().get_image()


func finish(title: String) -> void:
	var head := "%s —— 失败 %d 条" % [title, fails]
	lines.push_front(head)
	var file := FileAccess.open(dir + "/report.txt", FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	print("======== " + head)
	for line in lines:
		print(line)


func _frame() -> void:
	await Engine.get_main_loop().process_frame
