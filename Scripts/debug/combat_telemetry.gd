extends Node

signal event_recorded(event: Dictionary)
signal run_started(run_id: int)
signal run_ended(run_id: int)

const MAX_EVENTS_DEFAULT: int = 5000
const FILE_FLUSH_EVERY: int = 50
const TRIM_RATIO: float = 0.1

var enabled: bool = true
var record_detail_globally: bool = false
var record_to_file: bool = false
var max_events: int = MAX_EVENTS_DEFAULT

var events: Array[Dictionary] = []
var dropped_events: int = 0
var current_run_id: int = 0
var current_battle: BattleManager
var watch_unit_id: int = 0

var _seq: int = 0
var _bound_units: Dictionary = {}
var _bound_abilities: Dictionary = {}
var _file: FileAccess
var _file_path: String = ""
var _file_lines: int = 0
var _run_started_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func begin_run(run_id: int, battle: BattleManager, loadout: Array = []) -> void:
	current_run_id = run_id
	current_battle = battle
	watch_unit_id = 0
	_run_started_msec = Time.get_ticks_msec()
	var souls: Array = []
	for entry in loadout:
		if entry != null:
			souls.append({
				"name": entry.soul.item_name if entry.soul != null else "?",
				"vessel": (
					entry.slot.vessel.item_name
					if entry.slot != null and entry.slot.vessel != null
					else (entry.slot.container_name if entry.slot != null else "")
				),
				"column": entry.slot.column if entry.slot != null else -1,
			})
	record(CombatTelemetrySchema.BATTLE, "start", {"souls": souls, "enemy_count": battle.enemy_count()})
	if record_to_file:
		_open_file()
	run_started.emit(run_id)


func end_run(reason: String = "") -> void:
	if current_run_id == 0:
		return
	record(CombatTelemetrySchema.BATTLE, "end", {"reason": reason})
	var run_id := current_run_id
	_close_file()
	current_battle = null
	current_run_id = 0
	_bound_units.clear()
	_bound_abilities.clear()
	run_ended.emit(run_id)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_close_file()
	elif record_to_file and current_run_id != 0 and _file == null:
		_open_file()


func set_record_to_file(value: bool) -> void:
	record_to_file = value
	if record_to_file and current_run_id != 0 and _file == null:
		_open_file()
	elif not record_to_file:
		_close_file()


func get_record_path() -> String:
	return _file_path


func record(
	category: String,
	type: String,
	fields: Dictionary = {},
	importance: String = CombatTelemetrySchema.IMPORTANT
) -> Dictionary:
	if not enabled:
		return {}
	if importance == CombatTelemetrySchema.DETAIL and not record_detail_globally:
		if watch_unit_id == 0 or not _raw_detail_matches_watch(fields):
			return {}

	var event: Dictionary = fields.duplicate()
	_normalize_units(event)
	_normalize_trace(event)

	if importance == CombatTelemetrySchema.DETAIL and not _detail_allowed(event):
		return {}

	_seq += 1
	event["seq"] = _seq
	event["run_id"] = current_run_id
	event["frame"] = Engine.get_process_frames()
	event["t"] = _elapsed()
	event["category"] = category
	event["type"] = type
	event["importance"] = importance
	if not event.has("color"):
		event["color"] = CombatTelemetrySchema.category_color(category)

	events.append(event)
	if events.size() > max_events:
		_trim_events()

	if _file != null:
		_file.store_line(JSON.stringify(event))
		_file_lines += 1
		if _file_lines % FILE_FLUSH_EVERY == 0:
			_file.flush()

	event_recorded.emit(event)
	return event


func watch_unit(unit: BattleUnit) -> void:
	watch_unit_id = unit.get_instance_id() if unit != null and is_instance_valid(unit) else 0
	if unit != null and is_instance_valid(unit):
		bind_unit(unit)


