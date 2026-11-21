class_name VesselTooltip
extends RefCounted

const TYPE_LINE : String = "[ 魂器 ]"
const GRID_SEPARATOR_FORMAT : String = "==[ %d ][ %d ]======================="


static func build(
	vessel: SoulVesselData, format: TooltipText.Format = TooltipText.Format.PLAIN
) -> String:
	if vessel == null:
		return TooltipText.EMPTY_TEXT

	var lines := PackedStringArray()
	lines.append(TYPE_LINE)
	lines.append("")
	lines.append(TooltipText.SEPARATOR)
	var blocks := vessel.tooltip_blocks
	if blocks.is_empty():
		lines.append(TooltipText.EMPTY_TEXT)
	else:
		for i in blocks.size():
			if i > 0:
				lines.append(TooltipText.SEPARATOR)
			lines.append(blocks[i])
	lines.append("")
	lines.append(GRID_SEPARATOR_FORMAT % [vessel.container_columns, vessel.container_rows])
	lines.append_array(_grid_lines(vessel))
	lines.append(TooltipText.SEPARATOR)
	var body := "\n".join(lines)
	return TooltipText.render(body, format)


static func _grid_lines(vessel: SoulVesselData) -> PackedStringArray:
	var lines := PackedStringArray()
	var container := vessel.contents
	for column in vessel.container_columns:
		var cells := PackedStringArray()
		for row in vessel.container_rows:
			var item := container.find_item_data_by_grid(Vector2i(column, row)) if container != null else null
			cells.append(_cell_text(item))
		lines.append(" ".join(cells))
	return lines


static func _cell_text(item: ItemData) -> String:
	if item == null:
		return "*"
	if item.item_name.is_empty():
		return "#"
	return item.item_name.substr(0, 1)
