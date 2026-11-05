class_name ClawSlashCue
extends GameplayCueNotify
## 恐狼命中：三道爪痕从一侧横扫到另一侧。
##
## 方向由技能通过 payload 传入：direction < 0 = 右→左，> 0 = 左→右。
## 技能侧按每颗魂灵自己的命中次数交替，所以这里不保存方向状态。
## 爪痕完全程序绘制，不依赖贴图。
##
## 致命一击时 Cue 会被挂到战场单位层（而不是马上要销毁的怪物），
## 这时 payload 带 position，painter 直接摆到怪物最后的位置。

## payload 里的方向键名；由 AutoCastAbility 填写
const DIRECTION_KEY : StringName = &"direction"
## payload 里的世界坐标键名；挂在战场单位层时由 AutoCastAbility 填写
const POSITION_KEY : StringName = &"position"

@onready var painter : ClawSlashPainter = $Slashes

var _direction : float = 1.0
var _world_position : Variant = null


## 基类不会把 payload 传给 play_cue，先在这里接住方向和位置
func execute_cue(target: Node, payload: Dictionary = {}) -> void:
	_direction = -1.0 if float(payload.get(DIRECTION_KEY, 1.0)) < 0.0 else 1.0
	_world_position = payload.get(POSITION_KEY, null)
	super.execute_cue(target, payload)


## 每次播放都从对象池捞出来，painter 自己负责复位和补间
func play_cue() -> void:
	painter.play(_direction)
	if _world_position is Vector2:
		painter.global_position = _world_position
