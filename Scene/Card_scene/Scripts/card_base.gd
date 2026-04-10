# card_base
#
# 身份领取
# 出牌后发送自身数据
# 视觉表现：接收报错与动画

extends Control

# 参数
var card_id :int
var card_data:Dictionary# 卡牌数据存储

func _ready():
	_fetch_data_from_database()
	# 初始化时，监听自己是否被退回
	EventBus.card_rejected.connect(_on_card_rejected)
	
	
# ==========================================
# 身份领取
# ==========================================
func _fetch_data_from_database():
	# 1.失败检测
	if card_id == 0:
		print("基础卡牌：数据获取失败")
		return
		
	# 2.获取卡牌数据，打包进“card_data”
	card_data = CardDataBase.get_card(card_id)
	print("基础卡牌：成功获取数据 -> ", card_data.get("name", "未知卡牌"))
	
	
# ==========================================
# 出牌后发送自身数据
# ==========================================

func _on_button_pressed():
	print("基础卡牌：玩家点击了卡牌！发送请求...")
	# 【修复关键】：不仅发数据，还要把实体(self)一起发过去！
	EventBus.card_played.emit(card_data, self)


# ==========================================
# 视觉表现：接收报错与动画
# ==========================================

# 监听到任何卡牌被退回时触发
func _on_card_rejected(target_node: Control):
	# 核心：看看裁判退回的到底是不是我自己？
	if target_node == self:
		play_error_shake()
		pass

# 播放报错动画（变红 + 左右抖动）
func play_error_shake():
	# 瞬间变红 (保留了透明度)
	modulate = Color(1, 0.2, 0.2, 1) 
	
	# 创建原生补间动画 (Tween)
	var tween = create_tween()
	var original_pos = position
	
	# 极其短促的左右横跳 (0.05秒一次)
	tween.tween_property(self, "position:x", original_pos.x - 10, 0.05)
	tween.tween_property(self, "position:x", original_pos.x + 10, 0.05)
	tween.tween_property(self, "position:x", original_pos.x, 0.05)
	
	# 动画结束后，颜色花 0.15 秒平滑恢复正常 (白色)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.15)
