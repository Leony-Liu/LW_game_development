class_name BattleManager
extends Node

# 子系统管理器
@export var combat_manager: CombatManager
@export var card_manager: CardManger 

var battle_save_module: BattleSaveModule # 统筹存档与转译模块

# 内部状态
var is_battle_active: bool = false

# 信号连接
func _ready() -> void:
	card_manager.card_played.connect(_on_card_manager_card_played)
	combat_manager.input_lock_state_changed.connect(_on_combat_input_lock_changed)

# 初始化战斗，作为战斗场景唯一的对外接口
# 新增：接收局外传入的玩家与敌人实体数据
func start_battle(external_deck: Array, external_player_data: EntityData = null, external_enemy_data: EntityData = null) -> void:
	is_battle_active = true
	print("BattleManager: 战斗开始！初始化统筹系统...")
	
	var runtime_deck: Array[RuntimeCard] = []
	var runtime_player_data: EntityData
	var runtime_enemy_data: EntityData
	
	if battle_save_module:
		# 1. 将局外数据下发给存档模块进行转译和保存
		battle_save_module.input_deck = external_deck
		battle_save_module.input_player_data = external_player_data
		battle_save_module.input_enemy_data = external_enemy_data
		
		# 2. 从存档模块获取系统内流通的纯净数据
		runtime_deck = battle_save_module.process_and_get_runtime_deck()
		runtime_player_data = battle_save_module.process_and_get_player_data()
		runtime_enemy_data = battle_save_module.process_and_get_enemy_data()
	else:
		push_error("BattleManager: 未绑定 battle_save_module！无法转译牌组。")
		return
	
	# 3. 将数据交接给下层系统进行内部实例化
	card_manager.initialize(runtime_deck)
	
	if combat_manager.has_method("initialize_combat"):
		combat_manager.initialize_combat(runtime_player_data, runtime_enemy_data)
	else:
		push_warning("BattleManager: 暂未在 CombatManager 中找到 initialize_combat 方法")


# 处理卡牌系统的出牌信号
func _on_card_manager_card_played(runtime_card: RuntimeCard) -> void:
	if not is_battle_active:
		return
		
	# 直接从 RuntimeCard 提取带有 Buff 修正后的实时数据
	combat_manager._card_played(
		runtime_card.get_time_cost(),        
		runtime_card.get_action_name(),      
		runtime_card.compile_effect_data(),  
		runtime_card.get_priority()          
	)

# 桥接：当战斗系统锁定输入时
func _on_combat_input_lock_changed(is_locked: bool) -> void:
	if card_manager.player_hand_deck and card_manager.player_hand_deck.has_method("set_input_locked"):
		card_manager.player_hand_deck.set_input_locked(is_locked)
	
	if is_locked:
		print("BattleManager: 战斗系统执行中，已锁定玩家出牌UI")
	else:
		print("BattleManager: 战斗系统闲置，允许玩家出牌")

# 外部注入 Buff 通道
func inject_card_buff(target_card: RuntimeCard, buff_id: String, property: String, modifier_type: CardBuff.ModifierType, value: float, time_left: int = -1, count_left: int = -1) -> void:
	if not is_battle_active:
		return
		
	card_manager.apply_buff_to_card(target_card, buff_id, property, modifier_type, value, time_left, count_left)
