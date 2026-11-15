extends Node
## 见闻图鉴服务（Autoload 名称：CollectionDB）。
##
## 全量清单来自 ModLoader：内置 core mod + 第三方 mod，统一按 manifest 注册。
## 本节点只负责运行时索引（魂灵/怪物/魂器）、“已遇见”状态和存档。
##
## 已遇见状态以 manifest 的 content_id（例如 &"xiao_lu_soul"）为键，
## 资源改名/移动不会丢记录；解锁后由 SaveManager 统一写入存档。

## 新条目解锁；图鉴窗口用它刷新
signal entry_unlocked(kind: int, id: StringName)
## 读档整体替换“已遇见”状态后发出；图鉴窗口用它整体刷新
signal state_reloaded

## 测试开关：见闻条目是否全部按已解锁显示；默认关闭。
## 只影响显示，不写存档；调试窗口/TestAPI 可以临时切换。
var unlock_all_for_testing: bool = false

## content_id → 资源
var _souls: Dictionary[StringName, SoulData] = {}
var _monsters: Dictionary[StringName, MonsterData] = {}
var _vessels: Dictionary[StringName, SoulVesselData] = {}
## 已遇见：ContentKind.Kind → { content_id: true }
var _seen: Dictionary = {}


func _ready() -> void:
	_reset_seen()
	_load_catalog()
	GBIS.sig_inv_item_added.connect(_on_inv_item_added)
	GBIS.sig_inv_refresh.connect(_scan_owned_souls)
	@warning_ignore("missing_await")
	_scan_owned_souls_after_ready()


#region 查询
func get_soul_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_souls.keys())
	return ids


func get_monster_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_monsters.keys())
	return ids


func get_soul(id: StringName) -> SoulData:
	return _souls.get(id)


func get_monster(id: StringName) -> MonsterData:
	return _monsters.get(id)


func get_vessel_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_vessels.keys())
	return ids


func get_vessel(id: StringName) -> SoulVesselData:
	return _vessels.get(id)


func is_seen(kind: int, id: StringName) -> bool:
	if unlock_all_for_testing:
		return true
	var seen: Dictionary = _seen.get(kind, {})
	return seen.has(id)


## 测试接口：临时切换“全部已解锁”，不改存档
func set_unlock_all_for_testing(enabled: bool) -> void:
	unlock_all_for_testing = enabled


