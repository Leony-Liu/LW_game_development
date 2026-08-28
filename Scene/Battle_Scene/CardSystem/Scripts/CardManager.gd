# 接收武器牌组
# 提供方法： 抽牌 弃牌 出牌

class_name CardManger
extends Node

# 绑定 PlayerHandDeck 节点
@export var player_hand_deck: Control

#region 向上汇报信号
# 已初始化，输出抽牌堆内有几张牌
signal deck_initialized(deck_size: int)
# 已抽牌，抽到的牌的id和手牌数量
signal card_drawn(card_id: int, hand_pile_index: int)
# 已出牌，打出的牌的id和手牌数量
signal card_played(card_id: int, hand_pile_index: int)
# 已弃牌，弃牌id
signal card_discarded(card_id: int)
# 弃牌堆的牌被洗完并加入到抽牌堆中
signal discard_shuffled_into_draw(shuffled_amount: int)
# 所有的手牌都被丢弃
signal hand_pile_cleared()
#endregion

# 抽牌堆
var draw_pile: Array[int] = []
# 手牌堆
var hand_pile: Array[RuntimeCard] = []
# 弃牌堆
var discard_pile: Array[int] = []

# 检查手牌节点并连接信号
func _ready() -> void:
	if player_hand_deck:
		player_hand_deck.card_play_requested.connect(play_card)
		player_hand_deck.card_discard_requested.connect(discard_card)
	else:
		push_error("未在检查器中绑定 player_hand_deck！")

# 初始化系统（在战斗开始时调用）
func initialize(player_deck: Array[int]) -> void:
	# 深拷贝，在此脚本内复制一个玩家牌组，并全部加入抽牌堆
	draw_pile = player_deck.duplicate()
	# 初始洗牌
	draw_pile.shuffle()                 
	hand_pile.clear()
	discard_pile.clear()
	deck_initialized.emit(draw_pile.size())
	print("已成功初始化卡牌系统")

#region 卡牌操作方法
# 抽取卡牌
func draw_cards(amount: int) -> void:
	for i in range(amount):
		_draw_single_card()

# 出牌：参数是手牌数组的索引，就是手牌中的第几张
func play_card(hand_pile_index: int) -> void:
	if hand_pile_index < 0 or hand_pile_index >= hand_pile.size(): return
	var played_card: RuntimeCard = hand_pile[hand_pile_index]
	hand_pile.remove_at(hand_pile_index)
	card_played.emit(played_card.base_card_id, hand_pile_index)
	discard_pile.append(played_card.base_card_id)
	card_discarded.emit(played_card.base_card_id)

# 丢弃单张手牌
func discard_card(hand_pile_index: int) -> void:
	if hand_pile_index < 0 or hand_pile_index >= hand_pile.size(): return
	var discarded_card: RuntimeCard = hand_pile[hand_pile_index]
	hand_pile.remove_at(hand_pile_index)
	discard_pile.append(discarded_card.base_card_id)
	card_discarded.emit(discarded_card.base_card_id)

# 丢弃所有手牌
func discard_all_hand_pile() -> void:
	while hand_pile.size() > 0:
		var card_id = hand_pile.pop_back()
		discard_pile.append(card_id)
		card_discarded.emit(card_id)
	hand_pile_cleared.emit()
#endregion

#region 内部方法
# 抽取单张卡牌的核心逻辑
func _draw_single_card() -> void:
	if draw_pile.is_empty():
		if discard_pile.is_empty(): return
		_reshuffle_discard_to_draw()
		
	var drawn_id = draw_pile.pop_back()
	
	# ================= 核心组装区 =================
	# 假设 AllCardData 存在并能获取静态数据字典
	var card_database = AllCardData.get_cards()
	if not card_database.has(drawn_id): return push_error("查无此牌")
	
	# 在抽牌瞬间，将静态数据打包成动态黑盒
	var runtime_card = RuntimeCard.new(drawn_id, card_database[drawn_id])
	# ============================================
	
	hand_pile.append(runtime_card)
	var current_hand_pile_index = hand_pile.size() - 1
	
	# 将组装好的黑盒发给 UI
	if player_hand_deck and player_hand_deck.has_method("add_card_to_hand"):
		player_hand_deck.add_card_to_hand(runtime_card, current_hand_pile_index)
	
	card_drawn.emit(drawn_id, current_hand_pile_index)

# 洗牌逻辑：将弃牌堆重新洗入抽牌堆
func _reshuffle_discard_to_draw() -> void:
	var amount = discard_pile.size()
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle() 
	
	discard_shuffled_into_draw.emit(amount)
#endregion
