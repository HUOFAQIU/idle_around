class_name CubeScenePaths
extends RefCounted

const VIEWPORT := ^"CubeView/ViewportContainer/CubeViewport"
const CAMERA := ^"CubeView/ViewportContainer/CubeViewport/Camera3D"
const CUBE := ^"CubeView/ViewportContainer/CubeViewport/Cube"
const RIG := ^"CubeView/ViewportContainer/CubeViewport/Cube/CubeRig"
const ORIENTATION := ^"CubeView/ViewportContainer/CubeViewport/Cube/CubeRig/OrientationPivot"
const DRAG_HANDLE := ^"CubeView/ViewportContainer/CubeViewport/Cube/DragHandle/Dot"
const PLACEMENT := ^"CubePlacement"
const SAVE_SLOTS := NodePath(
		"CubeView/ViewportContainer/CubeViewport/Cube/CubeRig/OrientationPivot/Front/"
		+ "Viewport/SaveSlotsContent"
)
const CHARACTER_SELECT := NodePath(
		"CubeView/ViewportContainer/CubeViewport/Cube/CubeRig/OrientationPivot/Right/"
		+ "Viewport/CharacterSelectContent"
)
const PET_MENU := NodePath(
		"CubeView/ViewportContainer/CubeViewport/Cube/CubeRig/OrientationPivot/Back/"
		+ "Viewport/PetPanelContent"
)
const MAP_BOARD := NodePath(
		"CubeView/ViewportContainer/CubeViewport/Cube/CubeRig/OrientationPivot/Top/"
		+ "Viewport/MapBoardContent"
)


static func resolve(node: Node, path: NodePath) -> Node:
	var root := node.owner
	if root == null:
		var tree := node.get_tree()
		root = tree.current_scene if tree != null else null
	if root == null:
		return null
	return root.get_node_or_null(path)
