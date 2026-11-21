extends Node

var _mod_registered_tags: Array[StringName] = []
var _checked_cue_tags: Dictionary = {}
var _checked_effect_ids: Dictionary = {}


func _ready() -> void:
	_register_mod_cues()
	_validate_cue_references()


func register_cue(tag: StringName, scene: PackedScene) -> bool:
	if tag.is_empty() or scene == null or GameplayCueManager._cue_scenes.has(tag):
		return false
	GameplayCueManager._cue_scenes[tag] = scene
	GameplayCueManager._pool[tag] = []
	return true


func get_mod_cues() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in ModLoader.get_cue_entries():
		result.append({
			"tag": String(entry.content_id),
			"mod": String(entry.mod_id),
			"path": entry.path,
			"registered": _mod_registered_tags.has(entry.content_id),
		})
	return result


func is_mod_cue_registered(tag: StringName) -> bool:
	return _mod_registered_tags.has(tag)


func _validate_cue_references() -> void:
	for entry in ModLoader.get_soul_entries():
		var soul := entry.resource as SoulData
		if soul != null:
			_validate_soul_cue_references(entry, soul)


func _validate_soul_cue_references(entry: ModContentEntry, soul: SoulData) -> void:
	var skill := soul.skill
	if skill != null:
		for step in skill.steps:
			var unit_step := step as UnitSkillStep
			if unit_step != null:
				_check_cue_tag(entry, unit_step.hit_cue_tag)
				_check_effect_cues(entry, unit_step.effects)
		_check_effect_cues(entry, skill.self_effects)
	if soul is PassiveSoulData:
		_check_effect_cues(entry, (soul as PassiveSoulData).passive_effects)
	for trigger in soul.triggers:
		if trigger != null:
			_check_effect_cues(entry, trigger.effects)


func _check_effect_cues(entry: ModContentEntry, effects: Array[GameplayEffect]) -> void:
	for effect in effects:
		if effect == null:
			continue
		var effect_id := effect.get_instance_id()
		if _checked_effect_ids.has(effect_id):
			continue
		_checked_effect_ids[effect_id] = true
		for tag in effect.application_cue_tags:
			_check_cue_tag(entry, tag)
		for tag in effect.persistent_cue_tags:
			_check_cue_tag(entry, tag)
		for tag in effect.periodic_cue_tags:
			_check_cue_tag(entry, tag)
		for tag in effect.removal_cue_tags:
			_check_cue_tag(entry, tag)
		_check_effect_cues(entry, effect.overflow_effects)


func _check_cue_tag(entry: ModContentEntry, tag: StringName) -> void:
	if tag.is_empty() or _checked_cue_tags.has(tag):
		return
	_checked_cue_tags[tag] = true
	if GameplayCueManager._cue_scenes.has(tag):
		return
	ModLoader.report_warning("%s: Cue 标签未注册：%s（%s）" % [entry.mod_id, tag, entry.content_id])


func _register_mod_cues() -> void:
	for entry in ModLoader.get_cue_entries():
		if _register_entry(entry):
			_mod_registered_tags.append(entry.content_id)


func _register_entry(entry: ModContentEntry) -> bool:
	var scene := entry.resource as PackedScene
	if scene == null:
		ModLoader.report_warning("%s: Cue 资源不是 PackedScene：%s" % [entry.mod_id, entry.path])
		return false
	if not _scene_is_cue(scene):
		ModLoader.report_warning("%s: Cue 场景根节点必须能执行 Cue（execute_cue + cue_finished）：%s" % [
			entry.mod_id,
			entry.path,
		])
		return false
	if not register_cue(entry.content_id, scene):
		ModLoader.report_warning("%s: Cue 标签已被占用：%s" % [entry.mod_id, entry.content_id])
		return false
	return true


func _scene_is_cue(scene: PackedScene) -> bool:
	var instance := scene.instantiate()
	if instance == null:
		return false
	var valid := instance.has_method("execute_cue") and instance.has_signal("cue_finished")
	instance.free()
	return valid
