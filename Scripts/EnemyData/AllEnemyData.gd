extends Node


var _database: Dictionary = {}

const ENEMY_DATA_DIR = "res://Scripts/EnemyData/EnemyDatas/"

func _ready() -> void:
	_load_all_enemies_from_directory()

func _load_all_enemies_from_directory() -> void:
	var dir = DirAccess.open(ENEMY_DATA_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				# 兼容 Godot 导出项目后的资源重映射
				var actual_file = file_name.replace(".remap", "")
				if actual_file.ends_with(".tres") or actual_file.ends_with(".res"):
					var file_path = ENEMY_DATA_DIR + actual_file
					var resource = ResourceLoader.load(file_path)
					
					# 确保加载的资源确实是 EnemyData 类型
					if resource is EnemyData:
						_database[resource.enemy_id] = resource
						print("[AllEnemyData]已加载敌人数据: -ID: %s- %s" % [resource.enemy_id, resource.enemy_name])
			file_name = dir.get_next()
	else:
		push_error("无法打开敌人数据文件夹，请检查路径: " + ENEMY_DATA_DIR)

func get_enemy(id: int) -> EnemyData:
	if not _database.has(id):
		push_warning("未找到指定的敌人 ID: " + str(id))
		return null
	return _database.get(id)