func bind_unit(unit: BattleUnit) -> void:
	if unit == null or not is_instance_valid(unit) or unit.asc == null:
		return
	var unit_id := unit.get_instance_id()
	var state := String(_bound_units.get(unit_id, ""))
	if state == "full":
		return
	var full := unit.team == BattleUnit.Team.PLAYER or unit_id == watch_unit_id
	if not full and state.is_empty():
		unit.died.connect(_on_unit_died)
		_bound_units[unit_id] = "death"
		return
	_bound_units[unit_id] = "full"

	if not unit.died.is_connected(_on_unit_died):
		unit.died.connect(_on_unit_died)
	var asc := unit.asc
	asc.tag_added.connect(_on_tag_added.bind(unit))
	asc.tag_count_changed.connect(_on_tag_count_changed.bind(unit))
	asc.tag_removed.connect(_on_tag_removed.bind(unit))
	asc.attribute_changed.connect(_on_attribute_changed.bind(unit))
	asc.effect_applied_to_target.connect(_on_effect_applied_to_target.bind(unit))
	asc.effect_received.connect(_on_effect_received.bind(unit))
	asc.active_effect_added.connect(_on_active_effect_added.bind(unit))
	asc.active_effect_removed.connect(_on_active_effect_removed.bind(unit))
	asc.periodic_effect_ticked.connect(_on_periodic_effect_ticked.bind(unit))
	asc.ability_granted.connect(_on_ability_granted.bind(unit))
	asc.ability_removed.connect(_on_ability_removed.bind(unit))
	asc.ability_activation_failed.connect(_on_ability_activation_failed.bind(unit))
	asc.gameplay_event_received.connect(_on_gameplay_event_received.bind(unit))

	record(CombatTelemetrySchema.BATTLE, "unit_bound", {
		"actor_unit": unit,
		"max_health": unit.max_health,
		"souls": _soul_names(unit),
		"loadout_size": unit.loadout.size(),
	}, CombatTelemetrySchema.DETAIL)


func bind_ability(ability: GameplayAbility, unit: BattleUnit, runtime: SoulRuntime) -> void:
	if ability == null or not is_instance_valid(ability):
		return
	var ability_id := ability.get_instance_id()
	if _bound_abilities.has(ability_id):
		return
	_bound_abilities[ability_id] = true

	var charged := ability as ChargedAbility
	if charged == null:
		return
	charged.became_ready.connect(_on_ability_became_ready.bind(ability, unit, runtime))
	charged.charge_added.connect(_on_ability_charge_added.bind(ability, unit, runtime))
	charged.status_applied.connect(_on_ability_status_applied.bind(ability, unit, runtime))
	charged.status_expired.connect(_on_ability_status_expired.bind(ability, unit, runtime))


func query(filter: Dictionary = {}, limit: int = 1000) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for event in events:
		if _matches_filter(event, filter):
			matched.append(event)
	if limit > 0 and matched.size() > limit:
		return matched.slice(matched.size() - limit)
	return matched


func get_trace_chain(trace_id: int) -> Array[Dictionary]:
	if trace_id <= 0:
		return []
	var root_id := trace_id
	for event in events:
		if int(event.get("trace_id", 0)) == trace_id:
			root_id = int(event.get("root_trace_id", trace_id))
			break
	var chain: Array[Dictionary] = []
	for event in events:
		var event_trace := int(event.get("trace_id", 0))
		var event_root := int(event.get("root_trace_id", 0))
		if event_trace == root_id or event_root == root_id:
			chain.append(event)
	chain.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("seq", 0)) < int(b.get("seq", 0)))
	return chain


func export_jsonl(path: String = "") -> String:
	if path.is_empty():
		path = "user://debug/combat_%s.jsonl" % Time.get_datetime_string_from_system().replace(":", "-")
	_ensure_debug_dir()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("CombatTelemetry：无法写入 %s" % path)
		return ""
	file.store_line(JSON.stringify({
		"meta": true,
		"run_id": current_run_id,
		"exported_msec": Time.get_ticks_msec(),
		"event_count": events.size(),
		"dropped_events": dropped_events,
		"max_events": max_events,
	}))
	for event in events:
		file.store_line(JSON.stringify(event))
	file.close()
	return ProjectSettings.globalize_path(path)


func _trim_events() -> void:
	var trim := maxi(int(ceil(float(max_events) * TRIM_RATIO)), 1)
	trim = mini(trim, events.size())
	var remaining: Array[Dictionary] = []
	remaining.assign(events.slice(trim))
	events = remaining
	dropped_events += trim


func clear() -> void:
	events.clear()
	_seq = 0
	dropped_events = 0


func get_stats() -> Dictionary:
	var counts: Dictionary = {}
	for event in events:
		var category := String(event.get("category", "?"))
		counts[category] = int(counts.get(category, 0)) + 1
	return {
		"enabled": enabled,
		"run_id": current_run_id,
		"events": events.size(),
		"max_events": max_events,
		"dropped_events": dropped_events,
		"detail_globally": record_detail_globally,
		"record_to_file": record_to_file,
		"record_path": _file_path,
		"watch_unit_id": watch_unit_id,
		"counts": counts,
	}


