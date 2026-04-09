extends Node
class_name BattleGameManager


@onready var player_manager = $Player
@onready var enemy_slot = $EnemySlot

var current_enemy: Node = null # 当前敌人

func _ready() -> void:
	
	EventBus.card_played.connect(_on_card_played)# 接收出牌信号
	EventBus.player_dealt_damage.connect(_on_player_dealt_damage)# 接收计算完的总伤害
	
	_register_current_enemy()

# 登记敌人列表的第一个敌人
func _register_current_enemy():
	if enemy_slot.get_child_count() > 0:
		current_enemy = enemy_slot.get_child(0)
		print("战斗裁判：已登记当前擂主 -> ", current_enemy.name)
	else:
		current_enemy = null
		

# 卡牌拦截
func _on_card_played(card_data: Dictionary, card_node: Control) -> void:
	
	# 1. 外部裁判判定（比如敌人钻地了，或者没敌人）
	if not can_play_card(card_data):
		print("战斗裁判：拦截！目标无效或处于特殊状态。")
		# 呼叫总线，让 UI 卡牌变红抖动
		EventBus.card_rejected.emit(card_node)
		return
		
	# 2. 内部状态判定（向下命令玩家出牌）
	if player_manager.execute_card(card_data):
		print("战斗裁判：允许出牌！")
		# 既然牌都成功打出了，直接在画面上销毁这张牌
		card_node.queue_free() 
	else:
		print("战斗裁判：拦截！玩家处于硬直或非Idle状态，无法出牌。")
		# 同样打回去报错
		EventBus.card_rejected.emit(card_node)

# 接收玩家伤害，并转发给当前敌人
# 在 battle_game_manager.gd 中

func _on_player_dealt_damage(payload: Dictionary) -> void:
	# 只要擂台上有人，且他身上有 take_damage 这个方法
	if current_enemy and current_enemy.has_method("take_damage"):
		print("战斗裁判：收到玩家伤害包，直接路由给当前擂主...")
		
		# 直接调用根节点上的方法！水管连接到了极致的通畅！
		current_enemy.take_damage(payload)
	else:
		print("战斗裁判：伤害打空了！")
		
		
# 卡牌拦截逻辑
func can_play_card(card_data: Dictionary) -> bool:
	if card_data.has("categories") and card_data["categories"] == "attack":
		if current_enemy == null:
			return false
			
		# 直接判定当前擂主的状态
		var enemy_state = current_enemy.get_node("StateMachine").current_state.name
		if enemy_state in ["Burrowed", "Invincible"]: 
			return false
			
	return true
