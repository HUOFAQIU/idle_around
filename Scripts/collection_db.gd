extends Node
## 见闻图鉴服务（Autoload 名称：CollectionDB）。
##
## 全量清单来自两份 YARD registry：魂灵和怪物各一份，编辑器扫目录自动维护。
## 本节点只负责运行时索引、“已遇见”状态和存档；registry 本身运行时只读。
##
## 已遇见状态以 registry 的字符串 ID（例如 &"xiao_lu_soul"）为键，
## 资源改名/移动不会丢记录；解锁后由 SaveManager 统一写入存档。

## 新条目解锁；图鉴窗口用它刷新
signal entry_unlocked(kind: int, id: StringName)
## 读档整体替换“已遇见”状态后发出；图鉴窗口用它整体刷新
signal state_reloaded

enum Kind {
	MONSTER,
	SOUL,
}

const SOUL_REGISTRY: Registry = preload("res://game/content/Collection/soul_registry.tres")
const MONSTER_REGISTRY: Registry = preload("res://game/content/Collection/monster_registry.tres")
## 旧版独立存档：只读迁移用；新存档由 SaveManager 统一管理
const LEGACY_SAVE_PATH: String = "user://collection.cfg"
## 旧版 registry ID 兼容：旧存档里可能还留着带 _2 后缀的键。
## 读取时统一映射到当前 canonical ID，写回时只写 canonical ID。
const LEGACY_SOUL_ID_ALIASES := {
	&"du_ya_soul_2": &"du_ya_soul",
	&"hua_liu_shen_soul_2": &"hua_liu_shen_soul",
}
## 测试开关：见闻条目是否全部按已解锁显示；默认关闭。
## 只影响显示，不写存档；调试窗口/TestAPI 可以临时切换。
var unlock_all_for_testing: bool = false

## registry 字符串 ID → 资源
var _souls: Dictionary[StringName, SoulData] = {}
var _monsters: Dictionary[StringName, MonsterData] = {}
## item_name → registry ID。
## GBIS.add_item() 会 duplicate() 物品，副本没有 resource_path，
## 所以收到入包信号时不能靠 UID 反查，只能靠物品名。
var _soul_id_by_name: Dictionary[String, StringName] = {}
## 已遇见：Kind → { registry ID: true }
var _seen: Dictionary = {}


func _ready() -> void:
	_load_catalog()
	GBIS.sig_inv_item_added.connect(_on_inv_item_added)
	GBIS.sig_inv_refresh.connect(_scan_owned_souls)
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
	return _souls.get(_canonical_soul_id(id))


## 按物品名反查 registry ID；背包里的副本没有 resource_path，只能用名字
func get_soul_id_by_name(item_name: String) -> StringName:
	return _soul_id_by_name.get(item_name, &"")


func get_monster(id: StringName) -> MonsterData:
	return _monsters.get(id)


func is_seen(kind: int, id: StringName) -> bool:
	if unlock_all_for_testing:
		return true
	var seen: Dictionary = _seen.get(kind, {})
	return seen.has(_canonical_id(kind, id))


## 测试接口：临时切换“全部已解锁”，不改存档
func set_unlock_all_for_testing(enabled: bool) -> void:
	unlock_all_for_testing = enabled


