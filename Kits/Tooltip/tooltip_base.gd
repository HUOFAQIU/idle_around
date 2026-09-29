class_name TooltipBase
extends Control

## 提示框的公共部分：挂在窗口上、跟着鼠标走、贴边翻向之后还要夹回窗口里。
##
## 挂窗口上就意味着超出窗口的部分会被**裁掉**，所以「翻到另一侧」还不够，
## 最后必须再夹一次 —— 这段逻辑就这一处，两个提示框都从这儿走。
## 画什么归子类：装备那一个画整片魂灵区，魂灵那一个现在只画名字。

## 提示框跟鼠标隔开多少像素
const GAP : float = 18.0

## 底色 / 边框（跟仓库那套配色一致）。
## 得自己定：引擎默认主题给 PanelContainer 的是一块**浅色**面板，压在魂灵那种浅色美术上根本看不出边界
## （实测：提示框 255,248,225 压在魂灵 token 的纯白 255,255,255 上，就是「没弹框」）
const COLOR_BG := Color(0.10, 0.11, 0.14, 0.97)
const COLOR_BORDER := Color(0.45, 0.48, 0.58)
## 内容和边框之间留多少
const PADDING : int = 8

@onready var _bg : PanelContainer = $BG
@onready var _name_label : Label = $BG/VBoxContainer/NameLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_style_panel()


# 面板样式在代码里给，不写在各自的 .tscn 里：两个提示框共用这一处，以后加第三个也不会漏
func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(PADDING)
	_bg.add_theme_stylebox_override("panel", style)


## 收起来
func hide_tip() -> void:
	visible = false


## 摆位：默认在鼠标右下方，右边放不下就翻到左边，翻过头再夹回窗口里。
## 内容没变、只是鼠标动了的时候（每帧）也调这个，别重新 show_for
func place_near(anchor: Vector2, bounds: Vector2) -> void:
	# 尺寸得问 BG（PanelContainer）：根节点是个光杆 Control，它自己的最小尺寸恒为 0，
	# 子节点撑不开它。BG 是容器，它算出来的才是「内容要多大」
	var tip := _bg.get_combined_minimum_size()
	size = tip

	var pos := anchor + Vector2(GAP, GAP)
	if pos.x + tip.x > bounds.x:
		pos.x = anchor.x - GAP - tip.x
	if pos.y + tip.y > bounds.y:
		pos.y = anchor.y - GAP - tip.y

	pos.x = clampf(pos.x, 0.0, maxf(0.0, bounds.x - tip.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, bounds.y - tip.y))
	position = pos
