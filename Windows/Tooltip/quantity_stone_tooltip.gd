class_name QuantityStoneTooltip
extends RefCounted
## 数量石 tooltip 正文格式化器；标题「数量石」由 TooltipWindow 显示。

## 生成数量石 tooltip 正文（不含物品名）
static func build(
	stone: QuantityStoneData,
	format: TooltipText.Format = TooltipText.Format.PLAIN
) -> String:
	if stone == null:
		return TooltipText.EMPTY_TEXT

	var lines := PackedStringArray()
	for block in stone.tooltip_blocks:
		if not block.is_empty():
			lines.append(block)
	if lines.is_empty():
		lines.append(TooltipText.EMPTY_TEXT)
	return TooltipText.render("\n".join(lines), format)
