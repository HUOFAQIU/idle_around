class_name GameColors
extends RefCounted

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

const STATUS := {
	"伤害": DAMAGE,
	"灼烧": BURN,
	"剧毒": POISON,
	"加速": HASTE,
	"减速": SLOW,
	"充能": CHARGE,
	"生命再生": REGEN,
	"治疗": HEAL,
	"暴击": CRIT,
	"暴击率": CRIT,
	"冻结": FREEZE,
	"护盾": SHIELD,
}
const STATUS_PATTERN : String = "生命再生|暴击率|灼烧|剧毒|治疗|护盾|冻结|加速|减速|充能|伤害|暴击"


const TEXT_PRIMARY : String = "#ffffff"
const TEXT_SECONDARY : String = "#a6abb3"
const TEXT_DISABLED : String = "#4d4d4d"
const TEXT_OUTLINE : String = "#000000"
const TEXT_OUTLINE_SOFT : String = "#000000d9"
const LOCKED_MODULATE : String = TEXT_DISABLED


const TOOLTIP_BG : String = "#11120d"
const TOOLTIP_BORDER : String = "#b1adac"
const PANEL_SEPARATOR : String = "#7d838c"
const WINDOW_TITLE_BAR : String = "#facc15"


const ACCENT : String = "#3ddc4a"
const ACCENT_TEXT : String = "#062b0a"
const SUCCESS : String = "#8cff99"
const WARNING : String = "#ffd959"
const DANGER : String = "#ff6659"
const INFO : String = "#8cccff"


const BAR_BORDER : String = "#000000bf"
const BAR_BG : String = "#380d0d"
const STATUS_BAR_BG : String = "#1f1f1a"
const HEALTH_FILL : String = "#66d973"
const HEALTH_FILL_ENEMY : String = "#e64d40"


const GRID_BORDER : String = "#808080"
const GRID_EMPTY : String = "#2f4f4f"
const GRID_TAKEN : String = "#778899"
const GRID_CONFLICT : String = "#cd5c5c"
const GRID_AVAILABLE : String = "#4682b4"
const GRID_AVAILABLE_SLOT : String = "#004d004d"
const GRID_UNAVAILABLE_SLOT : String = "#2a00004d"
const SOUL_NAME : String = "#ffffff"
const SOUL_NAME_OUTLINE : String = "#0d0d0de6"
const STACK_NUM : String = "#ffffff"
const STACK_NUM_COLOR : Color = Color.WHITE


const SOUL_LINE : String = "#8cd9ff"
const SOUL_FREEZE : String = "#94dbff"
const PLAYER_MODULATE : String = "#00e052"
const ENEMY_MODULATE : String = "#eb4d4d"
const PROJECTILE : String = "#ffd94d"
const CLAW_SLASH : String = "#fff1e0"
const POISON_SPLASH : String = "#2e8c3df2"
const FREEZE_BADGE_BG : String = "#52b3faeb"
const FREEZE_BADGE_BORDER : String = "#d1f0ff"


const DEBUG_TEXT : String = "#b3bfcc"
const DEBUG_HINT : String = "#a6b3bf"
const DEBUG_COUNTER : String = "#bfc7cc"
const DEBUG_NAME : String = "#d9d9d9"
const DEBUG_STATUS : String = "#66d9f2"
const DEBUG_HIGHLIGHT : String = "#66ff80"


const GROUPS := {
	"战斗状态": [
		"DAMAGE",
		"BURN",
		"POISON",
		"HASTE",
		"SLOW",
		"CHARGE",
		"REGEN",
		"HEAL",
		"CRIT",
		"FREEZE",
		"SHIELD",
	],
	"UI 文字": [
		"TEXT_PRIMARY",
		"TEXT_SECONDARY",
		"TEXT_DISABLED",
		"TEXT_OUTLINE",
		"TEXT_OUTLINE_SOFT",
		"LOCKED_MODULATE",
	],
	"面板 / 提示": [
		"TOOLTIP_BG",
		"TOOLTIP_BORDER",
		"PANEL_SEPARATOR",
		"WINDOW_TITLE_BAR",
	],
	"语义色": [
		"ACCENT",
		"ACCENT_TEXT",
		"SUCCESS",
		"WARNING",
		"DANGER",
		"INFO",
	],
	"血条 / 状态条": [
		"BAR_BORDER",
		"BAR_BG",
		"STATUS_BAR_BG",
		"HEALTH_FILL",
		"HEALTH_FILL_ENEMY",
	],
	"背包网格": [
		"GRID_BORDER",
		"GRID_EMPTY",
		"GRID_TAKEN",
		"GRID_CONFLICT",
		"GRID_AVAILABLE",
		"GRID_AVAILABLE_SLOT",
		"GRID_UNAVAILABLE_SLOT",
		"SOUL_NAME",
		"SOUL_NAME_OUTLINE",
		"STACK_NUM",
	],
	"魂灵 / 场景特效": [
		"SOUL_LINE",
		"SOUL_FREEZE",
		"PLAYER_MODULATE",
		"ENEMY_MODULATE",
		"PROJECTILE",
		"CLAW_SLASH",
		"POISON_SPLASH",
		"FREEZE_BADGE_BG",
		"FREEZE_BADGE_BORDER",
	],
	"调试面板": [
		"DEBUG_TEXT",
		"DEBUG_HINT",
		"DEBUG_COUNTER",
		"DEBUG_NAME",
		"DEBUG_STATUS",
		"DEBUG_HIGHLIGHT",
	],
}


static func to_color(hex: String) -> Color:
	return Color.html(hex)


static func status_color(display_name: String) -> String:
	return STATUS.get(display_name, TEXT_PRIMARY)


static func build_label_theme() -> Theme:
	var theme := Theme.new()
	theme.set_color("font_color", "Label", to_color(TEXT_PRIMARY))
	theme.set_color("font_outline_color", "Label", to_color(TEXT_OUTLINE_SOFT))
	return theme
