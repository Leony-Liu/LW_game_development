extends Control
class_name UICardItem

signal card_interacted(card_id: int, click_type: String, is_equipped: bool)

var card_id: int = 0
var is_in_equipped_zone: bool = false

# 严格按照你截图中 base_card_item.tscn 的节点树路径绑定
@onready var cost_label = $Visuals/Background/CostContainer/CostLable
@onready var name_label = $Visuals/Background/NameContainer/NameLable

func setup(id: int, is_equipped: bool):
	card_id = id
	is_in_equipped_zone = is_equipped
	
	var card_data = CardDataBase.get_card(id)
	if card_data.is_empty(): return
	
	# 1. 绑定名字
	var name_key = card_data.get("name_key", "未知卡牌")
	# 如果你在本地化(Localization)里没有配置 CARD_NA 的翻译，这里会直接显示 CARD_NA
	name_label.text = tr(name_key) 
	
	# 2. 绑定费用 (根据你的 CSV 表头截断情况)
	var category = card_data.get("categories", "attack")
	var cost = 0
	if category == "attack":
		cost = card_data.get("stamina_c", 0) # 你的 CSV 中列名为 stamina_c
	elif category == "skill":
		cost = card_data.get("mana_cos", 0)  # 你的 CSV 中列名为 mana_cos
		
	cost_label.text = str(cost)

# 鼠标交互逻辑
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("点击了卡牌！卡牌ID：", card_id) # 添加这行打印
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_interacted.emit(card_id, "left_click", is_in_equipped_zone)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			card_interacted.emit(card_id, "right_click", is_in_equipped_zone)
