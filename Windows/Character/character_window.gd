class_name CharacterWindow
extends BaseWindow

## 角色档案标题字号；正文沿用 TooltipWindow.BODY_FONT_SIZE
const PROFILE_TITLE_FONT_SIZE: int = 24

@onready var info_label: RichTextLabel = $VBox/InfoLabel


func _ready() -> void:
	super()

	title = "人物窗口"
	# 打开位置写在场景里（character_window.tscn 的 open_position），
	# 在这儿设 position 没用：open_window() 会按 open_position 重设位置
	GameFlow.active_character_changed.connect(_on_active_character_changed)
	_render_profile()


## 角色名 + 生命值，正文沿用 Tooltip 的正文字号与分隔线，标题字号在本文件定义；
## 窗口底色是默认灰，分隔线用亮一档的 PANEL_SEPARATOR，tooltip 的暗色在这里几乎看不见
func _render_profile() -> void:
	var profile := GameFlow.get_player_profile()
	if profile == null:
		info_label.text = "未选择角色"
		return
	var max_health := int(floorf(profile.max_health))
	info_label.text = "\n".join(PackedStringArray([
		"[font_size=%d]%s[/font_size]" % [PROFILE_TITLE_FONT_SIZE, profile.display_name],
		"",
		"[font_size=%d]生命值：%d / %d[/font_size]" % [
			TooltipWindow.BODY_FONT_SIZE, max_health, max_health,
		],
		"[color=%s]%s[/color]" % [GameColors.PANEL_SEPARATOR, TooltipText.SEPARATOR],
	]))


func _on_active_character_changed(_character: CharacterDefinition) -> void:
	_render_profile()
