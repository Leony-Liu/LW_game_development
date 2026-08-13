extends Control


@export_category("Navigation")

@export var shelter_scene: PackedScene



@export var save_slot_card_scene: PackedScene


@export_category("Transition")

@export_range(0.0, 2.0, 0.05)
var transition_duration: float = 0.3


@onready var save_list_container: VBoxContainer = (
	%SaveListContainer
)

@onready var empty_state: Label = (
	%EmptyState
)


@onready var back_button: Button = (
	%BackButton
)

@onready var new_save_button: Button = (
	%NewSaveButton
)


@onready var name_input_modal: Control = (
	%NameInputModal
)

@onready var save_name_input: LineEdit = (
	%SaveNameInput
)

@onready var name_input_error: Label = (
	%NameInputError
)

@onready var create_cancel_button: Button = (
	%CreateCancelButton
)

@onready var create_confirm_button: Button = (
	%CreateConfirmButton
)


@onready var delete_confirm_modal: Control = (
	%DeleteConfirmModal
)

@onready var delete_target_label: Label = (
	%DeleteTargetLabel
)

@onready var delete_cancel_button: Button = (
	%DeleteCancelButton
)

@onready var delete_confirm_button: Button = (
	%DeleteConfirmButton
)


var pending_delete_id: String = ""
var pending_delete_name: String = ""


func _ready() -> void:
	name_input_modal.hide()
	delete_confirm_modal.hide()

	back_button.pressed.connect(
		_return_to_main_menu
	)

	new_save_button.pressed.connect(
		_open_create_dialog
	)

	create_cancel_button.pressed.connect(
		_close_create_dialog
	)

	create_confirm_button.pressed.connect(
		_confirm_create_save
	)

	save_name_input.text_submitted.connect(
		_on_name_submitted
	)

	delete_cancel_button.pressed.connect(
		_close_delete_dialog
	)

	delete_confirm_button.pressed.connect(
		_confirm_delete_save
	)

	_refresh_save_list()


func _unhandled_input(
	event: InputEvent
) -> void:
	if not event.is_action_pressed(
		"ui_cancel"
	):
		return

	if delete_confirm_modal.visible:
		_close_delete_dialog()
		get_viewport().set_input_as_handled()
		return

	if name_input_modal.visible:
		_close_create_dialog()
		get_viewport().set_input_as_handled()
		return

	_return_to_main_menu()


# ============================================================
# Save List
# ============================================================


func _refresh_save_list() -> void:
	_clear_save_cards()

	var saves: Array = SaveManager.get_all_saves()

	empty_state.visible = saves.is_empty()

	var last_save_id: String = (
		SaveManager.get_last_save_id()
	)

	for save_value in saves:
		if typeof(save_value) != TYPE_DICTIONARY:
			continue

		var save_data: Dictionary = save_value

		_create_save_card(
			save_data,
			str(
				save_data.get(
					"id",
					""
				)
			) == last_save_id
		)


func _clear_save_cards() -> void:
	for child in save_list_container.get_children():
		save_list_container.remove_child(
			child
		)

		child.queue_free()


func _create_save_card(
	save_data: Dictionary,
	is_last_save: bool
) -> void:
	if save_slot_card_scene == null:
		push_error(
			"FileList: Save Slot Card Scene 未绑定。"
		)
		return

	var card_node: Node = (
		save_slot_card_scene.instantiate()
	)

	if not card_node is SaveSlotCard:
		push_error(
			"FileList: SaveSlotCard 场景脚本错误。"
		)

		card_node.queue_free()
		return

	var card: SaveSlotCard = (
		card_node as SaveSlotCard
	)

	save_list_container.add_child(
		card
	)

	card.setup(
		save_data,
		is_last_save
	)

	card.play_requested.connect(
		_on_save_play_requested
	)

	card.delete_requested.connect(
		_on_save_delete_requested
	)


# ============================================================
# Load
# ============================================================


