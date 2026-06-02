extends Control

# 绑定顶部的导航按钮
@onready var btn_character = $MarginContainer/TopNavigationBar/Btn_Character
@onready var btn_warehouse = $MarginContainer/TopNavigationBar/Btn_Warehouse
@onready var btn_shop = $MarginContainer/TopNavigationBar/Btn_Shop
@onready var btn_upgrade = $MarginContainer/TopNavigationBar/Btn_Upgrade
@onready var btn_craft = $MarginContainer/TopNavigationBar/Btn_Craft

# 绑定下方的具体面板
@onready var panel_character = $ContentArea/base_character_panel
@onready var panel_warehouse = $ContentArea/base_warehouse_panel
@onready var panel_shop = $ContentArea/base_shop_panel
@onready var panel_upgrade = $ContentArea/base_upgrade_panel
@onready var panel_craft = $ContentArea/base_craft_panel

# 用一个数组把所有面板装起来，方便统一管理
var all_panels: Array[Control] = []

func _ready() -> void:
	all_panels = [panel_character, panel_warehouse, panel_shop, panel_upgrade, panel_craft]
	
	# 连接按钮信号，使用 bind() 传递对应的面板
	btn_character.pressed.connect(_switch_to_panel.bind(panel_character))
	btn_warehouse.pressed.connect(_switch_to_panel.bind(panel_warehouse))
	btn_shop.pressed.connect(_switch_to_panel.bind(panel_shop))
	btn_upgrade.pressed.connect(_switch_to_panel.bind(panel_upgrade))
	btn_craft.pressed.connect(_switch_to_panel.bind(panel_craft))
	
	# 游戏刚进入基地时，默认打开“角色”面板
	_switch_to_panel(panel_character)


# 核心切换逻辑
func _switch_to_panel(target_panel: Control) -> void:
	# 遍历所有面板，如果要打开的等于目标面板就显示，否则就隐藏
	for panel in all_panels:
		if panel == target_panel:
			panel.show()
		else:
			panel.hide()
			
	# 可选：如果你想加个切换的音效，这里就可以调用你的音频总线
	# BattleBus.play_sfx.emit("ui_system", "tab_switch", Vector3.ZERO)
