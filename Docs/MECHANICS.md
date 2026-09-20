# MECHANICS.md

> **文件作用（给人和 AI）：**这是项目的“玩法规则与数值层”。它记录当前源码实际采用的计算方式、数据含义、时间/伤害/资源/随机规则，以及已经表达但尚未实现或尚未确认的设计意图。  
> **它不负责：**列出所有函数、记录当前开发进度或规定 Agent 的工作纪律。实现位置请查 `CODE_INDEX.md`，当前任务请查 `AI_PROGRESS.md`。  
> **阅读规则：**标为“源码已实现”的规则可作为当前实现事实；标为 **[待确认]** 的规则不能被 AI 擅自固化成最终设计。  
> **基线：**依据 `PROJECT_DUMP.md`（2026-09-20 19:17 +08:00）静态分析，未做运行验证。

## 0. 状态标记

- **[源码已实现]**：可以直接从当前代码/Resource 证明。
- **[当前实现存在冲突]**：不同代码路径采用了不一致的规则。
- **[待确认：设计意图]**：来自旧版 `AGENTS.md` 或资源描述，但当前代码未完整实现。
- **[请用户填写]**：当前材料无法判断，需要人为决定。

## 1. 游戏总体设计

### 1.1 高层定位

**[待确认：设计意图，来自旧版 AGENTS.md]**

- 非回合制肉鸽卡牌战斗。
- 战斗使用“逻辑行动轴时间”而不是传统玩家/敌人轮流回合。
- 每把武器绑定一个牌组；武器毁坏时对应牌组消失。
- 地牢探索时进入带敌人的房间，随后从探索切换到卡牌战斗。

### 1.2 核心循环

**[待确认：设计意图]**

```text
基地整备
→ 进入地图
→ 探索
→ 获得物资
→ 遭遇
→ 战斗
→ 奖励
→ 完成地图目标
→ 收集/存放
→ 撤离
→ 返回基地
→ 保存成长
```

**[待确认：设计意图]** 出生房包含物资收集设施；玩家取得的物资/奖励需要存入设施后，远征结束才会保留。

当前源码尚未实现完整基地、物资、奖励、撤离和长期成长闭环。

## 2. 卡牌静态数据

`CardData` 当前字段：

- `id`
- `name`
- `stamina_cost`
- `mana_cost`
- `damage`
- `time_cost`
- `priority`
- `description`
- `card_type`
- `effects`

`CardType`：

- `Attack = 0`
- `Skill = 1`
- `Power = 2`

### 2.1 当前卡牌表

| ID | 名称 | 类型字段 | 体力 | 脑力 | 伤害 | 时间 | 优先级 | 描述中的额外效果 |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1001 | 重劈 | Attack | 2 | 0 | 70 | 60 | 3 | 无 |
| 1002 | 迅跃斩 | Attack | 1 | 0 | 25 | 30 | 3 | “伤害提升10%” |
| 1003 | 致命斩击 | Attack | 2 | 0 | 20 | 30 | 3 | “下一次攻击增加15点” |
| 1004 | 快砍 | Attack | 1 | 0 | 20 | 10 | 3 | 无 |
| 2001 | 蓄力 | Skill | 0 | 1 | 0 | 5 | 0 | “下一次攻击提升25点伤害” |
| 2002 | 崩势步 | **当前数据为 Attack** | 0 | 2 | 0 | 5 | 0 | “下一次攻击伤害增加50%” |
| 1005 | 劈砍 | Attack | 1 | 0 | 30 | 30 | 3 | 无 |

### 2.2 描述与实现差异

**[当前实现存在冲突 / 待确认]**

当前这些 `.tres` 的 `effects` 数组全部为空；`RuntimeCard.create_action()` 当前只从基础 `damage` / `shield` 和 `CardBuff` 计算效果。

因此：

- “迅跃斩伤害提升 10%”
- “致命斩击让下一次攻击 +15”
- “蓄力让下一次攻击 +25”
- “崩势步让下一次攻击 +50%”

