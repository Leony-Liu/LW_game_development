extends Node


# —————— 卡牌信号 ——————
signal card_played(card_data: Dictionary, card_node: Control) # 一张牌被打出
signal card_successfully_played(card_node: Control) # 卡牌成功打出
signal card_rejected(card_node: Control) # 卡牌不能打出

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

# —————— 音频系统信号 ——————
# 参数：大分类(决定去哪个文件夹找)、文件名字、3D坐标(传 Vector3.ZERO 就是 2D 播放)
signal play_sfx(category: String, sound_name: String, global_pos: Vector3)
