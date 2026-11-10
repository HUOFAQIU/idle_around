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
## 常规刷怪权重；0 表示不参与常规随机刷怪，只能由特殊规则或测试刷出
@export_range(0.0, 100.0, 0.1) var spawn_weight: float = 1.0
## 稀有标记：不参与常规随机池，由 BattleWindow 每击杀 N 只常规怪后替换刷出。
## 稀有怪应同时把 spawn_weight 设为 0；死亡也不计入常规击杀数。
@export var is_rare: bool = false
## 携带的魂灵与各自的掉落几率；部位由魂灵自身的 equip_part 决定
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
