extends CanvasLayer
class_name ShelterInventoryUI

# Shelter Inventory UI
#
# 当前阶段：
#
# A
#     角色身上的武器列表
#
# B
#     武器预览
#     当前支持图片，占位时显示文字
#
# C
#     武器名称 / 描述
#
# D
#     武器基础信息
#
# E
#     分类
#     当前只有“全部”
#
# F
#     操作提示
#
#
# 本脚本只属于 Shelter。
#
# 不访问 Dungeon Scene，
# 不访问 MAPInventoryManager，
# 不访问 Battle PlayerDeckManager。


signal inventory_opened_changed(
	is_open: bool
)


@export_category("Shelter References")

# 本 UI 场景必须作为 Shelter 根节点的直接子节点。
@export var player_path: NodePath = (
	^"../GameViewportContainer/GameViewport/World/Gameplay/ShelterPlayer"
)

@export var edit_mode_controller_path: NodePath = (
	^"../GameViewportContainer/GameViewport/World/EditModeController"
)

@export var inventory_manager_path: NodePath = (
	^"../GameViewportContainer/GameViewport/World/ShelterInventoryManager"
)

@export_category("Temporary Input")

## 当前阶段使用 I 打开。
##
## 后面正式做按键设置时，
## 再替换成 InputMap Action。
@export var open_key: Key = KEY_TAB


@onready var root_ui: Control = %Root

@onready var weapon_list: ItemList = (
	%WeaponList
)

@onready var weapon_name_label: Label = (
	%WeaponName
)

@onready var description_label: Label = (
	%Description
)

@onready var stats_label: Label = (
	%Stats
)

@onready var preview_texture: TextureRect = (
	%PreviewTexture
)

@onready var preview_placeholder: Label = (
	%PreviewPlaceholder
)

@onready var operation_guide: Label = (
	%OperationGuide
)


var _player: ShelterPlayer

# 不在 UI 层强类型依赖 ShelterEditModeController。
#
# Shelter Inventory 只关心：
# “这个节点是否允许当前打开背包”。
#
# 这样也避免 UI 与建造系统形成不必要的类型耦合。
var _edit_mode_controller = null

var _inventory_manager: ShelterInventoryManager

var _is_open: bool = false

var _selected_uid: String = ""

var _previous_mouse_mode: int = (
	Input.MOUSE_MODE_VISIBLE
)


func _ready() -> void:
	_player = get_node_or_null(
		player_path
	) as ShelterPlayer

	_edit_mode_controller = get_node_or_null(
		edit_mode_controller_path
	)

	_inventory_manager = get_node_or_null(
		inventory_manager_path
	) as ShelterInventoryManager

	root_ui.visible = false

	weapon_list.item_selected.connect(
		_on_item_selected
	)

	weapon_list.item_activated.connect(
		_on_item_activated
	)

	if (
		_inventory_manager != null
		and not _inventory_manager.inventory_changed.is_connected(
			_on_inventory_changed
		)
	):
		_inventory_manager.inventory_changed.connect(
			_on_inventory_changed
		)

	_clear_details()

	_validate_references()


func _exit_tree() -> void:
	if not _is_open:
		return

	if is_instance_valid(_player):
		_player.set_movement_enabled(
			true
		)

	Input.mouse_mode = (
		_previous_mouse_mode
	)


func _notification(
	what: int
) -> void:
	if not _is_open:
		return

	if (
		what
		== NOTIFICATION_WM_WINDOW_FOCUS_OUT
		or what
		== NOTIFICATION_APPLICATION_FOCUS_OUT
	):
		close_inventory()


# Input
#
# 使用 _unhandled_key_input：
#
# 先让 ItemList 处理 ↑↓，
# 然后再阻断其它 Shelter 世界输入。

# Input
#
# 打开 / 关闭背包属于最高优先级 UI 输入，
# 因此使用 _input()。
#
# 这样即使 ItemList 当前拥有键盘焦点，
# 同一个 open_key 也一定能够关闭背包。


func _input(
	event: InputEvent
) -> void:
	if not event is InputEventKey:
		return

	var key_event := (
		event as InputEventKey
	)

	if not key_event.pressed:
		return

	if key_event.echo:
		return

	# 同一个键负责：
	#
	# 关闭状态 -> 打开
	# 打开状态 -> 关闭
	if key_event.keycode == open_key:
		toggle_inventory()

		get_viewport().set_input_as_handled()
		return

	# Esc 只负责关闭，不负责打开。
	if (
		_is_open
		and key_event.keycode
		== KEY_ESCAPE
	):
		close_inventory()

		get_viewport().set_input_as_handled()
		return


