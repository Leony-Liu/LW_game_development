# Autoload 读取所有卡牌数据并打包成字典
extends Node


const CARDS_DIR = "res://Scripts/CardData/Cards/"


var _card_database: Dictionary = {} 

func _ready():
	_load_all_cards()

# 读取文件夹并打包
func _load_all_cards():
	_card_database.clear()
	
	var dir = DirAccess.open(CARDS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var file_path = CARDS_DIR + file_name
				var card_res = load(file_path) as CardData
				
				if card_res and card_res.id != 0:
					_card_database[card_res.id] = card_res
				else:
					push_warning("卡牌加载失败或未配置有效 ID: ", file_path)
					
			file_name = dir.get_next()
			
		dir.list_dir_end()
		print("[CardDataManager] 初始化完成，共加载 ", _card_database.size(), " 张卡牌。")
	else:
		push_error("无法打开卡牌目录，请检查路径: ", CARDS_DIR)

# 获取所有卡牌（返回整个打包好的字典）
func get_cards() -> Dictionary:
	# 增加一层容错：如果因为某些原因数据空了，尝试重新加载
	if _card_database.is_empty():
		push_warning("卡牌库为空，尝试重新加载...")
		_load_all_cards()
	return _card_database
