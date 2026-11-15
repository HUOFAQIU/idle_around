## 战斗叙事：把模拟层的信号与总线事件翻译成中文日志。
##
## 模拟层（BattleUnit / 技能 / 触发器 / 掉落）只发信号和结构化事件，
## 这里统一拼文本，再通过 BattleManager.log_line() 发回总线；
## InfoWindow 与控制台只需要订阅 log/line，不关心文案从哪来。
class_name CombatNarrator extends RefCounted

var _battle: BattleManager


func _init(battle: BattleManager) -> void:
	_battle = battle
	if _battle == null:
		return
	_battle.events.unit_asc_ready.connect(_on_unit_asc_ready)
	_battle.events.soul_runtime_created.connect(_on_soul_runtime_created)
	_battle.events.emitted.connect(_on_event)


#region 订阅
func _on_unit_asc_ready(unit: BattleUnit) -> void:
	if unit == null or unit.asc == null:
		return
	unit.asc.effect_received.connect(_on_effect_received.bind(unit))
	unit.asc.periodic_effect_ticked.connect(_on_periodic_effect_ticked.bind(unit))
	unit.asc.active_effect_added.connect(_on_active_effect_added.bind(unit))
	unit.asc.active_effect_removed.connect(_on_active_effect_removed.bind(unit))
	unit.died.connect(_on_unit_died)


func _on_soul_runtime_created(
	_unit: BattleUnit,
	ability: ChargedAbility,
	_runtime: SoulRuntime
) -> void:
	if ability == null:
		return
	ability.status_applied.connect(_on_status_applied.bind(ability))
	ability.status_expired.connect(_on_status_expired.bind(ability))
	ability.charge_added.connect(_on_charge_added.bind(ability))


func _on_event(event: BattleEvent) -> void:
	match event.category:
		BattleEvent.CATEGORY_CAST:
			_on_cast_event(event)
		BattleEvent.CATEGORY_TRIGGER:
			if event.type == "fired":
				_on_trigger_fired(event)
		BattleEvent.CATEGORY_BATTLE:
			if event.type == "drop":
				_on_drop(event)
#endregion


#region 总线事件
func _on_cast_event(event: BattleEvent) -> void:
	var caster: BattleUnit = event.fields.get("actor_unit", null)
	var ability := String(event.fields.get("ability", ""))
	match event.type:
		"targets":
			_log("%s 施放【%s】→ %s" % [
				_unit_label(caster),
				ability,
				String(event.fields.get("targets", "")),
			], "#6fb7ff")
		"soul_targets":
			var names: Array[String] = []
			for target_name in event.fields.get("targets", []):
				names.append(String(target_name))
			_log("%s 施放【%s】→ %s" % [
				_unit_label(caster),
				ability,
				"、".join(names),
			], "#6fb7ff")
		"empty":
			# 纯单位技能只有玩家施法才播报空放，避免敌人刷屏
			if bool(event.fields.get("narrate", false)):
				_log("%s 的【%s】空放了（%s）" % [
					_unit_label(caster),
					ability,
					String(event.fields.get("detail", "没有目标")),
				], "gray")
		"projectiles_finished":
			var missed := int(event.fields.get("missed", 0))
			if missed > 0:
				_log("%s 的【%s】有 %d 支空了" % [_unit_label(caster), ability, missed], "gray")


func _on_trigger_fired(event: BattleEvent) -> void:
	var soul := String(event.fields.get("soul", ""))
	var label := String(event.fields.get("trigger", ""))
	var count := int(event.fields.get("targets", 0))
	var trigger_name := String(event.fields.get("trigger_name", ""))
	if count > 1:
		_log("%s 触发【%s】：%d 个目标" % [soul, label, count], "#8cd9ff")
	elif not trigger_name.is_empty():
		_log("%s 触发【%s】" % [soul, trigger_name], "#8cd9ff")


func _on_drop(event: BattleEvent) -> void:
	var unit: BattleUnit = event.fields.get("actor_unit", null)
	var item := String(event.fields.get("item", ""))
	if bool(event.fields.get("success", false)):
		_log("%s 掉落了【%s】" % [_unit_label(unit), item], "#ffd866")
	else:
		_log("仓库已满，【%s】掉落丢失" % item, "yellow")
#endregion


#region ASC 信号
## 效果生命周期：只有对方真正收到效果时才写伤害/治疗日志。
## 击杀那一下也要显示，所以这里不因为 is_dead 直接返回。
func _on_effect_received(
	_source_asc: AbilitySystemComponent,
	spec: GameplayEffectSpec,
	unit: BattleUnit
) -> void:
	if spec == null or spec.effect_def is PassiveEffect:
		return
	# 周期效果在施加时只做了预览计算，并没有真正扣血；
	# 伤害要等每一跳通过 periodic_effect_ticked 单独记账。
	if spec.period > 0.0:
		return
	var health_delta := float(spec.calculated_deltas.get("health", 0.0))
	var shield_delta := float(spec.calculated_deltas.get("shield", 0.0))
	if is_zero_approx(health_delta) and shield_delta >= 0.0:
		return

	var current := unit.health_attr.current_value
	var old_value := current - health_delta
	var source_name := CombatNames.source_name(spec)
	var effect_name := CombatNames.effect_name(spec)
	var critical := spec.has_tag(GameplayTags.Event_Combat_Critical)
	var crit_suffix := "（暴击）" if critical else ""

	if shield_delta < 0.0:
		_log_shield_absorb(unit, -shield_delta, source_name, effect_name)
	if health_delta < 0.0:
		_log("%s 受到【%s】（来自 %s）%.0f 点伤害%s，HP %.0f → %.0f"
			% [unit.unit_name, effect_name, source_name, -health_delta, crit_suffix, old_value, current], GameColors.DAMAGE)
	elif health_delta > 0.0:
		_log("%s 回复 %.0f 点生命%s，HP %.0f → %.0f"
			% [unit.unit_name, health_delta, crit_suffix, old_value, current], GameColors.HEAL)


