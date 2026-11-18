extends RefCounted
## TestAPI 立方体外壳域：面内容、穿透、层级与交互。
##
## 对外入口仍是 res://Scripts/test_api.gd 的 TestAPI。

const COMMON: GDScript = preload("res://Scripts/test_api/common.gd")
const WINDOW: GDScript = preload("res://Scripts/test_api/window.gd")

static func set_cube_passthrough_enabled(enabled : bool) -> bool:
	var module := WindowPassthrough.instance
	if module == null:
		return false
	module.enabled = enabled
	return true


static func is_cube_passthrough_enabled() -> bool:
	var module := WindowPassthrough.instance
	return module != null and module.enabled


static func get_cube_passthrough_state() -> Dictionary:
	var module := WindowPassthrough.instance
	if module == null:
		return {}
	return {
		"enabled": module.enabled,
		"locked": module.is_locked(),
		"rects": module.get_hit_rects().size(),
		"polygon_points": module.get_polygon_points().size(),
	}


static func get_cube_state() -> Dictionary:
	if _cube_rig() == null:
		return {}
	var pivot := _cube_orientation()
	var camera := _cube_camera()
	var ui_face_viewport := _ui_face_viewport()
	return {
		"cube_scale": _cube_scale(),
		"screen_center": WINDOW.get_cube_screen_position(),
		"view_layer": _cube_view_layer(),
		"orientation": pivot.quaternion if pivot != null else Quaternion.IDENTITY,
		"front_face_index": _front_face_index(camera) if camera != null else -1,
		"ui_face_index": 1,
		"ui_face_viewport_size": (
				ui_face_viewport.size if ui_face_viewport != null else Vector2i.ZERO
		),
		"passthrough": get_cube_passthrough_state(),
	}


static func get_cube_layering_state() -> Dictionary:
	var surface := CubeInputSurface.instance
	if surface == null:
		return {}
	var cube_layer := _cube_view_layer()
	if cube_layer < 0:
		return {}

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {}
	var cube_view := tree.root.find_child("CubeView", true, false) as CanvasLayer
	var game_ui := tree.root.find_child("GameUI", true, false) as CanvasLayer
	var hud := tree.root.find_child("HUD", true, false) as CanvasLayer
	var tooltip := tree.root.find_child("TooltipLayer", true, false) as CanvasLayer
	var drag := tree.root.find_child("DragLayer", true, false) as CanvasLayer
	var rig := _cube_rig()
	var viewport := rig.get_viewport() if rig != null else null
	return {
		"cube_layer": cube_layer,
		"game_ui_layer": game_ui.layer if game_ui != null else -1,
		"hud_layer": hud.layer if hud != null else -1,
		"tooltip_layer": tooltip.layer if tooltip != null else -1,
		"drag_layer": drag.layer if drag != null else -1,
		"above_game_ui": game_ui != null and cube_layer > game_ui.layer,
		"above_hud": hud != null and cube_layer > hud.layer,
		"hud_above_cube": (
			hud != null and cube_view != null
			and (
				hud.layer > cube_view.layer
				or (
					hud.layer == cube_view.layer
					and hud.get_index() > cube_view.get_index()
				)
			)
		),
		"below_tooltip": tooltip != null and cube_layer < tooltip.layer,
		"below_drag_ghost": drag != null and cube_layer < drag.layer,
		"input_ready": surface.is_ready(),
		"hull_points": surface.get_hull_points().size(),
		"viewport_size": (
				Vector2i(viewport.get_visible_rect().size)
				if viewport != null
				else Vector2i.ZERO
		),
	}


static func set_cube_face_front(face_index : int) -> bool:
	var orientation := _cube_orientation()
	if orientation == null:
		return false
	return orientation.snap_face_to_camera(face_index)


static func get_cube_face_content(face_index : int) -> String:
	var content := face_content(face_index)
	return String(content.content_id()) if content != null else "unknown"


static func get_cube_face_lock_state(face_index : int) -> bool:
	return GameFlow.get_face_lock_state(face_index)


static func click_cube_face_button(face_index : int) -> bool:
	var face_ui := face_content(face_index) as FaceUI
	if face_ui == null:
		return false
	face_ui.identify_requested.emit()
	return true


static func click_cube_new_game() -> bool:
	var content := face_content(0) as SaveSlotsContent
	if content == null:
		return false
	content.activate_new_game()
	return true


static func click_cube_save_slot(slot: int) -> bool:
	var content := face_content(0) as SaveSlotsContent
	if content == null:
		return false
	return content.activate_slot(slot)


static func click_cube_delete_save_slot(slot: int) -> bool:
	var content := face_content(0) as SaveSlotsContent
	if content == null:
		return false
	return content.activate_delete(slot)


static func click_cube_character(character_id: StringName) -> bool:
	var content := face_content(3) as CharacterSelectContent
	if content == null:
		return false
	return content.activate_character(character_id)


static func click_cube_pet_button(panel_id: StringName) -> bool:
	var viewport := _ui_face_viewport()
	if viewport == null:
		return false
	var panel := viewport.find_child("PetPanel", true, false) as PetPanel
	if panel == null:
		return false
	return panel.press_button(panel_id)


static func _cube_rig() -> CubeRig:
	return COMMON.find_node_in_scene(CubeRig) as CubeRig


static func _cube_orientation() -> CubeOrientation:
	var rig := _cube_rig()
	if rig == null:
		return null
	return rig.get_node_or_null("OrientationPivot") as CubeOrientation


static func _cube_face(face_index : int) -> Face3D:
	var orientation := _cube_orientation()
	if orientation == null:
		return null
	for child in orientation.get_children():
		if child is Face3D and (child as Face3D).face_index == face_index:
			return child as Face3D
	return null


static func _cube_face_viewport(face_index : int) -> SubViewport:
	var face := _cube_face(face_index)
	if face == null:
		return null
	return face.get_node_or_null("Viewport") as SubViewport


## 05 面等内容节点；map 模块也用它走真实按钮流程
static func face_content(face_index : int) -> FaceContent:
	var viewport := _cube_face_viewport(face_index)
	if viewport == null:
		return null
	for child in viewport.get_children():
		if child is FaceContent:
			return child as FaceContent
	return null


static func _ui_face_viewport() -> SubViewport:
	return _cube_face_viewport(1)


static func _cube_scale() -> float:
	var rig := _cube_rig()
	if rig == null:
		return 0.0
	var cube := rig.get_parent() as Node3D
	if cube == null:
		return 0.0
	return cube.global_transform.basis.get_scale().x


static func _cube_camera() -> Camera3D:
	var rig := _cube_rig()
	if rig == null:
		return null
	return rig.get_viewport().get_camera_3d()


static func _cube_view_layer() -> int:
	var surface := CubeInputSurface.instance
	if surface == null:
		return -1
	var layer := surface.get_parent() as CanvasLayer
	return layer.layer if layer != null else -1


static func _front_face_index(camera : Camera3D) -> int:
	var orientation := _cube_orientation()
	if orientation == null:
		return -1
	var to_camera := (camera.global_position - orientation.global_position).normalized()
	var best_index := -1
	var best_alignment := -INF
	for child in orientation.get_children():
		if not child is Face3D:
			continue
		var face := child as Face3D
		var alignment := face.global_basis.z.normalized().dot(to_camera)
		if alignment > best_alignment:
			best_alignment = alignment
			best_index = face.face_index
	return best_index
