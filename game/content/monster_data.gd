## 怪物数据：图鉴与刷怪共用的一份资源。
##
## 场景（battle_scene）只负责战斗表现；名字、血量、掉落、携带魂灵都写在这里，
## 由刷怪方在实例化场景后注入 BattleUnit，避免场景和数据各存一份。
class_name MonsterData extends Resource

## 图鉴显示名，也是战斗中的头顶名字
@export var display_name: String = ""
## 图鉴图标
@export var icon: Texture2D
## 图鉴文案
@export_multiline var description: String = ""

## 血量上限（战斗时写入 ASC）
@export var max_health: float = 100.0
## 死亡掉落
@export var drops: Array[DropEntry] = []
## 携带的魂灵：图鉴展示用，战斗时由 BattleUnit 生成对应技能
@export var souls: Array[SoulData] = []
## 战斗时实例化的场景
@export var battle_scene: PackedScene