目前都只能视为**文本设计描述**，不能视为已经生效。

另外 `CardData.play()` + `CardEffect.execute()` 是另一条旧效果路径，而现行战斗链主要走：

`RuntimeCard -> CombatAction -> EntityManager`

AI 修改卡牌机制前必须先确认是否废弃旧 `CardData.play()` 路径。

## 3. 卡牌资源消耗

### 3.1 RuntimeCard 的当前计算

**[源码已实现]**

`RuntimeCard.get_resource_cost()`：

```text
如果 card_type == Attack:
    基础消耗 = stamina_cost
否则:
    基础消耗 = mana_cost

最终消耗 = CardBuff 修正后的 resource_cost
最终结果四舍五入为 int，并限制 >= 0
```

### 3.2 BattleManager 的当前实际扣费

**[当前实现存在冲突]**

`BattleManager._on_card_play_requested()` 当前无论卡牌类型，都执行：

```text
entity_manager.can_player_afford(cost, "stamina")
entity_manager.consume_player_resource(cost, "stamina")
```

所以当前代码的实际行为是：

- Attack 的 `get_resource_cost()` 来源于 `stamina_cost`，再扣 stamina。
- Skill / Power 的 `get_resource_cost()` 来源于 `mana_cost`，但仍然从 **stamina** 扣除。

**[待确认]**：技能/Power 是否应真正消耗 `mana`？若是，这是当前优先修复的不一致。

### 3.3 资源回复

`EntityData` 定义：

- `stamina_regen_rate = 1.0`
- `mana_regen_rate = 0.5`

但当前 `BattleManager._on_timeline_time_advanced()` 只调用：

`card_manager.advance_hand_buffs_time(delta_time)`

**没有实际给 stamina / mana 回复。**

源码注释提到“扣除手牌 Buff 时间与回复体力”，但回复部分尚未实现。

**[请用户填写]**：
- stamina 是否应每逻辑时间单位回复？
- regen_rate 的单位是“每 1 行动值”还是“每 N 行动值”？
- mana 是否自然回复？

## 4. 逻辑时间轴

### 4.1 玩家卡排期

**[源码已实现]**

`Timeline.receive_card()`：

```text
time_cost = runtime_card.get_time_cost()
priority = runtime_card.get_priority()
target_time = current_time + time_cost

如果 priority == 0:
    action.trigger_time = current_time
否则:
    action.trigger_time = target_time

随后 Timeline 仍会推进到 target_time
```

这意味着“优先级 0”在当前实现中具有特殊含义：**行动效果立即触发，但仍消耗其 time_cost 并把逻辑时间推进到目标时刻。**

**[待确认]**：`priority == 0` 是否确实应该代表“瞬发”，还是应该有独立字段表示瞬发。

### 4.2 行动排序

**[源码已实现]**

`Timeline._sort_actions(a, b)`：

1. `trigger_time` 小的先执行。
2. 同一 `trigger_time` 下，`priority` 大的先执行。
3. 同时间、同优先级时，`is_player == true` 的玩家行动先执行。

**[待确认：设计状态]**：旧版设计文档明确说“同刻排序尚未稳定，不应被重构悄悄定为最终规则”。因此上面的排序是**当前实现事实**，不是自动视为最终设计。

### 4.3 推进方式

**[源码已实现]**

`advance_timeline_to(target_time)` 会：

1. 找出 `target_time` 以前（含）的最早行动。
2. 先把 `current_time` 推到该行动时间。
3. 发出 `time_advanced(delta)`。
4. 发出 `action_triggered(action)`。
5. 等待外部调用 `notify_action_finished()`。
6. 继续寻找下一个到期行动。
7. 最后把剩余时间推进到 `target_time`。
8. 发出 `timeline_advancement_finished`。

因此逻辑时间和动画时间原则上已经分离：行动轴等待“表现完成通知”，但动画耗时本身不会改变逻辑行动值。

## 5. 敌人 AI

### 5.1 当前敌人数据

