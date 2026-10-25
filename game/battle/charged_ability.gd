## 充能式能力：冷却不再用 GAS 的 DURATION 效果，而是按帧累加充能值。
##
## 每 tick 由 BattleBrain 调用 add_charge()；充满后由大脑询问 is_ready()。
## 冰冻等状态由外部决定是否调用 add_charge / try_activate，本类不做判断。

class_name ChargedAbility extends GameplayAbility

## 冷却总时长（秒）
@export var cooldown: float = 0.0
## 当前充能（秒）
var charge: float = 0.0


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


func is_ready() -> bool:
	return cooldown <= 0.0 or charge >= cooldown


## 0 = 刚开始充能，1 = 充满
func charge_ratio() -> float:
	if cooldown <= 0.0:
		return 1.0
	return clampf(charge / cooldown, 0.0, 1.0)
