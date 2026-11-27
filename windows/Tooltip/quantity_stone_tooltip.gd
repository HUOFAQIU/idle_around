class_name QuantityStoneTooltip
extends RefCounted

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
