## 存档调度：脏标记、去抖、心跳。
##
## 由 SaveManager._process 每帧 tick；返回 true 表示这一帧应该写档。
## 只管时机，不碰文件与业务数据。
class_name SaveScheduler extends RefCounted

## 普通物品变化后延迟写盘，避免战斗掉落逐次写文件
const DEBOUNCE_SECONDS: float = 2.0
## 没有变化时也定期写一次，刷新 saved_at / play_time
const HEARTBEAT_SECONDS: float = 30.0

var _dirty: bool = false
var _urgent: bool = false
var _since_save: float = 0.0


## 数据变化；urgent 表示下次 tick 立即写（例如见闻解锁）
func mark_dirty(urgent: bool = false) -> void:
	_dirty = true
	_urgent = _urgent or urgent


## 每帧推进；can_save 为 false 时直接跳过本帧，不累计时间
func tick(delta: float, can_save: bool = true) -> bool:
	if not can_save:
		return false
	_since_save += delta
	if _dirty and (_urgent or _since_save >= DEBOUNCE_SECONDS):
		return true
	return _since_save >= HEARTBEAT_SECONDS


## 一次写档尝试开始：无论成败都重置计时与紧急标记，失败时脏标记保留
func begin_save() -> void:
	_since_save = 0.0
	_urgent = false


func on_saved() -> void:
	_dirty = false


## 读档/切场后整体复位
func reset() -> void:
	_dirty = false
	_urgent = false
	_since_save = 0.0


func is_dirty() -> bool:
	return _dirty
