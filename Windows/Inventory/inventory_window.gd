extends BaseWindow

func _ready() -> void:
	super()
	title = "仓库窗口"

	GBIS.sig_item_focused.connect(
		func (item_data: ItemData, container_name: String):
			# 只有魂灵有正文；其他物品保持原来的单行标题提示
			var body := ""
			if item_data is SoulData:
				body = SoulTooltip.build(item_data as SoulData)
			TooltipWindow.instance.show_tip(self, TooltipWindow.Layer.ITEM, item_data.item_name, body)
	)
	GBIS.sig_item_focus_lost.connect(
		func (item_data: ItemData):
			TooltipWindow.instance.hide_tip(self)
	)
