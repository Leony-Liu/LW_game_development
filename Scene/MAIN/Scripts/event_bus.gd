# 定义：全局时间广播(单例)
# 作用：
# 放置需要全局通报的信号

extends Node

# —————— 卡牌信号 ——————
signal card_played(card_data: Dictionary, card_node: Control) # 一张牌被打出
signal card_rejected(card_node: Control) # 卡牌不能打出

# —————— 状态信号 ——————
signal player_died(death_context: String)# 玩家死亡

# —————— 过程性信号 ——————
signal player_dealt_damage(payload: Dictionary)# 传递玩家造成的伤害
