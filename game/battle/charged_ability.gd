class_name ChargedAbility extends GameplayAbility

signal became_ready
signal charge_added(seconds: float, old_seconds: float, new_seconds: float, trace: CombatTrace)
signal status_applied(status_name: String, seconds: float, trace: CombatTrace)
signal status_expired(status_name: String)

const UNITS_PER_SECOND: int = 120
const ACTIVATION_LOCK_UNITS: int = 20
const FROZEN_TAG : StringName = GameplayTags.State_Frozen

## 冷却总时长（秒，数据仍用秒）
@export var cooldown: float = 0.0
var charge_units: int = 0
var activation_lock_units: int = 0

var haste_units: int = 0
var slow_units: int = 0
var freeze_units: int = 0

var soul_container: String = ""
var soul_column: int = -1
var soul_width: int = 1
var unit_soul_abilities: Array[ChargedAbility] = []


func reset_charge() -> void:
	charge_units = 0


func reset_activation_lock() -> void:
	activation_lock_units = 0


func advance_activation_lock(base_units: int) -> void:
	if activation_lock_units > 0 and base_units > 0:
		activation_lock_units = maxi(activation_lock_units - base_units, 0)


func can_activate_now() -> bool:
	return activation_lock_units <= 0


func mark_activated() -> void:
	activation_lock_units = ACTIVATION_LOCK_UNITS


func add_charge(seconds: float, trace: CombatTrace = null) -> void:
	var before := charge_seconds()
	add_charge_units(_seconds_to_units(seconds))
	var after := charge_seconds()
	if not is_equal_approx(before, after):
		_on_charge_received(maxf(after - before, 0.0))
		charge_added.emit(seconds, before, after, trace)


func _on_charge_received(_seconds: float) -> void:
	pass


func add_charge_units(units: int) -> void:
	if cooldown <= 0.0:
		charge_units = 0
		return
	if units <= 0:
		return
	var was_ready := is_ready()
	charge_units = mini(charge_units + units, _cooldown_units())
	if not was_ready and is_ready():
		became_ready.emit()


func advance_charge(base_units: int) -> void:
	if cooldown <= 0.0 or base_units <= 0:
		return
	add_charge_units(_charged_units_for_tick(base_units))


func apply_haste(seconds: float, trace: CombatTrace = null) -> bool:
	if cooldown <= 0.0 or seconds <= 0.0:
		return false
	haste_units += _seconds_to_units(seconds)
	status_applied.emit("加速", seconds, trace)
	return true


func apply_slow(seconds: float, trace: CombatTrace = null) -> bool:
	if cooldown <= 0.0 or seconds <= 0.0:
		return false
	slow_units += _seconds_to_units(seconds)
	status_applied.emit("减速", seconds, trace)
	return true


func apply_freeze(seconds: float, trace: CombatTrace = null) -> bool:
	if cooldown <= 0.0 or seconds <= 0.0:
		return false
	freeze_units += _seconds_to_units(seconds)
	status_applied.emit("冻结", seconds, trace)
	return true


func advance_status(base_units: int) -> void:
	if base_units <= 0:
		return
	if haste_units > 0:
		haste_units = maxi(haste_units - base_units, 0)
		if haste_units == 0:
			status_expired.emit("加速")
	if slow_units > 0:
		slow_units = maxi(slow_units - base_units, 0)
		if slow_units == 0:
			status_expired.emit("减速")
	if freeze_units > 0:
		freeze_units = maxi(freeze_units - base_units, 0)
		if freeze_units == 0:
			status_expired.emit("冻结")


func has_haste() -> bool:
	return haste_units > 0


func has_slow() -> bool:
	return slow_units > 0


func is_ready() -> bool:
	return cooldown <= 0.0 or charge_units >= _cooldown_units()


func is_frozen() -> bool:
	if freeze_units > 0:
		return true
	return owner_asc != null and owner_asc.has_tag(FROZEN_TAG)


func charge_ratio() -> float:
	if cooldown <= 0.0:
		return 1.0
	var total := _cooldown_units()
	if total <= 0:
		return 1.0
	return clampf(float(charge_units) / float(total), 0.0, 1.0)


func charge_seconds() -> float:
	return float(charge_units) / float(UNITS_PER_SECOND)


func haste_seconds() -> float:
	return float(haste_units) / float(UNITS_PER_SECOND)


func slow_seconds() -> float:
	return float(slow_units) / float(UNITS_PER_SECOND)


func freeze_seconds() -> float:
	return float(freeze_units) / float(UNITS_PER_SECOND)


func activation_lock_seconds() -> float:
	return float(activation_lock_units) / float(UNITS_PER_SECOND)


func _charged_units_for_tick(base_units: int) -> int:
	if has_haste() and has_slow():
		return base_units
	if has_haste():
		return base_units * 2
	if has_slow():
		return int(round(base_units * 0.5))
	return base_units


func _cooldown_units() -> int:
	if cooldown <= 0.0:
		return 0
	return maxi(int(round(cooldown * float(UNITS_PER_SECOND))), 1)


func _seconds_to_units(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	return int(round(seconds * float(UNITS_PER_SECOND)))
