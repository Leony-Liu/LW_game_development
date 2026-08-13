extends Node
class_name ShelterNPCRaidInteraction


# ============================================================
# Shelter NPC / Raid Interaction
# ============================================================
#
# 完全属于 Shelter 系统。
#
# 不依赖：
# - EventBus
# - InteractionManager
# - SearchManager
# - world_interactionUI
#
#
# Flow:
#
# Enter NPC Area
#     ↓
# Show "[E] 与NPC交互"
#
# Press E
#     ↓
# Confirmation Dialog
#
# YES
#     ↓
# raid_authorized = true
#
# NO
#     ↓
# raid_authorized = false
#
#
# Enter Raid Entry Area:
#
# authorized
#     → Battlescene
#
# unauthorized
#     → nothing
# ============================================================


@export_category("References")

@export var player: ShelterPlayer

@export var npc_interaction_area: Area3D

@export var raid_entry_area: Area3D


@export_category("Battle")

@export var battle_scene: PackedScene


@export_category("Interaction")

@export var interaction_text: String = "[E] 与 NPC 交互"

@export var authorized_text: String = "已确认出战，前往道路尽头"


@export_category("Dialog")

@export var dialog_title: String = "出战确认"

@export_multiline var dialog_text: String = (
	"是否进入战斗？\n\n"
	+ "选择“是”后，前往道路尽头即可进入战斗。"
)


var raid_authorized: bool = false

var _player_in_npc_range: bool = false

var _dialog_open: bool = false

var _transitioning: bool = false


var _ui_layer: CanvasLayer

var _prompt_panel: PanelContainer

var _prompt_label: Label

var _confirmation_dialog: ConfirmationDialog


func _ready() -> void:
	if not _validate_setup():
		set_process_unhandled_input(false)
		return

	_create_ui()

	_connect_detection_areas()


func _unhandled_input(
	event: InputEvent
) -> void:
	if not _player_in_npc_range:
		return

	if _dialog_open:
		return

	if _transitioning:
		return

	if event.is_action_pressed(
		"interact"
	):
		_open_confirmation_dialog()

		get_viewport().set_input_as_handled()


# ============================================================
# Setup
# ============================================================


func _connect_detection_areas() -> void:
	if not npc_interaction_area.body_entered.is_connected(
		_on_npc_body_entered
	):
		npc_interaction_area.body_entered.connect(
			_on_npc_body_entered
		)

	if not npc_interaction_area.body_exited.is_connected(
		_on_npc_body_exited
	):
		npc_interaction_area.body_exited.connect(
			_on_npc_body_exited
		)

	if not raid_entry_area.body_entered.is_connected(
		_on_raid_entry_body_entered
	):
		raid_entry_area.body_entered.connect(
			_on_raid_entry_body_entered
		)


# ============================================================
# UI
# ============================================================


func _create_ui() -> void:
	# --------------------------------------------------------
	# Canvas Layer
	# --------------------------------------------------------

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "ShelterInteractionUI"
	_ui_layer.layer = 20

	add_child(
		_ui_layer
	)

	# --------------------------------------------------------
	# Interaction Prompt
	# --------------------------------------------------------

	_prompt_panel = PanelContainer.new()
	_prompt_panel.name = "InteractionPrompt"

	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5

	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0

	_prompt_panel.offset_left = -190.0
	_prompt_panel.offset_right = 190.0

	_prompt_panel.offset_top = -115.0
	_prompt_panel.offset_bottom = -60.0

	_prompt_panel.visible = false

	_ui_layer.add_child(
		_prompt_panel
	)

	_prompt_label = Label.new()
	_prompt_label.name = "Label"

	_prompt_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	_prompt_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	_prompt_label.text = interaction_text

	_prompt_panel.add_child(
		_prompt_label
	)

	# --------------------------------------------------------
	# Confirmation Dialog
	# --------------------------------------------------------

	_confirmation_dialog = (
		ConfirmationDialog.new()
	)

	_confirmation_dialog.name = (
		"RaidConfirmationDialog"
	)

	_confirmation_dialog.title = (
		dialog_title
	)

	_confirmation_dialog.dialog_text = (
		dialog_text
	)

	_confirmation_dialog.ok_button_text = (
		"是"
	)

	_confirmation_dialog.cancel_button_text = (
		"否"
	)

	_ui_layer.add_child(
		_confirmation_dialog
	)

	_confirmation_dialog.confirmed.connect(
		_on_confirmation_yes
	)

	_confirmation_dialog.canceled.connect(
		_on_confirmation_no
	)


