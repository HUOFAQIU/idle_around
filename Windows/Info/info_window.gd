class_name InfoWindow
extends BaseWindow

## 全局唯一。战斗窗口左上角那颗 ☰ 就是开关它，别处要写信息直接 InfoWindow.instance
static var instance : InfoWindow

@onready var log_label: RichTextLabel = $LogPanel/LogLabel


func _ready() -> void:
	super()
	instance = self


## 加一行信息（战斗日志走这儿）
func append_line(line: String, color: String = "white") -> void:
	log_label.append_text("[color=%s]%s[/color]\n" % [color, line])


## 清空（每场战斗重开时用）
func clear_log() -> void:
	log_label.clear()


## 开/关：开着就收起来，关着就按 open_position 打开（没配就居中）
func toggle() -> void:
	if visible:
		hide()
		return
	open_window()
