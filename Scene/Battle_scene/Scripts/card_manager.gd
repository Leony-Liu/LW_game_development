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
var card_count : int = 0


func _ready():
	_get_player_card_deck()
	_draw_initial_hand_card()

# ==========================================
# 牌堆整理
# ==========================================
# 1. 读取玩家牌组,并塞入抽牌堆（未实例化）
func _get_player_card_deck():
	# 获得玩家手牌牌组的副本，不会影响全局内的手牌牌组本身
	var playerdeck = PlayerDeckManager.get_deck().duplicate()
	# 塞入抽牌堆
	draw_pile = playerdeck
	print("卡牌管理器：抽牌堆已准备就绪，当前张数",draw_pile.size())
	
	
# 2. 战斗初始阶段：抽初始手牌
func _draw_initial_hand_card():
	print("卡牌管理器：开始抽牌")
	
	for i in range(5):
		# 安全检查：如果抽牌堆没牌了，就停止抽牌
		if draw_pile.is_empty():
			print("卡牌管理器：抽牌堆为空")
			break
		# 从抽牌堆拿出一个 ID (从数组头部拿)
		var card_id = draw_pile.pop_front()
		card_count = card_count + 1
		print("卡牌管理器：已添加",card_count,"张牌")
		# 让工厂根据 ID 实例化卡牌 (CardFactory 是你的全局单例)
		var new_card_node = CardFactory.create_card(card_id)
		# 把实例化的卡牌加进 UI 容器里（这样你就看到牌了）
		hand_container.add_child(new_card_node)
		# 把这个节点记录到 hand 数组里，方便以后管理
		hand.append(new_card_node)

	print("卡牌管理器：开局抽牌完成，当前手牌数量: ", hand.size())
	
	
