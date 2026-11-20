class_name StartupTiming extends RefCounted
## 启动耗时打点（开发期）：以引擎启动为 0 点，输出到控制台（编辑器 Output 面板）。
##
## 调用点用 preload 引用，避免 --script 模式下全局类名解析不到；
## 同一进程内静态状态共享，各阶段间隔能串起来。

static var _last_msec: int = 0


## 打点并打印与上一次打点的间隔
static func mark(label: String) -> void:
	var now := Time.get_ticks_msec()
	print("[启动] %s：+%d ms（累计 %d ms）" % [label, now - _last_msec, now])
	_last_msec = now
