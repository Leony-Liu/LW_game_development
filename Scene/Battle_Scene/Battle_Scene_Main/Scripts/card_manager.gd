extends Node

# ==========================================
# 节点引用
# ==========================================

@export_category("节点引用")
## 指向 PlayerHandDeck，下面应当直接包含 Slot_1 ~ Slot_5
@export var hand_deck_node: Control
## 指向 CardFactory 节点
@export var card_factory: Node
## 直接绑定战斗场景中的 Player 根节点。
## 不再依赖节点是否被手动加入 Player 分组。
@export var player: Node

# ==========================================
# 抽牌与弃牌设置
# ==========================================

@export_category("牌堆设置")

@export var max_hand_size: int = 5

## 输入映射中的抽牌动作名称
@export var draw_action: StringName = &"draw_card"

## 补满手牌消耗的体力
@export var draw_stamina_cost: int = 1

## 主动弃置一张牌消耗的体力
@export var discard_stamina_cost: int = 1


# ==========================================
# 运行数据
# ==========================================

var draw_pile: Array = []
var hand: Array[Control] = []
var discard_pile: Array = []

var card_count: int = 0
var combat_data: Node


func _ready() -> void:
	
	_connect_signals()

	if not _resolve_dependencies():
		set_process(false)
		return

	_get_player_card_deck()
	_draw_initial_hand_card()


func _connect_signals() -> void:
	if not BattleBus.card_successfully_played.is_connected(
		_on_card_successfully_played
	):
		BattleBus.card_successfully_played.connect(
			_on_card_successfully_played
		)

	if not BattleBus.card_discard_requested.is_connected(
		_on_card_discard_requested
	):
		BattleBus.card_discard_requested.connect(
			_on_card_discard_requested
		)


func _resolve_dependencies() -> bool:
	var valid := true

	if hand_deck_node == null:
		push_error(
			"CardManager：没有绑定 hand_deck_node。"
		)
		valid = false

	if card_factory == null:
		push_error(
			"CardManager：没有绑定 card_factory。"
		)
		valid = false

	# 为旧场景保留分组查找作为备用方案。
	# 推荐在检查器中直接绑定 player。
	if player == null:
		player = get_tree().get_first_node_in_group("Player")

	if player == null:
		push_error(
			"CardManager：没有绑定 Player，"
			+ "并且场景树中也没有属于 Player 分组的节点。"
		)
		valid = false
	else:
		combat_data = player.get_node_or_null("Data/CombatData")

		if combat_data == null:
			push_error(
				"CardManager：Player 下没有找到 "
				+ "Data/CombatData。"
			)
			valid = false

	if not InputMap.has_action(draw_action):
		push_error(
			"CardManager：输入映射中不存在动作：%s"
			% draw_action
		)
		valid = false

	return valid


# ==========================================
# 输入
# ==========================================

func _process(_delta: float) -> void:
	# 使用 Input 单例轮询，而不是 _unhandled_input。
	# 这样不会因为 Control、SubViewport 或焦点吞掉事件而失效。
	if Input.is_action_just_pressed(draw_action):
		_request_refill_hand()


func _request_refill_hand() -> void:
	_cleanup_hand_references()

	var needed_cards := max_hand_size - hand.size()

	if needed_cards <= 0:
		print("卡牌管理器：手牌已满，不需要抽牌。")
		return

	if combat_data == null:
		push_error(
			"卡牌管理器：CombatData 无效，无法消耗体力抽牌。"
		)
		return

	if not combat_data.has_method("consume_stamina"):
		push_error(
			"卡牌管理器：CombatData 缺少 consume_stamina()。"
		)
		return

	if not combat_data.consume_stamina(draw_stamina_cost):
		print("卡牌管理器：体力不足，无法抽牌。")

		if combat_data.has_signal("not_enough_stamina"):
			combat_data.not_enough_stamina.emit()

		return

	print(
		"卡牌管理器：消耗 %d 点体力，准备抽取 %d 张牌。"
		% [draw_stamina_cost, needed_cards]
	)

	draw_cards(needed_cards)


# ==========================================
# 牌堆初始化
# ==========================================

func _get_player_card_deck() -> void:
	var player_deck: Array = PlayerDeckManager.get_deck().duplicate()

	draw_pile = player_deck
	draw_pile.shuffle()

	print(
		"卡牌管理器：抽牌堆初始化完成，当前张数：%d"
		% draw_pile.size()
	)


func _draw_initial_hand_card() -> void:
	print("卡牌管理器：开始抽取初始手牌。")
	draw_cards(max_hand_size)


# ==========================================
# 抽牌
# ==========================================

