extends BaseWindow

func _ready() -> void:
	super()
	title = "仓库窗口"

	GBIS.sig_item_focused.connect(
		func (item_data: ItemData, container_name: String):
			TooltipWindow.instance.show_tip(self, TooltipWindow.Layer.ITEM, item_data.item_name)
	)
	GBIS.sig_item_focus_lost.connect(
		func (item_data: ItemData):
			TooltipWindow.instance.hide_tip(self)
	)