## 周期效果每跳：护盾吸收、伤害/生命再生叙事
func _on_periodic_effect_ticked(
	_active_effect: ActiveGameplayEffect,
	spec: GameplayEffectSpec,
	unit: BattleUnit
) -> void:
	if spec == null:
		return
	var tick := PeriodicStatusTickExecution.find(spec.effect_def)
	if tick == null:
		return
	var health_delta := float(spec.calculated_deltas.get("health", 0.0))
	var shield_delta := float(spec.calculated_deltas.get("shield", 0.0))
	if shield_delta < 0.0:
		_log_shield_absorb(unit, -shield_delta, CombatNames.source_name(spec), CombatNames.effect_name(spec))
	if health_delta < 0.0:
		_log_periodic_damage(unit, tick, -health_delta, spec)
	elif health_delta > 0.0:
		_log_periodic_heal(unit, tick, health_delta, spec)


func _log_shield_absorb(unit: BattleUnit, amount: float, source_name: String, effect_name: String) -> void:
	if amount <= 0.0:
		return
	_log("%s 的护盾吸收 %.0f 点【%s】伤害（来自 %s）"
		% [unit.unit_name, amount, effect_name, source_name], GameColors.SHIELD)


func _log_periodic_damage(
	unit: BattleUnit,
	tick: PeriodicStatusTickExecution,
	damage: float,
	spec: GameplayEffectSpec
) -> void:
	if damage <= 0.0:
		return
	var old_value := unit.health_attr.current_value + damage
	_log("%s 受到【%s】（来自 %s）%.0f 点伤害，HP %.0f → %.0f" % [
		unit.unit_name,
		CombatNames.effect_name(spec),
		CombatNames.source_name(spec),
		damage,
		old_value,
		unit.health_attr.current_value,
	], tick.log_color())


func _log_periodic_heal(
	unit: BattleUnit,
	tick: PeriodicStatusTickExecution,
	amount: float,
	spec: GameplayEffectSpec
) -> void:
	if amount <= 0.0:
		return
	var old_value := unit.health_attr.current_value - amount
	_log("%s 受到【%s】（来自 %s）影响，恢复 %.0f 点生命，HP %.0f → %.0f" % [
		unit.unit_name,
		CombatNames.effect_name(spec),
		CombatNames.source_name(spec),
		amount,
		old_value,
		unit.health_attr.current_value,
	], tick.log_color())


func _on_active_effect_added(active_effect: ActiveGameplayEffect, unit: BattleUnit) -> void:
	var def := active_effect.get_effect_def()
	if unit.is_dead or def == null or def.policy == GameplayEffect.DurationPolicy.INSTANT or def is PassiveEffect:
		return
	if _has_suppressed_state_log(active_effect):
		return
	var duration_text := "持续" if def.policy == GameplayEffect.DurationPolicy.INFINITE else "%.1f 秒" % active_effect.time_remaining
	var effect_name := CombatNames.effect_name(active_effect.spec)
	_log("%s 获得状态【%s】（%s）" % [unit.unit_name, effect_name, duration_text], GameColors.status_color(effect_name))


func _on_active_effect_removed(active_effect: ActiveGameplayEffect, unit: BattleUnit) -> void:
	var def := active_effect.get_effect_def()
	if unit.is_dead or def == null or def.policy == GameplayEffect.DurationPolicy.INSTANT or def is PassiveEffect:
		return
	if _has_suppressed_state_log(active_effect):
		return
	_log("%s 的状态【%s】结束" % [unit.unit_name, CombatNames.effect_name(active_effect.spec)], "gray")


## 批量触发施加的效果不逐目标写状态日志，避免全体冻结时刷屏
func _has_suppressed_state_log(active_effect: ActiveGameplayEffect) -> bool:
	return (
		active_effect != null
		and active_effect.spec != null
		and active_effect.spec.has_tag(BattleUnit.SUPPRESS_STATE_LOG_TAG)
	)


func _on_unit_died(unit: BattleUnit) -> void:
	_log("%s 倒下了！" % unit.unit_name, "#ffcc44")
#endregion


#region 魂灵能力信号
func _on_status_applied(
	status_name: String,
	seconds: float,
	_trace: CombatTrace,
	ability: ChargedAbility
) -> void:
	_log("%s 获得状态【%s】（%.1f 秒）" % [ability.ability_name, status_name, seconds], GameColors.status_color(status_name))


func _on_status_expired(status_name: String, ability: ChargedAbility) -> void:
	_log("%s 的状态【%s】结束" % [ability.ability_name, status_name], "gray")


func _on_charge_added(
	seconds: float,
	_old_seconds: float,
	_new_seconds: float,
	_trace: CombatTrace,
	ability: ChargedAbility
) -> void:
	_log("%s 获得充能（%.1f 秒）" % [ability.ability_name, seconds], GameColors.CHARGE)
#endregion


func _log(text: String, color: String = "white") -> void:
	if _battle != null:
		_battle.log_line(text, color)


func _unit_label(unit: BattleUnit) -> String:
	return unit.unit_name if unit != null and is_instance_valid(unit) else "???"