# 背包打开以后：
#
# - ItemList 自己先处理 ↑ / ↓
# - Enter 如果没有被 ItemList 消耗，则这里处理
# - 其余没有被 UI 消耗的键盘输入全部截断
#
# 防止背包打开时 Ctrl / F2 / E 等输入
# 继续进入 Shelter 世界逻辑。

func _unhandled_key_input(
	event: InputEvent
) -> void:
	if not _is_open:
		return

	if not event is InputEventKey:
		return

	var key_event := (
		event as InputEventKey
	)

	if not key_event.pressed:
		return

	if key_event.echo:
		return

	if key_event.keycode == KEY_ENTER:
		_activate_current_selection()

	get_viewport().set_input_as_handled()


# Public API

func open_inventory() -> bool:
	if _is_open:
		return true

	if SaveManager.current_save.is_empty():
		push_warning(
			"ShelterInventoryUI: 当前没有加载存档。"
		)
		return false

	# 建造状态下不允许打开角色背包。
	#
	# EditModeController 当前约定：
	# 0 = NONE
	# 1 = FACILITY_BUILD
	# 2 = ROOM_LAYOUT
	#
	# 这里通过实例公开方法读取状态，
	# 不让 Inventory UI 静态依赖建造控制器的 class_name。
	if _edit_mode_controller != null:
		if _edit_mode_controller.has_method(
			"get_mode"
		):
			var edit_mode: int = int(
				_edit_mode_controller.call(
					"get_mode"
				)
			)

			if edit_mode != 0:
				return false

	_is_open = true

	_previous_mouse_mode = (
		Input.mouse_mode
	)

	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE
	)

	if _player != null:
		_player.set_movement_enabled(
			false
		)

	root_ui.visible = true

	refresh()

	weapon_list.grab_focus()

	inventory_opened_changed.emit(
		true
	)

	return true


func close_inventory() -> void:
	if not _is_open:
		return

	_is_open = false

	root_ui.visible = false

	weapon_list.release_focus()

	if _player != null:
		_player.set_movement_enabled(
			true
		)

	Input.mouse_mode = (
		_previous_mouse_mode
	)

	inventory_opened_changed.emit(
		false
	)


func toggle_inventory() -> void:
	if _is_open:
		close_inventory()
	else:
		open_inventory()


func is_inventory_open() -> bool:
	return _is_open


func refresh() -> void:
	_refresh_weapon_list(
		_selected_uid
	)


# Weapon List

func _refresh_weapon_list(
	preferred_uid: String = ""
) -> void:
	weapon_list.clear()

	var weapons: Array = (
		_inventory_manager.get_character_weapons()
	)

	if weapons.is_empty():
		_selected_uid = ""

		weapon_list.add_item(
			"（没有携带武器）"
		)

		weapon_list.set_item_disabled(
			0,
			true
		)

		_clear_details()

		operation_guide.text = (
			"I / Esc 关闭"
		)

		return

	var target_index: int = -1

	for item in weapons:
		var uid: String = str(
			item.get(
				"uid",
				""
			)
		)

		var template_id: String = str(
			item.get(
				"template_id",
				""
			)
		)

		var static_data: Dictionary = (
			ItemDatabaseManager.get_item_data(
				template_id
			)
		)

		var display_name: String = (
			_get_weapon_display_name(
				static_data,
				template_id
			)
		)

		var equipped: bool = (
			_inventory_manager.is_weapon_equipped(
				uid
			)
		)

		var prefix: String = (
			"◆ "
			if equipped
			else "　"
		)

		var index: int = (
			weapon_list.item_count
		)

		weapon_list.add_item(
			prefix + display_name
		)

		weapon_list.set_item_metadata(
			index,
			uid
		)

		if uid == preferred_uid:
			target_index = index

	if target_index < 0:
		target_index = 0

	weapon_list.select(
		target_index
	)

	weapon_list.ensure_current_is_visible()

	_on_item_selected(
		target_index
	)


func _on_item_selected(
	index: int
) -> void:
	if (
		index < 0
		or index
		>= weapon_list.item_count
	):
		return

	var metadata: Variant = (
		weapon_list.get_item_metadata(
			index
		)
	)

	if metadata == null:
		_clear_details()
		return

	var uid: String = str(metadata)

	if uid.is_empty():
		_clear_details()
		return

	_selected_uid = uid

	_show_weapon(
		uid
	)


