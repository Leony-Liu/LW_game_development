extends Node

var manager: TimelineManager
var player: BattleEntity
var enemy: BattleEntity

func _ready() -> void:
	# 1. 实例化核心组件 (纯逻辑测试，无需真实创建子节点层级)
	manager = TimelineManager.new()
	player = BattleEntity.new()
	enemy = BattleEntity.new()
	
	player.setup("勇者", 100, true)
	enemy.setup("哥布林", 60, false)
	
	# 2. 绑定 Manager 的输出信号到我们的打印函数
	manager.log_message.connect(_on_log_message)
	manager.timeline_updated.connect(_on_timeline_updated)
	manager.player_turn_started.connect(_on_player_turn_started)
	
	# 3. 启动战斗
	manager.init_battle([player, enemy])
	
	# 4. 模拟玩家输入: 过了1秒钟玩家思考时间，然后下达耗时 70 的大招指令
	await get_tree().create_timer(1.0).timeout
	manager.submit_player_action(player, enemy, "蓄力烈焰斩", 70, 40)

# ----- 接收 Manager 输出的回调（这里代替动画播放） -----
func _on_log_message(msg: String) -> void:
	print(msg)

func _on_timeline_updated(events: Array) -> void:
	# 这里只打印未来事件的状态，真实情况这里就是更新UI进度条的地方
	var preview = ""
	for e in events:
		if e.is_valid:
			preview += "[T=%d %s] " % [e.timestamp, e.action_name]
	# print("  [当前时间轴预告] -> ", preview)

func _on_player_turn_started(time: int) -> void:
	# 如果哥布林还没死，模拟玩家再次下达指令
	if not enemy.is_dead:
		await get_tree().create_timer(1.0).timeout
		manager.submit_player_action(player, enemy, "快速连击", 20, 30)
