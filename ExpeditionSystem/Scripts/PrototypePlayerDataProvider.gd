## 从 Inspector 测试配置创建玩家 EntityData 和 CardInstance[]。
## 仅负责校验与构造战斗输入，不管理远征中的玩家状态。
class_name PrototypePlayerDataProvider
extends Node


@export_category("原型玩家与牌组配置")

@export_group("玩家数据")
# 填写玩家配置后开启，避免将默认值误当作已配置数据。
@export var prototype_player_configured: bool = false

@export_subgroup("身份")
@export var prototype_entity_id: String = ""
@export var prototype_entity_name: String = ""

@export_subgroup("生命与护盾")
@export var prototype_max_hp: float = 0.0
@export var prototype_current_hp: float = 0.0
@export var prototype_shield: float = 0.0

@export_subgroup("体力")
@export var prototype_max_stamina: float = 0.0
@export var prototype_current_stamina: float = 0.0
@export var prototype_stamina_regen_rate: float = 0.0

@export_subgroup("法力")
@export var prototype_max_mana: float = 0.0
@export var prototype_current_mana: float = 0.0
@export var prototype_mana_regen_rate: float = 0.0

@export_subgroup("扩展属性")
# 在此添加额外属性，避免重复定义上方标准属性。
@export var prototype_custom_properties: Dictionary = {}

@export_group("牌组")
# 确认牌组配置完成；有意使用空牌组也需开启。
@export var prototype_deck_configured: bool = false
# 填写 AllCardData 中的卡牌 ID；允许重复 ID。
@export var prototype_card_ids: Array[int] = []


# 同时校验玩家与牌组配置，全部有效时返回 true。
func validate_configuration() -> bool:
	var is_valid := true
	if not _validate_player_configuration():
		is_valid = false
	if not _validate_deck_configuration():
		is_valid = false
	return is_valid


# 校验后创建玩家数据，配置不合法时返回 null。
func get_player_data() -> EntityData:
	if not _validate_player_configuration():
		return null

	# 新增玩家标准属性时，在此构造后调整下方字段映射。
	var player_data := EntityData.new(prototype_entity_id, prototype_entity_name)

	player_data.max_hp = prototype_max_hp
	player_data.current_hp = prototype_current_hp
	player_data.shield = prototype_shield
	player_data.max_stamina = prototype_max_stamina
	player_data.current_stamina = prototype_current_stamina
	player_data.stamina_regen_rate = prototype_stamina_regen_rate
	player_data.max_mana = prototype_max_mana
	player_data.current_mana = prototype_current_mana
	player_data.mana_regen_rate = prototype_mana_regen_rate

	# 深拷贝扩展属性，避免运行时修改 Inspector 配置。
	player_data.custom_properties = prototype_custom_properties.duplicate(true)
	return player_data


# 校验全部卡牌 ID，再构造独立实例；失败时返回空数组。
func get_player_deck() -> Array[CardInstance]:
	var player_deck: Array[CardInstance] = []
	if not _validate_deck_configuration():
		return player_deck

	# 需要改变卡牌实例构造方式时，修改此处。
	for card_id in prototype_card_ids:
		player_deck.append(CardInstance.new(card_id))
	return player_deck


# 校验玩家配置开关、ID 与名称；数值范围尚无此处规则。
func _validate_player_configuration() -> bool:
	if not prototype_player_configured:
		push_error(
			"PrototypePlayerDataProvider: prototype player data is not configured. "
			+ "Fill the Player Data fields and enable prototype_player_configured."
		)
		return false
	if prototype_entity_id.strip_edges().is_empty():
		push_error("PrototypePlayerDataProvider: prototype_entity_id must not be empty.")
		return false
	if prototype_entity_name.strip_edges().is_empty():
		push_error("PrototypePlayerDataProvider: prototype_entity_name must not be empty.")
		return false
	return true


# 校验牌组开关和所有卡牌 ID；允许有意配置为空牌组。
func _validate_deck_configuration() -> bool:
	if not prototype_deck_configured:
		push_error(
			"PrototypePlayerDataProvider: prototype deck is not configured. "
			+ "Fill prototype_card_ids and enable prototype_deck_configured."
		)
		return false

	var card_database: Dictionary = AllCardData.get_cards()
	for card_id in prototype_card_ids:
		if not card_database.has(card_id):
			push_error(
				"PrototypePlayerDataProvider: invalid CardData ID %d in prototype_card_ids."
				% card_id
			)
			return false
	return true
