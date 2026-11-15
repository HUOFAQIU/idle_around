class_name TerminalPalette
extends RefCounted
## 终端 16 色 ANSI 调色板与默认前景/背景。
##
## 颜色值与参考网页 how-terminals-work 保持一致；换主题只改这里。
## 索引 0-7 是普通色，8-15 是亮色；bold 是否提亮由调用方决定。

const DEFAULT_FG: String = "#e5e5e5"
const DEFAULT_BG: String = "#0a0a0a"

const COLORS: Array[String] = [
	"#0a0a0a", "#f85149", "#22c55e", "#eab308",
	"#3b82f6", "#a855f7", "#06b6d4", "#e5e5e5",
	"#525252", "#ff7b72", "#4ade80", "#facc15",
	"#60a5fa", "#c084fc", "#22d3ee", "#fafafa",
]


## 取 0-15 号 ANSI 颜色；越界自动夹到端点
static func color(index: int) -> Color:
	return Color.html(COLORS[clampi(index, 0, COLORS.size() - 1)])


## 256 色扩展：0-15 用现有 16 色，16-231 是 6×6×6 色立方，232-255 是灰阶
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
