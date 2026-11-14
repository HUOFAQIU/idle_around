class_name VesselTooltip
extends RefCounted
## 魂器 tooltip 正文格式化器。
##
## 标题（魂器名）由 TooltipWindow 显示，这里生成：
## [ 魂器 ] → 效果段落 → ==[ 列 ][ 行 ]== 分隔线 → 竖排文字网格。
## 网格按列从上到下输出，空格用 * 占位；一颗魂灵占几格就重复几次名字首字。
## format 决定输出纯文本、BBCode 还是终端 ANSI（统一走 TooltipText 色板）。

const TYPE_LINE : String = "[ 魂器 ]"
const GRID_SEPARATOR_FORMAT : String = "==[ %d ][ %d ]======================="


## 生成魂器 tooltip 正文（不含魂器名）
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


## 竖排网格：每一行输出一列，格子之间用空格隔开。
## 只读 vessel.contents，不调用 ensure_contents()：TestAPI 拿模板来格式化时
## 不能把运行期容器写回共享资源。
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


## 空格 = *；占用格显示魂灵名首字，多格魂灵在自己的每个格子上重复
static func _cell_text(item: ItemData) -> String:
	if item == null:
		return "*"
	if item.item_name.is_empty():
		return "#"
	return item.item_name.substr(0, 1)
