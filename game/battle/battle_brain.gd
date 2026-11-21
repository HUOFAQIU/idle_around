## @meta_addon: GodotGAS
## @meta_license: MIT

class_name BattleBrain extends Node

const FROZEN_TAG : StringName = ChargedAbility.FROZEN_TAG
const MAX_PENDING_ACTIVATIONS_PER_FRAME : int = 64

var unit: BattleUnit
var abilities: Array[GameplayAbility] = []

var _pending_activations: Array[ChargedAbility] = []
var _pending_traces: Dictionary = {}
var _flushing : bool = false


func add_ability(ability: GameplayAbility) -> void:
	ability.owner_asc = unit.asc
	unit.asc.grant_ability(ability)
	abilities.append(ability)


func begin_charge() -> void:
	_pending_activations.clear()
	_pending_traces.clear()
	for ability in abilities:
		var charged := ability as ChargedAbility
		if charged:
			charged.reset_charge()
			charged.reset_activation_lock()


func request_activation(ability: ChargedAbility, trace: CombatTrace = null) -> void:
	if ability == null or not abilities.has(ability):
		return
	if unit == null or not is_instance_valid(unit) or unit.is_dead:
		return
	if unit.battle == null or not is_instance_valid(unit.battle) or not unit.battle.is_running:
		return
	if not ability.is_ready() or ability.is_frozen() or ability.is_active:
		return
	if not ability.can_activate_now():
		return
	if _pending_activations.has(ability):
		return
	_pending_activations.append(ability)
	for runtime in unit.loadout:
		if runtime != null and runtime.ability == ability:
			unit.battle.events.emit_event(BattleEvent.CATEGORY_SOUL, "pending", {
				"actor_unit": unit,
				"soul": runtime.display_name(),
				"ability": ability.ability_name,
				"trace": trace,
			}, BattleEvent.IMPORTANCE_DETAIL)
			break
	if trace != null:
		_pending_traces[ability.get_instance_id()] = trace


func flush_pending_activations() -> void:
	if _pending_activations.is_empty() or _flushing:
		return
	if unit == null or not is_instance_valid(unit) or unit.is_dead:
		_pending_activations.clear()
		_pending_traces.clear()
		return
	if unit.battle == null or not is_instance_valid(unit.battle) or not unit.battle.is_running:
		_pending_activations.clear()
		_pending_traces.clear()
		return
	if unit.team == BattleUnit.Team.ENEMY and unit.battle.player != null:
		if not unit.is_in_attack_range(unit.battle.player):
			_pending_activations.clear()
			_pending_traces.clear()
			return
	if unit.asc == null or unit.asc.has_tag(FROZEN_TAG):
		_pending_activations.clear()
		_pending_traces.clear()
		return

	_flushing = true
	var guard := 0
	while not _pending_activations.is_empty():
		guard += 1
		if guard > MAX_PENDING_ACTIVATIONS_PER_FRAME:
			push_warning("BattleBrain：单帧待释放队列超过上限，丢弃剩余请求")
			_pending_activations.clear()
			_pending_traces.clear()
			break
		var ability: ChargedAbility = _pending_activations.pop_front()
		var trace: CombatTrace = _pending_traces.get(ability.get_instance_id()) if ability != null else null
		if ability != null:
			_pending_traces.erase(ability.get_instance_id())
		if ability == null or not is_instance_valid(ability):
			continue
		if ability.is_frozen() or ability.is_active or not ability.is_ready():
			continue
		if not ability.can_activate_now():
			continue
		if not unit.asc.can_activate_ability(ability):
			unit.battle.events.emit_event(BattleEvent.CATEGORY_SOUL, "flush_skip", {
				"actor_unit": unit,
				"ability": ability.ability_name,
				"detail": "ASC 门卫拒绝",
				"trace": trace,
			}, BattleEvent.IMPORTANCE_DETAIL)
			continue
		@warning_ignore("missing_await")
		ability.try_activate(trace)
	_flushing = false


func _physics_process(_delta: float) -> void:
	if unit == null or unit.battle == null or unit.battle.clock == null:
		return
	if unit.battle.clock.manual:
		return
	advance()


func advance() -> void:
	if unit == null or unit.is_dead or unit.battle == null or not unit.battle.is_running:
		return
	if unit.team == BattleUnit.Team.ENEMY and unit.battle.player != null:
		if not unit.is_in_attack_range(unit.battle.player):
			return

	var frozen := unit.asc.has_tag(FROZEN_TAG)
	var base_units := int(round(
		float(ChargedAbility.UNITS_PER_SECOND) * unit.battle.tick_seconds()
	))

	for ability in abilities:
		var charged := ability as ChargedAbility
		if charged == null:
			continue
		charged.advance_activation_lock(base_units)
		if not frozen and not charged.is_frozen():
			charged.advance_charge(base_units)
		charged.advance_status(base_units)

	if frozen:
		return

	for ability in abilities:
		if unit.is_dead or unit.battle == null or not unit.battle.is_running:
			return
		var charged := ability as ChargedAbility
		if charged != null and (
			charged.is_frozen()
			or not charged.is_ready()
			or not charged.can_activate_now()
		):
			continue
		if unit.asc.can_activate_ability(ability):
			@warning_ignore("missing_await")
			ability.try_activate()

	flush_pending_activations()
