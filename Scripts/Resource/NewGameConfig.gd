## 只定义新玩家的初始武器选择。
## 已保存的武器不读取此配置来重置牌组。
extends Resource
class_name NewGameConfig

@export var initial_weapon_id: int = 3001
