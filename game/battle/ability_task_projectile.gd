## 发射一批投射物，等它们全部落地（或飞空）之后把结果交回去。
##
## 继承 AbilityTask 是为了白拿框架的生命周期：技能被打断、单位被销毁时，
## 这个任务会自动作废，不会留下一个永远等不到结果的 await。
##
## 结果只交一个**命中支数**，不交单位名单 —— 名单攥不住：箭是各自落地各自结算的，
## 先落地的那支可能当场把目标打死（节点被释放），等最后一支飞完再回头去读名单，
## 里面就躺着已释放的对象了。

class_name AbilityTask_Projectile extends AbilityTask

## 每支箭落地就发一次（打空了 hit_unit 是 null）。
##
## 技能那边一定要接这个、就地结算 —— 别等 task_finished 再统一结算：
## 目标远近不同，近的那支要白等远的那支飞完，看起来就是"明明打中了却不掉血"。
signal projectile_landed(hit_unit: BattleUnit)

## 有几支打中了东西（同一只被两支打中也算两支）
var _hit_count : int = 0
## 还有几支没落地
var _pending : int = 0


## targets 里每个单位都会被瞄准"此刻"的坐标射一支
func execute(
	caster: BattleUnit,
	targets: Array[BattleUnit],
	projectile_scene: PackedScene,
	speed: float = SoulProjectile.DEFAULT_SPEED
) -> void:
	if is_aborted:
		return
	if caster == null or projectile_scene == null or targets.is_empty():
		finish_task(0)
		return

	_hit_count = 0
	_pending = 0
	var parent := caster.get_parent()

	for target in targets:
		if target == null:
			continue
		var projectile := projectile_scene.instantiate() as SoulProjectile
		if projectile == null:
			continue
		parent.add_child(projectile)
		projectile.setup(caster, target.position, speed)
		projectile.finished.connect(_on_projectile_finished)
		_pending += 1

	if _pending == 0:
		finish_task(0)


func _on_projectile_finished(_projectile: SoulProjectile, hit_unit: BattleUnit) -> void:
	if hit_unit:
		_hit_count += 1
	# 先喊"这一下落地了"，再判断是不是最后一下 —— 结算不等人
	projectile_landed.emit(hit_unit)
	_pending -= 1
	if _pending <= 0 and not is_aborted:
		finish_task(_hit_count)
