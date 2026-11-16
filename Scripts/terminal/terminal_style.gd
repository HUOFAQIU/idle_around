class_name TerminalStyle
extends RefCounted
## 单个字符单元的显示样式，只在写 Buffer 时使用。
##
## Buffer 不保存 Style 引用，只取写入瞬间的颜色和属性，
## 所以调用方可以复用一个 Style 对象逐行改色。

var fg: Color = TerminalPalette.default_fg()
var bg: Color = TerminalPalette.default_bg()
var bold: bool = false
var underline: bool = false
var reverse: bool = false


func reset() -> void:
	fg = TerminalPalette.default_fg()
	bg = TerminalPalette.default_bg()
	bold = false
	underline = false
	reverse = false


## 复制一份，避免多个写入点共享同一个可变对象
func duplicate_style() -> TerminalStyle:
	var result := TerminalStyle.new()
	result.fg = fg
	result.bg = bg
	result.bold = bold
	result.underline = underline
	result.reverse = reverse
	return result


## 按 ANSI 前景色索引设置颜色；0-7 普通色，8-15 亮色
func set_ansi_fg(index: int) -> void:
	fg = TerminalPalette.color(index)


func set_ansi_bg(index: int) -> void:
	bg = TerminalPalette.color(index)
