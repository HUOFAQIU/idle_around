@tool
extends EditorPlugin
## 编辑器「色板」主屏幕：在 2D / 3D / Script 旁增加一个整页色板。
##
## 色值仍以 GameColors / TerminalPalette 为准，本插件只负责展示。

const COLOR_SHEET_SCRIPT : GDScript = preload("res://addons/color_catalog/color_sheet.gd")

var _sheet : Control


func _enter_tree() -> void:
	_sheet = COLOR_SHEET_SCRIPT.new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(_sheet)
	# 启动时先隐藏，避免抢占主视口；切到「色板」页时编辑器会自动调用 _make_visible。
	_make_visible(false)


func _exit_tree() -> void:
	if _sheet == null:
		return
	_sheet.queue_free()
	_sheet = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _sheet != null:
		_sheet.visible = visible


func _get_plugin_name() -> String:
	return "色板"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("ColorPicker", "EditorIcons")
