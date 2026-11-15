extends Node3D
## 主场景装配：立方体、面 02 主菜单和游戏 UI 覆盖层。
##
## 立方体渲染在 CubeView 的透明子视口里，由 CubeInputSurface 接管输入，
## 因此它始终压在游戏 UI 面板和 HUD 之上；菜单按钮请求在这里转给 game UI。

@onready var _cube_rig: CubeRig = get_node(CubeScenePaths.RIG)
@onready var _hud: CubeHud = $HUD
@onready var _game_ui: GameUI = $GameUI/GameControl
@onready var _pet_menu: PetPanelContent = get_node(CubeScenePaths.PET_MENU)
@onready var _placement: CubePlacement = $CubePlacement


func _ready() -> void:
	_cube_rig.face_identified.connect(_on_face_identified)
	_cube_rig.setup_placement(_placement)
	_pet_menu.panel_requested.connect(_game_ui.open_panel)
	_placement.apply_now()


func _on_face_identified(
		face_index: int,
		face_name: String,
		accent_color: Color,
) -> void:
	print("[立方体] 点击面 %d：%s" % [face_index + 1, face_name])
	_hud.show_face_identified(face_name, accent_color)
