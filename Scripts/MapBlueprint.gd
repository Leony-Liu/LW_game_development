class_name MapBlueprint
extends Resource

@export_group("房间规模浮动")
## 基准房间总数
@export var base_room_count: int = 10
## 房间数上下浮动比率 (0.2 表示 ±20%)
@export_range(0.0, 1.0) var count_variance: float = 0.2

@export_group("Boss 配额 (计数)")
## 本局固定生成的 Boss 房间数
@export var boss_count: int = 0

@export_group("常规遇敌概率")
## 房间总遇敌概率
@export_range(0.0, 1.0) var enemy_spawn_chance: float = 0.7
## 精英怪占比
@export_range(0.0, 1.0) var elite_chance: float = 0.25

@export_group("房间类型权重")
## 房间功能类型权重池 (当前默认为 100% 普通房)
@export var room_type_weights: Dictionary = {
	RoomData.RoomType.NORMAL: 100
}
