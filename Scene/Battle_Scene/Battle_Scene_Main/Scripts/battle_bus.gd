extends Node

# —————— 战斗阶段信号 ——————
signal game_state_changed(state:int)
signal change_state_request(state:int)


signal battle_start()# 进入战斗
signal battle_inprogress()# 战斗开始
signal battle_finished(winner:String) # 战斗结束

# —————— 卡牌信号 ——————
signal deck_changed(deck:Dictionary)

signal card_played(card_data: Dictionary, card_node: Control) # 一张牌被打出
signal card_successfully_played(card_node: Control) # 卡牌成功打出
signal card_rejected(card_node: Control) # 卡牌不能打出
signal card_discard_requested(card_node: Control) # 请求主动弃牌

# —————— 行动轴相关 ——————
# 鼠标悬停卡牌时，请求时间轴显示时间推进预览。
signal card_timeline_preview_requested(card_node: Control,time_cost: int)
# 鼠标离开卡牌或卡牌被使用时，关闭对应预览。
signal card_timeline_preview_cleared(card_node: Control)
# 卡牌已经确认打出。
# 时间轴将悬停预览转换为实际推进动画。
signal card_timeline_preview_committed(time_cost: int)


# —————— 过程性信号 ——————
signal player_dealt_damage(payload: Dictionary) # 传递玩家造成的伤害
signal enemy_dealt_damage(payload: Dictionary)  # 传递敌人造成的伤害
signal enemy_died(death_context: String)  # 敌人死亡


# —————— UI 更新信号 ——————
# 敌人
signal enemy_hp_changed(current_hp: int, max_hp: int) # 敌人血量变化

# 玩家属性变化信号
signal player_hp_changed(current_hp: float, max_hp: float) # 玩家血量变化
signal player_stamina_changed(current_stamina: int, max_stamina: int) # 玩家体力变化
signal player_staminars_changed(current_staminars: float) # 玩家体力恢复速度变化
signal player_mana_changed(current_mana: int, max_mana: int) # 玩家能量变化
signal player_manars_changed(current_manars: float) # 玩家能量恢复速度变化
signal player_defence_changed(current_defence: float) # 玩家防御力变化
signal player_shield_changed(current_shield: float) # 玩家护盾变化

# —————— Buff 状态更新信号 ——————
signal player_buffs_changed(active_buffs: Dictionary) # 玩家 Buff 变化
signal enemy_buffs_changed(active_buffs: Dictionary)  # 敌人 Buff 变化

# —————— 音频系统信号 ——————
# 参数：大分类(决定去哪个文件夹找)、文件名字、3D坐标(传 Vector3.ZERO 就是 2D 播放)
signal play_sfx(category: String, sound_name: String, global_pos: Vector3)

# —————— 时间轴相关 ——————
signal action_committed(action: TimelineAction) # 被确认加入时间轴的行动
