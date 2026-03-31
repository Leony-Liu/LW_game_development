# 定义：卡牌管理器

# 作用：
# A.定义了抽牌堆、手牌堆、弃牌堆
# B.读取已选好的牌及其数量并塞入抽牌堆
# C.将牌抽到手牌堆并实例化


extends Node

# ——————A.定义三堆——————
var draw_pile: Array = []# 抽牌堆
var hand: Array = []# 手牌堆
var discard_pile: Array = []# 弃牌堆

# 参数
@onready var hand_container = $CardUI/HBoxContainer
var card_count : int = 0

# 初始化调用函数
func _ready():
	_get_player_card_deck()
	_draw_initial_hand_card()

# V.读取已经选好的牌及数量,并塞入抽牌堆，还未从数据库中读取数据
func _get_player_card_deck():
	# 获得玩家手牌牌组的副本，不会影响全局内的手牌牌组本身
	var playerdeck = PlayerDeckManager.get_deck().duplicate()
	# 塞入抽牌堆
	draw_pile = playerdeck
	print("卡牌管理器：抽牌堆已准备就绪，当前张数",draw_pile.size())
	
	
# C.战斗初始阶段：抽初始手牌
func _draw_initial_hand_card():
	print("卡牌管理器：开始抽牌")
	
	for i in range(5):
		# 安全检查：如果抽牌堆没牌了，就停止抽牌
		if draw_pile.is_empty():
			print("卡牌管理器：抽牌堆为空")
			break
		
		# 1. 从抽牌堆拿出一个 ID (从数组头部拿)
		var card_id = draw_pile.pop_front()
		card_count = card_count + 1
		print("卡牌管理器：已添加",card_count,"张牌")
		
		# 2. 让工厂根据 ID 实例化卡牌 (CardFactory 是你的全局单例)
		var new_card_node = CardFactory.create_card(card_id)
		
		# 3. 把实例化的卡牌加进 UI 容器里（这样你就看到牌了）
		hand_container.add_child(new_card_node)
		
		# 4. 把这个节点记录到 hand 数组里，方便以后管理
		hand.append(new_card_node)

	print("卡牌管理器：开局抽牌完成，当前手牌数量: ", hand.size())
	
	