## 真实已解锁的 content_id（不受测试开关影响）
func get_seen_ids(kind: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	var seen: Dictionary = _seen.get(kind, {})
	ids.assign(seen.keys())
	return ids


## 从常规刷怪池里按 spawn_weight 随机挑一只；权重 0 或 is_rare 的怪不参与
func pick_random_monster() -> MonsterData:
	var candidates: Array[MonsterData] = []
	var total_weight: float = 0.0
	for monster in _monsters.values():
		if monster == null or monster.is_rare or monster.battle_scene == null or monster.spawn_weight <= 0.0:
			continue
		candidates.append(monster)
		total_weight += monster.spawn_weight
	if candidates.is_empty():
		return null

	var roll := randf() * total_weight
	for monster in candidates:
		roll -= monster.spawn_weight
		if roll <= 0.0:
			return monster
	return candidates.back()


## 标记为稀有的怪物 content_id；没有配置时返回空数组
func get_rare_monster_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in _monsters:
		var monster: MonsterData = _monsters[id]
		if monster != null and monster.is_rare:
			ids.append(id)
	return ids


## 从稀有怪里随机挑一只；没有配置或没配战斗场景时返回 null
func pick_rare_monster() -> MonsterData:
	var candidates: Array[MonsterData] = []
	for monster in _monsters.values():
		if monster != null and monster.is_rare and monster.battle_scene != null:
			candidates.append(monster)
	return candidates.pick_random() if not candidates.is_empty() else null


## 魂灵“首次获得”即记录；content_id 随 duplicate() 进入背包副本
func mark_soul_seen(soul: SoulData) -> void:
	if soul == null:
		return
	var id: StringName = soul.content_id
	if id.is_empty():
		push_warning("见闻：魂灵没有 content_id「%s」" % soul.item_name)
		return
	_mark_seen(ContentKind.Kind.SOUL, id)


## 魂器“首次进入任意容器”即记录；内部魂灵由 _scan_owned_item() 一并解锁
func mark_vessel_seen(vessel: SoulVesselData) -> void:
	if vessel == null:
		return
	var id: StringName = vessel.content_id
	if id.is_empty():
		push_warning("见闻：魂器没有 content_id「%s」" % vessel.item_name)
		return
	_mark_seen(ContentKind.Kind.VESSEL, id)


## 怪物“首次刷出”即记录；所有内容都由 ModLoader 写入 content_id
func mark_monster_seen(monster: MonsterData) -> void:
	if monster == null:
		return
	var id: StringName = monster.content_id
	if id.is_empty():
		push_warning("见闻：怪物没有 content_id「%s」" % monster.display_name)
		return
	_mark_seen(ContentKind.Kind.MONSTER, id)


## 永久解锁目录里的全部条目；返回是否新增了记录。
## 新增条目照常发 entry_unlocked，SaveManager 会立即写盘。
func unlock_all() -> bool:
	var changed := _unlock_kind(ContentKind.Kind.MONSTER, _monsters)
	changed = _unlock_kind(ContentKind.Kind.SOUL, _souls) or changed
	return _unlock_kind(ContentKind.Kind.VESSEL, _vessels) or changed
#endregion


#region 存档
## 供 SaveManager 序列化；数组里只放 canonical content_id
func to_save_data() -> Dictionary:
	return {
		"monsters": _seen_ids(ContentKind.Kind.MONSTER),
		"souls": _seen_ids(ContentKind.Kind.SOUL),
		"vessels": _seen_ids(ContentKind.Kind.VESSEL),
	}


## 用统一存档里的 collection 段覆盖当前状态；不触发解锁信号
func apply_save_data(data: Dictionary) -> void:
	_reset_seen()
	var monsters: Variant = data.get("monsters", [])
	if monsters is Array:
		for id in monsters:
			_seen[ContentKind.Kind.MONSTER][StringName(String(id))] = true
	var souls: Variant = data.get("souls", [])
	if souls is Array:
		for id in souls:
			_seen[ContentKind.Kind.SOUL][StringName(String(id))] = true
	var vessels: Variant = data.get("vessels", [])
	if vessels is Array:
		for id in vessels:
			_seen[ContentKind.Kind.VESSEL][StringName(String(id))] = true
	state_reloaded.emit()
#endregion


#region 内部
## 建立三个种类的空桶；必须在连接物品信号前调用。
func _reset_seen() -> void:
	_seen = {
		ContentKind.Kind.MONSTER: {},
		ContentKind.Kind.SOUL: {},
		ContentKind.Kind.VESSEL: {},
	}


func _load_catalog() -> void:
	for entry in ModLoader.get_soul_entries():
		var soul := entry.resource as SoulData
		if soul == null:
			push_warning("见闻：魂灵加载失败 %s" % entry.content_id)
			continue
		soul.content_id = entry.content_id
		_register_soul(entry.content_id, soul)

	for entry in ModLoader.get_monster_entries():
		var monster := entry.resource as MonsterData
		if monster == null:
			push_warning("见闻：怪物加载失败 %s" % entry.content_id)
			continue
		monster.content_id = entry.content_id
		_monsters[entry.content_id] = monster

	for entry in ModLoader.get_vessel_entries():
		var vessel := entry.resource as SoulVesselData
		if vessel == null:
			push_warning("见闻：魂器加载失败 %s" % entry.content_id)
			continue
		vessel.content_id = entry.content_id
		_vessels[entry.content_id] = vessel

	if _souls.is_empty() or _monsters.is_empty():
		push_warning("见闻：内容目录为空，检查内置 core mod 是否加载成功")
	_warn_duplicate_skill_ids()


func _register_soul(id: StringName, soul: SoulData) -> void:
	if _souls.has(id):
		push_warning("见闻：魂灵 ID 重复，已跳过 %s" % id)
		return
	_souls[id] = soul


## 两个资源共用同一个 skill.id 会让 Skill.<id> 的 ability tag 互相顶掉
func _warn_duplicate_skill_ids() -> void:
	var skill_sources: Dictionary[StringName, String] = {}
	for soul: SoulData in _souls.values():
		if soul == null or soul.skill == null or soul.skill.id.is_empty():
			continue
		var skill_id := StringName(soul.skill.id)
		var source: String = soul.skill.resource_path
		if source.is_empty():
			source = str(soul.skill.get_instance_id())
		if skill_sources.has(skill_id) and skill_sources[skill_id] != source:
			ModLoader.report_warning("技能 ID 重复「%s」（%s / %s）" % [
				skill_id,
				skill_sources[skill_id],
				source,
			])
			continue
		skill_sources[skill_id] = source


func _unlock_kind(kind: int, catalog: Dictionary) -> bool:
	var changed := false
	for id: StringName in catalog:
		if _seen.get(kind, {}).has(id):
			continue
		_mark_seen(kind, id)
		changed = true
	return changed


func _mark_seen(kind: int, id: StringName) -> void:
	if not _seen.has(kind):
		_seen[kind] = {}
	var seen: Dictionary = _seen[kind]
	if seen.has(id):
		return
	seen[id] = true
	entry_unlocked.emit(kind, id)


func _on_inv_item_added(_inv_name: String, item_data: ItemData, _grids: Array[Vector2i]) -> void:
	_scan_owned_item(item_data)


## 读档后背包里的魂灵不会重新发 add_item 信号，这里补扫一遍
func _scan_owned_souls_after_ready() -> void:
	await get_tree().process_frame
	_scan_owned_souls()


func _scan_owned_souls() -> void:
	for inv_name in GBIS.inventory_names:
		var container := ContainerRepository.instance.get_container(inv_name)
		if container == null:
			continue
		for item in container.items:
			_scan_owned_item(item)


## 魂灵本身、魂器本身和魂器内部的魂灵都算“已拥有”；魂器可能还没打开过窗口
func _scan_owned_item(item: ItemData) -> void:
	if item is SoulData:
		mark_soul_seen(item as SoulData)
	elif item is SoulVesselData:
		var vessel := item as SoulVesselData
		mark_vessel_seen(vessel)
		for inner in vessel.ensure_contents().items:
			_scan_owned_item(inner)


func _seen_ids(kind: int) -> Array[String]:
	var ids: Array[String] = []
	var seen: Dictionary = _seen.get(kind, {})
	for id: StringName in seen:
		ids.append(String(id))
	ids.sort()
	return ids
#endregion