| ID | 名称 | 等级 | HP | 行动 time_cost | cooldown | weight | `effect_data` |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1001 | testenemy1 | 0 | 100 | 30 | 60 | 0.5 | `{}` |
| 1002 | testenemy2 | 1 | 100 | 30 | 60 | 0.5 | `{}` |

### 5.2 加权随机与冷却

**[源码已实现]**

`EnemyAI`：

- 每个行动有 `weight`。
- 在当前规划时间点筛选已经冷却完成的行动。
- 使用轮盘赌权重随机选择。
- 触发时间 = `current_plan_start + time_cost`。
- 选中后，下次可用时间 = `target_time + cooldown`。
- `_last_planned_time` 防止下一次规划早于已经预定的行动。

若全部技能仍在冷却：

```text
_last_planned_time = current_plan_start + 10
return
```

当前没有看到自动在这 10 点后重新请求规划的机制。

### 5.3 当前敌人伤害

**[源码已实现]**

`EnemyAI._create_combat_action_from_enemy_action()` 对 `"attack"` 使用：

```text
damage = effect_data.get("damage", 10.0)
```

现有两个测试敌人的 `effect_data = {}`，因此当前代码会给它们的普通攻击装配 **10 点伤害**。

### 5.4 连续行动规划

**[当前未完成]**

`EntityManager.initialize()` 会调用 `plan_initial_actions()`，但当前未看到敌人行动结算后再次调用 `plan_next_action()` 的完整闭环。

**[待确认]**：下一次敌人规划应由谁触发？
- `BattleManager`
- `EntityManager`
- `Timeline`
- 其他

建议保持“Timeline 只负责排期、不做 AI 决策”的现有职责方向。

## 6. 伤害、护盾与属性

### 6.1 当前伤害模型

**[源码已实现]**

玩家卡伤害：

```text
base_damage = CardData.damage
final_damage = RuntimeCard._calculate_property("damage", base_damage)
CombatAction 添加 hp = -final_damage
```

敌人伤害同样最终转为负 `hp` impact。

当前没有：

- 防御力减伤公式
- 暴击
- 命中/闪避
- 元素抗性

除非另有新代码，这些机制都不应由 AI 擅自假设存在。

### 6.2 护盾吸收

**[源码已实现]**

当 `CombatEntity.apply_attribute_impact()` 收到：

`attribute_name == "hp"` 且 `value < 0`

当前规则：

```text
incoming_damage = abs(value)

如果 shield > 0:
    先扣 shield
    shield 不足时，剩余伤害再扣 hp

如果 shield 足够:
    hp 不变
```

当前未看到护盾自然衰减、上限或回合清空规则。

### 6.3 Attribute 公式

**[源码已实现]**

一个 `Attribute` 有：

- `computed_value`
- 可选 `custom_formula`
- `Array[AttributeBuff]`

取值时：

```text
current_base =
    custom_formula()   （若存在）
    否则 computed_value

对 buffs 按数组当前顺序逐个执行：
    + add_value
    - sub_value
    * mul_value
    / div_value（div != 0）
```

没有统一的最小值/最大值 clamp。

`AttributeSet.bind_custom_formula_to_attribute()` 可以让依赖属性变化时触发目标属性重算。

## 7. CardBuff

### 7.1 生命周期

**[源码已实现]**

`CardBuff` 可以同时带：

- `time_left`
- `count_left`

其中 `-1` 表示对应维度不消耗。

- 时间轴推进 → `tick_time(delta)`
- 卡牌出牌成功 → `consume_action_event()` → `tick_count()`

达到 `<= 0` 时 Buff 被移除。

### 7.2 计算顺序

`ModifierType`：

1. `SET`
2. `ADD`
3. `MULTIPLY`

`RuntimeCard._calculate_property()` 会先按类型排序，然后依次应用。

最终：

```text
round(final_value)
→ 转 int
→ maxi(0, ...)
```

所以卡牌的：

- `resource_cost`
- `time_cost`
- `priority`
- `damage`
- `shield`

都不会通过这一路径得到负数。

