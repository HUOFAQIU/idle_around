## 战斗调试因果链。
##
## 一次施法/触发/效果施加创建一个 trace；它派生的效果、周期 tick、触发器、
## 充能都用 child() 挂在下面，调试窗口据此还原“谁导致谁”。
##
## 只保存 id 和原因，不持有 Node 引用；事件里也只存 id。
class_name CombatTrace extends RefCounted

## 全局自增 id：不在每场战斗重置，避免旧事件和新事件撞号
static var _next_id: int = 1

var id: int = 0
var parent_id: int = 0
var root_id: int = 0
var cause: String = ""
var created_msec: int = 0


func _init(p_cause: String = "", parent: CombatTrace = null) -> void:
	id = _next_id
	_next_id += 1
	cause = p_cause
	created_msec = Time.get_ticks_msec()
	if parent != null:
		parent_id = parent.id
		root_id = parent.root_id
	else:
		root_id = id


## 派生一个子 trace；父 trace 的 root_id 会一路继承
func child(p_cause: String) -> CombatTrace:
	return CombatTrace.new(p_cause, self)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"parent_id": parent_id,
		"root_id": root_id,
		"cause": cause,
	}
