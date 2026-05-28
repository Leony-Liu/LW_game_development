extends Node

const SAVE_DIR = "user://saves/"

func _ready() -> void:
	# 游戏启动时，检查并创建存档专属文件夹
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

# 极简版：仅保存名字
func create_new_save(player_name: String) -> void:
	# 使用时间戳作为唯一ID，防止同名存档互相覆盖
	var save_id = str(Time.get_unix_time_from_system()) 
	
	# 你未来要扩展的所有数据，都往这个字典里塞
	var save_data = {
		"id": save_id,
		"name": player_name
	}
	
	# 拼接文件路径：user://saves/save_1690000000.json
	var file_path = SAVE_DIR + "save_" + save_id + ".json"
	
	# 写入本地文件 (使用 JSON 格式，方便你开发时直接打开看)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		# "\t" 参数可以让生成的 JSON 文件自动换行缩进，阅读极其舒适
		file.store_string(JSON.stringify(save_data, "\t"))
		print("存档创建成功！玩家姓名: %s, 路径: %s" % [player_name, file_path])
	else:
		push_error("存档创建失败！")
