## 技能数据资源：一个技能 = 一份数据。
##
## 把"技能描述"翻译成这些字段；新增技能 = 新增一份数据，不改任何代码。
## 生产项目里把这些字段做成 .tres 资源给策划配，本案例为了单文件可读改为代码构造。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name SkillDefinition extends Resource

## 英文短 id（用于 ability_tag 等内部标识）
@export var id: String = ""

## 面向玩家的技能描述（与下面字段一一对应）
@export_multiline var description: String = ""

## 施加到每个目标的效果列表（可多个：例如"伤害 + 中毒"）
@export var effects: Array[GameplayEffect] = []

## 冷却效果（释放间隔）：DURATION 效果 + granted_tags 里放"冷却标签"。
## 开局 BattleBrain.begin_charge() 会给每个技能挂上它 —— 倒计时走完前，
## 门卫（can_activate_ability）会因冷却标签而拒绝释放；标签一脱落即可释放。
## 释放时 commit_ability() 会重新挂上，进入下一轮冷却 → 本质是"释放间隔 X 秒"。
## UI 可调用 asc.get_tag_duration_remaining(标签) 读剩余秒数画倒计时。
## 字段名与框架 GameplayAbility.cooldown_effect 保持一致，不做重命名。
@export var cooldown_effect: GameplayEffect

## 目标选择规则
@export var target_rule: TargetRule

## 投射物场景。留空 = 选完目标立刻结算（比如治疗）；
## 填了 = 每个目标发一支，射向它"此刻"的坐标，飞到谁身上才算打中谁，
## 飞空了就是空了 —— 空箭是设计的一部分，不是 bug。
@export var projectile_scene: PackedScene

## 吟唱时间（秒）；0 = 瞬发。吟唱结束会重新选目标，避免对着尸体放大。
@export_range(0.0, 10.0, 0.1) var cast_time: float = 0.0

## 施法条件：身上必须有其中任意一个标签才能放（例如"只在受伤时治疗"）。
## 内部会被翻译成 GameplayAbility.activation_query，由框架的门卫统一检查。
@export var cast_requires_tags: Array[StringName] = []
