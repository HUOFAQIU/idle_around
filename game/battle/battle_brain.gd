## 自动施法大脑：充能模型。
##
## 每个单位一个大脑，每物理帧：
##   1. 先给所有能力结算状态（加速/减速）和自然充能（按 1/120 秒刻度）
##   2. 再按魂灵栏从左到右的顺序，把充满的能力放出去
##   3. 最后结算本帧由触发器充能满的“待释放”能力（同帧释放，保持队列顺序）
## 门卫（can_activate_ability）负责花费、施法条件标签、是否正在施法等检查。
##
## 基础刻度 = 120 / physics_ticks_per_second：
## 60 FPS 时每帧 2 刻度；减速 1 刻度，加速 4 刻度。
## 先充能再统一释放：本帧新加的加速，下一帧才影响充能，避免连锁施法。
## 冻结期间：单位级冻结（State.Frozen）或魂灵级冻结（freeze_units）都不充能、
## 不释放；外部充能（Charge 效果）仍然可以直接调用 add_charge() 把充能加满，
## 解冻后下一帧立刻释放。加速/减速计时在冻结期间照常走。
##
## 触发充能同帧释放，但受 ChargedAbility.ACTIVATION_LOCK_UNITS（20 刻 = 1/6 秒）
## 限制：同一颗魂灵 1 秒最多激活 6 次，允许“你触发我、我触发你”，但不会无限递归。
##
## 实时制：怪物在角色攻击范围外时，BattleManager 不会开启本大脑 ——
## 魂灵根本不开始冷却（见 DOC/战斗/战斗逻辑.md）。移动由 BattleManager 统一驱动。
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name BattleBrain extends Node

## 冻结标签；唯一来源在 ChargedAbility，这里保留别名方便阅读
const FROZEN_TAG : StringName = ChargedAbility.FROZEN_TAG
## 单帧待释放队列的安全上限（20 刻激活锁是主限制，这里只防异常递归）
const MAX_PENDING_ACTIVATIONS_PER_FRAME : int = 64

var unit: BattleUnit
## 本单位的技能（AutoCastAbility 节点，已授予给 ASC）
var abilities: Array[GameplayAbility] = []

## 本帧由触发器充能满、等待统一释放的能力；每颗最多入队一次
var _pending_activations: Array[ChargedAbility] = []
## 待释放能力对应的因果链（能力实例 id → CombatTrace）
var _pending_traces: Dictionary = {}
## 正在 flush，防止 flush 中再次调度
var _flushing : bool = false


## 直接挂一个能力（不走 SkillDefinition 的，比如移动）。
## 先写 owner_asc：GameplayAbility._ready() 看到 owner_asc 已设置就不会重复 grant。
func add_ability(ability: GameplayAbility) -> void:
	ability.owner_asc = unit.asc
	unit.asc.grant_ability(ability)
	abilities.append(ability)


## 开局：所有能力从 0 开始充能
func begin_charge() -> void:
	_pending_activations.clear()
	_pending_traces.clear()
	for ability in abilities:
		var charged := ability as ChargedAbility
		if charged:
			charged.reset_charge()
			charged.reset_activation_lock()


## 外部（触发器）充能满足条件后，登记到本帧待释放队列。
## 真正的释放由本 Brain 的物理帧末或 BattleManager 的 tick 末统一 flush，保持确定顺序。
func request_activation(ability: ChargedAbility, trace: CombatTrace = null) -> void:
	if ability == null or not abilities.has(ability):
		return
	if unit == null or not is_instance_valid(unit) or unit.is_dead:
		return
	if unit.battle == null or not is_instance_valid(unit.battle) or not unit.battle.is_running:
		return
	if not ability.is_ready() or ability.is_frozen() or ability.is_active:
		return
	if not ability.can_activate_now():
		return
	if _pending_activations.has(ability):
		return
	_pending_activations.append(ability)
	for runtime in unit.loadout:
		if runtime != null and runtime.ability == ability:
			unit.battle.events.emit_event(BattleEvent.CATEGORY_SOUL, "pending", {
				"actor_unit": unit,
				"soul": runtime.display_name(),
				"ability": ability.ability_name,
				"trace": trace,
			}, BattleEvent.IMPORTANCE_DETAIL)
			break
	if trace != null:
		_pending_traces[ability.get_instance_id()] = trace
	# 真正释放由本 Brain 的物理帧末或 BattleManager 的 tick 末统一 flush；
	# flush 过程中新入队的由 while 循环直接处理，不需要再调度。