func _on_save_play_requested(
	save_id: String
) -> void:
	_load_save_and_enter_shelter(
		save_id
	)


func _load_save_and_enter_shelter(
	save_id: String
) -> void:
	if shelter_scene == null:
		push_error(
			"FileList: Shelter Scene 未绑定。"
		)
		return

	if not SaveManager.load_save(
		save_id
	):
		return

	var main_root: Node = _get_main_root()

	if main_root == null:
		push_error(
			"FileList: 找不到 MAIN。"
		)
		return

	var callback: Callable = Callable(
		main_root,
		"load_system_scene"
	).bind(
		shelter_scene,
		{
			"entry_source": "save_list",
			"save_id": save_id
		}
	)

	SceneManager.transition_to(
		callback,
		transition_duration
	)


# ============================================================
# Create
# ============================================================


func _open_create_dialog() -> void:
	save_name_input.text = ""

	name_input_error.text = ""
	name_input_error.hide()

	name_input_modal.show()

	save_name_input.grab_focus()


func _close_create_dialog() -> void:
	name_input_modal.hide()


func _on_name_submitted(
	_submitted_text: String
) -> void:
	_confirm_create_save()


func _confirm_create_save() -> void:
	var save_name: String = (
		save_name_input.text.strip_edges()
	)

	if save_name.is_empty():
		name_input_error.text = (
			"请输入存档名称。"
		)

		name_input_error.show()

		save_name_input.grab_focus()
		return

	var new_save_id: String = (
		SaveManager.create_new_save(
			save_name
		)
	)

	if new_save_id.is_empty():
		name_input_error.text = (
			"创建存档失败。"
		)

		name_input_error.show()
		return

	name_input_modal.hide()

	_load_save_and_enter_shelter(
		new_save_id
	)


# ============================================================
# Delete
# ============================================================


func _on_save_delete_requested(
	save_id: String
) -> void:
	var save_name: String = (
		_find_save_name(
			save_id
		)
	)

	pending_delete_id = save_id
	pending_delete_name = save_name

	delete_target_label.text = (
		"确定永久删除存档“%s”吗？\n"
		+ "该操作无法撤销。"
	) % save_name

	delete_confirm_modal.show()


func _close_delete_dialog() -> void:
	pending_delete_id = ""
	pending_delete_name = ""

	delete_confirm_modal.hide()


func _confirm_delete_save() -> void:
	if pending_delete_id.is_empty():
		_close_delete_dialog()
		return

	SaveManager.delete_save(
		pending_delete_id
	)

	_close_delete_dialog()

	_refresh_save_list()


func _find_save_name(
	save_id: String
) -> String:
	var saves: Array = SaveManager.get_all_saves()

	for save_value in saves:
		if typeof(save_value) != TYPE_DICTIONARY:
			continue

		var data: Dictionary = save_value

		if str(
			data.get(
				"id",
				""
			)
		) == save_id:
			return str(
				data.get(
					"name",
					"未命名存档"
				)
			)

	return "未命名存档"


# ============================================================
# Back
# ============================================================


func _return_to_main_menu() -> void:
	var main_root: Node = _get_main_root()

	if main_root == null:
		push_error(
			"FileList: 找不到 MAIN。"
		)
		return

	var target_scene: PackedScene = (
		main_root.get(
			"initial_system_scene"
		) as PackedScene
	)

	if target_scene == null:
		push_error(
			"FileList: MAIN 的 initial_system_scene 未配置。"
		)
		return

	var callback: Callable = Callable(
		main_root,
		"load_system_scene"
	).bind(
		target_scene,
		{
			"entry_source": "file_list"
		}
	)

	SceneManager.transition_to(
		callback,
		transition_duration
	)


func _get_main_root() -> Node:
	var current_scene: Node = (
		get_tree().current_scene
	)

	if (
		current_scene != null
		and current_scene.has_method(
			"load_system_scene"
		)
	):
		return current_scene

	return get_tree().root.get_node_or_null(
		"MAIN"
	)
