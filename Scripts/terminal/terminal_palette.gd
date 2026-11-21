class_name TerminalPalette
extends RefCounted

const DEFAULT_FG: String = "#e5e5e5"
const DEFAULT_BG: String = "#0a0a0a"

const COLORS: Array[String] = [
	"#0a0a0a", "#f85149", "#22c55e", "#eab308",
	"#3b82f6", "#a855f7", "#06b6d4", "#e5e5e5",
	"#525252", "#ff7b72", "#4ade80", "#facc15",
	"#60a5fa", "#c084fc", "#22d3ee", "#fafafa",
]


static func color(index: int) -> Color:
	return Color.html(COLORS[clampi(index, 0, COLORS.size() - 1)])


static func color_256(index: int) -> Color:
	if index < 16:
		return color(index)
	if index < 232:
		var value := index - 16
		var red := floori(value / 36.0)
		var green := floori((value % 36) / 6.0)
		var blue := value % 6
		return Color8(_cube_level(red), _cube_level(green), _cube_level(blue))
	if index < 256:
		var level := 8 + (index - 232) * 10
		return Color8(level, level, level)
	return color(7)


static func default_fg() -> Color:
	return Color.html(DEFAULT_FG)


static func default_bg() -> Color:
	return Color.html(DEFAULT_BG)


static func _cube_level(value: int) -> int:
	return 0 if value == 0 else 55 + value * 40
