extends Node
## 项目侧 Cue 注册器（Autoload：ModCueRegistrar）。
##
## `GameplayCueManager` 直接使用 GodotGAS 的
## `addons/GodotGAS/managers/gameplay_cue_manager.gd`，本节点只负责把
## ModLoader 的 core/第三方 mod Cue 注册进它的 `_cue_scenes` / `_pool`。
##
## 不继承 addon 脚本：导出包里路径式 extends 会解析失败，导致整个
## GameplayCueManager autoload 挂掉。

var _mod_registered_tags: Array[StringName] = []
## 引用检查去重：同一个 Cue 标签/效果可能被多颗魂灵引用
var _checked_cue_tags: Dictionary = {}
var _checked_effect_ids: Dictionary = {}


func _ready() -> void:
	_register_mod_cues()
	_validate_cue_references()


## 运行时注册一个 Cue；标签已存在时返回 false
func register_cue(tag: StringName, scene: PackedScene) -> bool:
	if tag.is_empty() or scene == null or GameplayCueManager._cue_scenes.has(tag):
		return false
	GameplayCueManager._cue_scenes[tag] = scene
	GameplayCueManager._pool[tag] = []
	return true


## 已发现的 mod Cue 概况：tag / mod / path / 是否注册成功
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


## 某个 mod Cue 是否已注册
func is_mod_cue_registered(tag: StringName) -> bool:
	return _mod_registered_tags.has(tag)


## Cue 注册完成后，检查魂灵技能/效果引用的 Cue 标签是否真的存在
func _validate_cue_references() -> void:
	for entry in ModLoader.get_soul_entries():
		var soul := entry.resource as SoulData
		if soul != null:
			_validate_soul_cue_references(entry, soul)


func _validate_soul_cue_references(entry: ModContentEntry, soul: SoulData) -> void:
	var skill := soul.skill
	if skill != null:
		_check_cue_tag(entry, skill.hit_cue_tag)
		_check_effect_cues(entry, skill.effects)
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


## 实例化一次检查根节点能力；不在场景树里，只会触发 _init。
func _scene_is_cue(scene: PackedScene) -> bool:
	var instance := scene.instantiate()
	if instance == null:
		return false
	var valid := instance.has_method("execute_cue") and instance.has_signal("cue_finished")
	instance.free()
	return valid