## 本帧待释放队列：按入队顺序释放，期间新触发的继续往后接。
## 由本 Brain 的物理帧末或 BattleManager 的 tick 末调用；后者覆盖跨单位触发器。
## 20 刻激活锁负责防止同一颗魂灵无限连发；这里的上限只防异常递归。
func flush_pending_activations() -> void:
	if _pending_activations.is_empty() or _flushing:
		return
	if unit == null or not is_instance_valid(unit) or unit.is_dead:
		_pending_activations.clear()
		_pending_traces.clear()
		return
	if unit.battle == null or not is_instance_valid(unit.battle) or not unit.battle.is_running:
		_pending_activations.clear()
		_pending_traces.clear()
		return
	# 和主循环同一套门控：怪物在攻击范围外不放
	if unit.team == BattleUnit.Team.ENEMY and unit.battle.player != null:
		if not unit.is_in_attack_range(unit.battle.player):
			_pending_activations.clear()
			_pending_traces.clear()
			return
	# 单位级冻结：本帧整体不放；充能保持，解冻后由主循环处理
	if unit.asc == null or unit.asc.has_tag(FROZEN_TAG):
		_pending_activations.clear()
		_pending_traces.clear()
		return

	_flushing = true
	var guard := 0
	while not _pending_activations.is_empty():
		guard += 1
		if guard > MAX_PENDING_ACTIVATIONS_PER_FRAME:
			push_warning("BattleBrain：单帧待释放队列超过上限，丢弃剩余请求")
			_pending_activations.clear()
			_pending_traces.clear()
			break
		var ability: ChargedAbility = _pending_activations.pop_front()
		var trace: CombatTrace = _pending_traces.get(ability.get_instance_id()) if ability != null else null
		if ability != null:
			_pending_traces.erase(ability.get_instance_id())
		if ability == null or not is_instance_valid(ability):
			continue
		if ability.is_frozen() or ability.is_active or not ability.is_ready():
			continue
		if not ability.can_activate_now():
			continue
		if not unit.asc.can_activate_ability(ability):
			unit.battle.events.emit_event(BattleEvent.CATEGORY_SOUL, "flush_skip", {
				"actor_unit": unit,
				"ability": ability.ability_name,
				"detail": "ASC 门卫拒绝",
				"trace": trace,
			}, BattleEvent.IMPORTANCE_DETAIL)
			continue
		@warning_ignore("missing_await")
		ability.try_activate(trace)  # 开火即忘；激活锁在 AutoCastAbility._activate_ability() 里扣
	_flushing = false


func _physics_process(_delta: float) -> void:
	if unit == null or unit.battle == null or unit.battle.clock == null:
		return
	if unit.battle.clock.manual:
		return
	advance()


## 推进一个固定 tick：状态/充能、释放与当帧待释放队列。
func advance() -> void:
	if unit == null or unit.is_dead or unit.battle == null or not unit.battle.is_running:
		return
	# 兜底：怪物在攻击范围外不跑大脑（正常由 BattleManager 直接关掉物理帧）
	if unit.team == BattleUnit.Team.ENEMY and unit.battle.player != null:
		if not unit.is_in_attack_range(unit.battle.player):
			return

	var frozen := unit.asc.has_tag(FROZEN_TAG)
	# 步长来自 BattleClock，不读渲染/物理 delta；
	# 掉帧时引擎补跑的 tick 也按同一 tick_seconds 计算刻度。
	var base_units := int(round(
		float(ChargedAbility.UNITS_PER_SECOND) * unit.battle.tick_seconds()
	))

	# 第一段：所有魂灵先结算状态和自然充能。
	# 先充能再统一释放，避免“左边一放加速、右边同一帧连锁放”。
	for ability in abilities:
		var charged := ability as ChargedAbility
		if charged == null:
			continue
		charged.tick_activation_lock(base_units)
		charged.tick_status(base_units)
		# 单位级冻结或魂灵自身冻结时都不充能；吟唱等施法过程不阻塞冷却
		if not frozen and not charged.is_frozen():
			charged.tick_charge(base_units)

	if frozen:
		return

	# 第二段：按数组顺序释放 —— 数组已按魂灵栏从左到右排好
	for ability in abilities:
		if unit.is_dead or unit.battle == null or not unit.battle.is_running:
			return
		var charged := ability as ChargedAbility
		if charged != null and (
			charged.is_frozen()
			or not charged.is_ready()
			or not charged.can_activate_now()
		):
			continue
		if unit.asc.can_activate_ability(ability):
			@warning_ignore("missing_await")
			ability.try_activate()  # 开火即忘，技能内部自己 await

	# 第三段：本帧触发充能满的魂灵同帧释放（保持入队顺序）
	flush_pending_activations()
