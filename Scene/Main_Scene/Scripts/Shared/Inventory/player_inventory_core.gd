extends Node


# ============================================================
# Player Inventory Core
# ============================================================
#
# 永久玩家库存的公共数据层。
#
# 负责：
#
# - 获取永久库存快照
# - 根据 UID 查找物品
# - 验证 Item V1 数据
# - 提交一份新的永久库存
# - 保存
# - 通知库存变化
#
#
# 不负责：
#
# - Shelter 装备规则
# - Shelter 仓库规则
# - Dungeon 搜索规则
# - Raid 撤离规则
# - Raid 死亡规则
# - 战斗道具效果
#
#
# 正常的 Shelter / Dungeon 玩法开发
# 不应该修改这个文件。
# ============================================================


signal inventory_changed(
	reason: StringName
)


# ============================================================
# Read
# ============================================================

func has_loaded_save() -> bool:
	return not SaveManager.current_save.is_empty()


func get_inventory_snapshot() -> Array:
	if SaveManager.current_save.is_empty():
		return []

	var value: Variant = (
		SaveManager.current_save.get(
			"inventory",
			[]
		)
	)

	if not value is Array:
		return []

	var inventory: Array = value

	# 永远返回深复制。
	#
	# 外部系统不能通过偷偷修改返回值，
	# 绕过 Core 改写永久存档。
	return inventory.duplicate(
		true
	)


func get_item_by_uid(
	uid: String
) -> Dictionary:
	if uid.is_empty():
		return {}

	for value in get_inventory_snapshot():
		if not value is Dictionary:
			continue

		var item: Dictionary = value

		if str(
			item.get(
				"uid",
				""
			)
		) != uid:
			continue

		return item.duplicate(
			true
		)

	return {}


# ============================================================
# Validation
# ============================================================

func validate_inventory(
	inventory: Array
) -> bool:
	var used_uids: Dictionary = {}

	for index in range(
		inventory.size()
	):
		var value: Variant = inventory[index]

		if not value is Dictionary:
			push_error(
				"PlayerInventoryCore: "
				+ "库存第 %d 项不是 Dictionary。"
				% index
			)

			return false

		var item: Dictionary = value

		if not ItemContract.validate_instance(
			item
		):
			push_error(
				"PlayerInventoryCore: "
				+ "库存第 %d 项不符合 Item V1 协议。"
				% index
			)

			return false

		var uid: String = str(
			item.get(
				"uid",
				""
			)
		)

		if used_uids.has(
			uid
		):
			push_error(
				"PlayerInventoryCore: "
				+ "发现重复 UID -> "
				+ uid
			)

			return false

		used_uids[
			uid
		] = true

	return true


# ============================================================
# Write
# ============================================================

## new_inventory 必须是一份已经完成业务处理的最终结果。
##
## Core 不知道为什么发生变化。
func replace_inventory(
	new_inventory: Array,
	reason: StringName = &"inventory_update",
	save_immediately: bool = true
) -> bool:
	if SaveManager.current_save.is_empty():
		push_error(
			"PlayerInventoryCore: "
			+ "当前没有加载存档。"
		)

		return false

	if not validate_inventory(
		new_inventory
	):
		push_error(
			"PlayerInventoryCore: "
			+ "拒绝写入非法库存。"
		)

		return false

	var previous_inventory: Array = (
		get_inventory_snapshot()
	)

	SaveManager.current_save[
		"inventory"
	] = new_inventory.duplicate(
		true
	)	

	if save_immediately:
		if not SaveManager.save_current_state():
			# 保存失败时恢复旧库存，
			# 避免内存和磁盘出现两种结果。
			SaveManager.current_save[
				"inventory"
			] = previous_inventory

			push_error(
				"PlayerInventoryCore: "
				+ "库存保存失败，本次修改已回滚。"
			)

			return false

	inventory_changed.emit(
		reason
	)

	return true
