## 技能数据资源：一个技能 = 一份数据。
##
## 把"技能描述"翻译成这些字段；新增技能 = 新增一份 .tres，不改任何代码。
## 真正的能力节点是 AutoCastAbility（GameplayAbility 子类），这份资源只提供配置。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name SkillDefinition extends Resource

## ability_tag 的后缀（不含 "Skill."），必须符合 GAS 标签格式。
## core 为 <PascalName>（如 XiaoLu），第三方为 Mod.<PascalModId>.<PascalName>。
## 留空时由 ModLoader 按魂灵 content_id 自动派生。
@export var id: String = ""

## 面向玩家的技能描述
@export_multiline var description: String = ""

## 只对施法者自己结算的效果列表（例如"攻击敌人的同时提高自身再生"）
@export var self_effects: Array[GameplayEffect] = []

## 冷却时长（秒）。魂灵使用充能模型：ChargedAbility 按 1/120 秒刻度累加，
## 充满后释放；这不是 GAS 的 DURATION 冷却效果。
@export_range(0.0, 60.0, 0.1) var cooldown_seconds: float = 0.0

## 多重触发：一次激活连续释放技能的次数。
## 每次释放重新选目标、独立判定暴击、独立结算自身效果；
## 第 2 次起各占一个 20 刻激活锁，1 秒最多 6 次，超出部分顺延到后续秒继续，不丢弃。
@export var cast_times: int = 1

## 暴击率（0~1）与暴击倍率；伤害和治疗共用
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.5

## 释放步骤；按数组顺序执行。
## 每一步自己决定目标域（单位/魂灵）、目标规则和效果。
@export var steps: Array[SkillStep] = []

## 吟唱时间（秒）；0 = 瞬发。吟唱结束才执行 steps，避免对着尸体放大。
@export_range(0.0, 10.0, 0.1) var cast_time: float = 0.0

## 施法条件：身上必须同时持有这些标签才能放（例如"只在受伤时治疗"）。
## 内部翻译成 GameplayTagQuery.require_all_tags。
@export var cast_require_all_tags: Array[StringName] = []

## 施法条件：身上持有其中任意一个标签时拒绝施放。
## 内部翻译成 GameplayTagQuery.ignore_tags。
@export var cast_block_tags: Array[StringName] = []
