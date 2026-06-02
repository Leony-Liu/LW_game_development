# 定义：卡牌管理器 (3D 重构版)
#
# 牌堆整理：装载玩家牌组、抽牌并自动放入空闲的 3D 槽位

extends Node

# ==========================================
# 参数
# ==========================================
# 定义三个牌堆
var draw_pile: Array = [] # 抽牌堆
var hand: Array = []      # 手牌堆
var discard_pile: Array = [] # 弃牌堆

# 节点引用 (在检查器中配置)
@export var hand_deck_node: Node  # 【修改点】指向 player_hand_deck 场景根节点 (包含5个槽位)
@export var max_hand_size: int = 5  # 限制最大手牌数量
@export var card_factory: Node      # 卡牌工厂

var card_count: int = 0

func _ready():
	_get_player_card_deck()
	_draw_initial_hand_card()
	
	# 监听成功出牌的信号
	BattleBus.card_successfully_played.connect(_on_card_successfully_played)
	# 监听主动弃牌请求
	BattleBus.card_discard_requested.connect(_on_card_discard_requested)


func _get_player_node() -> Node:
	# 动态在场景树中寻找标记为 "Player" 的节点
	return get_tree().get_first_node_in_group("Player")
	
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
			
		# 2. 获取玩家节点
		var player_node = _get_player_node()
		if not player_node:
			print("卡牌管理器：未找到 'Player' 节点，可能 3D 场景还未加载完毕")
			return
			
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
	print("卡牌管理器：抽牌堆已准备就绪，当前张数: ", draw_pile.size())

# 2. 战斗初始阶段：抽初始手牌
func _draw_initial_hand_card():
	print("卡牌管理器：开局抽牌")
	draw_cards(max_hand_size) # 开局直接抽满最大手牌数

# ==========================================
# 核心循环：抽牌、洗牌、弃牌
# ==========================================

# 通用抽牌方法 (适配 3D 槽位系统)
func draw_cards(amount: int):
	for i in range(amount):
		# 1. 洗牌检查
		if draw_pile.is_empty():
			_shuffle_discard_to_draw()
			
		if draw_pile.is_empty():
			print("卡牌管理器：牌库彻底空了，无牌可抽！")
			break
			
		# 2. 寻找一个空闲的槽位 (遍历 HBoxContainer 下的 5 个 Slot)
		var empty_slot: Control = null
		if hand_deck_node:
			for slot in hand_deck_node.get_children():
				# 如果这个槽位下没有子节点，说明是空的
				if slot.get_child_count() == 0:
					empty_slot = slot
					break
		
		if empty_slot == null:
			print("卡牌管理器：手牌槽位已满，无法放置新卡牌！")
			break
			
		# 3. 抽牌与实例化
		var card_id = draw_pile.pop_front()
		card_count += 1
		var new_card_node = card_factory.create_card(card_id)
		
		# 4. 将卡牌放入空槽位
		empty_slot.add_child(new_card_node)
		
		# 因为放入了固定槽位，所以强制卡牌坐标归零，让它完美贴合槽位
		new_card_node.position = Vector2.ZERO 
		
		# 记录进手牌数组
		hand.append(new_card_node)
		
		# 5. 播放出场动画
		if new_card_node.has_method("play_draw_animation"):
			new_card_node.play_draw_animation()

	print("卡牌管理器：抽牌完毕，当前手牌数量: %d" % hand.size())

# 洗牌逻辑：将弃牌堆倒回抽牌堆并打乱
func _shuffle_discard_to_draw():
	if discard_pile.is_empty():
		return
		
	print("卡牌管理器：抽牌堆已空，正在将弃牌堆洗入抽牌堆...")
	# 转移并打乱
	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	
	# 清空弃牌堆
	discard_pile.clear()
	print("卡牌管理器：洗牌完成！当前抽牌堆张数: ", draw_pile.size())

# 收到卡牌打出成功的信号：加入弃牌堆并播放动画
# 【修改点】参数类型改成了 Node，以兼容 3D 的 Area3D 节点
func _on_card_successfully_played(card_node: Node):
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

# ==========================================
# 玩家主动右键弃牌
# ==========================================
func _on_card_discard_requested(card_node: Node) -> void:
	var player_node = _get_player_node()
	if not player_node: return
	
	var combat_data = player_node.get_node_or_null("Data/CombatData")
	
	# 2. 尝试扣除 1 点体力
	if combat_data and combat_data.consume_stamina(1):
		print("卡牌管理器：消耗 1 点体力，主动弃置卡牌成功！")
		# 完美复用你之前写好的“进入弃牌堆并播放动画”的方法
		_on_card_successfully_played(card_node)
	else:
		print("卡牌管理器：体力不足，无法弃牌！")
		# 拒绝弃牌，让卡牌发红抖动，并解锁让玩家可以继续操作
		BattleBus.card_rejected.emit(card_node)
		if combat_data:
			combat_data.not_enough_stamina.emit() # 触发UI红光或提示音
