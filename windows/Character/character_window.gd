class_name CharacterWindow
extends BaseWindow

const PROFILE_TITLE_FONT_SIZE: int = 24

@onready var info_label: RichTextLabel = $VBox/InfoLabel


func _ready() -> void:
	super()

	title = "人物窗口"
	GameFlow.active_character_changed.connect(_on_active_character_changed)
	_render_profile()


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
