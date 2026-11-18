extends RefCounted
## 命令解析：空格分隔，支持单双引号和反斜杠转义。


## 光标所在 token 的区间；token 含引号（含未闭合）时 quoted 为 true。
## 返回 {start, end, index, quoted, text}；caret 为负时按行尾处理。
static func token_at(line: String, caret: int = -1) -> Dictionary:
	var length := line.length()
	var pos := clampi(length if caret < 0 else caret, 0, length)
	var quote := ""
	var escaped := false
	var token_start := -1
	var token_end := -1
	var token_index := 0
	var quoted := false
	var index := 0
	var i := 0
	while i < length:
		var ch := line[i]
		if escaped:
			if token_start < 0:
				token_start = i
				token_index = index
			token_end = i + 1
			escaped = false
			i += 1
			continue
		if quote != "":
			quoted = true
			if ch == "\\":
				escaped = true
			elif ch == quote:
				quote = ""
			token_end = i + 1
			i += 1
			continue
		if ch == "\\":
			if token_start < 0:
				token_start = i
				token_index = index
			escaped = true
			token_end = i + 1
			i += 1
			continue
		if ch == "\"" or ch == "'":
			if token_start < 0:
				token_start = i
				token_index = index
			quoted = true
			quote = ch
			token_end = i + 1
			i += 1
			continue
		if ch == " " or ch == "\t":
			if token_start >= 0:
				if pos <= token_end:
					return _token_span(line, token_start, token_end, token_index, quoted)
				token_start = -1
				token_end = -1
				quoted = false
				index += 1
			elif pos == i:
				return _token_span(line, i, i, index, false)
			i += 1
			continue
		if token_start < 0:
			token_start = i
			token_index = index
			quoted = false
		token_end = i + 1
		i += 1
	if token_start >= 0:
		return _token_span(line, token_start, token_end, token_index, quoted)
	return _token_span(line, pos, pos, index, false)


static func parse(line: String) -> Dictionary:
	var args := PackedStringArray()
	var current := ""
	var quote := ""
	var started := false
	var escaped := false
	for ch in line.strip_edges():
		if escaped:
			current += ch
			escaped = false
			continue
		if ch == "\\":
			escaped = true
			continue
		if quote != "":
			if ch == quote:
				quote = ""
			else:
				current += ch
			continue
		if ch == "\"" or ch == "'":
			quote = ch
			started = true
			continue
		if ch == " " or ch == "\t":
			if started:
				args.append(current)
				current = ""
				started = false
			continue
		current += ch
		started = true
	if quote != "":
		return {"ok": false, "command": "", "args": PackedStringArray(), "error": "引号没有闭合"}
	if escaped:
		current += "\\"
	if started:
		args.append(current)
	if args.is_empty():
		return {"ok": true, "command": "", "args": PackedStringArray(), "error": ""}
	return {"ok": true, "command": args[0], "args": args.slice(1), "error": ""}


static func _token_span(
	line: String, start: int, end: int, index: int, quoted: bool
) -> Dictionary:
	return {
		"start": start,
		"end": end,
		"index": index,
		"quoted": quoted,
		"text": line.substr(start, end - start),
	}