### 7.3 当前重复入口风险

**[当前实现存在冲突]**

`EntityManager.execute_action()` 对 `action.card_buffs` 会发出 `card_buff_requested`。

`BattleManager` 已监听这个信号，并转发给 `CardManager`。

但 `BattleManager._on_timeline_action_triggered()` 随后又直接遍历同一个 `action.card_buffs` 再调用一次：

`card_manager.apply_buff_to_all_hand_cards(card_buff)`

因此当前代码存在**同一 CardBuff 可能被施加两次**的路径。

## 8. 卡牌牌堆

**[源码已实现]**

`CardManager` 持有三个权威数组：

- `draw_pile`
- `hand_pile`
- `discard_pile`

当前规则：

- 初始化时把输入的 RuntimeCard 全部放入 draw pile。
- 抽牌堆随机 `shuffle()`。
- 自动补手牌至 `hand_limit`。
- `CardSystem.tscn` 当前 `hand_limit = 6`。
- 出牌确认后：hand → discard。
- 主动弃牌后：hand → discard。
- draw 空且 discard 非空时：复制 discard → draw，清空 discard，再 shuffle。

UI `PlayerHandDeck` 只实例化/删除卡牌表现节点，不应成为逻辑牌堆所有者。

## 9. 地图生成

### 9.1 当前默认 MapBlueprint

`test_mapblueprint.tres`：

- `base_room_count = 15`
- `count_variance = 0.2`
- `boss_count = 0`
- `enemy_spawn_chance = 0.7`
- `elite_chance = 0.25`
- `room_type_weights = { NORMAL: 100 }`

### 9.2 房间数量

**[源码已实现]**

```text
min_count = round(base_room_count * (1 - variance))
max_count = round(base_room_count * (1 + variance))
target_room_count = random integer [min_count, max_count]
```

以当前默认值：

```text
15 ± 20%
→ 12 ~ 18 个房间
```

### 9.3 地图几何

- 房间逻辑尺寸：`10.0`
- 半尺寸：`5.0`
- 初始房固定在 `(0, 0)`
- 四方向扩展：N / S / E / W
- `CORRIDOR_BIAS = 0.1`

扩展时：
- 10% 概率优先从最新生成的房间继续延伸。
- 其他情况从已有房间随机选一个再扩展。

相邻房间会自动建立双向 `connected_doors`。

### 9.4 敌人分配

初始房不生成敌人。

其余房间：

```text
70% 概率有敌人
有敌人时：
    25% → 等级 1 敌人
    75% → 等级 0 敌人
```

实际敌人 ID 从 `AllEnemyData` 中按 `enemy_level` 随机选择。

### 9.5 Boss 选址算法

虽然当前 `boss_count = 0`，代码已经实现 Boss 位置选择：

```text
score = BFS 深度 * 10
      + (死胡同 ? 60 : 0)
```

优先：
1. 高分。
2. 不同主分支。
3. 分支不足时按总分补齐。

但当前敌人库只有 `enemy_level = 0 / 1`。

**[待确认 / 当前数据不完整]**：若把 `boss_count` 调到 > 0，`WorldGenerator` 会尝试查找 `enemy_level == 2`，当前会找不到并返回 `-1`。

## 10. 探索与遭遇

### 10.1 开门

当前门参数默认：

- 下沉深度：`3.0 m`
- 自动关门距离：`2.0 m`
- 开/关动画：`0.5 s`
- 交互：直接检测 `KEY_E`

### 10.2 当前门关闭逻辑异常

**[当前实现疑似 Bug，需运行确认]**

`Door._process()` 中，当门已打开且 `current_player` 存在：

- 距离 > 2m → `close_door()`
- 距离 <= 2m → 当前代码的 `else` 也调用 `close_door()`

所以按静态代码，门打开动画结束后，只要玩家仍被记录，就可能立即开始关门。

### 10.3 房间识别

玩家开门后，`WorldManager`：