func _on_unit_died(unit: BattleUnit) -> void:
	_bound_units.erase(unit.get_instance_id())
	record(CombatTelemetrySchema.BATTLE, "died", {
		"actor_unit": unit,
		"hp": unit.health_attr.current_value if unit.health_attr != null else 0.0,
	}, CombatTelemetrySchema.IMPORTANT)


func _on_tag_added(tag: StringName, unit: BattleUnit) -> void:
	record(CombatTelemetrySchema.TAG, "added", {
		"actor_unit": unit,
		"tag": String(tag),
	}, CombatTelemetrySchema.DETAIL)


func _on_tag_count_changed(tag: StringName, new_count: int, unit: BattleUnit) -> void:
	record(CombatTelemetrySchema.TAG, "count", {
		"actor_unit": unit,
		"tag": String(tag),
		"count": new_count,
	}, CombatTelemetrySchema.DETAIL)


func _on_tag_removed(tag: StringName, unit: BattleUnit) -> void:
	record(CombatTelemetrySchema.TAG, "removed", {
		"actor_unit": unit,
		"tag": String(tag),
	}, CombatTelemetrySchema.DETAIL)


func _on_attribute_changed(
	attribute_name: String,
	old_value: float,
	new_value: float,
	spec: GameplayEffectSpec,
	unit: BattleUnit
) -> void:
	var fields := _spec_fields(spec)
	fields["actor_unit"] = unit
	fields["attribute"] = attribute_name
	fields["old"] = old_value
	fields["new"] = new_value
	fields["delta"] = new_value - old_value
	record(CombatTelemetrySchema.ATTRIBUTE, "changed", fields, CombatTelemetrySchema.DETAIL)


func _on_effect_applied_to_target(
	target_asc: AbilitySystemComponent,
	spec: GameplayEffectSpec,
	source_unit: BattleUnit
) -> void:
	var fields := _spec_fields(spec)
	fields["actor_unit"] = source_unit
	if target_asc != null and target_asc.get_parent() is BattleUnit:
		fields["target_unit"] = target_asc.get_parent()
	record(CombatTelemetrySchema.EFFECT, "applied", fields, CombatTelemetrySchema.DETAIL)


func _on_effect_received(
	source_asc: AbilitySystemComponent,
	spec: GameplayEffectSpec,
	target_unit: BattleUnit
) -> void:
	if spec == null:
		return
	if spec.period > 0.0:
		return
	var fields := _spec_fields(spec)
	fields["target_unit"] = target_unit
	if source_asc != null and source_asc.get_parent() is BattleUnit:
		fields["actor_unit"] = source_asc.get_parent()
	fields["health_delta"] = float(spec.calculated_deltas.get("health", 0.0))
	fields["shield_delta"] = float(spec.calculated_deltas.get("shield", 0.0))
	var important := target_unit.team == BattleUnit.Team.PLAYER or bool(fields.get("crit", false))
	record(
		CombatTelemetrySchema.EFFECT,
		"received",
		fields,
		CombatTelemetrySchema.IMPORTANT if important else CombatTelemetrySchema.DETAIL
	)


func _on_active_effect_added(active_effect: ActiveGameplayEffect, unit: BattleUnit) -> void:
	if active_effect == null or active_effect.spec == null:
		return
	var spec := active_effect.spec
	var fields := _spec_fields(spec)
	var source_unit := _source_unit(spec)
	fields["actor_unit"] = source_unit if source_unit != null else unit
	fields["target_unit"] = unit
	fields["policy"] = _policy_name(active_effect.get_effect_def())
	fields["duration"] = spec.duration
	fields["remaining"] = active_effect.time_remaining
	fields["stacks"] = active_effect.stack_count
	fields["suppressed"] = active_effect.is_suppressed
	fields["effect_tags"] = _string_array(active_effect.get_effect_def().granted_tags)
	fields["persistent_cues"] = _string_array(active_effect.get_effect_def().persistent_cue_tags)
	record(
		CombatTelemetrySchema.EFFECT,
		"added",
		fields,
		_event_importance(unit, source_unit)
	)


