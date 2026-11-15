class_name CubeScenePaths
extends RefCounted
## 主场景里立方体子树的规范路径（相对 Main 根节点）。
##
## CubeView 子视口、相机、CubeRig 和拖动圆点只在这里登记一次；
## CubePlacement / WindowPassthrough / CubeInputSurface 都通过 resolve()
## 解析。改 main.tscn 里的立方体子树时只改这份路径；cube.tscn 内部
## 拖动圆点的 CubeRig 路径仍由 cube_rig.gd 维护。

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


## 从 main.tscn 里的任意节点解析路径；动态实例用 current_scene 兜底
static func resolve(node: Node, path: NodePath) -> Node:
	var root := node.owner
	if root == null:
		var tree := node.get_tree()
		root = tree.current_scene if tree != null else null
	if root == null:
		return null
	return root.get_node_or_null(path)
