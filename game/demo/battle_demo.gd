## 自动战斗文字游戏 · 演示入口
##
## 玩法：双方单位挂着技能自动倒计时，冷却一到就随机选目标发动，全程文字播报。
##
## 运行：按 F5（本场景已设为项目主场景），点击【开始战斗】按钮开战。
## 重开：按 R。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

extends Node

var battle: BattleManager
var log_label: RichTextLabel
var start_button: Button


func _ready() -> void:
	_build_ui()

	battle = BattleManager.new()
	battle.name = "BattleManager"
	add_child(battle)
	battle.setup()
	battle.log_sink = _append_log_line

	# —— 我方 ——
	_make_unit("勇者", BattleUnit.Team.PLAYER, 130.0, 20.0, SkillLibrary.build_hero_skills())
	# —— 敌方 ——
	_make_unit("哥布林A", BattleUnit.Team.ENEMY, 75.0, 9.0, SkillLibrary.build_goblin_skills())
	_make_unit("哥布林B", BattleUnit.Team.ENEMY, 75.0, 9.0, SkillLibrary.build_goblin_skills())

	_print_skill_intro()
	battle.log_line("准备就绪：点击【开始战斗】开战。（按 R 重开）", "yellow")


func _make_unit(unit_name: String, team: BattleUnit.Team, hp: float, atk: float, skills: Array[SkillDefinition]) -> void:
	var unit := BattleUnit.new()
	unit.name = unit_name
	add_child(unit)
	unit.setup(unit_name, team, hp, atk, skills, battle)
	battle.add_unit(unit)


## 开场把每个技能的"描述 ↔ 数据"打印出来，方便对照案例
func _print_skill_intro() -> void:
	battle.log_line("—— 技能一览（技能描述 → 数据规则）——", "yellow")
	for unit in battle.units:
		for ability in unit.brain.abilities:
			var skill: SkillDefinition = (ability as AutoCastAbility).skill
			battle.log_line("%s【%s】：%s" % [unit.unit_name, skill.display_name, skill.description], "gray")


#region 文字 UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UILayer"
	add_child(layer)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# 顶部操作栏：手动开战
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(top_bar)

	start_button = Button.new()
	start_button.text = "开始战斗"
	start_button.pressed.connect(_on_start_pressed)
	top_bar.add_child(start_button)

	var hint := Label.new()
	hint.text = "（按 R 重开新一局）"
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(hint)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 18)
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(log_label)


## 点击【开始战斗】：禁用按钮并正式开战（冷却倒计时从这个时刻开始）
func _on_start_pressed() -> void:
	start_button.disabled = true
	start_button.text = "战斗进行中…"
	battle.start_battle()


func _append_log_line(line: String, color: String) -> void:
	log_label.append_text("[color=%s]%s[/color]\n" % [color, line])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()
#endregion
