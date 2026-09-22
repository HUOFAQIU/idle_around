class_name ItemDraw
extends RefCounted

## 一件东西长什么样，就这一处说了算：底色块 + 一圈深色描边 + 居中的白字（塞不下就不写）。
## 仓库、装备面板、跟着指针的小窗口画的都是同一套，以后改样式只改这里。

const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.95)
const COLOR_NAME_OUTLINE := Color(0.0, 0.0, 0.0, 0.65)


static func block(canvas: Control, rect: Rect2, item: InventoryItem, font_size: int = 14) -> void:
	canvas.draw_rect(rect, item.color)
	canvas.draw_rect(rect, item.color.darkened(0.45), false, 1.0)

	if item.name.is_empty():
		return
	var font := canvas.get_theme_default_font()
	if font == null:
		return
	var text_size := font.get_string_size(item.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	if text_size.x > rect.size.x - 2.0:
		return
	var baseline := Vector2(
		rect.get_center().x - text_size.x / 2.0,
		rect.get_center().y + font.get_ascent(font_size) / 2.0 - 1.0
	)
	canvas.draw_string_outline(font, baseline, item.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, COLOR_NAME_OUTLINE)
	canvas.draw_string(font, baseline, item.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_NAME)
