extends Area3D

# ==========================================
# 动画参数配置 (3D版)
# ==========================================
@export var discard_duration: float = 0.15 
@export var discard_y_offset: float = 2.0 # 3D中的消失向上漂移距离
@export var draw_duration: float = 0.20 

@onready var illustration_sprite: Sprite3D = $Visuals/CardIMG/Sprite3D

var card_id: int
var card_data: Dictionary

# 状态控制
var is_locked: bool = false # 防误触锁：播放动画或正在判定时锁定
var is_hovered: bool = false
var original_pos: Vector3
var original_rot: Vector3

@onready var visuals = $Visuals
@onready var cost_label = $Visuals/CostNumber/Cost
@onready var name_label = $Visuals/CardNamePoint/CardName

func _ready() -> void:
	# 记录初始的本地坐标和旋转，用于悬停动画复位
	original_pos = visuals.position
	original_rot = visuals.rotation
	
	_fetch_data_from_database()
	
	# 连接总线信号
	BattleBus.card_rejected.connect(_on_card_rejected)
	
	# 连接 Area3D 自带的鼠标交互信号
	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)
	self.input_event.connect(_on_input_event)

# ==========================================
# 身份与数据装载
# ==========================================
func _fetch_data_from_database() -> void:
	if card_id == 0: return
	
	card_data = CardDataBase.get_card(card_id)
	
	# 1. 同步UI显示 
	var cost = card_data.get("stamina_cost", 0)
	if cost == 0:
		cost = card_data.get("mana_cost", 0)
	
	cost_label.text = str(cost) if cost > 0 else ""
	name_label.text = str(card_data.get("name", "Unknown"))

	# ==========================================
	# 核心修改：将卡面换上对应的外部美术资源
	# ==========================================
	var img_name = card_data.get("image_name", "card") 
	var img_path = "res://Scene/Card_Scene/Arts/CardIllustration/%s.png" % img_name
	
	if ResourceLoader.exists(img_path):
		# 2. 【核心修复】把图片赋值给插图节点，千万别再动 background_sprite 了！
		illustration_sprite.texture = load(img_path)
	else:
		print("⚠️ 3D卡牌警告：找不到对应的插图资源 -> ", img_path)

# ==========================================
# 3D 交互与出牌广播
# ==========================================
func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	# 防误触：必须是左键刚刚按下，且卡牌没有被锁定
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_locked: return 
		
		print("3D卡牌被点击，发起出牌请求...")
		is_locked = true # 立刻上锁，防止玩家帕金森狂点
		BattleBus.card_played.emit(card_data, self) 

func _on_card_rejected(target_node: Node) -> void:
	if target_node == self:
		is_locked = false # 解锁，允许重新打出
		play_error_shake()

# ==========================================
# 3D 悬停动画 (视差摇摆)
# ==========================================
func _on_mouse_entered() -> void:
	if is_locked: return
	is_hovered = true
	# 鼠标放上去时，卡牌稍微往上浮一点点 (Z轴或Y轴，取决于你的摄像机角度)
	create_tween().tween_property(visuals, "position:y", original_pos.y + 0.5, 0.1)

func _on_mouse_exited() -> void:
	is_hovered = false
	# 鼠标离开，复位
	var tween = create_tween().set_parallel(true)
	tween.tween_property(visuals, "position", original_pos, 0.15)
	tween.tween_property(visuals, "rotation", original_rot, 0.15)

func _process(delta: float) -> void:
	# 悬停时的 3D 摇摆计算
	if is_hovered and not is_locked:
		var viewport_size = get_viewport().get_visible_rect().size
		var mouse_pos = get_viewport().get_mouse_position()
		
		var offset_x = (mouse_pos.x / viewport_size.x) * 2.0 - 1.0
		var offset_y = (mouse_pos.y / viewport_size.y) * 2.0 - 1.0
		
		# 最大倾斜 15 度
		var target_rot_x = original_rot.x + (-offset_y * deg_to_rad(15.0))
		var target_rot_y = original_rot.y + (offset_x * deg_to_rad(15.0))
		
		visuals.rotation.x = lerp(visuals.rotation.x, target_rot_x, 8.0 * delta)
		visuals.rotation.y = lerp(visuals.rotation.y, target_rot_y, 8.0 * delta)

# ==========================================
# 3D 视觉表现：动画
# ==========================================
func play_error_shake() -> void:
	# 3D 版的错误晃动：沿 X 轴快速抖动 
	var tween = create_tween()
	var base_x = original_pos.x
	tween.tween_property(visuals, "position:x", base_x - 0.2, 0.05)
	tween.tween_property(visuals, "position:x", base_x + 0.2, 0.05)
	tween.tween_property(visuals, "position:x", base_x, 0.05)

func play_discard_animation() -> void:
	is_locked = true
	var tween = create_tween().set_parallel(true)
	# 向上飘逸并缩放至 0 
	tween.tween_property(self, "position:y", position.y + discard_y_offset, discard_duration)
	tween.tween_property(visuals, "scale", Vector3.ZERO, discard_duration)
	tween.chain().tween_callback(self.queue_free)

func play_draw_animation() -> void:
	# 出场动画：从扁平变立体
	visuals.scale = Vector3(0, 1, 1)
	create_tween().tween_property(visuals, "scale", Vector3(1, 1, 1), draw_duration).set_ease(Tween.EASE_OUT)
