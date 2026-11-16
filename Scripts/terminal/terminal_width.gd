class_name TerminalWidth
extends RefCounted
## 终端字符宽度表：1 = 单宽，2 = 双宽（CJK/全角/emoji），0 = 组合字符。
##
## 只覆盖终端常见范围，不追求完整 Unicode wcwidth。组合字符目前被 Buffer 跳过，
## emoji ZWJ 序列、区域旗帜等复合字形也还没做组合渲染。

## 组合字符、变体选择符、零宽连接符等：不占格
const ZERO_WIDTH_RANGES: Array[Vector2i] = [
	Vector2i(0x0300, 0x036F), # Combining Diacritical Marks
	Vector2i(0x0483, 0x0489), # Cyrillic combining
	Vector2i(0x0591, 0x05BD), # Hebrew combining
	Vector2i(0x0610, 0x061A), # Arabic combining
	Vector2i(0x064B, 0x065F),
	Vector2i(0x0670, 0x0670),
	Vector2i(0x06D6, 0x06DC),
	Vector2i(0x06DF, 0x06E4),
	Vector2i(0x06E7, 0x06E8),
	Vector2i(0x06EA, 0x06ED),
	Vector2i(0x0900, 0x0903), # Devanagari combining
	Vector2i(0x093A, 0x094F),
	Vector2i(0x0E31, 0x0E31), # Thai
	Vector2i(0x0E34, 0x0E3A),
	Vector2i(0x0E47, 0x0E4E),
	Vector2i(0x1160, 0x11FF), # Hangul Jamo medial/final
	Vector2i(0x1AB0, 0x1AFF),
	Vector2i(0x1DC0, 0x1DFF),
	Vector2i(0x200B, 0x200F), # zero-width space/joiners
	Vector2i(0x202A, 0x202E),
	Vector2i(0x2060, 0x206F),
	Vector2i(0x20D0, 0x20FF),
	Vector2i(0xFE00, 0xFE0F), # variation selectors
	Vector2i(0xFE20, 0xFE2F),
	Vector2i(0xFEFF, 0xFEFF),
	Vector2i(0x1F3FB, 0x1F3FF), # skin tone modifiers
	Vector2i(0xE0100, 0xE01EF), # variation selectors supplement
]

## 双宽范围：CJK、全角、Hangul、emoji
const WIDE_RANGES: Array[Vector2i] = [
	Vector2i(0x1100, 0x115F), # Hangul Jamo leading
	Vector2i(0x2E80, 0x303E), # CJK radicals / Kangxi / punctuation
	Vector2i(0x3041, 0x33FF), # Hiragana / Katakana / Bopomofo / Hangul compat / CJK compat
	Vector2i(0x3400, 0x4DBF), # CJK Extension A
	Vector2i(0x4E00, 0x9FFF), # CJK Unified Ideographs
	Vector2i(0xA000, 0xA4CF), # Yi
	Vector2i(0xA960, 0xA97F), # Hangul Jamo Extended-A
	Vector2i(0xAC00, 0xD7A3), # Hangul Syllables
	Vector2i(0xF900, 0xFAFF), # CJK Compatibility Ideographs
	Vector2i(0xFE10, 0xFE19), # Vertical forms
	Vector2i(0xFE30, 0xFE6F), # CJK Compatibility Forms
	Vector2i(0xFF00, 0xFF60), # Fullwidth Forms
	Vector2i(0xFFE0, 0xFFE6), # Fullwidth signs
	Vector2i(0x1F000, 0x1FAFF), # emoji / symbols
	Vector2i(0x20000, 0x2FFFD), # CJK Extension B–F
	Vector2i(0x30000, 0x3FFFD), # CJK Extension G+
]


static func columns(code: int) -> int:
	if code < 0x0300:
		return 1
	if _in_ranges(code, ZERO_WIDTH_RANGES):
		return 0
	if code < 0x1100:
		return 1
	if _in_ranges(code, WIDE_RANGES):
		return 2
	return 1


static func _in_ranges(code: int, ranges: Array[Vector2i]) -> bool:
	for allowed_range in ranges:
		if code < allowed_range.x:
			continue
		if code <= allowed_range.y:
			return true
	return false
