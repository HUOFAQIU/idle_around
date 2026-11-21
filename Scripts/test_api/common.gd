extends RefCounted

static func scene_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


static func find_node_in_scene(type : Variant, node_name : StringName = &"") -> Node:
	var root := scene_root()
	if root == null:
		return null
	for node in root.find_children("*", "", true, false):
		if not is_instance_of(node, type):
			continue
		if node_name != &"" and node.name != node_name:
			continue
		return node
	return null


static func show_window(window : BaseWindow) -> bool:
	if window == null:
		return false
	var manager := PanelManager.instance
	if manager == null:
		return false
	manager.open(window)
	return true


static func find_unit(target : String) -> BattleUnit:
	var root := scene_root()
	if root == null:
		return null
	for node in root.find_children("*", "", true, false):
		if not node is BattleUnit:
			continue
		var unit := node as BattleUnit
		if unit.is_dead or unit.asc == null:
			continue
		if target == "player" and unit.team == BattleUnit.Team.PLAYER:
			return unit
		if target == "enemy" and unit.team == BattleUnit.Team.ENEMY:
			return unit
		if unit.unit_name == target:
			return unit
	return null
