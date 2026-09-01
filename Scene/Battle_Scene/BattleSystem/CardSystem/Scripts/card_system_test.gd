extends Node

# 捕获下属的核心管理器
@onready var card_manager: CardManger = $".."

func _ready() -> void:
	# 监听卡牌打出信号，验证输出结果
	card_manager.card_played.connect(_on_test_card_played)
	
	# 1. 模拟 BattleManager 传入初始牌组 (请替换为你数据库里真实的卡牌 ID)
	var test_deck: Array[int] = [1001,1001,1001,1001,1001,1002,1003,1004,1005] 
	print(">>> 模拟测试：初始化牌组")
	card_manager.initialize(test_deck)



func _input(event: InputEvent) -> void:
	# 测试 1：按空格键，模拟战斗系统给第一张手牌挂载减费 Buff
	if event.is_action_pressed("ui_accept"): 
		if card_manager.hand_pile.size() > 0:
			var target_card = card_manager.hand_pile[0]
			# 添加一个绝对赋值 (SET) 为 0 费用的 Buff，不受时间影响，打出1次后失效
			var test_buff = CardBuff.new("test_free", "cost", CardBuff.ModifierType.SET, 0.0, -1, 1)
			target_card.add_buff(test_buff)
			print(">>> 模拟测试：给第一张牌强制设为 0 费！")
			
	# 测试 2：按 T 键，模拟战斗系统推进 Timeline 时间
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		print(">>> 模拟测试：Timeline 推进 10 时间单位")
		for card in card_manager.hand_pile:
			card.advance_time(10)

# 验证最终输出
func _on_test_card_played(runtime_card: RuntimeCard) -> void:
	print("=====================================")
	print("玩家打出了卡牌：", runtime_card.card_data.get("name"))
	print("消耗资源：", runtime_card.get_resource_cost())
	print("消耗时间：", runtime_card.get_time_cost())
	print("最终生成意图字典：", runtime_card.compile_effect_data())
	
	# 模拟动作执行完毕，消耗基于次数的 Buff
	runtime_card.consume_action_event()
	print("=====================================")
