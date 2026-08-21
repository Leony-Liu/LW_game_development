class_name ShelterInventoryManager
extends Node


# ============================================================
# Shelter Inventory Manager
# ============================================================
#
# 只属于 Shelter。
#
# 负责：
#
# - Shelter 内库存查询
# - 仓库 / 角色背包流转
# - 武器装备 / 卸下
#
#
# 不负责：
#
# - Dungeon 搜索
# - Dungeon 局内背包
# - Raid 死亡
# - Raid 撤离
# - 战斗物品效果
#
#
# 所有永久库存写入最终都经过：
#
# PlayerInventoryCore
#
# ============================================================


signal inventory_changed


const LOCATION_WAREHOUSE: String = "warehouse"

const LOCATION_CHARACTER_BACKPACK: String = (
	"character_backpack"
)

const EQUIPPED_WEAPON_PREFIX: String = (
	"equipped_weapon_"
)


func _ready() -> void:
	if not PlayerInventoryCore.inventory_changed.is_connected(
		_on_core_inventory_changed
	):
		PlayerInventoryCore.inventory_changed.connect(
			_on_core_inventory_changed
		)


# ============================================================
# Query
# ============================================================

func get_items(
	location_filter: String = "",
	category_filter: String = ""
) -> Array:
	var result: Array = []

	var inventory: Array = (
		PlayerInventoryCore.get_inventory_snapshot()
	)

	for value in inventory:
		if not value is Dictionary:
			continue

		var item: Dictionary = value

		var location: String = str(
			item.get(
				"location",
				""
			)
		)

		if (
			not location_filter.is_empty()
			and location != location_filter
		):
			continue

		if not category_filter.is_empty():
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

			if str(
				definition.get(
					"category",
					""
				)
			) != category_filter:
				continue

		result.append(
			item
		)

	return result


func get_item_by_uid(
	uid: String
) -> Dictionary:
	return PlayerInventoryCore.get_item_by_uid(
		uid
	)


# ============================================================
# Character Inventory
# ============================================================

func get_character_weapons() -> Array:
	var result: Array = []

	for value in PlayerInventoryCore.get_inventory_snapshot():
		if not value is Dictionary:
			continue

		var item: Dictionary = value

		var location: String = str(
			item.get(
				"location",
				""
			)
		)

		var belongs_to_character: bool = (
			location
			== LOCATION_CHARACTER_BACKPACK
			or location.begins_with(
				EQUIPPED_WEAPON_PREFIX
			)
		)

		if not belongs_to_character:
			continue

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

		if str(
			definition.get(
				"category",
				""
			)
		) != ItemContract.CATEGORY_WEAPON:
			continue

		result.append(
			item
		)

	return result


func is_weapon_equipped(
	uid: String
) -> bool:
	var item: Dictionary = get_item_by_uid(
		uid
	)

	if item.is_empty():
		return false

	var location: String = str(
		item.get(
			"location",
			""
		)
	)

	return location.begins_with(
		EQUIPPED_WEAPON_PREFIX
	)


# ============================================================
# Weapon Equip
# ============================================================

func equip_weapon(
	uid: String,
	slot_index: int = 1
) -> bool:
	if slot_index < 1:
		push_warning(
			"ShelterInventoryManager: "
			+ "武器槽编号必须 >= 1。"
		)

		return false

	var inventory: Array = (
		PlayerInventoryCore.get_inventory_snapshot()
	)

	var target_index: int = (
		_find_item_index(
			inventory,
			uid
		)
	)

	if target_index < 0:
		push_warning(
			"ShelterInventoryManager: "
			+ "找不到物品 -> "
			+ uid
		)

		return false

	var item: Dictionary = (
		inventory[target_index]
	)

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

	if str(
		definition.get(
			"category",
			""
		)
	) != ItemContract.CATEGORY_WEAPON:
		push_warning(
			"ShelterInventoryManager: "
			+ "目标物品不是武器 -> "
			+ uid
		)

		return false

	var source_location: String = str(
		item.get(
			"location",
			""
		)
	)

	# Shelter 不允许直接把仓库中的武器
	# 隔空装备到角色身上。
	if (
		source_location
		!= LOCATION_CHARACTER_BACKPACK
		and not source_location.begins_with(
			EQUIPPED_WEAPON_PREFIX
		)
	):
		push_warning(
			"ShelterInventoryManager: "
			+ "武器当前不在角色身上 -> "
			+ uid
		)

		return false

	var target_location: String = (
		EQUIPPED_WEAPON_PREFIX
		+ str(slot_index)
	)

	if source_location == target_location:
		return true

	# 同一装备槽只允许一个物品。
	#
	# 原装备自动退回角色背包。
	for index in range(
		inventory.size()
	):
		if index == target_index:
			continue

		var existing_value: Variant = (
			inventory[index]
		)

		if not existing_value is Dictionary:
			continue

		var existing_item: Dictionary = (
			existing_value
		)

		if str(
			existing_item.get(
				"location",
				""
			)
		) != target_location:
			continue

		existing_item[
			"location"
		] = LOCATION_CHARACTER_BACKPACK

	item[
		"location"
	] = target_location

	return PlayerInventoryCore.replace_inventory(
		inventory,
		&"shelter_equip_weapon",
		true
	)


