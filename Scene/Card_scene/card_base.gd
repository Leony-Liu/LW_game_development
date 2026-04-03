# 定义：基础卡牌
# 作用：
# A.拿着ID去数据库认领自己
# B.点击后执行的部分
# C.执行通用逻辑


extends Control

# 参数
var card_id :int
var card_data:Dictionary# 卡牌数据存储

func _ready():
	_fetch_data_from_database()
	
	
	
# A.拿到ID后去数据库找自己
func _fetch_data_from_database():
	# 1.失败检测
	if card_id == 0:
		print("基础卡牌：数据获取失败")
		return
		
	# 2.获取卡牌数据，打包进“card_data”
	card_data = CardDataBase.get_card(card_id)
	print("基础卡牌：成功获取数据")
	
	
	
# B.当卡牌被点击后执行：发送信号及该卡牌数据
func _on_button_pressed():
	#发送信号并携带这张牌的数据
	EventBus.card_played.emit(card_data)
	
	
