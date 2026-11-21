## 管理本次远征的付费候选、选牌与删牌交易。
## 不持有玩家模型或 UI，不访问存档及 Base 武器。
class_name CardWorkbenchSession
extends RefCounted

const CardOfferGenerator = preload("res://Scripts/RefCounted/CardOfferGenerator.gd")
const ExpeditionWallet = preload("res://Scripts/RefCounted/ExpeditionWallet.gd")
const DRAW_COST: int = 3
const DELETE_REFUND: int = 1
enum Result { SUCCESS, OFFER_ALREADY_PENDING, COMBAT_DECK_FULL, INSUFFICIENT_SOUL,
	EMPTY_CARD_POOL, INVALID_SELECTION, INVALID_STATE, CARD_CREATION_FAILED,
	CARD_INSERTION_FAILED, OPERATION_IN_PROGRESS, INVALID_CARD, REFUND_FAILED }

signal pending_offer_changed(offer: Array[CardData])
signal card_added(card_instance: CardInstance)
signal card_removed(card_instance: CardInstance, deck_type: String)

var _weapon: WeaponInstance
var _wallet: ExpeditionWallet
var _generator: CardOfferGenerator
var _pending_offer: Array[CardData] = []
var _operation_in_progress := false
var _revision: int = 0


# 必需依赖完整后才发布会话，不反向持有 ExpeditionPlayerData。
func initialize(weapon: WeaponInstance, wallet: ExpeditionWallet, generator: CardOfferGenerator) -> bool:
	if _operation_in_progress:
		return false
	clear()
	if weapon == null or wallet == null or generator == null:
		push_error("[CardWorkbenchSession] 初始化失败：缺少武器、钱包或候选生成器。")
		return false
	if weapon.combat_deck == null or weapon.reserve_deck == null or weapon.combat_deck.capacity != WeaponInstance.COMBAT_LIMIT:
		push_error("[CardWorkbenchSession] 初始化失败：武器双牌组或战斗容量无效。")
		return false
	_weapon = weapon
	_wallet = wallet
	_generator = generator
	return true


# 待选状态与 UI 是否打开无关。
func has_pending_offer() -> bool:
	return not _pending_offer.is_empty()


# 返回新数组，保留原模板引用及顺序。
func get_pending_offer() -> Array[CardData]:
	return _pending_offer.duplicate()


# 供未来编辑器复用完整远征双牌组。
func get_weapon_instance() -> WeaponInstance:
	return _weapon


# 用统一门闩保护支付与全部同步通知。
func begin_draw() -> Result:
	if _operation_in_progress:
		return Result.OPERATION_IN_PROGRESS
	_operation_in_progress = true
	var revision := _revision
	var result := _begin_draw(revision)
	if revision == _revision:
		_operation_in_progress = false
	return result


# 生成成功后才扣费，支付回调若结束远征则不复活旧候选。
func _begin_draw(revision: int) -> Result:
	if not _is_initialized():
		return Result.INVALID_STATE
	if has_pending_offer():
		return Result.OFFER_ALREADY_PENDING
	if not _combat_has_room():
		return Result.COMBAT_DECK_FULL
	if _wallet.get_soul_balance() < DRAW_COST:
		return Result.INSUFFICIENT_SOUL
	var offer := _generator.generate_offer()
	if revision != _revision or not _is_initialized():
		return Result.INVALID_STATE
	if offer.size() != CardOfferGenerator.OFFER_SIZE:
		return Result.EMPTY_CARD_POOL
	for card in offer:
		if card == null or card.id <= 0:
			return Result.EMPTY_CARD_POOL
	if not _combat_has_room():
		return Result.COMBAT_DECK_FULL
	if not _wallet.try_spend_soul(DRAW_COST):
		return Result.INSUFFICIENT_SOUL
	if revision != _revision:
		return Result.INVALID_STATE
	_pending_offer = offer.duplicate()
	pending_offer_changed.emit(get_pending_offer())
	return Result.SUCCESS


# 选中后才生成新身份，插入失败保留付费候选。
func choose_card(candidate_index: int) -> Result:
	if _operation_in_progress:
		return Result.OPERATION_IN_PROGRESS
	if not _is_initialized():
		return Result.INVALID_STATE
	if candidate_index < 0 or candidate_index >= _pending_offer.size():
		return Result.INVALID_SELECTION
	if not _combat_has_room():
		return Result.COMBAT_DECK_FULL
	var template := _pending_offer[candidate_index]
	if template == null or template.id <= 0:
		return Result.CARD_CREATION_FAILED
	_operation_in_progress = true
	var revision := _revision
	var card := CardInstance.new(template.id, template)
	if not _weapon.combat_deck.add_card(card):
		_operation_in_progress = false
		return Result.CARD_INSERTION_FAILED
	_pending_offer.clear()
	pending_offer_changed.emit(get_pending_offer())
	if revision == _revision:
		card_added.emit(card)
	if revision == _revision:
		_operation_in_progress = false
	return Result.SUCCESS


# 先核对精确对象及退款空间，移除后入账；失败按原顺序回滚。
func delete_card(card_instance: CardInstance, deck_type: String) -> Result:
	if _operation_in_progress:
		return Result.OPERATION_IN_PROGRESS
	if not _is_initialized():
		return Result.INVALID_STATE
	if deck_type not in ["combat_deck", "reserve_deck"]:
		return Result.INVALID_STATE
	var container: CardContainer = _weapon.combat_deck if deck_type == "combat_deck" else _weapon.reserve_deck
	if card_instance == null or container.find_card(card_instance.unique_id) != card_instance:
		return Result.INVALID_CARD
	if card_instance.container_ref == null or card_instance.container_ref.get_ref() != container:
		return Result.INVALID_CARD
	if not _wallet.can_add_soul(DELETE_REFUND):
		return Result.REFUND_FAILED
	_operation_in_progress = true
	var revision := _revision
	var index := container.get_cards().find(card_instance)
	if container.remove_card(card_instance.unique_id) != card_instance:
		_operation_in_progress = false
		return Result.INVALID_CARD
	if not _wallet.add_soul(DELETE_REFUND):
		if not container.add_card(card_instance, index):
			push_error("[CardWorkbenchSession] 删除回滚失败：无法恢复原卡牌位置。")
		_operation_in_progress = false
		return Result.REFUND_FAILED
	if revision == _revision:
		card_removed.emit(card_instance, deck_type)
	if revision == _revision:
		_operation_in_progress = false
	return Result.SUCCESS


# 生命周期清理不退款；使同步回调中的旧交易失效。
func clear() -> void:
	_revision += 1
	_pending_offer.clear()
	_operation_in_progress = false
	_weapon = null
	_wallet = null
	_generator = null


# 会话只使用初始化时注入的依赖。
func _is_initialized() -> bool:
	return _weapon != null and _wallet != null and _generator != null and _weapon.combat_deck != null and _weapon.reserve_deck != null


# 同时遵守容器容量与战斗牌组 20 张上限。
func _combat_has_room() -> bool:
	return _weapon.combat_deck.capacity == WeaponInstance.COMBAT_LIMIT and _weapon.combat_deck.get_cards().size() < WeaponInstance.COMBAT_LIMIT
