# 接收并处理武器牌组
# 提供：抽牌、出牌、弃牌方法

class_name CardPileSystem
extends Node


# 已初始化，输出抽牌堆内有几张牌
signal deck_initialized(deck_size: int)
# 已抽牌，抽到的牌的id和手牌数量
signal card_drawn(card_id: String, hand_pile_index: int)
# 已出牌，打出的牌的id和手牌数量
signal card_played(card_id: String, hand_pile_index: int)
# 已弃牌，弃牌id
signal card_discarded(card_id: String)
# 弃牌堆的牌被洗完并加入到抽牌堆中
signal discard_shuffled_into_draw(shuffled_amount: int)
# 所有的手牌都被丢弃
signal hand_pile_cleared()


# 抽牌堆
var draw_pile: Array[String] = []
# 手牌堆
var hand_pile: Array[String] = []
# 弃牌堆
var discard_pile: Array[String] = []


# 初始化系统（在战斗开始时调用）
func initialize(player_deck: Array[String]) -> void:
	 # 深拷贝，在此脚本内复制一个玩家牌组，并全部加入抽牌堆
	draw_pile = player_deck.duplicate()
	# 初始洗牌
	draw_pile.shuffle()                 
	hand_pile.clear()
	discard_pile.clear()
	deck_initialized.emit(draw_pile.size())

# 抽取卡牌
func draw_cards(amount: int) -> void:
	for i in range(amount):
		_draw_single_card()

# 出牌：参数是手牌数组的索引，就是手牌中的第几张
func play_card(hand_pile_index: int) -> void:
	if hand_pile_index < 0 or hand_pile_index >= hand_pile.size():
		push_warning("无效的手牌索引")
		return
		
	var played_card_id = hand_pile[hand_pile_index]
	hand_pile.remove_at(hand_pile_index)
	
	# 抛出打出信号，通知BattleManager执行卡牌效果
	card_played.emit(played_card_id, hand_pile_index)
	
	# 放入弃牌堆
	discard_pile.append(played_card_id)
	card_discarded.emit(played_card_id)

# 丢弃单张手牌
func discard_card(hand_pile_index: int) -> void:
	if hand_pile_index < 0 or hand_pile_index >= hand_pile.size(): return
	var card_id = hand_pile[hand_pile_index]
	hand_pile.remove_at(hand_pile_index)
	discard_pile.append(card_id)
	card_discarded.emit(card_id)

# 丢弃所有手牌
func discard_all_hand_pile() -> void:
	while hand_pile.size() > 0:
		var card_id = hand_pile.pop_back()
		discard_pile.append(card_id)
		card_discarded.emit(card_id)
	hand_pile_cleared.emit()

# ----------------- 内部方法 (Private) -----------------

# 抽取单张卡牌的核心逻辑
func _draw_single_card() -> void:
	# 1. 如果抽牌堆为空，尝试洗牌
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			print("抽牌堆和弃牌堆均为空，无法抽牌！")
			return
		_reshuffle_discard_to_draw()
		
	# 2. 从抽牌堆顶部（数组尾部）抽出一张牌
	var drawn_card = draw_pile.pop_back()
	
	# 3. 加入手牌
	hand_pile.append(drawn_card)
	var current_hand_pile_index = hand_pile.size() - 1
	
	# 4. 通知外部
	card_drawn.emit(drawn_card, current_hand_pile_index)

# 洗牌逻辑：将弃牌堆重新洗入抽牌堆
func _reshuffle_discard_to_draw() -> void:
	var amount = discard_pile.size()
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle() 
	
	discard_shuffled_into_draw.emit(amount)
