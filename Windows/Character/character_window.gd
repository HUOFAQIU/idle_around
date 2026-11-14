class_name CharacterWindow
extends BaseWindow

## 角色静态档案：名字和最大生命与战斗共用
const PLAYER_PROFILE := preload("res://game/content/Player/player_profile.tres")
## 角色档案标题字号；正文沿用 TooltipWindow.BODY_FONT_SIZE
const PROFILE_TITLE_FONT_SIZE: int = 24

@onready var info_label: RichTextLabel = $VBox/InfoLabel


func _ready() -> void:
	super()

	title = "人物窗口"
	# 打开位置写在场景里（character_window.tscn 的 open_position），
	# 在这儿设 position 没用：open_window() 会按 open_position 重设位置
	_render_profile()


## 角色名 + 生命值，正文沿用 Tooltip 的正文字号与分隔线，标题字号在本文件定义；
## 窗口底色是默认灰，分隔线用亮一档的 PANEL_SEPARATOR，tooltip 的暗色在这里几乎看不见
func _render_profile() -> void:
	var max_health := int(floorf(PLAYER_PROFILE.max_health))
	info_label.text = "\n".join(PackedStringArray([
		"[font_size=%d]%s[/font_size]" % [PROFILE_TITLE_FONT_SIZE, PLAYER_PROFILE.display_name],
		"",
		"[font_size=%d]生命值：%d / %d[/font_size]" % [
			TooltipWindow.BODY_FONT_SIZE, max_health, max_health,
		],
		"[color=%s]%s[/color]" % [GameColors.PANEL_SEPARATOR, TooltipText.SEPARATOR],
	]))
