class_name CommandResult
extends RefCounted


static func ok(value: Variant = null) -> Dictionary:
	return {"ok": true, "value": value, "error": ""}


static func fail(error: String) -> Dictionary:
	return {"ok": false, "value": null, "error": error}
