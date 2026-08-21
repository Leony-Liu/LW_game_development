class_name ItemContract
extends RefCounted


# ============================================================
# Item Contract V1
# ============================================================
#
# Shelter / Dungeon / Battle 共用的物品数据最低协议。
#
# 这里不负责任何具体玩法。
#
# 不负责：
#
# - 武器如何攻击
# - 道具如何使用
# - 装备如何计算
# - Dungeon 如何搜刮
# - Shelter 如何整理仓库
# - 死亡如何结算
#
# 这里只定义：
#
# 1. 静态物品有哪些顶级类别。
# 2. 永久物品实例最低必须包含什么。
#
# 这个文件属于“共享协议”。
# 后续尽量少改。
# ============================================================


# ============================================================
# Categories
# ============================================================

const CATEGORY_WEAPON: String = "weapon"
const CATEGORY_EQUIPMENT: String = "equipment"
const CATEGORY_USABLE: String = "usable"
const CATEGORY_KEY_ITEM: String = "key_item"
const CATEGORY_RESOURCE: String = "resource"
const CATEGORY_SUPPLY: String = "supply"


const VALID_CATEGORIES: Array[String] = [
	CATEGORY_WEAPON,
	CATEGORY_EQUIPMENT,
	CATEGORY_USABLE,
	CATEGORY_KEY_ITEM,
	CATEGORY_RESOURCE,
	CATEGORY_SUPPLY
]


# ============================================================
# ItemDefinition
# ============================================================

## 静态定义最低要求：
##
## template_id
## category
## data
##
## 其它字段允许继续扩展。
static func validate_definition(
	definition: Dictionary
) -> bool:
	var template_id: String = str(
		definition.get(
			"template_id",
			""
		)
	).strip_edges()

	if template_id.is_empty():
		return false

	var category: String = str(
		definition.get(
			"category",
			""
		)
	).strip_edges()

	if category not in VALID_CATEGORIES:
		return false

	var data: Variant = definition.get(
		"data",
		{}
	)

	if not data is Dictionary:
		return false

	return true


static func is_valid_category(
	category: String
) -> bool:
	return category in VALID_CATEGORIES


# ============================================================
# ItemInstance
# ============================================================

## 最终永久库存中的一个物品实例，
## V1 最低结构：
##
## {
##     "uid": "...",
##     "template_id": "...",
##     "location": "...",
##     "count": 1,
##     "state": {}
## }
##
##
## state 内容完全由具体玩法决定。
##
## 例如武器：
##
## state = {
##     "current_durability": 70
## }
##
## 道具：
##
## state = {
##     "remaining_uses": 2
## }
##
static func validate_instance(
	item: Dictionary
) -> bool:
	var uid: String = str(
		item.get(
			"uid",
			""
		)
	).strip_edges()

	if uid.is_empty():
		return false

	var template_id: String = str(
		item.get(
			"template_id",
			""
		)
	).strip_edges()

	if template_id.is_empty():
		return false

	var location: String = str(
		item.get(
			"location",
			""
		)
	).strip_edges()

	if location.is_empty():
		return false

	var count: int = int(
		item.get(
			"count",
			0
		)
	)

	if count <= 0:
		return false

	var state: Variant = item.get(
		"state",
		{}
	)

	if not state is Dictionary:
		return false

	return true
