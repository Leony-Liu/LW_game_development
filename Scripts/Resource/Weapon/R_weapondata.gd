## 定义可复用的静态武器模板元数据。
## 牌组关系、装备状态与运行时效果由后续设计决定。
class_name WeaponData
extends Resource

@export_category("基本信息")
@export var id: int
@export var name: String
@export_multiline var description: String
