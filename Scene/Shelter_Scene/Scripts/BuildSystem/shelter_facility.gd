extends StaticBody3D
class_name ShelterFacility


# ============================================================
# Shelter Facility
# ============================================================
#
# 基地设施基础节点。
#
# 当前负责：
# - 设施 ID
# - 建造碰撞尺寸
# - 所属房间 ID
#
# 后续可以继续加入：
# - Storage Item ID
# - 建造成本
# - 设施等级
# - 功能状态
# - 存档数据
# ============================================================


@export_category("Facility")

@export var facility_id: StringName = &"test_facility"

@export var display_name: String = "Test Facility"


@export_category("Placement")

## 用于建造合法性检测的实际尺寸。
##
## 必须与设施真正占用空间大致一致。
@export var placement_size: Vector3 = Vector3(
	1.8,
	1.0,
	0.5
)


## 当前所属房间。
var room_id: int = -1


func set_room_id(
	new_room_id: int
) -> void:
	room_id = new_room_id
