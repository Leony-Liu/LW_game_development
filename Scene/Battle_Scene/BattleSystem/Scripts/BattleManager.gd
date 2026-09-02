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
func start_battle(external_deck: Array, external_player_data: EntityData = null, enemy_id: int = -1) -> void:
	is_battle_active = true
	print("BattleManager: 战斗开始！初始化统筹系统...")
	
	# 核心：通过 ID 向数据库提取完整的敌人模板
	var real_enemy_data = AllEnemyData.get_enemy(enemy_id)
	if not real_enemy_data:
		push_error("BattleManager: 无法找到敌人数据，ID: " + str(enemy_id))
		return
	
	var runtime_deck: Array[RuntimeCard] = []
	var runtime_player_data: EntityData
	var runtime_enemy_data: EnemyData # 注意此处类型改为 EnemyData
	
	if battle_save_module:
		battle_save_module.input_deck = external_deck
		battle_save_module.input_player_data = external_player_data
		# 传入真实的敌人数据供存档模块深拷贝/快照
		battle_save_module.input_enemy_data = real_enemy_data 
		
		runtime_deck = battle_save_module.process_and_get_runtime_deck()
		runtime_player_data = battle_save_module.process_and_get_player_data()
		runtime_enemy_data = battle_save_module.process_and_get_enemy_data()
	else:
		return
	
	card_manager.initialize(runtime_deck)
	combat_manager.initialize_combat(runtime_player_data, runtime_enemy_data)


# 处理卡牌系统的出牌信号
func _on_card_manager_card_played(runtime_card: RuntimeCard) -> void:
	if not is_battle_active:
		return

	# 直接从 RuntimeCard 提取带有 Buff 修正后的实时数据
	combat_manager.runtimecard_to_combataction(runtime_card)

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