func _on_item_activated(
	index: int
) -> void:
	_on_item_selected(
		index
	)

	_toggle_selected_weapon()


func _activate_current_selection() -> void:
	var selected_items: PackedInt32Array = (
		weapon_list.get_selected_items()
	)

	if selected_items.is_empty():
		return

	_on_item_selected(
		selected_items[0]
	)

	_toggle_selected_weapon()


func _toggle_selected_weapon() -> void:
	if _selected_uid.is_empty():
		return

	if _inventory_manager.is_weapon_equipped(
		_selected_uid
	):
		_inventory_manager.unequip_weapon(
			_selected_uid
		)

	else:
		_inventory_manager.equip_weapon(
			_selected_uid,
			1
		)


# Details

func _show_weapon(
	uid: String
) -> void:
	var item: Dictionary = (
		_inventory_manager.get_item_by_uid(
			uid
		)
	)

	if item.is_empty():
		_clear_details()
		return

	var template_id: String = str(
		item.get(
			"template_id",
			""
		)
	)

	var static_data: Dictionary = (
		ItemDatabaseManager.get_item_data(
			template_id
		)
	)

	weapon_name_label.text = (
		_get_weapon_display_name(
			static_data,
			template_id
		)
	)

	var description_key: String = str(
		static_data.get(
			"desc",
			""
		)
	)

	if description_key.is_empty():
		description_label.text = (
			"暂无描述"
		)
	else:
		description_label.text = (
			tr(description_key)
		)

	var weapon_type: String = str(
		static_data.get(
			"wep_type",
			"—"
		)
	)

	var card_count: int = 0

	var cards: Variant = static_data.get(
		"default_cards",
		[]
	)

	if cards is Array:
		card_count = cards.size()

	var equipped: bool = (
		_inventory_manager.is_weapon_equipped(
			uid
		)
	)

	var status_text: String = (
		"已装备"
		if equipped
		else "角色背包"
	)

	stats_label.text = (
		"状态：%s\n"
		+ "武器类型：%s\n"
		+ "牌组卡牌数：%d\n"
		+ "模板 ID：%s"
	) % [
		status_text,
		weapon_type,
		card_count,
		template_id
	]

	_refresh_preview(
		static_data
	)

	if equipped:
		operation_guide.text = (
			"↑ / ↓ 选择    "
			+ "Enter 卸下    "
			+ "I / Esc 关闭"
		)

	else:
		operation_guide.text = (
			"↑ / ↓ 选择    "
			+ "Enter 装备    "
			+ "I / Esc 关闭"
		)


func _refresh_preview(
	static_data: Dictionary
) -> void:
	preview_texture.texture = null
	preview_texture.visible = false

	preview_placeholder.visible = true

	var preview_path: String = str(
		static_data.get(
			"preview_texture",
			""
		)
	).strip_edges()

	if preview_path.is_empty():
		return

	if not ResourceLoader.exists(
		preview_path
	):
		push_warning(
			"ShelterInventoryUI: 找不到预览图片 -> "
			+ preview_path
		)
		return

	var resource: Resource = load(
		preview_path
	)

	if not resource is Texture2D:
		push_warning(
			"ShelterInventoryUI: preview_texture 不是 Texture2D -> "
			+ preview_path
		)
		return

	preview_texture.texture = (
		resource as Texture2D
	)

	preview_texture.visible = true

	preview_placeholder.visible = false


func _clear_details() -> void:
	_selected_uid = ""

	weapon_name_label.text = "—"

	description_label.text = (
		"请选择武器。"
	)

	stats_label.text = "—"

	preview_texture.texture = null
	preview_texture.visible = false

	preview_placeholder.visible = true


func _get_weapon_display_name(
	static_data: Dictionary,
	fallback: String
) -> String:
	var name_key: String = str(
		static_data.get(
			"name_key",
			""
		)
	)

	if name_key.is_empty():
		return fallback

	return tr(name_key)


func _on_inventory_changed() -> void:
	if not _is_open:
		return

	refresh()


# Validation

func _validate_references() -> void:
	if _player == null:
		push_warning(
			"ShelterInventoryUI: 找不到 ShelterPlayer。"
		)

	if _edit_mode_controller == null:
		push_warning(
			"ShelterInventoryUI: 找不到 EditModeController。"
			)

	if _inventory_manager == null:
		push_error(
			"ShelterInventoryUI: "
			+ "找不到 ShelterInventoryManager。"
		)
