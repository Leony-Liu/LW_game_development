# 接收玩家初始牌组(RuntimeCard数组)，管理卡牌在各个牌堆间的流转。
# 提供方法：抽牌、弃牌、出牌、洗牌、施加Buff
class_name CardManager
extends Node

# 绑定手牌展示节点
@export var player_hand_deck: Control
# 手牌上限
@export var hand_limit: int

#region 向上汇报信号
signal deck_initialized(deck_size: int)
signal card_drawn(runtime_card: RuntimeCard)
signal card_play_requested(runtime_card: RuntimeCard)
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
		player_hand_deck.card_play_requested.connect(_on_hand_deck_card_play_requested)
		player_hand_deck.card_discard_requested.connect(discard_card)
	else:
		push_error("未在检查器中绑定 player_hand_deck！")

# 初始化系统，清空牌堆、读取传入的实例数组、补齐手牌
func initialize(player_deck: Array[RuntimeCard]) -> void:
	# 清空三个牌堆
	draw_pile.clear()
	hand_pile.clear()
	discard_pile.clear()
	
	if player_deck == null:
		print("[CardManager] 接收得到的玩家牌组为空")
		return
	
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

#region 卡牌Buff
# 接收打包好的 CardBuff 实例
func apply_buff_to_card(target_card: RuntimeCard, buff: CardBuff) -> void:
	if not target_card:
		push_warning("CardManager: 施加 Buff 失败，目标 RuntimeCard 为空。")
		return
	target_card.add_buff(buff)

# AOE 给所有手牌施加 Buff
func apply_buff_to_all_hand_cards(buff: CardBuff) -> void:
	for card in hand_pile:
		card.add_buff(buff)

# 随时间轴推进扣减手牌限时 Buff
func advance_hand_buffs_time(delta_time: int) -> void:
	for card in hand_pile:
		card.advance_time(delta_time)
#endregion

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
func _on_hand_deck_card_play_requested(runtime_card: RuntimeCard) -> void:
	if not hand_pile.has(runtime_card):
		push_warning("出牌失败：手牌堆中找不到该卡牌实例")
		return
	card_play_requested.emit(runtime_card)

func confirm_play_card(runtime_card: RuntimeCard) -> void:
	var current_index = hand_pile.find(runtime_card)
	if current_index == -1: 
		return

	# 1. 从手牌移除并向外汇报
	hand_pile.remove_at(current_index)
	card_played.emit(runtime_card)

	# 2. 通知手牌节点触发 CardLogic 的飞出动画（新增）
	if player_hand_deck and player_hand_deck.has_method("confirm_play"):
		player_hand_deck.confirm_play(runtime_card)

	# 3. 消耗卡牌上绑定的“出牌计数类”Buff（新增）
	runtime_card.consume_action_event()

	# 4. 压入弃牌堆（原逻辑保留）
	discard_pile.append(runtime_card)
	card_discarded.emit(runtime_card)

func cancel_play_card(runtime_card: RuntimeCard) -> void:
	# 通知手牌节点触发 CardLogic 的飘红与回弹动画
	if player_hand_deck and player_hand_deck.has_method("reject_action"):
		player_hand_deck.reject_action(runtime_card)

# 弃牌
func discard_card(runtime_card: RuntimeCard) -> void:
	var current_index = hand_pile.find(runtime_card)
	if current_index == -1: 
		return

	hand_pile.remove_at(current_index)

	# 新增：通知 UI 触发下落掉出动画
	if player_hand_deck and player_hand_deck.has_method("confirm_discard"):
		player_hand_deck.confirm_discard(runtime_card)

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
