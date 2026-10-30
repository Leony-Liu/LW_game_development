## 协调基地设施的邻近交互、唯一模态窗口和武器牌组编辑意图。
## 玩家控制归 PlayerVisual，持久数据归武器模型，保存切换归 GameManager。
extends Node3D

enum Modal { NONE, EXPEDITION, DECK_EDITOR, COMBAT_VIEW }

@export var player_visual: PlayerVisualManager
@export var entrance_area: Area3D
@export var editor_area: Area3D
@export var base_ui: CanvasLayer

var _modal: Modal = Modal.NONE
var _selected_area: Area3D
var _editing_weapon: WeaponInstance
var _previous_mode: String = "explore"
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _entry_requested: bool = false

# 必需场景引用失败时停用本模块，不在损坏状态下接收交互。
func _ready() -> void:
	if player_visual == null or entrance_area == null or editor_area == null or base_ui == null or not base_ui.validate_configuration():
		push_error("[Base] 初始化失败：缺少必需的玩家、设施检测区域或 UI 场景配置。")
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return
	base_ui.expedition_confirmed.connect(_on_expedition_confirmed)
	base_ui.modal_close_requested.connect(_close_modal)
	base_ui.card_transfer_requested.connect(_on_card_transfer_requested)

# 原生 Area3D 提供范围事实；只选择与真实玩家碰撞体重叠的最近设施。
func _process(_delta: float) -> void:
	_update_interaction_target()

# 在 GUI 焦点遍历前消费 Tab；编辑或其他模态期间保持当前窗口。
func _input(event: InputEvent) -> void:
	if get_tree().current_scene != self or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed("toggle_weapon_deck_viewer"):
		get_viewport().set_input_as_handled()
		if _modal == Modal.COMBAT_VIEW:
			_close_modal()
		elif _modal == Modal.NONE:
			_open_combat_view()
	elif _modal == Modal.COMBAT_VIEW and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_modal()

# 通过原权威入口获取当前武器，仅把实战牌组交给 UI。
func _open_combat_view() -> void:
	if _modal != Modal.NONE:
		return
	var weapon: WeaponInstance = PlayerSaveManager.get_current_weapon() if PlayerSaveManager.ensure_loaded() else null
	_previous_mode = player_visual.current_mode
	_previous_mouse_mode = Input.mouse_mode
	if not player_visual.change_mode("modal"):
		push_error("[Base] 无法打开实战牌组：玩家控制锁定失败。")
		return
	_modal = Modal.COMBAT_VIEW
	_selected_area = null
	var cards: Array[CardInstance] = weapon.combat_deck.get_cards() if weapon != null else []
	base_ui.show_combat_view(cards)

# 所有设施共用一个 E 入口；模态期间只处理关闭，不接收新设施交互。
func _unhandled_input(event: InputEvent) -> void:
	if get_tree().current_scene != self or (event is InputEventKey and event.echo):
		return
	if _modal != Modal.NONE:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_modal()
		return
	if not event.is_action_pressed("interact"):
		return
	_update_interaction_target()
	if _selected_area == null:
		return
	get_viewport().set_input_as_handled()
	_open_facility(_selected_area)

# 每帧更新唯一提示；离开范围或打开模态立即隐藏。
func _update_interaction_target() -> void:
	if _modal != Modal.NONE or get_tree().current_scene != self:
		_selected_area = null
		base_ui.show_prompt("")
		return
	var nearest: Area3D = null
	var best_distance: float = INF
	for area in [entrance_area, editor_area]:
		if not area.overlaps_body(player_visual.player):
			continue
		var distance: float = area.global_position.distance_squared_to(player_visual.player.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = area
	if nearest != _selected_area:
		_selected_area = nearest
		base_ui.show_prompt("" if nearest == null else ("按 E 进入远征" if nearest == entrance_area else "按 E 编辑牌组"))

# 复核范围后锁住共享玩家组件；打开窗口本身不创建武器或写存档。
func _open_facility(area: Area3D) -> void:
	if _modal != Modal.NONE or area not in [entrance_area, editor_area] or not area.overlaps_body(player_visual.player):
		return
	_previous_mode = player_visual.current_mode
	_previous_mouse_mode = Input.mouse_mode
	if not player_visual.change_mode("modal"):
		push_error("[Base] 无法停用玩家控制，设施窗口未打开。")
		return
	_selected_area = null
	base_ui.show_prompt("")
	if area == entrance_area:
		_modal = Modal.EXPEDITION
		base_ui.show_confirmation()
	else:
		_modal = Modal.DECK_EDITOR
		_editing_weapon = PlayerSaveManager.get_current_weapon() if PlayerSaveManager.ensure_loaded() else null
		base_ui.show_editor(_editing_weapon)

# 仅按钮确认后调用已有保存感知入口；失败保持弹窗和锁定状态供重试。
func _on_expedition_confirmed() -> void:
	if _modal != Modal.EXPEDITION or _entry_requested or get_tree().current_scene != self:
		return
	_entry_requested = true
	if not GameManager.start_expedition():
		_entry_requested = false
		base_ui.show_entry_failure()
		push_error("[Base] 远征确认未提交：玩家数据初始化、保存或场景准备失败。")

# 关闭不保存、不重建牌组；恢复打开前的玩家控制与鼠标状态。
func _close_modal() -> void:
	if _modal == Modal.NONE or _entry_requested:
		return
	base_ui.hide_modals()
	_editing_weapon = null
	_modal = Modal.NONE
	if not player_visual.change_mode(_previous_mode):
		push_error("[Base] 关闭设施窗口后无法恢复玩家控制。")
		return
	Input.mouse_mode = _previous_mouse_mode
	_update_interaction_target()

# UI 只提供意图；Base 校验当前武器与源卡牌后移动原实例。
func _on_card_transfer_requested(source_id: String, uid: String) -> void:
	if _modal != Modal.DECK_EDITOR or _editing_weapon == null or get_tree().current_scene != self:
		return
	if source_id not in ["combat_deck", "reserve_deck"]:
		return
	var source: CardContainer = _editing_weapon.combat_deck if source_id == "combat_deck" else _editing_weapon.reserve_deck
	var destination: CardContainer = _editing_weapon.reserve_deck if source == _editing_weapon.combat_deck else _editing_weapon.combat_deck
	if source.find_card(uid) == null:
		base_ui.show_editor_status("卡牌已不在原牌组，请重新操作。")
		return
	if destination.capacity >= 0 and destination.get_cards().size() >= destination.capacity:
		base_ui.show_editor_status("实战牌组已满（20/20），请先移出一张卡牌。")
		return
	if not source.transfer_to(destination, uid):
		base_ui.show_editor_status("移动失败；原卡牌与牌组保持不变，请查看日志。")
		return
	base_ui.refresh_editor(_editing_weapon)
