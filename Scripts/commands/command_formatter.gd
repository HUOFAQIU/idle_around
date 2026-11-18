extends RefCounted
## 终端显示格式：标量直接输出，Dictionary/Array 转 JSON。


static func format(value: Variant) -> PackedStringArray:
	if value == null:
		return PackedStringArray()
	if value is String:
		return String(value).split("\n")
	if value is bool or value is int or value is float:
		return PackedStringArray([str(value)])
	return JSON.stringify(_json_safe(value), "\t").split("\n")


static func _json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			result[String(key)] = _json_safe(value[key])
		return result
	if value is Array:
		var result := []
		for item in value:
			result.append(_json_safe(item))
		return result
	if value is StringName:
		return String(value)
	if value is Vector2:
		return [value.x, value.y]
	if value is Vector2i:
		return [value.x, value.y]
	if value is Rect2:
		return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Rect2i:
		return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Color:
		return value.to_html()
	return value