# ============================================================
# NPC Area
# ============================================================


func _on_npc_body_entered(
	body: Node3D
) -> void:
	if body != player:
		return

	_player_in_npc_range = true

	_update_interaction_prompt()


func _on_npc_body_exited(
	body: Node3D
) -> void:
	if body != player:
		return

	_player_in_npc_range = false

	_hide_interaction_prompt()


# ============================================================
# Prompt
# ============================================================


func _update_interaction_prompt() -> void:
	if _prompt_panel == null:
		return

	if raid_authorized:
		_prompt_label.text = (
			authorized_text
		)
	else:
		_prompt_label.text = (
			interaction_text
		)

	_prompt_panel.visible = true


func _hide_interaction_prompt() -> void:
	if _prompt_panel != null:
		_prompt_panel.visible = false


# ============================================================
# Dialog
# ============================================================


func _open_confirmation_dialog() -> void:
	if _confirmation_dialog == null:
		return

	_dialog_open = true

	_hide_interaction_prompt()

	_set_player_frozen(
		true
	)

	_confirmation_dialog.popup_centered(
		Vector2i(
			460,
			240
		)
	)


func _on_confirmation_yes() -> void:
	_dialog_open = false

	raid_authorized = true

	_set_player_frozen(
		false
	)

	print(
		"[ShelterNPC] Raid authorized."
	)

	if _player_in_npc_range:
		_update_interaction_prompt()


func _on_confirmation_no() -> void:
	_dialog_open = false

	raid_authorized = false

	_set_player_frozen(
		false
	)

	print(
		"[ShelterNPC] Raid canceled."
	)

	if _player_in_npc_range:
		_update_interaction_prompt()


# ============================================================
# Raid Entry
# ============================================================


func _on_raid_entry_body_entered(
	body: Node3D
) -> void:
	if body != player:
		return

	if _transitioning:
		return

	# --------------------------------------------------------
	# 没有经过 NPC 确认：
	#
	# 什么都不发生。
	# --------------------------------------------------------

	if not raid_authorized:
		return

	if battle_scene == null:
		push_error(
			"ShelterNPC: Battle Scene 未设置。"
		)

		return

	_enter_battle()


func _enter_battle() -> void:
	_transitioning = true

	_set_player_frozen(
		true
	)

	_hide_interaction_prompt()

	print(
		"[ShelterNPC] Entering BattleScene."
	)

	var error := (
		get_tree().change_scene_to_packed(
			battle_scene
		)
	)

	if error != OK:
		push_error(
			"ShelterNPC: 战斗场景切换失败。"
		)

		_transitioning = false

		_set_player_frozen(
			false
		)


# ============================================================
# Player
# ============================================================


func _set_player_frozen(
	frozen: bool
) -> void:
	if player == null:
		return

	if frozen:
		player.velocity = Vector3.ZERO

		player.set_physics_process(
			false
		)

		if (
			player.animation_player != null
			and player.animation_player.has_animation(
				player.idle_animation
			)
		):
			player.animation_player.play(
				player.idle_animation,
				player.animation_blend_time
			)

	else:
		player.set_physics_process(
			true
		)


# ============================================================
# Validation
# ============================================================


func _validate_setup() -> bool:
	var valid := true

	if player == null:
		push_error(
			"ShelterNPC: Player 未绑定。"
		)

		valid = false

	if npc_interaction_area == null:
		push_error(
			"ShelterNPC: NPC InteractionArea 未绑定。"
		)

		valid = false

	if raid_entry_area == null:
		push_error(
			"ShelterNPC: Raid Entry Area 未绑定。"
		)

		valid = false

	if battle_scene == null:
		push_error(
			"ShelterNPC: Battle Scene 未绑定。"
		)

		valid = false

	return valid
