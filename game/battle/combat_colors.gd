class_name CombatColors
extends RefCounted
## 全局状态色板：tooltip、战斗日志、飘字、状态条共用这一份。
##
## 颜色统一用 HTML 十六进制字符串保存；需要 Color 的地方用 to_color() 转换。
## 状态显示名和颜色的对应关系见 STATUS，tooltip 的关键词正则也用这一份。

const DAMAGE : String = "#f5503d"
const BURN : String = "#ff9f45"
const POISON : String = "#0ebe4f"
const HASTE : String = "#00ecc3"
const SLOW : String = "#cb9f6e"
const CHARGE : String = "#00ecc3"
const REGEN : String = "#8eea31"
const HEAL : String = "#8eea31"
const CRIT : String = "#f5503d"
const FREEZE : String = "#3fc8f7"
const SHIELD : String = "#f4cf20"

## 显示名 → 颜色。tooltip 和战斗日志共用这一份。
const STATUS := {
	"伤害": DAMAGE,
	"灼烧": BURN,
	"剧毒": POISON,
	"加速": HASTE,
	"减速": SLOW,
	"充能": CHARGE,
	"生命再生": REGEN,
	"再生": REGEN,
	"治疗": HEAL,
	"暴击": CRIT,
	"暴击率": CRIT,
	"冻结": FREEZE,
	"护盾": SHIELD,
}
## tooltip 关键词匹配用；长词在前，避免「生命再生」「暴击率」被拆开
const STATUS_PATTERN : String = "生命再生|暴击率|灼烧|剧毒|治疗|护盾|冻结|加速|减速|充能|伤害|暴击|再生"


static func to_color(hex: String) -> Color:
	return Color.html(hex)


static func status_color(display_name: String) -> String:
	return STATUS.get(display_name, "white")
