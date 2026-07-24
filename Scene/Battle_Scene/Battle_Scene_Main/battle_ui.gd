extends Control
class_name BattleUIRoot

# ==========================================
# 1. 美术资源插槽 (彻底告别硬编码，在编辑器右侧拖拽赋值)
# ==========================================
@export_category("Player HUD Assets")
@export var stamina_icon_texture: Texture2D
@export var mana_icon_texture: Texture2D

# ==========================================
# 2. 节点绑定 (已完全匹配你的最新场景树)
# ==========================================
@export_category("Enemy HUD Nodes")
@export var enemy_hp_current :Control
@export var enemy_hp_diff :Control
@export var enemy_hp_label :Control

@export_category("Player HUD Nodes")
@export var player_hp_bar :Control
@export var player_sp_bar :Control # HBoxContainer
@export var player_mp_bar :Control # HBoxContainer

# 存储敌人扣血缓动动画的变量，防止连续受击动画冲突
var catchup_tween: Tween 

func _ready() -> void:
	# 确保 UI 不遮挡 3D 视角的鼠标点击事件
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# ==========================================
	# 3. 统一监听全局总线信号
	# ==========================================
	BattleBus.enemy_hp_changed.connect(_on_enemy_hp_changed)
	
	BattleBus.player_hp_changed.connect(_on_player_hp_changed)
	BattleBus.player_stamina_changed.connect(_on_player_stamina_changed)
	BattleBus.player_mana_changed.connect(_on_player_mana_changed)

# ==========================================
# 4. 敌人 HUD 更新 (极简数字 + 扣血缓动)
# ==========================================
func _on_enemy_hp_changed(current: int, max_hp: int) -> void:
	# 敌人血量显示纯数字
	enemy_hp_label.text = str(current)
	
	enemy_hp_current.max_value = max_hp
	enemy_hp_diff.max_value = max_hp
	
	# 真实血条瞬间扣除
	enemy_hp_current.value = current
	
	# 差值血条平滑追赶
	if catchup_tween and catchup_tween.is_valid():
		catchup_tween.kill()
		
	catchup_tween = create_tween()
	catchup_tween.tween_property(enemy_hp_diff, "value", current, 0.4)\
		.set_delay(0.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

# ==========================================
# 5. 玩家 HUD 更新 (血条与动态方块)
# ==========================================
func _on_player_hp_changed(current_hp: float, max_hp: float) -> void:
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = current_hp

# 【动态渲染体力方块】
func _on_player_stamina_changed(current_stamina: int, max_stamina: int) -> void:
	# 清空原本的格子
	for child in player_sp_bar.get_children():
		child.queue_free()
		
	# 根据最大体力值，生成对应数量的格子
	for i in range(max_stamina):
		var icon = TextureRect.new()
		icon.texture = stamina_icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# 设置单个格子的长宽 (与你 Figma 导出的尺寸保持协调)
		icon.custom_minimum_size = Vector2(25, 25) 
		
		if i < current_stamina:
			# 有体力：保持原图高亮颜色
			icon.modulate = Color.WHITE 
		else:
			# 没体力：变暗灰并半透明，显示为“空壳”
			icon.modulate = Color(0.3, 0.3, 0.3, 0.5) 
			
		player_sp_bar.add_child(icon)

# 【动态渲染脑力方块】
func _on_player_mana_changed(current_mana: int, max_mana: int) -> void:
	# 清空原本的格子
	for child in player_mp_bar.get_children():
		child.queue_free()
		
	for i in range(max_mana):
		var icon = TextureRect.new()
		icon.texture = mana_icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(25, 25) 
		
		if i < current_mana:
			# 有脑力：保持原图高亮
			icon.modulate = Color.WHITE 
		else:
			# 没脑力：变暗灰并半透明，显示为“空壳”
			icon.modulate = Color(0.3, 0.3, 0.3, 0.5) 
			
		player_mp_bar.add_child(icon)
