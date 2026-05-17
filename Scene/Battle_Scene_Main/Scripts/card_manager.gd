# 定义：卡牌管理器
#
# 牌堆整理：装载玩家牌组、抽五张牌


extends Node


# ==========================================
# 参数
# ==========================================
# 定义三个牌堆
var draw_pile: Array = []# 抽牌堆
var hand: Array = []# 手牌堆
var discard_pile: Array = []# 弃牌堆

# 参数
@export var hand_container : HBoxContainer
@export var max_hand_size : int = 5  # 【新增】限制最大手牌数量
@export var player_node: Node
@export var card_factory : Node

var card_count : int = 0


func _ready():
	_get_player_card_deck()
	_draw_initial_hand_card()
	
	# 监听成功出牌的信号
	BattleBus.card_successfully_played.connect(_on_card_successfully_played)
	
	
# ==========================================
# 玩家主动控制抽牌 (按键 F)
# ==========================================
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("draw_card"):
		# 1. 计算需要补齐几张牌
		var needed_cards = max_hand_size - hand.size()
		if needed_cards <= 0:
			print("系统：手牌已满，无法抽牌！")
			return
			
		# 2. 获取玩家节点（假设玩家和 CardManager 都在战斗场景根节点下）
		if not player_node:
			print("卡牌管理器：未找到'Player'节点")
			return
			
		# 3. 安全检测：只有在待机（Idle）状态下才能抽牌，防止在受击或攻击时抽牌
		#var state_machine = player_node.get_node_or_null("StateMachine")
		#if state_machine and state_machine.current_state.name != "Idle":
			#print("系统：玩家正在行动或受击中，无法抽牌！")
			#return
			
		# 4. 体力扣除判定
		var combat_data = player_node.get_node_or_null("Data/CombatData")
		if combat_data:
			# 尝试扣除 1 点体力
			if combat_data.consume_stamina(1):
				print("系统：消耗 1 点体力，补齐手牌（抽 %d 张）" % needed_cards)
				draw_cards(needed_cards)
			else:
				# 体力不足，触发 UI 警告
				combat_data.not_enough_stamina.emit()
				print("系统：体力不足，无法抽牌！")


# ==========================================
# 牌堆整理
# ==========================================
# 1. 读取玩家牌组,并塞入抽牌堆（未实例化）
func _get_player_card_deck():
	var playerdeck = PlayerDeckManager.get_deck().duplicate()
	draw_pile = playerdeck
	draw_pile.shuffle() # 开局洗牌
	print("卡牌管理器：抽牌堆已准备就绪，当前张数", draw_pile.size())

# 2. 战斗初始阶段：抽初始手牌
func _draw_initial_hand_card():
	print("卡牌管理器：开局抽牌")
	draw_cards(max_hand_size) # 开局直接抽满最大手牌数

# ==========================================
# 核心循环：抽牌、洗牌、弃牌
# ==========================================

# 通用抽牌方法
func draw_cards(amount: int):
	for i in range(amount):
		# 如果抽牌堆空了，尝试洗牌
		if draw_pile.is_empty():
			_shuffle_discard_to_draw()
			
		# 洗完牌如果还是空，说明弃牌堆和抽牌堆都没牌了
		if draw_pile.is_empty():
			print("卡牌管理器：牌库彻底空了，无牌可抽！")
			break
			
		# 从抽牌堆拿出一个 ID
		var card_id = draw_pile.pop_front()
		card_count += 1
		
		# 实例化卡牌
		var new_card_node = card_factory.create_card(card_id)
		hand_container.add_child(new_card_node)
		hand.append(new_card_node)
		
		# 播放抽牌出现的平滑展开动画
		if new_card_node.has_method("play_draw_animation"):
			new_card_node.play_draw_animation()

	print("卡牌管理器：抽牌完毕，当前手牌数量: %d | 抽牌堆剩余: %d" % [hand.size(), draw_pile.size()])

# 洗牌逻辑：将弃牌堆倒回抽牌堆并打乱
func _shuffle_discard_to_draw():
	if discard_pile.is_empty():
		return
		
	print("卡牌管理器： 抽牌堆已空，正在将弃牌堆洗入抽牌堆...")
	# 转移并打乱
	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	
	# 清空弃牌堆
	discard_pile.clear()
	print("卡牌管理器： 洗牌完成！当前抽牌堆张数: ", draw_pile.size())

# 收到卡牌打出成功的信号：加入弃牌堆并播放动画
func _on_card_successfully_played(card_node: Control):
	# 1. 从手牌数组中移除
	if hand.has(card_node):
		hand.erase(card_node)
		
	# 2. 将这把牌的 ID 记录进弃牌堆
	if "card_id" in card_node:
		discard_pile.append(card_node.card_id)
		print("卡牌管理器：卡牌(ID:%d)进入弃牌堆。当前弃牌堆数量: %d" % [card_node.card_id, discard_pile.size()])
		
	# 3. 触发该卡牌的平滑消失动画
	if card_node.has_method("play_discard_animation"):
		card_node.play_discard_animation()
	else:
		card_node.queue_free()
