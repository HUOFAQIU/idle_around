extends Node3D
## 主场景装配：立方体、面 02 主菜单和游戏 UI 覆盖层。
##
## 游戏 UI 仍在主视口全屏覆盖层里；立方体只承接原来 PetPanel 的浮层职责，
## 菜单按钮请求在这里转给 game UI。

@onready var _cube_rig: CubeRig = $Cube/CubeRig
@onready var _hud: CubeHud = $HUD
@onready var _game_ui: GameUI = $GameUI/GameControl
@onready var _pet_menu: PetPanelContent = (
		$Cube/CubeRig/OrientationPivot/Back/Viewport/PetPanelContent
)
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
