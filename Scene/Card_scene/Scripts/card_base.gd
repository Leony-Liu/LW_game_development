# card_base
#
# 身份领取
# 出牌后发送自身数据
# 视觉表现：接收报错与动画

extends Control

# ==========================================
# 动画参数配置 (直接在检查器中调节)
# ==========================================
@export_category("弃牌动画设置 (Discard Anim)")
## 弃牌动画的持续时间（秒）。数值越小，卡牌消失越快。
@export var discard_duration: float = 0.15 
## 消失时向上飘移的距离。负数表示向上，正数表示向下。
@export var discard_y_offset: float = -40.0 
## 弃牌运动的曲线类型。
@export var discard_trans: Tween.TransitionType = Tween.TRANS_QUART 
## 弃牌缓动方向。通常使用 EASE_OUT 让结尾更平滑。
@export var discard_ease: Tween.EaseType = Tween.EASE_OUT 
@export_category("抽牌动画设置 (Draw Anim)")
## 抽牌时宽度展开的持续时间（秒）。
@export var draw_duration: float = 0.20 
## 抽牌展开的运动曲线。
@export var draw_trans: Tween.TransitionType = Tween.TRANS_QUART 
## 抽牌展开的缓动方向。
@export var draw_ease: Tween.EaseType = Tween.EASE_OUT 
## 抽牌时透明度淡入（变亮）的持续时间（秒）。
@export var draw_fade_duration: float = 0.15 
## 抽牌透明度淡入的曲线。推荐 TRANS_SINE。
@export var draw_fade_trans: Tween.TransitionType = Tween.TRANS_SINE

# ==========================================
# 内部参数
# ==========================================
var card_id :int
var card_data: Dictionary # 卡牌数据存储

var original_min_size: Vector2 # 记录卡牌原本的大小
var is_playing_discard_anim: bool = false # 防止动画冲突

@onready var card_cost = $Visual/MarginContainer/CostLable

func _ready():
	# 记录原本的尺寸，为了给抽牌的“展开动画”提供目标宽度
	original_min_size = custom_minimum_size
	if original_min_size.x == 0:
		original_min_size = size # 兜底机制
		
	_fetch_data_from_database()
	BattleBus.card_rejected.connect(_on_card_rejected)
	
# ==========================================
# 身份领取 (保持不变)
# ==========================================
func _fetch_data_from_database():
	if card_id == 0:
		print("基础卡牌：数据获取失败")
		return
	card_data = CardDataBase.get_card(card_id)
	
	if card_data["stamina_cost"] != 0 :
		card_cost.text = str(card_data["stamina_cost"])
	elif card_data["mana_cost"] != 0: # 原来写的是 card_cost["mana_cost"]，注意修正
		card_cost.text = str(card_data["mana_cost"])
	elif card_data["stamina_cost"] == 0 and card_data["mana_cost"] == 0:
		card_cost.text = ""
	else:
		push_error("基础卡牌：该卡牌未设置体力/能量消耗")
		
# ==========================================
# 出牌与报错 (保持不变)
# ==========================================
func _on_button_pressed():
	BattleBus.card_played.emit(card_data, self)

func _on_card_rejected(target_node: Control):
	if target_node == self:
		play_error_shake()

func play_error_shake():
	modulate = Color(1, 0.2, 0.2, 1) 
	var tween = create_tween()
	var original_pos = position
	tween.tween_property(self, "position:x", original_pos.x - 10, 0.05)
	tween.tween_property(self, "position:x", original_pos.x + 10, 0.05)
	tween.tween_property(self, "position:x", original_pos.x, 0.05)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.15)


# ==========================================
# 视觉表现：弃牌与平滑缩进动画 (已接入检查器参数)
# ==========================================
func play_discard_animation():
	if is_playing_discard_anim:
		return
	is_playing_discard_anim = true
	
	# 禁用鼠标交互，防止在消失过程中被再次点击引发报错
	mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	var tween = create_tween()
	tween.set_parallel(true) 
	
	# 1. 透明度消失
	tween.tween_property(self, "modulate:a", 0.0, discard_duration) \
		.set_trans(discard_trans).set_ease(discard_ease)
		
	# 2. 向上位移
	tween.tween_property(self, "position:y", position.y + discard_y_offset, discard_duration) \
		.set_trans(discard_trans).set_ease(discard_ease)
	
	# 3. 宽度收缩 (控制旁边卡牌的平滑挤压)
	tween.tween_property(self, "custom_minimum_size:x", 0.0, discard_duration) \
		.set_trans(discard_trans).set_ease(discard_ease)
	
	# 动画结束后彻底销毁
	tween.chain().tween_callback(self.queue_free)


# ==========================================
# 视觉表现：抽牌出现动画 (已接入检查器参数)
# ==========================================
func play_draw_animation():
	# 初始状态隐藏并压扁
	custom_minimum_size.x = 0
	modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 1. 宽度从 0 展开到原宽度
	tween.tween_property(self, "custom_minimum_size:x", original_min_size.x, draw_duration) \
		.set_trans(draw_trans).set_ease(draw_ease)
		
	# 2. 透明度淡入
	tween.tween_property(self, "modulate:a", 1.0, draw_fade_duration) \
		.set_trans(draw_fade_trans).set_ease(Tween.EASE_IN_OUT)
