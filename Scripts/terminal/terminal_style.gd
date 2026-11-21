class_name TerminalStyle
extends RefCounted

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


func duplicate_style() -> TerminalStyle:
	var result := TerminalStyle.new()
	result.fg = fg
	result.bg = bg
	result.bold = bold
	result.underline = underline
	result.reverse = reverse
	return result


func set_ansi_fg(index: int) -> void:
	fg = TerminalPalette.color(index)


func set_ansi_bg(index: int) -> void:
	bg = TerminalPalette.color(index)
