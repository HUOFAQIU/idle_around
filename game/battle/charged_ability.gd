## 充能式能力：冷却不再用 GAS 的 DURATION 效果，而是按帧累加充能值。
##
## 每物理帧由 BattleBrain 调用 tick_charge() 做自然充能；外部充能直接调 add_charge()。
## 加速只乘 tick_charge()，不会放大外部充能。
## 冰冻等状态由外部决定是否调用 tick_charge / try_activate，本类不做判断。

class_name ChargedAbility extends GameplayAbility

## 冷却总时长（秒）
@export var cooldown: float = 0.0
## 当前充能（秒）
var charge: float = 0.0

## 加速剩余时间：加速期间充能固定 2x，重复施加只累加时间
var haste_remaining: float = 0.0

## 装备位置（只对玩家魂灵有效；没有位置时为空 / -1）
var soul_container: String = ""
var soul_column: int = -1
var soul_width: int = 1
## 同一单位本场所有魂灵能力（用于左右/随机目标）
var soul_loadout: Array[ChargedAbility] = []


## 从冷却效果里读时长；传入 null 时冷却归零
func setup_cooldown_from_effect(effect: GameplayEffect) -> void:
	cooldown = effect.duration if effect != null else 0.0


func reset_charge() -> void:
	charge = 0.0


func add_charge(amount: float) -> void:
	if cooldown <= 0.0:
		charge = 0.0
		return
	charge = minf(charge + amount, cooldown)


## 每物理帧的自然充能；加速只乘这里，外部 add_charge() 不受影响
func tick_charge(delta: float) -> void:
	if cooldown <= 0.0:
		return
	add_charge(delta * haste_multiplier())


## 施加加速；无冷却魂灵拒绝（等无冷却设计好再改）。
## 已经在加速时只把剩余时间加上去，速率保持 2x。
func apply_haste(duration: float) -> bool:
	if cooldown <= 0.0 or duration <= 0.0:
		return false
	haste_remaining += duration
	return true


## 状态计时：返回本次是否刚好到期（用于只打一次“结束”日志）
func tick_status(delta: float) -> bool:
	if haste_remaining <= 0.0:
		return false
	haste_remaining = maxf(haste_remaining - delta, 0.0)
	return haste_remaining <= 0.0


func has_haste() -> bool:
	return haste_remaining > 0.0


## 自然充能倍率：加速固定 2x，不随施加次数变化
func haste_multiplier() -> float:
	return 2.0 if has_haste() else 1.0


func is_ready() -> bool:
	return cooldown <= 0.0 or charge >= cooldown


## 0 = 刚开始充能，1 = 充满
func charge_ratio() -> float:
	if cooldown <= 0.0:
		return 1.0
	return clampf(charge / cooldown, 0.0, 1.0)