func _on_active_effect_removed(active_effect: ActiveGameplayEffect, unit: BattleUnit) -> void:
	if active_effect == null or active_effect.spec == null:
		return
	var spec := active_effect.spec
	var fields := _spec_fields(spec)
	var source_unit := _source_unit(spec)
	fields["actor_unit"] = source_unit if source_unit != null else unit
	fields["target_unit"] = unit
	fields["stacks"] = active_effect.stack_count
	record(
		CombatTelemetrySchema.EFFECT,
		"removed",
		fields,
		_event_importance(unit, source_unit)
	)


func _on_periodic_effect_ticked(
	_active_effect: ActiveGameplayEffect,
	spec: GameplayEffectSpec,
	unit: BattleUnit
) -> void:
	if spec == null:
		return
	var fields := _spec_fields(spec)
	var source_unit := _source_unit(spec)
	fields["actor_unit"] = source_unit if source_unit != null else unit
	fields["target_unit"] = unit
	fields["health_delta"] = float(spec.calculated_deltas.get("health", 0.0))
	fields["shield_delta"] = float(spec.calculated_deltas.get("shield", 0.0))
	fields["burn_delta"] = float(spec.calculated_deltas.get("burn", 0.0))
	record(CombatTelemetrySchema.EFFECT, "tick", fields, CombatTelemetrySchema.DETAIL)


func _on_ability_granted(ability: GameplayAbility, unit: BattleUnit) -> void:
	record(CombatTelemetrySchema.CAST, "granted", {
		"actor_unit": unit,
		"ability": CombatNames.ability_name(ability),
		"ability_tag": String(ability.ability_tag),
	}, CombatTelemetrySchema.DETAIL)


func _on_ability_removed(ability: GameplayAbility, unit: BattleUnit) -> void:
	record(CombatTelemetrySchema.CAST, "removed", {
		"actor_unit": unit,
		"ability": CombatNames.ability_name(ability),
		"ability_tag": String(ability.ability_tag),
	}, CombatTelemetrySchema.DETAIL)


func _on_ability_activation_failed(
	ability: GameplayAbility,
	reason: int,
	payload: Dictionary,
	unit: BattleUnit
) -> void:
	record(CombatTelemetrySchema.CAST, "blocked", {
		"actor_unit": unit,
		"ability": CombatNames.ability_name(ability),
		"ability_tag": String(ability.ability_tag) if ability != null else "",
		"reason": _activation_error_name(reason),
		"detail": _payload_summary(payload),
	}, CombatTelemetrySchema.IMPORTANT)


func _on_gameplay_event_received(
	event_tag: StringName,
	payload: Variant,
	unit: BattleUnit
) -> void:
	var tag := String(event_tag)
	var important := (
		tag.contains("SoulUsed")
		or tag.contains("FreezeApplied")
		or tag.contains("BelowPercent")
	)
	record(CombatTelemetrySchema.TRIGGER, "event", {
		"actor_unit": unit,
		"event": tag,
		"detail": _payload_summary(payload),
	}, CombatTelemetrySchema.IMPORTANT if important else CombatTelemetrySchema.DETAIL)


func _on_ability_became_ready(
	ability: GameplayAbility,
	unit: BattleUnit,
	runtime: SoulRuntime
) -> void:
	record(CombatTelemetrySchema.SOUL, "ready", _ability_event_fields(ability, unit, runtime), CombatTelemetrySchema.DETAIL)


func _on_ability_charge_added(
	seconds: float,
	old_seconds: float,
	new_seconds: float,
	trace: CombatTrace,
	ability: GameplayAbility,
	unit: BattleUnit,
	runtime: SoulRuntime
) -> void:
	var fields := _ability_event_fields(ability, unit, runtime)
	fields["amount"] = new_seconds - old_seconds
	fields["old"] = old_seconds
	fields["new"] = new_seconds
	fields["detail"] = "外部充能 %.2f 秒" % seconds
	if trace != null:
		fields["trace"] = trace
	record(
		CombatTelemetrySchema.SOUL,
		"charge",
		fields,
		CombatTelemetrySchema.IMPORTANT if unit.team == BattleUnit.Team.PLAYER else CombatTelemetrySchema.DETAIL
	)


func _on_ability_status_applied(
	status_name: String,
	seconds: float,
	trace: CombatTrace,
	ability: GameplayAbility,
	unit: BattleUnit,
	runtime: SoulRuntime
) -> void:
	var fields := _ability_event_fields(ability, unit, runtime)
	fields["status"] = status_name
	fields["amount"] = seconds
	if trace != null:
		fields["trace"] = trace
	record(
		CombatTelemetrySchema.SOUL,
		"status",
		fields,
		CombatTelemetrySchema.IMPORTANT if unit.team == BattleUnit.Team.PLAYER else CombatTelemetrySchema.DETAIL
	)