## 真实已解锁的 registry ID（不受测试开关影响）
func get_seen_ids(kind: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	var seen: Dictionary = _seen.get(kind, {})
	ids.assign(seen.keys())
	return ids


## 从常规刷怪池里按 spawn_weight 随机挑一只；权重 0 的怪只走特殊规则
func pick_random_monster() -> MonsterData:
	var candidates: Array[MonsterData] = []
	var total_weight: float = 0.0
	for monster in _monsters.values():
		if monster == null or monster.battle_scene == null or monster.spawn_weight <= 0.0:
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


## 魂灵“首次获得”即记录。入包信号给的是副本，优先用副本携带的 content_id
func mark_soul_seen(soul: SoulData) -> void:
	if soul == null:
		return
	var id: StringName = soul.content_id
	if id.is_empty():
		id = _soul_id_by_name.get(soul.item_name, &"")
	if id.is_empty():
		return
	_mark_seen(Kind.SOUL, id)


## 怪物“首次刷出”即记录；mod 怪物没有 YARD registry，靠 content_id
func mark_monster_seen(monster: MonsterData) -> void:
	if monster == null:
		return
	var id: StringName = monster.content_id
	if id.is_empty():
		id = MONSTER_REGISTRY.get_string_id_of(monster)
	if id.is_empty():
		return
	_mark_seen(Kind.MONSTER, id)
#endregion


#region 存档
## 供 SaveManager 序列化；数组里只放 canonical registry ID
func to_save_data() -> Dictionary:
	return {
		"monsters": _seen_ids(Kind.MONSTER),
		"souls": _seen_ids(Kind.SOUL),
	}


## 用统一存档里的 collection 段覆盖当前状态；不触发解锁信号
func apply_save_data(data: Dictionary) -> void:
	_seen = {
		Kind.MONSTER: {},
		Kind.SOUL: {},
	}
	var monsters: Variant = data.get("monsters", [])
	if monsters is Array:
		for id in monsters:
			_seen[Kind.MONSTER][StringName(String(id))] = true
	var souls: Variant = data.get("souls", [])
	if souls is Array:
		for id in souls:
			_seen[Kind.SOUL][_canonical_soul_id(StringName(String(id)))] = true
	state_reloaded.emit()


## 读取旧版 user://collection.cfg；成功返回 true（只读，不删除旧文件）
func load_legacy_state() -> bool:
	_seen = {
		Kind.MONSTER: {},
		Kind.SOUL: {},
	}
	var config := ConfigFile.new()
	if config.load(LEGACY_SAVE_PATH) != OK:
		return false
	for id in config.get_value("collection", "monsters", PackedStringArray()):
		_seen[Kind.MONSTER][StringName(id)] = true
	for id in config.get_value("collection", "souls", PackedStringArray()):
		_seen[Kind.SOUL][_canonical_soul_id(StringName(id))] = true
	state_reloaded.emit()
	return true
#endregion


#region 内部
func _load_catalog() -> void:
	for id: StringName in SOUL_REGISTRY.get_all_string_ids():
		var soul := SOUL_REGISTRY.load_entry(id) as SoulData
		if soul == null:
			push_warning("见闻：魂灵加载失败 %s" % id)
			continue
		soul.content_id = id
		_register_soul(id, soul)

	for id: StringName in MONSTER_REGISTRY.get_all_string_ids():
		var monster := MONSTER_REGISTRY.load_entry(id) as MonsterData
		if monster == null:
			push_warning("见闻：怪物加载失败 %s" % id)
			continue
		monster.content_id = id
		_monsters[id] = monster

	_merge_mod_catalog()
	_warn_duplicate_skill_ids()


func _register_soul(id: StringName, soul: SoulData) -> void:
	_souls[id] = soul
	if _soul_id_by_name.has(soul.item_name):
		push_warning("见闻：魂灵物品名重复「%s」（%s / %s）" % [
			soul.item_name,
			_soul_id_by_name[soul.item_name],
			id,
		])
	_soul_id_by_name[soul.item_name] = id


## 把 ModLoader 收集的运行时条目合并进图鉴/刷怪目录
func _merge_mod_catalog() -> void:
	for entry in ModLoader.get_soul_entries():
		if _souls.has(entry.content_id):
			ModLoader.report_warning("mod 魂灵 ID 与原版冲突，已跳过 %s" % entry.content_id)
			continue
		var soul := entry.resource as SoulData
		if soul == null:
			continue
		soul.content_id = entry.content_id
		_register_soul(entry.content_id, soul)

	for entry in ModLoader.get_monster_entries():
		if _monsters.has(entry.content_id):
			ModLoader.report_warning("mod 怪物 ID 与原版冲突，已跳过 %s" % entry.content_id)
			continue
		var monster := entry.resource as MonsterData
		if monster == null:
			continue
		monster.content_id = entry.content_id
		_monsters[entry.content_id] = monster


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


func _mark_seen(kind: int, id: StringName) -> void:
	var seen: Dictionary = _seen[kind]
	if seen.has(id):
		return
	seen[id] = true
	entry_unlocked.emit(kind, id)


func _on_inv_item_added(_inv_name: String, item_data: ItemData, _grids: Array[Vector2i]) -> void:
	if item_data is SoulData:
		mark_soul_seen(item_data as SoulData)


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
			if item is SoulData:
				mark_soul_seen(item as SoulData)


func _seen_ids(kind: int) -> Array[String]:
	var ids: Array[String] = []
	var seen: Dictionary = _seen.get(kind, {})
	for id: StringName in seen:
		ids.append(String(id))
	ids.sort()
	return ids


func _canonical_id(kind: int, id: StringName) -> StringName:
	return _canonical_soul_id(id) if kind == Kind.SOUL else id


func _canonical_soul_id(id: StringName) -> StringName:
	return LEGACY_SOUL_ID_ALIASES.get(id, id)
#endregion
