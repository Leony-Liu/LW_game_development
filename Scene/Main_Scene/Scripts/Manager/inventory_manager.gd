extends Node


signal inventory_changed

const LOCATION_CHARACTER_BACKPACK: String = "character_backpack"
const EQUIPPED_WEAPON_PREFIX: String = "equipped_weapon_"

# inventory_manager.gd

# 获取对存档库存的引用 (确保 SaveManager 已经读取了存档)
func _get_inv() -> Array:
	if SaveManager.current_save.has("inventory"):
		return SaveManager.current_save["inventory"]
	return []

# --- A. 物品查询过滤 ---

# 万能查询器：可以按位置和分类筛选。如果传空字符串，则不限制该条件。
func get_items(location_filter: String = "", category_filter: String = "") -> Array:
	var result = []
	var inv = _get_inv()
	
	for item in inv:
		var match_loc = (location_filter == "" or item.get("location") == location_filter)
		
		var match_cat = true
		if category_filter != "":
			var static_data = ItemDatabaseManager.get_item_data(item["template_id"])
			match_cat = (static_data.get("category") == category_filter)
			
		if match_loc and match_cat:
			result.append(item)
			
	return result

# 查找具体单一物品
func get_item_by_uid(uid: String) -> Dictionary:
	for item in _get_inv():
		if item["uid"] == uid: return item
	return {}


# --- Character Inventory ---
#
# 这里只负责角色永久携带空间。
#
# character_backpack
#     身上携带但未装备
#
# equipped_weapon_1
#     当前装备中的武器
#
# warehouse / backpack 等其他位置
# 不属于 Shelter 角色背包列表。


func get_character_weapons() -> Array:
	var result: Array = []

	for item in _get_inv():
		var location: String = str(
			item.get(
				"location",
				""
			)
		)

		var belongs_to_character: bool = (
			location == LOCATION_CHARACTER_BACKPACK
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

		if template_id.is_empty():
			continue

		var static_data: Dictionary = (
			ItemDatabaseManager.get_item_data(
				template_id
			)
		)

		if str(
			static_data.get(
				"category",
				""
			)
		) != "weapon":
			continue

		result.append(item)

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


func equip_weapon(
	uid: String,
	slot_index: int = 1
) -> bool:
	if slot_index < 1:
		push_warning(
			"InventoryManager: 武器槽编号必须 >= 1。"
		)
		return false

	var item: Dictionary = get_item_by_uid(
		uid
	)

	if item.is_empty():
		push_warning(
			"InventoryManager: 找不到物品 -> "
			+ uid
		)
		return false

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

	if str(
		static_data.get(
			"category",
			""
		)
	) != "weapon":
		push_warning(
			"InventoryManager: 目标物品不是武器 -> "
			+ uid
		)
		return false

	var source_location: String = str(
		item.get(
			"location",
			""
		)
	)

	# Shelter 不允许从仓库、箱子或战术背包
	# 隔空直接装备。
	if (
		source_location
		!= LOCATION_CHARACTER_BACKPACK
		and not source_location.begins_with(
			EQUIPPED_WEAPON_PREFIX
		)
	):
		push_warning(
			"InventoryManager: 武器当前不在角色身上 -> "
			+ uid
		)
		return false

	var target_location: String = (
		EQUIPPED_WEAPON_PREFIX
		+ str(slot_index)
	)

	if source_location == target_location:
		return true

	# 目前只有一把武器槽。
	# 新武器装备时，原武器退回角色背包。
	for existing_item in _get_inv():
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

	_commit_character_inventory_change()

	return true


func unequip_weapon(
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

	if not location.begins_with(
		EQUIPPED_WEAPON_PREFIX
	):
		return false

	item[
		"location"
	] = LOCATION_CHARACTER_BACKPACK

	_commit_character_inventory_change()

	return true


func _commit_character_inventory_change() -> void:
	inventory_changed.emit()

	if SaveManager.current_save.is_empty():
		return

	if not SaveManager.save_current_state():
		push_warning(
			"InventoryManager: 角色背包状态已改变，但存档写入失败。"
		)
# --- B. 物品操作流通 ---

# 核心转移方法：在仓库、背包、装备槽之间流通
func move_item(uid: String, new_location: String) -> bool:
	var item = get_item_by_uid(uid)
	if item.is_empty(): 
		push_error("InventoryManager: 转移失败，找不到UID -> ", uid)
		return false
		
	# 如果目标槽位是唯一型（比如 equipped_helmet），需要先将那里的旧装备脱到背包
	if new_location.begins_with("equipped_"):
		var existing_items = get_items(new_location)
		if existing_items.size() > 0:
			existing_items[0]["location"] = "backpack" # 挤回背包
			
	item["location"] = new_location
	print("🔄 物品流转: [%s] 已移动至 [%s]" % [uid, new_location])
	return true

# --- C. 搜打撤核心机制结算 ---

# 进图：打上死神标记
func enter_raid() -> void:
	SaveManager.current_save["in_raid"] = true
	SaveManager.save_current_state()
	print("💀 战术行动开始：已打上 in_raid 标记，强行落盘。")

# 结算：死亡撤离惩罚
func settle_death_penalty() -> void:
	if not SaveManager.current_save.get("in_raid", false):
		return # 没有死神标记，属于正常基地操作，跳过
		
	var inv = _get_inv()
	print("⚠️ 正在结算死亡惩罚...")
	
	# 逆序遍历，防止在遍历时删除元素导致数组越界
	for i in range(inv.size() - 1, -1, -1):
		var item = inv[i]
		var loc = item.get("location", "")
		var static_data = ItemDatabaseManager.get_item_data(item["template_id"])
		var cat = static_data.get("category", "")
		
		# 1. 战术背包里的处理 (含道具槽)
		if loc == "backpack" or loc.begins_with("equipped_item_"):
			if cat == "item" or cat == "material":
				# 是材料/消耗品，直接爆掉销毁
				inv.remove_at(i)
				print("💥 死亡爆装备: 失去道具 [%s]" % item["uid"])
			elif cat == "weapon" or cat == "armor":
				# 是武器防具，不掉落，但重损耐久
				_reduce_durability(item, 50)
				
		# 2. 身上穿戴的装备处理
		elif loc.begins_with("equipped_weapon_") or loc.begins_with("equipped_"):
			# 轻度损坏耐久
			_reduce_durability(item, 20)

	# 解除死神标记并保存
	SaveManager.current_save["in_raid"] = false
	SaveManager.save_current_state()
	print("✅ 死亡结算完成，进度已强行保存。")

# 内部处理耐久度逻辑
func _reduce_durability(item: Dictionary, damage_amount: int) -> void:
	if item.has("current_durability") and not item.get("is_broken", false):
		item["current_durability"] -= damage_amount
		if item["current_durability"] <= 0:
			item["current_durability"] = 0
			item["is_broken"] = true # 打上破损标记，面板失效，需去修理铺花钱修
			print("💔 装备损坏: [%s] 耐久归零，需要维修！" % item["uid"])
