@tool
extends Control
## 视图刷新策略基类：脏标记 + 可见性合并。
##
## 数据变化只调用 [method mark_dirty]：视图可见时在本帧末合并重建一次，
## 隐藏时只记脏，等下次显示、布局结算后再重建。重建后清脏；没有脏标记时
## 显示只调用 [method _on_shown_without_refresh] 做轻量同步。
class_name RefreshableView

## 是否需要重建视图
var _dirty: bool = true
## 已排队本帧末重建，避免同一帧重复排队
var _refresh_queued: bool = false


## 数据已变化：可见时排一次本帧末重建，隐藏时等下次显示
func mark_dirty() -> void:
	_dirty = true
	if not is_visible_in_tree() or _refresh_queued:
		return
	_refresh_queued = true
	_refresh_if_dirty.call_deferred()


## 全量重建；子类覆写时先调用 super()，由基类清脏
func refresh() -> void:
	_dirty = false


## 显示但不需要重建时调用；子类可按需做轻量同步
func _on_shown_without_refresh() -> void:
	pass


## 可见性变化后的统一入口：等布局结算，再按脏标记重建或轻量同步
func _sync_after_show() -> void:
	await get_tree().process_frame
	if not is_visible_in_tree():
		return
	if _dirty:
		refresh()
	else:
		_on_shown_without_refresh()


## 重建排队的实际执行；排队期间视图被隐藏则保留脏标记
func _refresh_if_dirty() -> void:
	_refresh_queued = false
	if _dirty and is_visible_in_tree():
		refresh()
