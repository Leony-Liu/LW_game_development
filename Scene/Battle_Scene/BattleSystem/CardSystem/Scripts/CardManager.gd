# 接收玩家初始牌组(RuntimeCard数组)，管理卡牌在各个牌堆间的流转。
# 提供方法：抽牌、弃牌、出牌、洗牌、施加Buff
class_name CardManger
extends Node

# 绑定手牌展示节点
@export var player_hand_deck: Control
# 手牌上限
@export var hand_limit: int

#region 向上汇报信号
signal deck_initialized(deck_size: int)
signal card_drawn(runtime_card: RuntimeCard)
signal card_played(runtime_card: RuntimeCard)
signal card_discarded(runtime_card: RuntimeCard)
signal discard_shuffled_into_draw(shuffled_amount: int)
signal hand_pile_cleared()
#endregion

var draw_pile: Array[RuntimeCard] = []
var hand_pile: Array[RuntimeCard] = []
var discard_pile: Array[RuntimeCard] = []

# 检查是否绑定手牌节点，同时连接信号
func _ready() -> void:
	if player_hand_deck:
		player_hand_deck.card_play_requested.connect(play_card)
		player_hand_deck.card_discard_requested.connect(discard_card)
	else:
		push_error("未在检查器中绑定 player_hand_deck！")

# 初始化系统，清空牌堆、读取传入的实例数组、补齐手牌
func initialize(player_deck: Array[RuntimeCard]) -> void:
	# 清空三个牌堆
	draw_pile.clear()
	hand_pile.clear()
	discard_pile.clear()
	
	# 直接接收外界生成好的 RuntimeCard 实例数组作为抽牌堆
	draw_pile = player_deck.duplicate()
			
	draw_pile.shuffle()                 
	deck_initialized.emit(draw_pile.size())
	print("已成功初始化卡牌系统，牌堆数量：", draw_pile.size())
	draw_cards_to_limit()

# 供外部系统（或玩家点击抽牌堆按钮）调用的标准抽牌操作
func execute_player_draw_action() -> void:
	var draw_amount = hand_limit - hand_pile.size()
	if draw_amount > 0:
		print("玩家发起抽牌，补齐数量：", draw_amount)
		draw_cards(draw_amount)
	else:
		print("手牌已达上限，无法抽牌")

# 接收战斗管理器下发的 Buff 指令，实例化并挂载给指定的 RuntimeCard
func apply_buff_to_card(target_card: RuntimeCard, buff_id: String, property: String, modifier_type: CardBuff.ModifierType, value: float, time_left: int = -1, count_left: int = -1) -> void:
	if not target_card:
		push_warning("CardManager: 施加 Buff 失败，目标 RuntimeCard 为空。")
		return
		
	var new_buff = CardBuff.new(buff_id, property, modifier_type, value, time_left, count_left)
	target_card.add_buff(new_buff)
	print("CardManager: 成功向卡牌施加 Buff -> ", buff_id, " (影响属性: ", property, ")")

#region 卡牌操作方法
# 抽牌
func draw_cards(amount: int) -> void:
	# 计算当前手牌堆距离上限还有多少空位
	var space_left = hand_limit - hand_pile.size()
	# 实际能抽的数量，取“请求数量”与“剩余空位”中的最小值
	var actual_draw = mini(amount, space_left)
	
	if actual_draw <= 0:
		print("手牌已达上限 (", hand_limit, ")，指令被拦截！")
		return
		
	for i in range(actual_draw):
		_draw_single_card()

# 出牌
func play_card(runtime_card: RuntimeCard) -> void:
	var current_index = hand_pile.find(runtime_card)
	if current_index == -1: 
		return push_warning("出牌失败：手牌堆中找不到该卡牌实例")
		
	# 从手牌数组移除
	hand_pile.remove_at(current_index)
	# 触发信号并附带实时位置
	card_played.emit(runtime_card)
	# 压入弃牌堆
	discard_pile.append(runtime_card)
	card_discarded.emit(runtime_card)

# 弃牌
func discard_card(runtime_card: RuntimeCard) -> void:
	var current_index = hand_pile.find(runtime_card)
	if current_index == -1: 
		return
		
	hand_pile.remove_at(current_index)
	discard_pile.append(runtime_card)
	card_discarded.emit(runtime_card)

# 弃全部手牌
func discard_all_hand_pile() -> void:
	while hand_pile.size() > 0:
		var card = hand_pile.pop_back()
		discard_pile.append(card)
		card_discarded.emit(card)
	hand_pile_cleared.emit()

# 开局补齐手牌
func draw_cards_to_limit() -> void:
	var draw_amount = hand_limit - hand_pile.size()
	if draw_amount > 0:
		draw_cards(draw_amount)
#endregion

#region 内部方法
# 抽单张卡，触发PHD中的实例化函数
func _draw_single_card() -> void:
	if draw_pile.is_empty():
		if discard_pile.is_empty(): return
		_reshuffle_discard_to_draw()
		
	var drawn_card = draw_pile.pop_back()
	hand_pile.append(drawn_card)
	print("抽了一张牌")
	# 直接下发实体对象给 UI，不传 index
	if player_hand_deck and player_hand_deck.has_method("add_card_to_hand"):
		player_hand_deck.add_card_to_hand(drawn_card)
	
	card_drawn.emit(drawn_card)

# 重置弃牌堆
func _reshuffle_discard_to_draw() -> void:
	var amount = discard_pile.size()
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle() 
	
	discard_shuffled_into_draw.emit(amount)
#endregion
