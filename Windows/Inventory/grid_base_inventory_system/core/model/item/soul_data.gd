extends ItemData
## 魂灵数据基类，你的魂灵数据类应该继承此类
class_name SoulData

## 扫描线进度（0~1）；战斗窗口每帧写入，ItemView 直接更新自己的材质
signal sig_scanline_progress(value: float)

## 这颗魂灵在战斗中提供的技能：冷却、范围、效果全写在这份数据里。
## 空着 = 装上去也不提供任何技能
@export var skill: SkillDefinition

## 魂灵触发规则；主动魂灵和被动魂灵都可以配
@export var triggers: Array[PassiveTrigger] = []

## 图鉴文案（本项目扩展）；主动魂灵留空时，图鉴回退到 skill.description
@export_multiline var description: String = ""

## 魂灵标签：用于让特定触发效果只识别特定魂灵（例：Soul.RealEstate）
@export var tags: Array[StringName] = []

## 可装备的部位；ANY = 不限
@export_enum("ANY", "HEADSOUL", "TORSOSOUL", "ARMSSOUL", "LEGSSOUL")
var equip_part: String = "ANY"

## 战斗显示用：加速/减速/冻结剩余秒数（0 = 没有）
var haste_seconds: float = 0.0
var slow_seconds: float = 0.0
var freeze_seconds: float = 0.0
## 战斗显示用：扫描线进度（0 = 刚触发，1 = 充满）
var scanline_progress: float = 0.0


## 由 BattleWindow 每帧写入；按 0.1 秒取整，变化时才触发重绘
func set_battle_status(haste: float, slow: float, freeze: float = 0.0) -> void:
	var new_haste := snappedf(maxf(haste, 0.0), 0.1)
	var new_slow := snappedf(maxf(slow, 0.0), 0.1)
	var new_freeze := snappedf(maxf(freeze, 0.0), 0.1)
	if (
		is_equal_approx(new_haste, haste_seconds)
		and is_equal_approx(new_slow, slow_seconds)
		and is_equal_approx(new_freeze, freeze_seconds)
	):
		return
	haste_seconds = new_haste
	slow_seconds = new_slow
	freeze_seconds = new_freeze
	sig_refresh.emit()


## 战斗结束/重开时清零
func clear_battle_status() -> void:
	set_battle_status(0.0, 0.0, 0.0)


## 扫描线进度：直接通知已存在的 ItemView 更新材质，
## 不走 set_shader_param() 的字典复制 + sig_refresh 全量重绘。
func set_scanline_progress(value: float) -> void:
	var new_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(new_value, scanline_progress):
		return
	scanline_progress = new_value
	sig_scanline_progress.emit(new_value)
