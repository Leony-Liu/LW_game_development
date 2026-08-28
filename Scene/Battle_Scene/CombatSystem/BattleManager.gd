class_name BattleManager
extends Node

# 子系统管理器
@export var combat_manager: CombatManager
@export var card_manager: CardManger # 沿用你代码中的类名

# 内部状态
var is_battle_active: bool = false

# 初始化
func _ready() -> void:
	# 监听 CardManger 信号
	card_manager.card_played.connect(_on_card_manager_card_played)
	# 监听 CombatManager 信号
	combat_manager.input_lock_state_changed.connect(_on_combat_input_lock_changed)

# 外部调用入口：开始战斗
func start_battle(player_deck: Array[int]) -> void:
	is_battle_active = true
	print("BattleManager: 战斗开始！初始化统筹系统...")
	
	# 初始化卡牌系统
	card_manager.initialize(player_deck)
	
	# 抽取初始手牌
	card_manager.draw_cards(5)

# 出牌后执行
func _on_card_manager_card_played(card_id: int, hand_pile_index: int) -> void:
	if not is_battle_active:
		return
		
	# 拿取打出卡牌的信息
	var card_database = AllCardData.get_cards()
	var query_id = card_id 
	# 检查：是否有这张卡牌
	if not card_database.has(query_id):
		push_error("BattleManager: 无法在数据库中找到打出的卡牌 ID: ", query_id)
		return
	# 获取对应的 CardData 资源
	var card_data = card_database[query_id]
	
	# 2. 下达指令：将真实数据下发给战斗处理器
	combat_manager._card_played(
		card_data.cost,          # 行动花费的时间
		card_data.action_name,   # 行动名称
		card_data.effect_data,   # 效果字典 (如 {"type": "attack", "damage": 10})
		card_data.priority       # 优先级
	)

# 桥接：当战斗系统锁定输入时（例如正在播放动画）
func _on_combat_input_lock_changed(is_locked: bool) -> void:
	# 向下通知 UI 系统锁定/解锁交互
	if card_manager.player_hand_deck and card_manager.player_hand_deck.has_method("set_input_locked"):
		card_manager.player_hand_deck.set_input_locked(is_locked)
	
	if is_locked:
		print("BattleManager: 战斗系统执行中，已锁定玩家出牌UI")
	else:
		print("BattleManager: 战斗系统闲置，允许玩家出牌")
