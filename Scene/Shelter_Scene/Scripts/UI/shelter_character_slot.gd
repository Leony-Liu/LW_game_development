extends Button
class_name ShelterCharacterSlot

# Shelter Character Slot
#
# 角色页的单个装备槽。
# 这个脚本不负责决定“什么能装备到这里”，只负责：
# - 显示当前物品
# - 读取物品图标
# - 右键发送卸下请求
#
# 为了方便美术在同一个角色场景里直接复制、缩放、移动槽位，
# 这里使用相对节点路径，而不是 %UniqueName。
# 因此同一个角色页面可以存在多个完全相同结构的槽位节点。

signal unequip_requested(
	uid: String
)

@export_category("槽位设置")

@export var slot_title: String = "槽位"

## 永久库存中的位置名称。
## 例如：equipped_weapon_1
@export var slot_location: String = ""

## 仅用于开发期校验。
## weapon / equipment / usable
@export var accepted_category: String = ""

@export var empty_text: String = "未装备"

@onready var slot_title_label: Label = (
	$Margin/VBox/SlotTitle
)

@onready var item_icon: TextureRect = (
	$Margin/VBox/IconCenter/ItemIcon
)

@onready var item_name_label: Label = (
	$Margin/VBox/ItemName
)

var _item_uid: String = ""

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE

	slot_title_label.text = slot_title
	clear_item()

func set_item_data(
	item: Dictionary,
	definition: Dictionary
) -> void:
	_item_uid = str(
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

	var name_key: String = str(
		definition.get(
			"name_key",
			""
		)
	)

	var display_name: String = template_id

	if not name_key.is_empty():
		display_name = tr(
			name_key
		)

	var count: int = int(
		item.get(
			"count",
			1
		)
	)

	if count > 1:
		display_name += " ×%d" % count

	item_name_label.text = display_name
	tooltip_text = (
		"%s\n右键卸下" % display_name
	)

	_refresh_icon(
		definition
	)

func clear_item() -> void:
	_item_uid = ""

	if is_instance_valid(
		slot_title_label
	):
		slot_title_label.text = slot_title

	if is_instance_valid(
		item_name_label
	):
		item_name_label.text = empty_text

	tooltip_text = (
		"%s：%s" % [
			slot_title,
			empty_text
		]
	)

	if is_instance_valid(
		item_icon
	):
		item_icon.texture = null
		item_icon.visible = false

func get_item_uid() -> String:
	return _item_uid

func _gui_input(
	event: InputEvent
) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := (
		event as InputEventMouseButton
	)

	if not mouse_event.pressed:
		return

	if mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return

	if _item_uid.is_empty():
		return

	unequip_requested.emit(
		_item_uid
	)

	accept_event()

func _refresh_icon(
	definition: Dictionary
) -> void:
	item_icon.texture = null
	item_icon.visible = false

	var icon_path: String = str(
		definition.get(
			"icon_path",
			""
		)
	).strip_edges()

	if icon_path.is_empty():
		return

	if not ResourceLoader.exists(
		icon_path
	):
		push_warning(
			"ShelterCharacterSlot: 找不到图标 -> "
			+ icon_path
		)
		return

	var resource: Resource = load(
		icon_path
	)

	if not resource is Texture2D:
		push_warning(
			"ShelterCharacterSlot: icon_path 不是 Texture2D -> "
			+ icon_path
		)
		return

	item_icon.texture = (
		resource as Texture2D
	)
	item_icon.visible = true