func _on_ability_status_expired(
	status_name: String,
	ability: GameplayAbility,
	unit: BattleUnit,
	runtime: SoulRuntime
) -> void:
	var fields := _ability_event_fields(ability, unit, runtime)
	fields["status"] = status_name
	record(
		CombatTelemetrySchema.SOUL,
		"status_end",
		fields,
		CombatTelemetrySchema.IMPORTANT if unit.team == BattleUnit.Team.PLAYER else CombatTelemetrySchema.DETAIL
	)


func _elapsed() -> float:
	if current_battle != null and is_instance_valid(current_battle) and current_battle.is_running:
		return current_battle.elapsed_seconds()
	return (Time.get_ticks_msec() - _run_started_msec) / 1000.0 if _run_started_msec > 0 else 0.0


func _spec_fields(spec: GameplayEffectSpec) -> Dictionary:
	var fields: Dictionary = {}
	if spec == null:
		return fields
	fields["effect"] = CombatNames.effect_name(spec)
	fields["source"] = CombatNames.source_name(spec)
	if spec.has_tag(GameplayTags.Event_Combat_Critical):
		fields["crit"] = true
	var trace := _trace_of_spec(spec)
	if trace != null:
		fields["trace"] = trace
	return fields


func _trace_of_spec(spec: GameplayEffectSpec) -> CombatTrace:
	if spec == null or not (spec.context is SoulEffectContext):
		return null
	return (spec.context as SoulEffectContext).trace


func _source_unit(spec: GameplayEffectSpec) -> BattleUnit:
	if spec == null or spec.context == null:
		return null
	var instigator = spec.context.instigator
	if is_instance_valid(instigator) and instigator is BattleUnit:
		return instigator as BattleUnit
	var causer = spec.context.causer
	if is_instance_valid(causer) and causer is BattleUnit:
		return causer as BattleUnit
	return null


func _event_importance(target: BattleUnit, _source: BattleUnit) -> String:
	return (
		CombatTelemetrySchema.IMPORTANT
		if target != null and target.team == BattleUnit.Team.PLAYER
		else CombatTelemetrySchema.DETAIL
	)


func _ability_event_fields(
	ability: GameplayAbility,
	unit: BattleUnit,
	runtime: SoulRuntime
) -> Dictionary:
	var fields: Dictionary = {
		"actor_unit": unit,
		"ability": CombatNames.ability_name(ability),
		"ability_tag": String(ability.ability_tag) if ability != null else "",
	}
	if runtime != null:
		fields["soul"] = runtime.display_name()
		fields["soul_id"] = runtime.id
	return fields


func _soul_names(unit: BattleUnit) -> Array[String]:
	var names: Array[String] = []
	for runtime in unit.loadout:
		if runtime != null:
			names.append(runtime.display_name())
	return names


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result


func _policy_name(effect: GameplayEffect) -> String:
	if effect == null:
		return "?"
	var names: Array[String] = ["INSTANT", "DURATION", "INFINITE", "TURN_BASED"]
	return names[effect.policy] if effect.policy >= 0 and effect.policy < names.size() else "?"


func _activation_error_name(reason: int) -> String:
	var names: Array[String] = [
		"ALREADY_ACTIVE",
		"ON_COOLDOWN",
		"FAILED_QUERY",
		"INSUFFICIENT_RESOURCES",
		"BLOCKED_BY_OTHER_ABILITY",
		"INTERNAL_ERROR",
	]
	return names[reason] if reason >= 0 and reason < names.size() else "UNKNOWN"


func _payload_summary(payload: Variant) -> String:
	if payload == null:
		return ""
	if payload is Dictionary:
		var parts: Array[String] = []
		for key in payload:
			var value: Variant = payload[key]
			if value is BattleUnit:
				value = (value as BattleUnit).unit_name
			elif value is GameplayAbility:
				value = CombatNames.ability_name(value as GameplayAbility)
			elif value is SoulData:
				value = (value as SoulData).item_name
			elif value is CombatTrace:
				value = "trace#%d" % (value as CombatTrace).id
			elif value is Vector2i:
				value = "(%d,%d)" % [(value as Vector2i).x, (value as Vector2i).y]
			elif value is Node:
				value = (value as Node).name
			parts.append("%s=%s" % [key, str(value)])
		return ", ".join(parts)
	if payload is GameplayEffectSpec:
		return CombatNames.effect_name(payload)
	if payload is CombatTrace:
		return "trace#%d" % payload.id
	return str(payload).left(200)


