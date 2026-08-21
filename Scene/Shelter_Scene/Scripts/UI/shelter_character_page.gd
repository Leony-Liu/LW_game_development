extends Control
class_name ShelterCharacterPage

# Shelter Character Page
#
# 独立角色页面。
#
# 设计目标：
# - 角色页面的美术布局完全放在独立 .tscn 中；
# - ShelterInventoryUI 只负责页面切换，不管理角色页内部布局；
# - 本页面只读取 ShelterInventoryManager 的正式库存数据；
# - 装备显示以 item.location 为唯一依据；
# - 右键卸下仍然经过 ShelterInventoryManager。

@onready var weapon_slot_1: ShelterCharacterSlot = %WeaponSlot1
@onready var weapon_slot_2: ShelterCharacterSlot = %WeaponSlot2

@onready var helmet_slot: ShelterCharacterSlot = %HelmetSlot
@onready var chest_slot: ShelterCharacterSlot = %ChestSlot
@onready var legs_slot: ShelterCharacterSlot = %LegsSlot
@onready var gloves_slot: ShelterCharacterSlot = %GlovesSlot
@onready var shoes_slot: ShelterCharacterSlot = %ShoesSlot

@onready var usable_slot_1: ShelterCharacterSlot = %UsableSlot1
@onready var usable_slot_2: ShelterCharacterSlot = %UsableSlot2
@onready var usable_slot_3: ShelterCharacterSlot = %UsableSlot3

var _inventory_manager: ShelterInventoryManager
var _slots: Array[ShelterCharacterSlot] = []

func _ready() -> void:
	_slots = [
		weapon_slot_1,
		weapon_slot_2,
		helmet_slot,
		chest_slot,
		legs_slot,
		gloves_slot,
		shoes_slot,
		usable_slot_1,
		usable_slot_2,
		usable_slot_3
	]

	for slot in _slots:
		if not slot.unequip_requested.is_connected(
			_on_slot_unequip_requested
		):
			slot.unequip_requested.connect(
				_on_slot_unequip_requested
			)

	_clear_all_slots()

# 由 ShelterInventoryUI 注入当前 Shelter 的库存管理器。
# 角色场景不自行寻找 Shelter 根节点，避免场景层级调整后路径失效。
func setup(
	inventory_manager: ShelterInventoryManager
) -> void:
	_inventory_manager = inventory_manager
	refresh()

# 每次打开角色页或库存变化时调用。
#
# 这里不缓存“当前装备是什么”。
# 每次都重新读取正式库存中的 location，确保背包和角色页永远看同一份数据。
func refresh() -> void:
	_clear_all_slots()

	if _inventory_manager == null:
		return

	for slot in _slots:
		_refresh_slot(
			slot
		)

func _refresh_slot(
	slot: ShelterCharacterSlot
) -> void:
	if slot == null:
		return

	if slot.slot_location.is_empty():
		return

	# 精确按 location 查询。
	# 例如背包装备到武器槽 1 后：
	# location == "equipped_weapon_1"
	# 这里会直接读到同一个物品实例。
	var items: Array = (
		_inventory_manager.get_items(
			slot.slot_location
		)
	)

	if items.is_empty():
		return

	if items.size() > 1:
		push_warning(
			"ShelterCharacterPage: 装备槽出现多个物品 -> "
			+ slot.slot_location
		)

	var item_value: Variant = items[0]

	if not item_value is Dictionary:
		return

	var item: Dictionary = item_value

	var template_id: String = str(
		item.get(
			"template_id",
			""
		)
	)

	var definition: Dictionary = (
		ItemDatabaseManager.get_item_definition(
			template_id
		)
	)

	var category: String = str(
		definition.get(
			"category",
			""
		)
	)

	if (
		not slot.accepted_category.is_empty()
		and not category.is_empty()
		and category != slot.accepted_category
	):
		push_warning(
			"ShelterCharacterPage: 槽位类别不一致 -> %s / %s"
			% [
				slot.slot_location,
				category
			]
		)

	slot.set_item_data(
		item,
		definition
	)

func _clear_all_slots() -> void:
	for slot in _slots:
		if slot != null:
			slot.clear_item()

func _on_slot_unequip_requested(
	uid: String
) -> void:
	if _inventory_manager == null:
		return

	if uid.is_empty():
		return

	# 所有 equipped_* 都通过 ShelterInventoryManager
	# 移回角色背包，不在 UI 层直接写 SaveManager。
	_inventory_manager.move_to_character_backpack(
		uid
	)

	# 正常情况下 inventory_changed 会触发外层 UI 再次 refresh。
	# 这里立即刷新一次，保证右键后视觉反馈不依赖信号时序。
	refresh()
