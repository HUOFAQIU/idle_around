class_name InfoWindow
extends BaseWindow

## 战斗日志最多保留这么多行，超出从顶部删，避免长时间挂机无限增长
const MAX_LOG_LINES: int = 500

## 全局唯一。战斗窗口左上角那颗 ☰ 就是开关它，别处要写信息直接 InfoWindow.instance
static var instance : InfoWindow

@onready var log_label: RichTextLabel = $LogPanel/LogLabel


func _ready() -> void:
	super()
	instance = self
	title = "战斗信息"


## 加一行信息（战斗日志走这儿）；超过上限时裁掉最旧的行
func append_line(line: String, color: String = "white") -> void:
	log_label.append_text("[color=%s]%s[/color]\n" % [color, line])
	while log_label.get_paragraph_count() > MAX_LOG_LINES:
		# 每行都是一个自带闭合标签的完整段落，删掉不影响后面的段落缓存。
		# no_invalidate 不能省：窗口可见时默认会重排剩余全部段落，500 行下每来一条日志都会卡一下。
		log_label.remove_paragraph(0, true)


## 清空（每场战斗重开时用）
func clear_log() -> void:
	log_label.clear()


## 开/关：开着就收起来，关着就按 open_position 打开（没配就居中）
func toggle() -> void:
	if visible:
		hide()
		return
	open_window()
