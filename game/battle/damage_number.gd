class_name DamageNumber extends Label

const RISE : float = 28.0
const LIFETIME : float = 0.7
const FONT_SIZE : int = 16
const CRIT_FONT_SIZE : int = 20
static var COLOR_DAMAGE := GameColors.to_color(GameColors.DAMAGE)
static var COLOR_HEAL := GameColors.to_color(GameColors.HEAL)
static var COLOR_CRIT := GameColors.to_color(GameColors.CRIT)
static var COLOR_BURN := GameColors.to_color(GameColors.BURN)
static var COLOR_SHIELD := GameColors.to_color(GameColors.SHIELD)
static var COLOR_POISON := GameColors.to_color(GameColors.POISON)
static var COLOR_REGEN := GameColors.to_color(GameColors.REGEN)


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
