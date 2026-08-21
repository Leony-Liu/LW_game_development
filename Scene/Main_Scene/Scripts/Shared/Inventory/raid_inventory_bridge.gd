extends Node


# ============================================================
# Raid Inventory Bridge
# ============================================================
#
# Dungeon / Raid 与永久库存之间唯一的公共交接端口。
#
#
# 不负责：
#
# - 搜索如何生成物品
# - Dungeon 背包如何工作
# - 死亡掉什么
# - 成功撤离获得什么
# - 安全箱规则
# - 耐久损失
#
#
# Dungeon 负责自己算出最终结果。
#
# Bridge 只负责：
#
# 1. 出发时提供永久库存副本。
# 2. 返回时接收已经完成结算的最终库存。
#
# ============================================================


signal return_inventory_committed(
	item_count: int
)


# ============================================================
# Departure
# ============================================================

## 给 Dungeon 一份玩家出发前的永久库存快照。
##
## 返回的是深复制。
## Dungeon 无法直接修改永久存档。
func get_departure_inventory_snapshot() -> Array:
	return PlayerInventoryCore.get_inventory_snapshot()


# ============================================================
# Return
# ============================================================

## final_inventory 必须是 Dungeon 已经完成所有规则以后
## 得出的“最终永久库存”。
func commit_return_inventory(
	final_inventory: Array
) -> bool:
	if not _validate_known_items(
		final_inventory
	):
		return false

	var success: bool = (
		PlayerInventoryCore.replace_inventory(
			final_inventory,
			&"raid_return",
			true
		)
	)

	if not success:
		return false

	return_inventory_committed.emit(
		final_inventory.size()
	)

	return true


# ============================================================
# Validation
# ============================================================

func _validate_known_items(
	inventory: Array
) -> bool:
	if not PlayerInventoryCore.validate_inventory(
		inventory
	):
		push_error(
			"RaidInventoryBridge: "
			+ "Dungeon 返回库存不符合 Item V1 协议。"
		)

		return false

	for value in inventory:
		if not value is Dictionary:
			return false

		var item: Dictionary = value

		var template_id: String = str(
			item.get(
				"template_id",
				""
			)
		)

		if not ItemDatabaseManager.has_item_data(
			template_id
		):
			push_error(
				"RaidInventoryBridge: "
				+ "Dungeon 返回了未知 template_id -> "
				+ template_id
			)

			return false

	return true
