## 单位表现：血条、阵营染色、头顶名字、伤害/治疗飘字。
##
## 只订阅 ASC 信号做视觉反馈，不写中文日志、不参与战斗判定；
## 叙事由 CombatNarrator 统一处理。单位销毁时随单位一起释放。
class_name UnitPresenter extends Node

var unit: BattleUnit


func _init(p_unit: BattleUnit) -> void:
	unit = p_unit


func _ready() -> void:
	_bind_health_bar()
	_apply_appearance()
	if unit.asc == null:
		return
	unit.asc.effect_received.connect(_on_effect_received)
	unit.asc.periodic_effect_ticked.connect(_on_periodic_effect_ticked)


## 血条颜色：敌红我绿
func _bar_color() -> Color:
	return GameColors.to_color(GameColors.HEALTH_FILL) if unit.team == BattleUnit.Team.PLAYER else GameColors.to_color(GameColors.HEALTH_FILL_ENEMY)


func _bind_health_bar() -> void:
	var health_bar := unit.get_node_or_null("HealthBar") as UnitHealthBar
	if health_bar == null:
		return
	health_bar.bind(unit.health_attr, unit.max_health_attr, unit.asc, _bar_color())


## 外观：场景只负责贴图，阵营染色统一走 GameColors
func _apply_appearance() -> void:
	var body := unit.get_node_or_null("Body") as Sprite2D
	if body != null:
		body.modulate = GameColors.to_color(
			GameColors.PLAYER_MODULATE if unit.team == BattleUnit.Team.PLAYER else GameColors.ENEMY_MODULATE
		)

	# 头顶名字：场景里有 Name 标签就跟着 unit_name 走
	var name_label := unit.get_node_or_null("Name") as Label
	if name_label != null:
		name_label.text = unit.unit_name
		name_label.add_theme_color_override("font_color", GameColors.to_color(GameColors.TEXT_PRIMARY))
		name_label.add_theme_color_override("font_outline_color", GameColors.to_color(GameColors.TEXT_OUTLINE))


## 即时伤害/治疗/护盾吸收飘字；周期效果施加时的预览不弹
func _on_effect_received(_source_asc: AbilitySystemComponent, spec: GameplayEffectSpec) -> void:
	if spec == null or spec.effect_def is PassiveEffect:
		return
	if spec.period > 0.0:
		return
	var health_delta := float(spec.calculated_deltas.get("health", 0.0))
	var shield_delta := float(spec.calculated_deltas.get("shield", 0.0))
	if is_zero_approx(health_delta) and shield_delta >= 0.0:
		return
	var critical := spec.has_tag(GameplayTags.Event_Combat_Critical)
	if shield_delta < 0.0:
		_pop_number(-shield_delta, false, false, false, true)
	if health_delta < 0.0:
		_pop_number(-health_delta, false, critical)
	elif health_delta > 0.0:
		_pop_number(health_delta, true, critical)


## 周期效果每跳的伤害/治疗/护盾吸收飘字
func _on_periodic_effect_ticked(_active_effect: ActiveGameplayEffect, spec: GameplayEffectSpec) -> void:
	if spec == null:
		return
	var tick := PeriodicStatusTickExecution.find(spec.effect_def)
	if tick == null:
		return
	var health_delta := float(spec.calculated_deltas.get("health", 0.0))
	var shield_delta := float(spec.calculated_deltas.get("shield", 0.0))
	if shield_delta < 0.0:
		_pop_number(-shield_delta, false, false, false, true)
	if health_delta < 0.0:
		_pop_periodic_number(tick, -health_delta)
	elif health_delta > 0.0:
		_pop_periodic_number(tick, health_delta)


func _pop_periodic_number(tick: PeriodicStatusTickExecution, amount: float) -> void:
	match tick.popup_style():
		PeriodicStatusTickExecution.PopupStyle.BURN:
			_pop_number(amount, false, false, true)
		PeriodicStatusTickExecution.PopupStyle.POISON:
			_pop_number(amount, false, false, false, false, true)
		PeriodicStatusTickExecution.PopupStyle.REGEN:
			_pop_number(amount, true, false, false, false, false, true)
		_:
			_pop_number(amount, tick.is_heal())


## 头顶跳一个数字；致命伤害挂到战场层，避免随单位一起释放
func _pop_number(
	amount: float,
	heal: bool,
	critical: bool = false,
	burn: bool = false,
	shield: bool = false,
	poison: bool = false,
	regen: bool = false
) -> void:
	var number := DamageNumber.new()
	var number_parent: Node2D = unit
	var anchor := Vector2.ZERO
	var parent := unit.get_parent()
	if not heal and not shield and unit.is_dying() and parent is Node2D:
		number_parent = parent as Node2D
		anchor = number_parent.to_local(unit.global_position)
	number_parent.add_child(number)  # 先入树，里面建补间要用
	number.setup(amount, heal, critical, burn, shield, poison, regen, anchor)
