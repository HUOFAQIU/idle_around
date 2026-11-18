extends Node
## 当前游戏会话与立方体流程（Autoload：GameFlow）。
##
## 只管理「现在处于哪个阶段、活动槽、活动角色」和面锁定结果；
## 存档读写交给 SaveManager，立方体翻面/面内容由 main.gd 按信号接线。
## 启动不自动读档：默认 NO_SESSION，停在 01 面选档。

signal state_changed(state: int)
signal slots_changed
signal active_character_changed(character: CharacterDefinition)
signal face_focus_requested(face_index: int)
signal toast_requested(text: String)
## 切档/新游戏前发出；main.gd 用它结束当前战斗并关闭旧面板
signal session_will_change

enum State {
	NO_SESSION,
	CHARACTER_SELECT,
	IN_GAME,
}

const FACE_ENTRY: int = 0
const FACE_MENU: int = 1
const FACE_CHARACTER: int = 3
const FACE_MAP: int = 4

var _state: State = State.NO_SESSION
var _active_character: CharacterDefinition
var _profile: PlayerProfile


func _ready() -> void:
	SaveManager.slot_list_changed.connect(_on_slot_list_changed)
	SaveManager.active_slot_changed.connect(_on_active_slot_changed)


#region 公共接口
## 01 面「新游戏」：满槽提示；已在游戏中则先保存当前档，再进角色选择
func request_new_game() -> void:
	if SaveManager.first_empty_slot() < 0:
		toast_requested.emit("角色已满")
		return
	if not _prepare_session_change():
		return
	if _state == State.IN_GAME and not _save_current_before_switch():
		return
	if _state != State.CHARACTER_SELECT:
		_set_state(State.CHARACTER_SELECT)
	face_focus_requested.emit(FACE_CHARACTER)


## 04 面选角：在第一个空槽创建新档并进入 02 面
func create_new_game(character_id: StringName) -> bool:
	if _state != State.CHARACTER_SELECT:
		return false
	var character := CharacterCatalog.get_by_id(character_id)
	if character == null:
		push_warning("GameFlow：未知角色 %s" % character_id)
		return false
	var slot := SaveManager.first_empty_slot()
	if slot < 0:
		toast_requested.emit("角色已满")
		return false
	var player_data := {
		"character_id": character.id,
		"display_name": character.display_name,
	}
	if not SaveManager.create_new_game(slot, player_data):
		toast_requested.emit("无法创建存档")
		return false
	_set_active_character(character)
	_set_state(State.IN_GAME)
	face_focus_requested.emit(FACE_MENU)
	return true


## 01 面读档：已在游戏中先保存当前档；点当前档只翻回 02 面
func request_load_slot(slot: int) -> bool:
	if not SaveManager.is_slot_occupied(slot):
		return false
	if _state == State.IN_GAME and slot == SaveManager.get_active_slot():
		face_focus_requested.emit(FACE_MENU)
		return true
	if not _prepare_session_change():
		return false
	if _state == State.IN_GAME and not _save_current_before_switch():
		return false
	if not SaveManager.load_slot(slot):
		toast_requested.emit("读取存档失败")
		return false
	_set_active_character(_resolve_character(SaveManager.get_player_data()))
	_set_state(State.IN_GAME)
	face_focus_requested.emit(FACE_MENU)
	return true


## 01 面删除非活动存档；活动槽不显示删除按钮，这里再拦一次
func request_delete_slot(slot: int) -> bool:
	if slot < 0 or slot >= SaveManager.SLOT_COUNT:
		return false
	if slot == SaveManager.get_active_slot():
		toast_requested.emit("当前存档正在使用，无法删除")
		return false
	if not SaveManager.is_slot_occupied(slot):
		return false
	if not SaveManager.get_save_status().get("missing_containers", []).is_empty():
		toast_requested.emit("存档系统只读，无法删除")
		return false
	if not SaveManager.delete_slot(slot):
		toast_requested.emit("删除存档失败")
		return false
	toast_requested.emit("已删除存档 %d" % (slot + 1))
	return true


## 面是否锁定：02/05 只在游戏中解锁，04 只在角色选择时解锁
func get_face_lock_state(face_index: int) -> bool:
	match face_index:
		FACE_MENU, FACE_MAP:
			return _state != State.IN_GAME
		FACE_CHARACTER:
			return _state != State.CHARACTER_SELECT
		_:
			return false


## 01 面存档位视图数据：slot / occupied / character_name
func get_slot_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw in SaveManager.get_slot_summaries():
		var occupied := bool(raw.get("occupied", false))
		var character_name := ""
		if occupied:
			var player: Dictionary = raw.get("player", {})
			character_name = String(player.get("display_name", ""))
			if character_name.is_empty():
				character_name = _resolve_character(player).display_name
		var slot := int(raw.get("slot", 0))
		result.append({
			"slot": slot,
			"occupied": occupied,
			"character_name": character_name,
			"active": slot == SaveManager.get_active_slot(),
		})
	return result


## 当前角色档案；没有会话时回退到默认角色，保证测试/工具模式可开战
func get_player_profile() -> PlayerProfile:
	if _profile != null:
		return _profile
	return CharacterCatalog.default_character().profile


func get_active_character() -> CharacterDefinition:
	return _active_character


func get_state() -> State:
	return _state


## TestAPI/调试用快照
func get_state_snapshot() -> Dictionary:
	return {
		"state": String(State.find_key(_state)),
		"active_slot": SaveManager.get_active_slot(),
		"character_id": _active_character.id if _active_character != null else &"",
		"character_name": (
			_active_character.display_name
			if _active_character != null
			else ""
		),
	}
#endregion


#region 内部
## 会话切换前统一收尾：放下拖拽物品、停战/关面板；失败则不切
func _prepare_session_change() -> bool:
	if GBIS.has_moving_item() and not GBIS.moving_item_service.cancel():
		toast_requested.emit("无法放下拖拽中的物品")
		return false
	session_will_change.emit()
	return true


## 保存当前活动槽；只读档跳过保存并继续切换
func _save_current_before_switch() -> bool:
	if bool(SaveManager.get_save_status().get("read_only", false)):
		toast_requested.emit("当前存档只读，进度不会保存")
		return true
	if SaveManager.save_now():
		return true
	toast_requested.emit("当前存档不可写")
	return false


## 活动槽被删除（TestAPI 等）：回到 01 面，结束旧会话
func _on_active_slot_changed(slot: int) -> void:
	if slot >= 0:
		return
	if GBIS.has_moving_item():
		GBIS.moving_item_service.cancel()
	session_will_change.emit()
	_set_active_character(null)
	_set_state(State.NO_SESSION)
	face_focus_requested.emit(FACE_ENTRY)


func _set_state(state: State) -> void:
	if _state == state:
		return
	_state = state
	state_changed.emit(state)


func _set_active_character(character: CharacterDefinition) -> void:
	_active_character = character
	_profile = null
	if character != null and character.profile != null:
		_profile = character.profile.duplicate(true) as PlayerProfile
	active_character_changed.emit(character)


func _resolve_character(player_data: Dictionary) -> CharacterDefinition:
	var character_id := StringName(player_data.get("character_id", &""))
	var character := CharacterCatalog.get_by_id(character_id)
	return character if character != null else CharacterCatalog.default_character()


func _on_slot_list_changed() -> void:
	slots_changed.emit()
#endregion
