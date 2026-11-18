class_name CommandResult
extends RefCounted
## 命令统一返回：terminal 和 AI 探针都读 {ok, value, error}。


static func ok(value: Variant = null) -> Dictionary:
	return {"ok": true, "value": value, "error": ""}


static func fail(error: String) -> Dictionary:
	return {"ok": false, "value": null, "error": error}
