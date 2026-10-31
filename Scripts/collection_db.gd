extends Node
## 见闻图鉴服务（Autoload 名称：CollectionDB）。
##
## 全量清单来自两份 YARD registry：魂灵和怪物各一份，编辑器扫目录自动维护。
## 本节点只负责运行时索引、“已遇见”状态和存档；registry 本身运行时只读。
##
## 已遇见状态以 registry 的字符串 ID（例如 &"xiao_lu_soul"）为键，
## 资源改名/移动不会丢记录；解锁后立即写入 user://collection.cfg。

## 新条目解锁；图鉴窗口用它刷新
signal entry_unlocked(kind: int, id: StringName)

enum Kind {
	MONSTER,
	SOUL,
}

const SOUL_REGISTRY: Registry = preload("res://game/content/Collection/soul_registry.tres")
const MONSTER_REGISTRY: Registry = preload("res://game/content/Collection/monster_registry.tres")
const SAVE_PATH: String = "user://collection.cfg"
## 测试期开关：见闻条目全部默认解锁；正式上线前改回 false。
## 只影响显示，不写存档，关掉后按真实解锁进度显示。
## 测试接口可用 set_unlock_all_for_testing() 临时切换。
var unlock_all_for_testing: bool = true

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
	_load_state()
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
	return _souls.get(id)


func get_monster(id: StringName) -> MonsterData:
	return _monsters.get(id)


func is_seen(kind: int, id: StringName) -> bool:
	if unlock_all_for_testing:
		return true
	var seen: Dictionary = _seen.get(kind, {})
	return seen.has(id)


## 测试接口：临时切换“全部已解锁”，不改存档
func set_unlock_all_for_testing(enabled: bool) -> void:
	unlock_all_for_testing = enabled


## 真实已解锁的 registry ID（不受测试开关影响）
func get_seen_ids(kind: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	var seen: Dictionary = _seen.get(kind, {})
	ids.assign(seen.keys())
	return ids


## 随机挑一只配了战斗场景的怪物；刷怪用它
func pick_random_monster() -> MonsterData:
	var candidates: Array[MonsterData] = []
	for monster in _monsters.values():
		if monster != null and monster.battle_scene != null:
			candidates.append(monster)
	if candidates.is_empty():
		return null
	return candidates.pick_random()


## 魂灵“首次获得”即记录。入包信号给的是副本，按 item_name 反查 registry ID
func mark_soul_seen(soul: SoulData) -> void:
	if soul == null:
		return
	var id: StringName = _soul_id_by_name.get(soul.item_name, &"")
	if id.is_empty():
		return
	_mark_seen(Kind.SOUL, id)


## 怪物“首次刷出”即记录
func mark_monster_seen(monster: MonsterData) -> void:
	if monster == null:
		return
	var id := MONSTER_REGISTRY.get_string_id_of(monster)
	if id.is_empty():
		return
	_mark_seen(Kind.MONSTER, id)
#endregion


#region 内部
func _load_catalog() -> void:
	for id: StringName in SOUL_REGISTRY.get_all_string_ids():
		var soul := SOUL_REGISTRY.load_entry(id) as SoulData
		if soul == null:
			push_warning("见闻：魂灵加载失败 %s" % id)
			continue
		_souls[id] = soul
		if _soul_id_by_name.has(soul.item_name):
			push_warning("见闻：魂灵物品名重复「%s」" % soul.item_name)
		_soul_id_by_name[soul.item_name] = id

	for id: StringName in MONSTER_REGISTRY.get_all_string_ids():
		var monster := MONSTER_REGISTRY.load_entry(id) as MonsterData
		if monster == null:
			push_warning("见闻：怪物加载失败 %s" % id)
			continue
		_monsters[id] = monster


func _mark_seen(kind: int, id: StringName) -> void:
	var seen: Dictionary = _seen[kind]
	if seen.has(id):
		return
	seen[id] = true
	save_state()
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


func _load_state() -> void:
	_seen = {
		Kind.MONSTER: {},
		Kind.SOUL: {},
	}
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for id in config.get_value("collection", "monsters", PackedStringArray()):
		_seen[Kind.MONSTER][StringName(id)] = true
	for id in config.get_value("collection", "souls", PackedStringArray()):
		_seen[Kind.SOUL][StringName(id)] = true


func save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("collection", "monsters", _seen_ids(Kind.MONSTER))
	config.set_value("collection", "souls", _seen_ids(Kind.SOUL))
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("见闻：存档写入失败 %s" % error_string(err))


func _seen_ids(kind: int) -> PackedStringArray:
	var ids := PackedStringArray()
	var seen: Dictionary = _seen.get(kind, {})
	for id: StringName in seen:
		ids.append(String(id))
	return ids
#endregion
