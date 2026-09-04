class_name BattleManager
extends Node

# 子系统管理器
@export var combat_manager: CombatManager
@export var card_manager: CardManger

var battle_save_module: BattleSaveModule

# 内部状态
var is_battle_active: bool = false

# 信号连接
func _ready() -> void:
	card_manager.card_played.connect(_on_card_manager_card_played)
	combat_manager.input_lock_state_changed.connect(_on_combat_input_lock_changed)

# 初始化战斗，将数据输入各个子系统
func start_battle(
	external_deck: Array[CardInstance], # 带入战斗的牌组
	external_player_data: EntityData = null, # 玩家数据
	enemy_id: int = -1 # 进入战斗的敌人ID
	) -> void:

	is_battle_active = true
	print("[BattleManager] 系统状态：激活")
	
	# 通过 ID 向数据库提取敌人模板
	var real_enemy_data = AllEnemyData.get_enemy(enemy_id)
	if not real_enemy_data:
		push_error("[BattleManager] 无法找到敌人数据，ID: " + str(enemy_id))
		return
	# 内部存储变量
	var runtime_deck: Array[RuntimeCard] = []
	var runtime_player_data: EntityData
	var runtime_enemy_data: EnemyData 
	# 将数据存入 BattleSaveModule
	if battle_save_module:
		# 存入
		battle_save_module.input_deck = external_deck
		battle_save_module.input_player_data = external_player_data
		battle_save_module.input_enemy_data = real_enemy_data 
		# 拿取
		runtime_deck = battle_save_module.process_and_get_runtime_deck()
		runtime_player_data = battle_save_module.process_and_get_player_data()
		runtime_enemy_data = battle_save_module.process_and_get_enemy_data()
	else:
		return
	# 初始化牌组、玩家、敌人
	card_manager.initialize(runtime_deck)
	combat_manager.initialize_combat(runtime_player_data, runtime_enemy_data)

# 交接 CardSystem（RuntimeCard） 卡牌给 CombatSystem（CombatAction）
func _on_card_manager_card_played(runtime_card: RuntimeCard) -> void:
	if not is_battle_active:
		return
	combat_manager.runtimecard_to_combataction(runtime_card)

# 交接 CombatSystem 的可出牌状态给 CardSystem
func _on_combat_input_lock_changed(is_locked: bool) -> void:
	if card_manager.player_hand_deck and card_manager.player_hand_deck.has_method("set_input_locked"):
		card_manager.player_hand_deck.set_input_locked(is_locked)
	
	if is_locked:
		print("[BattleManager] 战斗系统执行中，已锁定玩家出牌UI")
	else:
		print("[BattleManager] 战斗系统闲置，允许玩家出牌")

# 给 CardSystem 中的卡牌添加 buff
func inject_card_buff(
	target_card: RuntimeCard,# 目标卡牌
	buff_id: String, # buff名称
	property: String, # 修改的数值名称
	modifier_type: CardBuff.ModifierType,
	value: float, time_left: int = -1,
	count_left: int = -1
	) -> void:
	if not is_battle_active:
		return
		
	card_manager.apply_buff_to_card(target_card, buff_id, property, modifier_type, value, time_left, count_left)
