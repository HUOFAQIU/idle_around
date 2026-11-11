## 单位头顶跳一下的数字：伤害红、治疗/再生绿、灼烧橙、护盾黄、剧毒绿，边升边淡出。
##
## 普通情况挂在单位节点下，单位走它跟着走；
## 致命一击改挂战场层，避免单位释放时数字一起消失。

class_name DamageNumber extends Label

## 往上飘多远
const RISE : float = 28.0
## 飘多久
const LIFETIME : float = 0.7
const FONT_SIZE : int = 16
const CRIT_FONT_SIZE : int = 20
## 颜色统一从 GameColors 取，和 tooltip / 战斗日志 / 状态条保持一致
static var COLOR_DAMAGE := GameColors.to_color(GameColors.DAMAGE)
static var COLOR_HEAL := GameColors.to_color(GameColors.HEAL)
static var COLOR_CRIT := GameColors.to_color(GameColors.CRIT)
static var COLOR_BURN := GameColors.to_color(GameColors.BURN)
static var COLOR_SHIELD := GameColors.to_color(GameColors.SHIELD)
static var COLOR_POISON := GameColors.to_color(GameColors.POISON)
static var COLOR_REGEN := GameColors.to_color(GameColors.REGEN)


## amount 传正数；heal = true 表示这是回血，burn = true 表示灼烧，shield = true 表示护盾吸收，poison = true 表示剧毒，regen = true 表示生命再生。
## 注意：要先 add_child 再调这个 —— 建补间需要节点已经在树里
func setup(
	amount: float,
	heal: bool,
	critical: bool = false,
	burn: bool = false,
	shield: bool = false,
	poison: bool = false,
	regen: bool = false,
	anchor: Vector2 = Vector2.ZERO
) -> void:
	var text_value := ("+%d" % floori(amount)) if heal else ("-%d" % floori(amount))
	if critical:
		text_value += "!"
	text = text_value
	# Label 的坐标是左上角，所以要自己往左上挪半个身位，让它落在单位正上方
	size = Vector2(48.0, 20.0)
	position = anchor + Vector2(-24.0, -46.0)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", CRIT_FONT_SIZE if critical else FONT_SIZE)
	var color := COLOR_SHIELD if shield else (COLOR_POISON if poison else (COLOR_REGEN if regen else (COLOR_BURN if burn else (COLOR_CRIT if critical else (COLOR_HEAL if heal else COLOR_DAMAGE)))))
	add_theme_color_override("font_color", color)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE, LIFETIME)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME)
	tween.chain().tween_callback(queue_free)
