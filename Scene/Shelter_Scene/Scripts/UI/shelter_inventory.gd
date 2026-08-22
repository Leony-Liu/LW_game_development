extends Control

# 通过 Unique Name (%) 获取节点，无论你后续怎么调整 UI 层级结构都不会报错
@onready var item_list: ItemList = %ItemList

func _ready() -> void:
	# 清空可能在编辑器里留下的测试占位数据
	if item_list:
		item_list.clear()

# 由主页面打开时调用
func refresh_ui() -> void:
	if not item_list:
		return
	item_list.clear()

	# 预留获取数据的接口
	var items = _get_items_from_logic()

	for item in items:
		# 提取物品名称并添加到列表中
		var item_name = item.get("name_key", "未知物品") 
		item_list.add_item(item_name)

# 预留给后端逻辑的对接函数
func _get_items_from_logic() -> Array:
	# 待明确具体的单例调用方法后填入
	return []
