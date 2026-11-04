extends Control
## 冻结徽章：面板颜色从 GameColors 取，场景只留边框宽度和圆角。

func _ready() -> void:
	var panel := get_node_or_null("Panel") as Panel
	if panel == null:
		return
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = GameColors.to_color(GameColors.FREEZE_BADGE_BG)
	style.border_color = GameColors.to_color(GameColors.FREEZE_BADGE_BORDER)
	panel.add_theme_stylebox_override("panel", style)
