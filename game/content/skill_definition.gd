## 技能数据资源：一个技能 = 一份数据。
##
## 把"技能描述"翻译成这些字段；新增技能 = 新增一份 .tres，不改任何代码。
## 真正的能力节点是 AutoCastAbility（GameplayAbility 子类），这份资源只提供配置。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name SkillDefinition extends Resource

## 英文短 id（用于 ability_tag 等内部标识）
@export var id: String = ""

## 面向玩家的技能描述（与下面字段一一对应）
@export_multiline var description: String = ""

## 魂灵 tooltip 的技能段：每条一行，显示时统一加 "- " 前缀。
## 留空表示该技能不提供 tooltip 文案；魂灵没有技能段和触发段时正文显示「无」。
@export var tooltip_lines: Array[String] = []

## 施加到每个目标的效果列表（可多个：例如"伤害 + 中毒"）
@export var effects: Array[GameplayEffect] = []
## 只对施法者自己结算的效果列表（例如"攻击敌人的同时提高自身再生"）
@export var self_effects: Array[GameplayEffect] = []

## 冷却时长（秒）。魂灵使用充能模型：ChargedAbility 按 1/120 秒刻度累加，
## 充满后释放；这不是 GAS 的 DURATION 冷却效果。
@export_range(0.0, 60.0, 0.1) var cooldown_seconds: float = 0.0

## 暴击率（0~1）与暴击倍率；伤害和治疗共用
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.5

## 目标选择规则：
##   TargetRule      选战斗单位，使用 effects / projectile_scene
##   SoulTargetRule  选魂灵，使用 haste/slow/freeze/charge 时长
@export var target_rule: TargetRuleBase

## 加速/减速/冻结时长（秒）；0 = 不施加。只有 target_rule 是 SoulTargetRule 时才生效。
@export_range(0.0, 60.0, 0.1) var haste_duration: float = 0.0
@export_range(0.0, 60.0, 0.1) var slow_duration: float = 0.0
@export_range(0.0, 60.0, 0.1) var freeze_duration: float = 0.0

## 充能数值（秒）：直接给目标减少多少当前冷却；0 = 不充能。
@export_range(0.0, 60.0, 0.1) var charge_duration: float = 0.0

## 投射物场景。留空 = 选完目标立刻结算（比如治疗）；
## 填了 = 每个目标发一支，射向它"此刻"的坐标，飞到谁身上才算打中谁，
## 飞空了就是空了 —— 空箭是设计的一部分，不是 bug。
@export var projectile_scene: PackedScene

## 投射物飞行速度（像素/秒）；0 或负数使用投射物默认速度
@export var projectile_speed: float = 420.0

## 吟唱时间（秒）；0 = 瞬发。吟唱结束会重新选目标，避免对着尸体放大。
@export_range(0.0, 10.0, 0.1) var cast_time: float = 0.0

## 施法条件：身上必须同时持有这些标签才能放（例如"只在受伤时治疗"）。
## 内部翻译成 GameplayTagQuery.require_all_tags。
@export var cast_require_all_tags: Array[StringName] = []

## 施法条件：身上持有其中任意一个标签时拒绝施放。
## 内部翻译成 GameplayTagQuery.ignore_tags。
@export var cast_block_tags: Array[StringName] = []