func unequip_weapon(
	uid: String
) -> bool:
	var inventory: Array = (
		PlayerInventoryCore.get_inventory_snapshot()
	)

	var target_index: int = (
		_find_item_index(
			inventory,
			uid
		)
	)

	if target_index < 0:
		return false

	var item: Dictionary = (
		inventory[target_index]
	)

	var location: String = str(
		item.get(
			"location",
			""
		)
	)

	if not location.begins_with(
		EQUIPPED_WEAPON_PREFIX
	):
		return false

	item[
		"location"
	] = LOCATION_CHARACTER_BACKPACK

	return PlayerInventoryCore.replace_inventory(
		inventory,
		&"shelter_unequip_weapon",
		true
	)


# ============================================================
# Shelter Item Movement
# ============================================================

## 给之后的仓库 UI 使用。
##
## 当前允许：
##
## warehouse
## character_backpack
## equipped_*
##
## Shelter 不操作 Dungeon 自己的局内位置。
func move_item(
	uid: String,
	new_location: String
) -> bool:
	if not _is_shelter_location(
		new_location
	):
		push_warning(
			"ShelterInventoryManager: "
			+ "拒绝移动到非 Shelter 位置 -> "
			+ new_location
		)

		return false

	var inventory: Array = (
		PlayerInventoryCore.get_inventory_snapshot()
	)

	var target_index: int = (
		_find_item_index(
			inventory,
			uid
		)
	)

	if target_index < 0:
		return false

	var item: Dictionary = (
		inventory[target_index]
	)

	var source_location: String = str(
		item.get(
			"location",
			""
		)
	)

	if not _is_shelter_location(
		source_location
	):
		push_warning(
			"ShelterInventoryManager: "
			+ "目标物品不属于 Shelter 库存位置 -> "
			+ source_location
		)

		return false

	if source_location == new_location:
		return true

	# equipped_* 都视为唯一装备槽。
	if new_location.begins_with(
		"equipped_"
	):
		for index in range(
			inventory.size()
		):
			if index == target_index:
				continue

			var existing_value: Variant = (
				inventory[index]
			)

			if not existing_value is Dictionary:
				continue

			var existing_item: Dictionary = (
				existing_value
			)

			if str(
				existing_item.get(
					"location",
					""
				)
			) != new_location:
				continue

			existing_item[
				"location"
			] = LOCATION_CHARACTER_BACKPACK

	item[
		"location"
	] = new_location

	return PlayerInventoryCore.replace_inventory(
		inventory,
		&"shelter_move_item",
		true
	)


func move_to_warehouse(
	uid: String
) -> bool:
	return move_item(
		uid,
		LOCATION_WAREHOUSE
	)


func move_to_character_backpack(
	uid: String
) -> bool:
	return move_item(
		uid,
		LOCATION_CHARACTER_BACKPACK
	)


# ============================================================
# Internal
# ============================================================

func _find_item_index(
	inventory: Array,
	uid: String
) -> int:
	for index in range(
		inventory.size()
	):
		var value: Variant = (
			inventory[index]
		)

		if not value is Dictionary:
			continue

		var item: Dictionary = value

		if str(
			item.get(
				"uid",
				""
			)
		) == uid:
			return index

	return -1


func _is_shelter_location(
	location: String
) -> bool:
	return (
		location == LOCATION_WAREHOUSE
		or location
		== LOCATION_CHARACTER_BACKPACK
		or location.begins_with(
			"equipped_"
		)
	)


func _on_core_inventory_changed(
	_reason: StringName
) -> void:
	inventory_changed.emit()
