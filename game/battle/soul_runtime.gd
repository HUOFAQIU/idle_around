class_name SoulRuntime extends RefCounted

signal changed

static var _next_id: int = 1

var id: int = 0
var soul: SoulData
var slot: SoulSlot
var ability: ChargedAbility
var triggers: Array[SoulTriggerAbility] = []
var owner_unit: BattleUnit

var scanline_progress: float = 0.0
var haste_seconds: float = 0.0
var slow_seconds: float = 0.0
var freeze_seconds: float = 0.0
var vessel_damage_bonus: float = 0.0

var counters: Dictionary = {
	"activations": 0,
	"releases": 0,
	"empty_casts": 0,
	"triggers_fired": 0,
	"charges_received": 0.0,
	"charges_given": 0.0,
	"freezes_applied": 0,
	"last_activation_t": -1.0,
	"last_trigger_t": -1.0,
}


func _init(
	p_soul: SoulData = null,
	p_slot: SoulSlot = null,
	p_ability: ChargedAbility = null,
	p_owner: BattleUnit = null
) -> void:
	id = _next_id
	_next_id += 1
	soul = p_soul
	slot = p_slot
	ability = p_ability
	owner_unit = p_owner
	if slot != null and slot.vessel != null:
		vessel_damage_bonus = slot.vessel.soul_damage_bonus()


func display_name() -> String:
	return soul.item_name if soul != null else "未知魂灵"


func vessel_name() -> String:
	if slot == null:
		return ""
	if slot.vessel != null:
		return slot.vessel.item_name
	return slot.container_name


func refresh_from_ability() -> void:
	if ability == null:
		set_display(0.0, 0.0, 0.0, 0.0)
		return
	set_display(
		snappedf(ability.charge_ratio(), 0.01),
		snappedf(ability.haste_seconds(), 0.1),
		snappedf(ability.slow_seconds(), 0.1),
		snappedf(ability.freeze_seconds(), 0.1)
	)


func set_display(progress: float, haste: float, slow: float, freeze: float) -> void:
	var new_progress := clampf(progress, 0.0, 1.0)
	var new_haste := maxf(haste, 0.0)
	var new_slow := maxf(slow, 0.0)
	var new_freeze := maxf(freeze, 0.0)
	if (
		is_equal_approx(new_progress, scanline_progress)
		and is_equal_approx(new_haste, haste_seconds)
		and is_equal_approx(new_slow, slow_seconds)
		and is_equal_approx(new_freeze, freeze_seconds)
	):
		return
	scanline_progress = new_progress
	haste_seconds = new_haste
	slow_seconds = new_slow
	freeze_seconds = new_freeze
	changed.emit()


func clear_display() -> void:
	set_display(0.0, 0.0, 0.0, 0.0)


func add_counter(key: String, amount: float = 1.0) -> void:
	counters[key] = float(counters.get(key, 0.0)) + amount


func set_counter_timestamp(key: String, value: float) -> void:
	counters[key] = value


func counter(key: String) -> float:
	return float(counters.get(key, 0.0))


func to_dict() -> Dictionary:
	var trigger_rows: Array = []
	for trigger_ability in triggers:
		if trigger_ability == null:
			continue
		var definition := trigger_ability.definition
		trigger_rows.append({
			"event": String(definition.event_tag) if definition != null else "UNKNOWN",
			"label": PassiveTrigger.event_label(definition.event_tag) if definition != null else "",
			"name": definition.trigger_name if definition != null else "",
			"fired": trigger_ability.fired,
			"run_count": trigger_ability.run_count,
		})
	return {
		"id": id,
		"name": display_name(),
		"vessel": vessel_name(),
		"vessel_damage_bonus": vessel_damage_bonus,
		"column": slot.column if slot != null else -1,
		"width": slot.width if slot != null else 1,
		"cooldown": ability.cooldown if ability != null else 0.0,
		"charge_seconds": ability.charge_seconds() if ability != null else 0.0,
		"charge_ratio": ability.charge_ratio() if ability != null else 0.0,
		"haste": ability.haste_seconds() if ability != null else 0.0,
		"slow": ability.slow_seconds() if ability != null else 0.0,
		"freeze": ability.freeze_seconds() if ability != null else 0.0,
		"frozen": ability.is_frozen() if ability != null else false,
		"active": ability.is_active if ability != null else false,
		"activation_lock": ability.activation_lock_seconds() if ability != null else 0.0,
		"counters": counters.duplicate(),
		"triggers": trigger_rows,
	}
