class_name BattleMobArchetype
extends Resource

@export_group("Identity & Visual")
## 怪物唯一标识（用于合批渲染键名）
@export var id: String = "rat"
## 怪物使用的 3D 网格模型（.res）
@export var mesh: Mesh
## 怪物模型显示缩放倍率
@export_range(0.4, 3.0, 0.02) var visual_scale: float = 1.0
## 受击火花与浮空血条的垂直高度偏移（米）
@export_range(0.1, 3.0, 0.05) var hit_height: float = 0.8
## 怪物死亡碎裂时飞散方块的基础颜色
@export var debris_color: Color = Color(0.6, 0.55, 0.45, 1.0)

@export_group("Combat Stats")
## 怪物第 1 波基础最大生命值（后续每波自动递增 14%）
@export_range(1.0, 1000.0, 1.0) var max_hp: float = 30.0
## 怪物向中心移动的速度（米/秒）
@export_range(0.5, 10.0, 0.05) var move_speed: float = 2.5
## 怪物每次攻击造成的伤害
@export_range(1.0, 100.0, 0.5) var damage: float = 5.0
## 怪物两次攻击之间的冷却时间（秒）
@export_range(0.2, 5.0, 0.05) var attack_cooldown: float = 1.0
## 怪物停下并开始攻击士兵的距离（米）
@export_range(0.5, 5.0, 0.05) var attack_reach: float = 1.2

@export_group("Spawning")
## 允许自然刷出该怪物的起始波次
@export_range(1, 20, 1) var unlock_wave: int = 1
