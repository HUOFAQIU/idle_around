extends RefCounted
## 命令 handler 的公共参数校验；失败时直接返回 CommandResult 字典。


static func require(args: PackedStringArray, count: int, usage: String) -> Dictionary:
	if args.size() < count:
		return CommandResult.fail("参数不足\nusage: %s" % usage)
	return CommandResult.ok()


static func int_arg(text: String, usage: String) -> Dictionary:
	if not text.is_valid_int():
		return CommandResult.fail("不是整数：%s\nusage: %s" % [text, usage])
	return CommandResult.ok(int(text))


static func float_arg(text: String, usage: String) -> Dictionary:
	if not text.is_valid_float():
		return CommandResult.fail("不是数字：%s\nusage: %s" % [text, usage])
	return CommandResult.ok(float(text))
