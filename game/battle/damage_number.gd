## 单位头顶跳一下的数字：掉血红、回血绿、灼烧橙、护盾黄、剧毒墨绿、再生亮绿，边升边淡出。
##
## 挂在单位节点底下，所以单位走它跟着走、单位没了它跟着没，
## 不需要外面拿个容器管它们。

class_name DamageNumber extends Label

## 往上飘多远
const RISE : float = 28.0
## 飘多久
const LIFETIME : float = 0.7
const FONT_SIZE : int = 16
const CRIT_FONT_SIZE : int = 20
const COLOR_DAMAGE := Color(1.0, 0.45, 0.4)
const COLOR_HEAL := Color(0.5, 0.95, 0.5)
const COLOR_CRIT := Color(1.0, 0.68, 0.25)
## 灼烧用高饱和橙色，和普通伤害/暴击区分开
const COLOR_BURN := Color(1.0, 0.40, 0.0)
## 护盾吸收用高饱和黄色
const COLOR_SHIELD := Color(1.0, 0.85, 0.10)
## 剧毒用墨绿色
const COLOR_POISON := Color(0.18, 0.42, 0.25)
## 生命再生用亮绿色
const COLOR_REGEN := Color(0.25, 1.0, 0.40)


## amount 传正数；heal = true 表示这是回血，burn = true 表示灼烧，shield = true 表示护盾吸收，poison = true 表示剧毒，regen = true 表示生命再生。
## 注意：要先 add_child 再调这个 —— 建补间需要节点已经在树里
func setup(
	amount: float,
	heal: bool,
	critical: bool = false,
	burn: bool = false,
	shield: bool = false,
	poison: bool = false,
	regen: bool = false
) -> void:
	var text_value := ("+%d" % roundi(amount)) if heal else ("-%d" % roundi(amount))
	if critical:
		text_value += "!"
	text = text_value
	# Label 的坐标是左上角，所以要自己往左上挪半个身位，让它落在单位正上方
	size = Vector2(48.0, 20.0)
	position = Vector2(-24.0, -46.0)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", CRIT_FONT_SIZE if critical else FONT_SIZE)
	var color := COLOR_SHIELD if shield else (COLOR_POISON if poison else (COLOR_REGEN if regen else (COLOR_BURN if burn else (COLOR_CRIT if critical else (COLOR_HEAL if heal else COLOR_DAMAGE)))))
	add_theme_color_override("font_color", color)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE, LIFETIME)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME)
	tween.chain().tween_callback(queue_free)
