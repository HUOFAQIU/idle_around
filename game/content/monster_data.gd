## 怪物数据：图鉴与刷怪共用的一份资源。
##
## 场景（battle_scene）只负责碰撞体与节点结构；名字、血量、攻击范围、移速、
## 贴图、掉落、携带魂灵都写在这里，由刷怪方在实例化场景后注入 BattleUnit。
class_name MonsterData extends Resource

## 运行期稳定 ID：由 ModLoader 从 manifest 写入（core 沿用原 ID）。
## 由 CollectionDB / ModLoader 写入；不要在资源里手填。
@export_storage var content_id: StringName = &""

## 图鉴显示名，也是战斗中的头顶名字
@export var display_name: String = ""
## 图鉴图标，也用作战斗贴图（推荐 AtlasTexture）
@export var icon: Texture2D

## 血量上限（战斗时写入 ASC）
@export var max_health: float = 100.0
## 攻击范围（像素，圆心到圆心）
@export_range(0.0, 1000.0, 0.1) var attack_range: float = 30.0
## 移动速度（像素/秒）
@export_range(0.0, 1000.0, 0.1) var move_speed: float = 11.0
## 可用的刷新距离（格）；刷怪时从这些距离环的格子中合并随机选一格。
## 默认 [3]；ModLoader 要求非空且每个距离 >= 1。
@export var spawn_distances: Array[int] = [3]
## 携带的魂灵与各自的掉落几率；战斗时按列表顺序生成虚拟魂灵栏
@export var soul_entries: Array[MonsterSoulEntry] = []
## 战斗时实例化的场景
@export var battle_scene: PackedScene


## 按配置顺序取出魂灵，交给 SoulLoadout 生成技能
func soul_list() -> Array[SoulData]:
	var result : Array[SoulData] = []
	for entry in soul_entries:
		if entry != null and entry.soul != null:
			result.append(entry.soul)
	return result


## 每颗携带的魂灵都是一条掉落：死亡时逐条独立掷骰
func drop_entries() -> Array[DropEntry]:
	var result : Array[DropEntry] = []
	for entry in soul_entries:
		if entry == null or entry.soul == null:
			continue
		var drop := DropEntry.new()
		drop.item = entry.soul
		drop.chance = entry.drop_chance
		result.append(drop)
	return result