func draw_cards(amount: int) -> void:
	if amount <= 0:
		return

	for _index in range(amount):
		if draw_pile.is_empty():
			_shuffle_discard_to_draw()

		if draw_pile.is_empty():
			print("卡牌管理器：抽牌堆和弃牌堆都为空。")
			break

		var empty_slot := _find_empty_slot()

		if empty_slot == null:
			print(
				"卡牌管理器：没有空闲卡槽，停止抽牌。"
			)
			break

		var next_card_id = draw_pile.pop_front()
		var created_node = card_factory.create_card(next_card_id)
		var new_card := created_node as Control

		if new_card == null:
			push_error(
				"卡牌管理器：CardFactory 创建的节点不是 Control。"
			)
			continue

		card_count += 1

		empty_slot.add_child(new_card)
		new_card.position = Vector2.ZERO

		hand.append(new_card)

		if new_card.has_method("play_draw_animation"):
			new_card.play_draw_animation()

	print(
		"卡牌管理器：抽牌结束，当前手牌数量：%d"
		% hand.size()
	)


func _find_empty_slot() -> Control:
	if hand_deck_node == null:
		return null

	for child in hand_deck_node.get_children():
		var slot := child as Control

		if slot == null:
			continue

		if slot.get_child_count() == 0:
			return slot

	return null


func _shuffle_discard_to_draw() -> void:
	if discard_pile.is_empty():
		return

	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()

	print(
		"卡牌管理器：弃牌堆已洗回抽牌堆，当前张数：%d"
		% draw_pile.size()
	)


# ==========================================
# 出牌和弃牌
# ==========================================

func _on_card_successfully_played(card_node: Control) -> void:
	if card_node == null or not is_instance_valid(card_node):
		return

	_remove_card_from_hand(card_node)
	_add_card_to_discard_pile(card_node)

	if card_node.has_method("play_discard_animation"):
		card_node.play_discard_animation()
	else:
		card_node.queue_free()


func _on_card_discard_requested(card_node: Control) -> void:
	if card_node == null or not is_instance_valid(card_node):
		return

	# 任何失败分支都必须发出 card_rejected，
	# 否则 CardBase 中的 is_locked 会永久保持 true。
	if player == null or combat_data == null:
		_reject_card(
			card_node,
			"玩家或 CombatData 无效，主动弃牌被拒绝。"
		)
		return

	if not combat_data.has_method("consume_stamina"):
		_reject_card(
			card_node,
			"CombatData 缺少 consume_stamina()。"
		)
		return

	if not combat_data.consume_stamina(discard_stamina_cost):
		_reject_card(
			card_node,
			"体力不足，无法主动弃牌。"
		)

		if combat_data.has_signal("not_enough_stamina"):
			combat_data.not_enough_stamina.emit()

		return

	print(
		"卡牌管理器：消耗 %d 点体力，主动弃牌成功。"
		% discard_stamina_cost
	)

	_on_card_successfully_played(card_node)


func _reject_card(card_node: Control, reason: String) -> void:
	print("卡牌管理器：%s" % reason)
	BattleBus.card_rejected.emit(card_node)


func _remove_card_from_hand(card_node: Control) -> void:
	if hand.has(card_node):
		hand.erase(card_node)


func _add_card_to_discard_pile(card_node: Control) -> void:
	if "card_id" not in card_node:
		push_warning(
			"卡牌管理器：卡牌节点没有 card_id，"
			+ "无法记录到弃牌堆。"
		)
		return

	discard_pile.append(card_node.card_id)

	print(
		(
			"卡牌管理器：卡牌 ID %d 进入弃牌堆，"
			+ "弃牌堆当前数量：%d"
		)
		% [card_node.card_id, discard_pile.size()]
	)


func _cleanup_hand_references() -> void:
	for index in range(hand.size() - 1, -1, -1):
		if not is_instance_valid(hand[index]):
			hand.remove_at(index)


# ==========================================
# 手牌强化
# ==========================================

func apply_buff_to_hand(
	target_category: String,
	stat_name: String,
	value: float
) -> void:
	_cleanup_hand_references()

	var buffed_count := 0

	for card_node in hand:
		if "card_data" not in card_node:
			continue

		var data: Dictionary = card_node.card_data

		if (
			target_category == "all"
			or data.get("categories", "") == target_category
		):
			var current_value = data.get(stat_name, 0)
			data[stat_name] = current_value + value
			buffed_count += 1

	print(
		"卡牌管理器：强化了 %d 张 %s 卡牌的 %s，增加 %f。"
		% [
			buffed_count,
			target_category,
			stat_name,
			value
		]
	)
