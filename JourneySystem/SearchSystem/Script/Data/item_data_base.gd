##物品数据基类
##挂载：全局
##作用：负责读取CSV、查抄物品、搜索时返回物品数据
extends Node

var item_list: Array[ItemData]

func _ready() -> void:
	load_csv("res://DataBase/AllItemData.csv")
	print("开始读取数据")

##读取CSV
func load_csv(path: String):
	
	print("读取：" + path)
	item_list.clear()
	
	var file := FileAccess.open(path, FileAccess.READ)
	
	
	if file == null:
		push_error("ItemDataBase：无法打开CSV数据包：" + path)
		return
	
	#读取表头
	var headers := file.get_csv_line()
	
	while  not file.eof_reached():
		var row := file.get_csv_line()
		
		if row.is_empty():
			continue
		
		if row.size() < headers.size():
			continue
		
		var id := int(row[0])
		var item_name := row[1]
		var item_type := row[2]
		var rarity := int(row[3])
		var weight := int(row[4])
		var icon_path := row[5]
		var description := row[6]
		
		var icon: Texture2D = null
		if icon_path != "":
			icon = load(icon_path) as Texture2D

		var item := ItemData.new(id,item_name,item_type,rarity,weight,icon,description)
		item_list.append(item)
		
		file.close()
	pass


##随机返回count件物品
func get_random_items(count: int) -> Array[ItemData]:
	
	if item_list.is_empty():
		print("ItemDataBase无数据传入")
	#创建结果列表
	var result: Array[ItemData] = []
	
	if item_list.is_empty():
		return result

	# 创建候选列表
	var candidates := item_list.duplicate()
	
	#随机确定物品数量（后续需可控）
	for i in range(count):
		if candidates.is_empty():
			break
		#加权随机添加物品
		var total_weight := 0
		
		for item in candidates:
			total_weight += item.weight
		
		if total_weight <= 0:
			break
		
		var random_value := randi_range(1, total_weight)
		
		var current_weight := 0
		
		for item in candidates:
			current_weight += item.weight
			
			if random_value <= current_weight:
				result.append(item)
				candidates.erase(item)
				break

	return result
	pass


##根据ID查找物品
func find_item(id):
	for item in item_list:
		if item.id == id:
			return item
	
	return null
	pass
