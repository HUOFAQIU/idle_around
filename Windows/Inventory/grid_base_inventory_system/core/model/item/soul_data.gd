extends ItemData
## 魂灵数据基类，你的魂灵数据类应该继承此类
class_name SoulData

## 这颗魂灵在战斗中提供的技能：冷却、范围、效果全写在这份数据里。
## 空着 = 装上去也不提供任何技能
@export var skill: SkillDefinition

## 可装备的部位；ANY = 不限
@export_enum("ANY", "HEADSOUL", "TORSOSOUL", "ARMSSOUL", "LEGSSOUL")
var equip_part: String = "ANY"

## 战斗显示用：加速/减速剩余秒数（0 = 没有）
var haste_seconds: float = 0.0
var slow_seconds: float = 0.0


## 由 BattleWindow 每帧写入；按 0.1 秒取整，变化时才触发重绘
func set_battle_status(haste: float, slow: float) -> void:
	var new_haste := snappedf(maxf(haste, 0.0), 0.1)
	var new_slow := snappedf(maxf(slow, 0.0), 0.1)
	if is_equal_approx(new_haste, haste_seconds) and is_equal_approx(new_slow, slow_seconds):
		return
	haste_seconds = new_haste
	slow_seconds = new_slow
	sig_refresh.emit()


## 战斗结束/重开时清零
func clear_battle_status() -> void:
	set_battle_status(0.0, 0.0)
