class_name BaseWindow
extends Window

## 打开时摆在屏幕哪儿；x 或 y 是负数表示「居中」（就按 popup_centered 来）
@export var open_position : Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	unresizable = true
	#popup_window = true
	minimize_disabled = true
	maximize_disabled = true

	close_requested.connect(
		func ():
			self.hide()
			# 暂时的
			Engine.time_scale = 1
	)


## 打开：写了 open_position 就摆在那儿，没写就居中
## （由 `control.gd::popup_window()` 调；别直接 popup_centered()，那会把位置覆盖掉）
func open_window() -> void:
	if open_position.x < 0 or open_position.y < 0:
		popup_centered()
		return
	popup(Rect2i(open_position, _popup_size()))


## popup() 会连尺寸一起定，所以别把窗口缩得比内容还小
func _popup_size() -> Vector2i:
	var need := Vector2i(get_contents_minimum_size().ceil())
	return Vector2i(maxi(size.x, need.x), maxi(size.y, need.y))