1. 读取玩家和门的 X/Z 坐标。
2. 计算玩家指向门的单位向量。
3. 从门位置向前偏移 `4.0`。
4. 除以 `10.0` 后四舍五入，再乘回 `10.0`。
5. 得到门对面的房间中心坐标。

如果目标房存在，更新 `current_room_coords`。

### 10.4 遭遇切换

如果目标房 `has_enemies`：

```text
EXPLORE
→ PREPARING_BATTLE
→ 暂停 PlayerController
→ 等 1.2 秒
→ BATTLE
→ 当前代码又把 PlayerController 重新设为 active
```

当前尚未实际启动 `BattleManager`。

**[待确认]**：进入正式战斗后，探索 PlayerController 是否应该继续保持关闭，直到战斗结束？

## 11. 玩家移动与镜头

### 11.1 当前场景实际移速

脚本默认：
- walk = 3.5
- sprint = 6.5

但 `PlayerVisual.tscn` 覆盖为：
- **walk = 2.5**
- **sprint = 4.5**

因此以当前场景实例为准。

### 11.2 奔跑

- WASD 直接读物理键，不依赖 InputMap。
- 只有“按住左 Shift 且输入方向包含向前 (`input_dir.y < 0`)”才使用 sprint speed。
- 加速度默认 `10.0`。
- 重力来自项目设置。

### 11.3 视角

- 身体 Yaw 灵敏度：`0.001`
- 头部 Pitch 灵敏度：`0.002`
- Pitch clamp：`-60° ~ +60°`

### 11.4 Head bob

步行：
- freq `10`
- amp `0.04`

奔跑：
- freq `14`
- amp `0.08`

## 12. 存档

### 12.1 SaveManager

**[源码已实现基础框架]**

路径：

`user://saves/<slot_id>.json`

根结构：

```text
{
  "metadata": {...},
  "modules_data": {
    "<module_key>": ...
  }
}
```

模块必须提供：

- `get_module_key()`
- `get_save_data()`
- `load_save_data()`
- `clear_data()`

### 12.2 BattleSaveModule

**[当前实现不一致，不能视为可用机制]**

当前已发现：

- `BattleManager.start_battle()` 检查 `save_initial_state`，但 `BattleSaveModule` 没有这个方法。
- `BattleSaveModule` 使用 `EntityData.base_attributes`，但当前 `EntityData` 没有该字段。
- `BattleSaveModule.load_save_data()` / `build_test_player_data()` 对 `EntityData.new()` 的参数形态与当前构造函数不一致。
- 对 `EnemyData.base_attributes` 的访问与当前 `EnemyData.attributes` 字段不一致。
- `_compile_input_to_runtime()` 仍为 `pass`。
- `RuntimeCard.to_dictionary()` 当前不保存 `active_buffs`。
- `CardInstance.modifiers` 在 `BattleManager._convert_deck_to_runtime()` 中没有被转换为战斗内 Buff/Modifier。

因此战斗读档/恢复规则尚未稳定。

## 13. 仍需用户做出的机制决定

以下内容请不要让 AI 自行“补全设计”。

- **[请用户填写]** Skill / Power 的资源类型与扣费规则：
- **[请用户填写]** stamina / mana 回复公式：
- **[请用户填写]** 同时间、同优先级行动最终排序：
- **[请用户填写]** `priority == 0` 是否永久定义为瞬发：
- **[请用户填写]** CardBuff 的 SET / ADD / MULTIPLY 同类型多个 Buff 的排序是否重要：
- **[请用户填写]** Buff 在“出牌请求、确认出牌、行动结算、时间推进”的哪个阶段消耗：
- **[请用户填写]** 防御/护甲、暴击等是否计划进入伤害公式：
- **[请用户填写]** 护盾是否会衰减/清空/有上限：
- **[请用户填写]** 敌人下一次规划的触发时机：
- **[请用户填写]** RNG 是否需要固定种子并进入存档：
- **[请用户填写]** 遭遇失败/撤离失败后的奖励和地图状态：
- **[请用户填写]** 战斗中读档要恢复到什么粒度：