func _normalize_units(event: Dictionary) -> void:
	if event.has("actor_unit"):
		event["actor"] = CombatTelemetrySchema.unit_info(event["actor_unit"])
		event.erase("actor_unit")
	if event.has("target_unit"):
		event["target"] = CombatTelemetrySchema.unit_info(event["target_unit"])
		event.erase("target_unit")
	if event.has("unit_unit"):
		event["unit"] = CombatTelemetrySchema.unit_info(event["unit_unit"])
		event.erase("unit_unit")


func _normalize_trace(event: Dictionary) -> void:
	if not event.has("trace"):
		return
	var trace = event["trace"]
	event.erase("trace")
	if trace is CombatTrace:
		event["trace_id"] = trace.id
		event["parent_trace_id"] = trace.parent_id
		event["root_trace_id"] = trace.root_id
		event["trace_cause"] = trace.cause


func _detail_allowed(event: Dictionary) -> bool:
	if record_detail_globally:
		return true
	if watch_unit_id == 0:
		return false
	var actor: Dictionary = event.get("actor", {})
	var target: Dictionary = event.get("target", {})
	var unit: Dictionary = event.get("unit", {})
	var actor_id := int(actor.get("id", 0))
	var target_id := int(target.get("id", 0))
	var unit_id := int(unit.get("id", 0))
	return actor_id == watch_unit_id or target_id == watch_unit_id or unit_id == watch_unit_id


func _matches_filter(event: Dictionary, filter: Dictionary) -> bool:
	if filter.is_empty():
		return true
	if filter.has("category") and String(event.get("category", "")) != String(filter["category"]):
		return false
	if filter.has("type") and String(event.get("type", "")) != String(filter["type"]):
		return false
	if filter.has("importance") and String(event.get("importance", "")) != String(filter["importance"]):
		return false
	if filter.has("run_id") and int(event.get("run_id", 0)) != int(filter["run_id"]):
		return false
	if filter.has("since_seq") and int(event.get("seq", 0)) < int(filter["since_seq"]):
		return false
	if filter.has("actor_id"):
		var actor: Dictionary = event.get("actor", {})
		if int(actor.get("id", 0)) != int(filter["actor_id"]):
			return false
	if filter.has("target_id"):
		var target: Dictionary = event.get("target", {})
		if int(target.get("id", 0)) != int(filter["target_id"]):
			return false
	if filter.has("soul") and String(event.get("soul", "")) != String(filter["soul"]):
		return false
	if filter.has("text"):
		var needle := String(filter["text"]).to_lower()
		if not needle.is_empty() and not _event_text(event).to_lower().contains(needle):
			return false
	return true


func _event_text(event: Dictionary) -> String:
	var parts: Array[String] = [
		String(event.get("category", "")),
		String(event.get("type", "")),
		String(event.get("soul", "")),
		String(event.get("ability", "")),
		String(event.get("effect", "")),
		String(event.get("detail", "")),
	]
	var actor: Dictionary = event.get("actor", {})
	var target: Dictionary = event.get("target", {})
	parts.append(String(actor.get("name", "")))
	parts.append(String(target.get("name", "")))
	return " ".join(parts)


func _ensure_debug_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://debug"))


func _open_file() -> void:
	_close_file()
	_ensure_debug_dir()
	_file_path = "user://debug/combat_%s_run%d.jsonl" % [
		Time.get_datetime_string_from_system().replace(":", "-"),
		current_run_id,
	]
	_file = FileAccess.open(_file_path, FileAccess.WRITE)
	_file_lines = 0
	if _file == null:
		push_warning("CombatTelemetry：无法打开录制文件 %s" % _file_path)
	else:
		_file_path = ProjectSettings.globalize_path(_file_path)


func _close_file() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null
	_file_lines = 0


func _raw_detail_matches_watch(fields: Dictionary) -> bool:
	for key in ["actor_unit", "target_unit", "unit"]:
		var raw = fields.get(key)
		if raw is Object and is_instance_valid(raw) and (raw as Object).get_instance_id() == watch_unit_id:
			return true
	for key in ["actor", "target", "unit"]:
		var info = fields.get(key)
		if info is Dictionary and int(info.get("id", 0)) == watch_unit_id:
			return true
	return false
