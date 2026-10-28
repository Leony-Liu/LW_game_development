## 定义共享的静态武器模板与初始牌组引用。
## 不保存玩家拥有的武器、卡牌实例或可变牌组状态。
class_name WeaponData
extends Resource

@export_category("基本信息")
@export var id: int
@export var name: String
@export_multiline var description: String

@export_category("初始牌组")
## 静态卡牌模板 ID；允许重复，不在此创建 CardInstance。
@export var starting_combat_deck_card_ids: Array[int] = []
@export var starting_reserve_deck_card_ids: Array[int] = []
