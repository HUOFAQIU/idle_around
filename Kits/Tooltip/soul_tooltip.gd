class_name SoulTooltip
extends TooltipBase

## 魂灵的提示框：版面就是 `soul_tooltip.tscn` 自己的样子（名字 + 冷却秒数 + 技能说明），
## 这里只负责把 `NameLabel` 换成这颗魂灵的名字。
##
## `CooldownLabel` / `TextLabel` 现在还是场景里写死的占位文字 —— 这两样数据工程里还没有：
## `Soul` 只有进度 `cd_progress`，时长还挂在 `SlotCell.cooldown_seconds` 上
## （那是**面板级**的，每颗魂灵不能各是各的）。等数据模型定下来再往这两个 Label 里填。


## 显示这颗魂灵的提示。anchor 是鼠标位置、bounds 是能占的地方（都是所在容器的坐标）
#func show_for(soul: Soul, anchor: Vector2, bounds: Vector2) -> void:
	#_name_label.text = soul.name
	#visible = true
	#place_near(anchor, bounds)
