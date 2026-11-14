class_name TerminalAnsiParser
extends RefCounted
## ANSI 转义序列解析器：把 SGR（颜色/样式）转成 TerminalStyle，再交给 Buffer。
##
## 目前处理 SGR（...m）和 OSC 跳过；光标移动/擦除等 CSI 命令暂时整段吞掉，
## 不会当普通文字显示，也不会改 Buffer。Parser 的 style 在多次 write() 之间保持，
## 和真实终端一样是流式状态；未收完的 ESC 序列会挂到下一次 write() 继续解析。

const ESC_CODE: int = 27
const CSI_FINAL_MIN: int = 0x40
const CSI_FINAL_MAX: int = 0x7E
const MAX_PENDING_LENGTH: int = 4096

var style: TerminalStyle

var _esc_text: String = String.chr(ESC_CODE)
var _pending: String = ""


func _init(initial_style: TerminalStyle = null) -> void:
	if initial_style != null:
		style = initial_style.duplicate_style()
	else:
		style = TerminalStyle.new()


## 解析一段文本并写入 Buffer；SGR 样式跨调用保持
func write(buffer: TerminalBuffer, text: String) -> void:
	if buffer == null:
		return
	var data := _pending + text
	_pending = ""
	var index := 0
	var length := data.length()
	while index < length:
		var esc := data.find(_esc_text, index)
		if esc < 0:
			_write_plain(buffer, data.substr(index))
			return
		if esc > index:
			_write_plain(buffer, data.substr(index, esc - index))
		var next := _consume_escape(data, esc)
		if next < 0:
			var tail := data.substr(esc)
			if tail.length() <= MAX_PENDING_LENGTH:
				_pending = tail
			return
		index = next


## 重置当前样式和未完成的转义序列
func reset() -> void:
	style.reset()
	_pending = ""


## 用指定样式作为起点（会复制，不影响调用方）
func set_style(new_style: TerminalStyle) -> void:
	if new_style != null:
		style = new_style.duplicate_style()
	_pending = ""


func _write_plain(buffer: TerminalBuffer, text: String) -> void:
	if not text.is_empty():
		buffer.write_text(text, style)


## 返回序列结束后的位置；-1 表示序列还没收完
func _consume_escape(data: String, esc: int) -> int:
	var length := data.length()
	if esc + 1 >= length:
		return -1
	var kind := data.unicode_at(esc + 1)
	if kind == 0x5B: # '['
		return _consume_csi(data, esc)
	if kind == 0x5D: # ']'
		return _consume_osc(data, esc)
	# 字符集设计符 ESC ( B / ESC ) B / ESC # 8 多吞一个字符
	if kind == 0x28 or kind == 0x29 or kind == 0x23:
		return mini(esc + 3, length)
	# 其他 ESC 单字符序列：ESC c 重置，其余忽略
	if kind == 0x63: # 'c'
		style.reset()
	return mini(esc + 2, length)


func _consume_csi(data: String, esc: int) -> int:
	var index := esc + 2
	var length := data.length()
	while index < length:
		var code := data.unicode_at(index)
		if code < 0x20:
			# 控制字符出现在 CSI 中间：放弃这一小段，避免吞掉后面的正常文本
			return index + 1
		if code >= CSI_FINAL_MIN and code <= CSI_FINAL_MAX:
			if code == 0x6D: # 'm'
				_apply_sgr(data.substr(esc + 2, index - (esc + 2)))
			return index + 1
		index += 1
	return -1


func _consume_osc(data: String, esc: int) -> int:
	var index := esc + 2
	var length := data.length()
	while index < length:
		var code := data.unicode_at(index)
		if code == 0x07: # BEL
			return index + 1
		if code == ESC_CODE and index + 1 < length and data.unicode_at(index + 1) == 0x5C: # ST
			return index + 2
		index += 1
	return -1


func _apply_sgr(param_text: String) -> void:
	var params := param_text.split(";")
	if params.is_empty() or (params.size() == 1 and params[0].is_empty()):
		style.reset()
		return
	var index := 0
	while index < params.size():
		var code := int(params[index]) if not params[index].is_empty() else 0
		if code == 0:
			style.reset()
		elif code == 1:
			style.bold = true
		elif code == 22:
			style.bold = false
		elif code == 4:
			style.underline = true
		elif code == 24:
			style.underline = false
		elif code == 7:
			style.reverse = true
		elif code == 27:
			style.reverse = false
		elif code >= 30 and code <= 37:
			style.fg = TerminalPalette.color(code - 30)
		elif code == 39:
			style.fg = TerminalPalette.default_fg()
		elif code >= 40 and code <= 47:
			style.bg = TerminalPalette.color(code - 40)
		elif code == 49:
			style.bg = TerminalPalette.default_bg()
		elif code >= 90 and code <= 97:
			style.fg = TerminalPalette.color(code - 90 + 8)
		elif code >= 100 and code <= 107:
			style.bg = TerminalPalette.color(code - 100 + 8)
		elif code == 38 or code == 48:
			index = _apply_extended_color(params, index, code == 38)
		index += 1


## 返回最后一个被消费的参数下标
func _apply_extended_color(params: PackedStringArray, index: int, foreground: bool) -> int:
	if index + 1 >= params.size():
		return index
	var mode := int(params[index + 1]) if not params[index + 1].is_empty() else -1
	if mode == 5:
		if index + 2 >= params.size():
			return index
		var palette_index := int(params[index + 2])
		var palette_color := TerminalPalette.color_256(palette_index)
		if foreground:
			style.fg = palette_color
		else:
			style.bg = palette_color
		return index + 2
	if mode == 2:
		if index + 4 >= params.size():
			return index
		var red := clampi(int(params[index + 2]), 0, 255)
		var green := clampi(int(params[index + 3]), 0, 255)
		var blue := clampi(int(params[index + 4]), 0, 255)
		var true_color := Color8(red, green, blue)
		if foreground:
			style.fg = true_color
		else:
			style.bg = true_color
		return index + 4
	return index
