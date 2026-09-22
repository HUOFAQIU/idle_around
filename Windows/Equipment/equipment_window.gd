extends BaseWindow

@onready var panel: EquipmentPanel = $Panel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	title = "装备窗口"
	# 铺满窗口的一层：手上拖着的东西鼠标走到哪儿都看得见（不然只有魂灵区和装备槽会画它）
	add_child(DragOverlay.new())
