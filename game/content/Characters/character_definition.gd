class_name CharacterDefinition
extends Resource
## 一个可选角色的静态定义：身份、显示名、立绘和战斗初始档案。
##
## 存档只记录 character_id 和 display_name；数值仍以这里的 PlayerProfile 为准，
## 这样 mod 调整角色数值不会改到旧档。

@export var id: StringName = &""
@export var display_name: String = ""
@export var portrait: Texture2D
@export var profile: PlayerProfile
