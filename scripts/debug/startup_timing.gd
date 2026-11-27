class_name StartupTiming extends RefCounted

static var _last_msec: int = 0


static func mark(label: String) -> void:
	var now := Time.get_ticks_msec()
	print("[启动] %s：+%d ms（累计 %d ms）" % [label, now - _last_msec, now])
	_last_msec = now
