class_name CharacterWindow
extends BaseWindow

## 角色静态档案：名字和最大生命与战斗共用
const PLAYER_PROFILE := preload("res://game/content/Player/player_profile.tres")

@onready var info_label: RichTextLabel = $VBox/InfoLabel


func _ready() -> void:
	super()

	title = "人物窗口"
	# 打开位置写在场景里（character_window.tscn 的 open_position），
	# 在这儿设 position 没用：control.gd 打开时会 popup，位置会被覆盖
	_render_profile()


## 角色名 + 生命值，排版沿用 Tooltip 的标题/正文字号与分隔线
func _render_profile() -> void:
	var max_health := int(floorf(PLAYER_PROFILE.max_health))
	info_label.text = "\n".join(PackedStringArray([
		"[font_size=%d]%s[/font_size]" % [TooltipWindow.TITLE_FONT_SIZE, PLAYER_PROFILE.display_name],
		"",
		"[font_size=%d]生命值：%d / %d[/font_size]" % [
			TooltipWindow.BODY_FONT_SIZE, max_health, max_health,
		],
		"[color=%s]%s[/color]" % [TooltipText.SEPARATOR_COLOR, TooltipText.SEPARATOR],
	]))
