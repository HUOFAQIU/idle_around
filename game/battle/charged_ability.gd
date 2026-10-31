## 充能式能力：冷却按 1/120 秒的整数刻度累加，不用 delta。
##
## 60 FPS 下每物理帧基础 +2 刻度；加速 ×2、减速 ×0.5，两者同时存在时抵消。
## 加速/减速/冻结持续时间也用同一刻度，避免浮点误差。
## 外部充能直接调 add_charge(秒)，内部换算成刻度。
## 冻结分两种来源：魂灵自身的 freeze_units 计时，或所属单位带 State.Frozen 标签。
## 冻结期间由 BattleBrain 决定不充能、不释放，本类只提供 is_frozen() 查询。

class_name ChargedAbility extends GameplayAbility

## 1 秒 = 120 刻度；60 FPS 下每帧基础 2 刻度，减速 1 刻度，加速 4 刻度
const UNITS_PER_SECOND: int = 120
## 冻结标签；单位级冻结由 Freeze 效果挂/摘，魂灵级冻结用 freeze_units 计时
const FROZEN_TAG : StringName = GameplayTags.State_Frozen

## 冷却总时长（秒，数据仍用秒）
@export var cooldown: float = 0.0
## 当前充能（刻度）
var charge_units: int = 0

## 加速/减速剩余时间（刻度）；加速固定 2x、减速固定 0.5x，重复施加只累加时间
var haste_units: int = 0
var slow_units: int = 0
## 魂灵自身冻结剩余时间（刻度）；重复施加只累加时间
var freeze_units: int = 0

## 装备位置（玩家来自装备容器，怪物来自配置生成的虚拟魂灵栏；没有位置时为空 / -1）
var soul_container: String = ""
var soul_column: int = -1
var soul_width: int = 1
## 同一单位本场所有魂灵能力（用于左右/随机目标）
var soul_loadout: Array[ChargedAbility] = []


## 从冷却效果里读时长；传入 null 时冷却归零
func setup_cooldown_from_effect(effect: GameplayEffect) -> void:
	cooldown = effect.duration if effect != null else 0.0


func reset_charge() -> void:
	charge_units = 0


## 外部充能：传入秒数，内部换算成刻度
func add_charge(seconds: float) -> void:
	add_charge_units(_seconds_to_units(seconds))


## 直接加刻度（内部/测试用）
func add_charge_units(units: int) -> void:
	if cooldown <= 0.0:
		charge_units = 0
		return
	if units <= 0:
		return
	charge_units = mini(charge_units + units, _cooldown_units())


## 每物理帧自然充能；base_units 是 1x 下的每帧刻度（60 FPS 为 2）
func tick_charge(base_units: int) -> void:
	if cooldown <= 0.0 or base_units <= 0:
		return
	add_charge_units(_charged_units_for_tick(base_units))


## 施加加速；无冷却魂灵拒绝。已经在加速时只累加剩余时间，速率保持 2x。
func apply_haste(seconds: float) -> bool:
	if cooldown <= 0.0 or seconds <= 0.0:
		return false
	haste_units += _seconds_to_units(seconds)
	return true


## 施加减速；无冷却魂灵拒绝。已经在减速时只累加剩余时间，速率保持 0.5x。
func apply_slow(seconds: float) -> bool:
	if cooldown <= 0.0 or seconds <= 0.0:
		return false
	slow_units += _seconds_to_units(seconds)
	return true


## 施加魂灵冻结；无冷却魂灵拒绝。已经在冻结时只累加剩余时间。
func apply_freeze(seconds: float) -> bool:
	if cooldown <= 0.0 or seconds <= 0.0:
		return false
	freeze_units += _seconds_to_units(seconds)
	return true


## 状态计时：返回本次到期的状态名（用于打“结束”日志）
## 冻结期间也照常倒计时，加速/减速不受冻结影响。
func tick_status(base_units: int) -> Array[String]:
	var expired: Array[String] = []
	if base_units <= 0:
		return expired
	if haste_units > 0:
		haste_units = maxi(haste_units - base_units, 0)
		if haste_units == 0:
			expired.append("加速")
	if slow_units > 0:
		slow_units = maxi(slow_units - base_units, 0)
		if slow_units == 0:
			expired.append("减速")
	if freeze_units > 0:
		freeze_units = maxi(freeze_units - base_units, 0)
		if freeze_units == 0:
			expired.append("冻结")
	return expired


func has_haste() -> bool:
	return haste_units > 0


func has_slow() -> bool:
	return slow_units > 0


func is_ready() -> bool:
	return cooldown <= 0.0 or charge_units >= _cooldown_units()


## 是否处于冻结状态；魂灵自身冻结或所属单位冻结都算
func is_frozen() -> bool:
	if freeze_units > 0:
		return true
	return owner_asc != null and owner_asc.has_tag(FROZEN_TAG)


## 0 = 刚开始充能，1 = 充满
func charge_ratio() -> float:
	if cooldown <= 0.0:
		return 1.0
	var total := _cooldown_units()
	if total <= 0:
		return 1.0
	return clampf(float(charge_units) / float(total), 0.0, 1.0)


## 给 UI / 日志用的秒数
func charge_seconds() -> float:
	return float(charge_units) / float(UNITS_PER_SECOND)


func haste_seconds() -> float:
	return float(haste_units) / float(UNITS_PER_SECOND)


func slow_seconds() -> float:
	return float(slow_units) / float(UNITS_PER_SECOND)


func freeze_seconds() -> float:
	return float(freeze_units) / float(UNITS_PER_SECOND)


func _charged_units_for_tick(base_units: int) -> int:
	if has_haste() and has_slow():
		return base_units
	if has_haste():
		return base_units * 2
	if has_slow():
		return int(round(base_units * 0.5))
	return base_units


func _cooldown_units() -> int:
	if cooldown <= 0.0:
		return 0
	return maxi(int(round(cooldown * float(UNITS_PER_SECOND))), 1)


func _seconds_to_units(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	return int(round(seconds * float(UNITS_PER_SECOND)))
