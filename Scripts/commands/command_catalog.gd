extends RefCounted
## 命令表：内置命令和域命令都在这里登记，终端、补全和 AI 共用。
##
## 新增命令时在这里登记 usage、summary、handler 和可选的 complete，并更新
## DOC/指南/命令控制台.md。

const BATTLE: GDScript = preload("res://Scripts/commands/actions/battle_actions.gd")
const INVENTORY: GDScript = preload("res://Scripts/commands/actions/inventory_actions.gd")
const MAP: GDScript = preload("res://Scripts/commands/actions/map_actions.gd")
const SAVE: GDScript = preload("res://Scripts/commands/actions/save_actions.gd")
const CUBE: GDScript = preload("res://Scripts/commands/actions/cube_actions.gd")
const DEBUG: GDScript = preload("res://Scripts/commands/actions/debug_actions.gd")
const COMPLETERS: GDScript = preload("res://Scripts/commands/command_completers.gd")

## 执行逻辑在 CommandRegistry.run() 里单独处理，元数据仍放在命令表
const BUILTIN_ENTRIES := {
	"help": {"usage": "help [command]", "summary": "列出命令或查看单条用法"},
	"clear": {"usage": "clear", "summary": "清空终端；AI 调用只返回 ok"},
	"echo": {"usage": "echo <text>", "summary": "原样回显；带空格的文本用引号"},
}

static var _entries: Dictionary = {}


static func entries() -> Dictionary:
	if _entries.is_empty():
		_entries = _build_entries()
	return _entries


static func builtin_entries() -> Dictionary:
	return BUILTIN_ENTRIES.duplicate(true)


## 内置命令 + 域命令；help 和补全都读这一份
static func all_entries() -> Dictionary:
	var result := builtin_entries()
	result.merge(entries(), true)
	return result


static func command_names() -> PackedStringArray:
	var names: Array = all_entries().keys()
	names.sort()
	return PackedStringArray(names)


## 命令元数据；内置命令也能查到，供 help 和补全抬头使用
static func get_entry(command: String) -> Dictionary:
	if BUILTIN_ENTRIES.has(command):
		return BUILTIN_ENTRIES[command]
	return entries().get(command, {})


static func _build_entries() -> Dictionary:
	return {
		"battle.start": {
			"usage": "battle.start [map_id]",
			"summary": "打开战斗窗口并开战；默认 forest_map",
			"handler": Callable(BATTLE, "start"),
			"complete": [Callable(COMPLETERS, "map_ids")],
		},
		"battle.stop": {
			"usage": "battle.stop",
			"summary": "结束当前战斗",
			"handler": Callable(BATTLE, "stop"),
		},
		"battle.state": {
			"usage": "battle.state",
			"summary": "当前战斗快照",
			"handler": Callable(BATTLE, "state"),
		},
		"battle.spawn": {
			"usage": "battle.spawn <monster_id>",
			"summary": "立刻刷一只怪",
			"handler": Callable(BATTLE, "spawn"),
			"complete": [Callable(COMPLETERS, "monster_ids")],
		},
		"battle.damage": {
			"usage": "battle.damage <target> <amount>",
			"summary": "对目标造成伤害；target 为 player/enemy/单位名",
			"handler": Callable(BATTLE, "damage"),
			"complete": [Callable(COMPLETERS, "damage_targets")],
		},
		"soul.list": {
			"usage": "soul.list",
			"summary": "列出所有魂灵 content_id",
			"handler": Callable(INVENTORY, "soul_list"),
		},
		"soul.add": {
			"usage": "soul.add <soul_id> [container]",
			"summary": "把魂灵放进容器；container 为空时放仓库",
			"handler": Callable(INVENTORY, "soul_add"),
			"complete": [Callable(COMPLETERS, "soul_ids")],
		},
		"map.list": {
			"usage": "map.list",
			"summary": "列出地图 id",
			"handler": Callable(MAP, "list"),
		},
		"map.add": {
			"usage": "map.add [map_id] [slot]",
			"summary": "把地图放到地图板；slot 省略时用第一个空槽",
			"handler": Callable(MAP, "add"),
			"complete": [
				Callable(COMPLETERS, "map_ids"),
				Callable(COMPLETERS, "map_slots"),
			],
		},
		"map.state": {
			"usage": "map.state",
			"summary": "地图板 8 个槽位和中心待放地图",
			"handler": Callable(MAP, "state"),
		},
		"map.start": {
			"usage": "map.start <slot>",
			"summary": "从地图板指定槽位开战",
			"handler": Callable(MAP, "start"),
			"complete": [Callable(COMPLETERS, "map_slots")],
		},
		"save.new": {
			"usage": "save.new [character_id]",
			"summary": "新游戏并占第一个空槽；默认小煤灯",
			"handler": Callable(SAVE, "new_game"),
			"complete": [Callable(COMPLETERS, "character_ids")],
		},
		"save.load": {
			"usage": "save.load <slot>",
			"summary": "走完整流程读取存档",
			"handler": Callable(SAVE, "load"),
			"complete": [Callable(COMPLETERS, "save_slots")],
		},
		"save.now": {
			"usage": "save.now",
			"summary": "立即保存当前活动槽",
			"handler": Callable(SAVE, "now"),
		},
		"cube.state": {
			"usage": "cube.state",
			"summary": "立方体朝向、缩放和层级快照",
			"handler": Callable(CUBE, "state"),
		},
		"debug.state": {
			"usage": "debug.state",
			"summary": "当前战斗调试快照",
			"handler": Callable(DEBUG, "state"),
		},
	}
