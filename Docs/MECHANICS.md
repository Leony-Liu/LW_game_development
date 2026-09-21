# MECHANICS.md

> **文件作用（给人和 AI）：**这是项目的“玩法规则与数值层”。它记录当前源码实际采用的机制、已确认但尚未实现的设计，以及实现与设计之间的冲突。
>
> **它不负责：**
> - SceneTree / script contract / runtime data flow → `ARCHITECTURE.md`
> - 系统职责与 state ownership → `AI_CONTEXT.md`
> - 当前 blocker / milestone → `AI_PROGRESS.md`
> - 文件定位 → `CODE_INDEX.md`
> - Agent 工作规则 → `AGENTS.md`
>
> **事实原则：**
> 1. 当前真实 `.gd` / `.tres` / `.tscn` 高于本文。
> 2. `[IMPLEMENTED]` 只表示当前源码明确实现，不自动等于最终设计。
> 3. `[CONFIRMED DESIGN]` 表示用户已经确认的设计方向，即使代码尚未实现。
> 4. `[CONFLICT]` 表示当前实现内部不一致，AI 不得擅自选一边当最终规则。
> 5. `[PENDING DESIGN]` 表示仍需用户决定。
> 6. 不因为某个机制尚未实现就删除设计意图；也不因为描述文字存在就宣称机制已经生效。
>
> **当前基线：**2026-09-21。本文基于已有 `MECHANICS.md`、当前源码审计结果和已确认的长期架构决定整理。没有把 `PROJECT_DUMP.md` 作为 Agent 的实时事实来源；运行时行为若未实际验证，不标记为 runtime verified。

---

# 0. 状态标记

| 标签 | 含义 |
| --- | --- |
| `[IMPLEMENTED]` | 当前源码明确实现 |
| `[CONFIRMED DESIGN]` | 用户已确认的长期设计方向 |
| `[CONFLICT]` | 当前实现存在互相冲突的规则 |
| `[LEGACY]` | 旧实现仍存在，但不应驱动新设计 |
| `[PENDING DESIGN]` | 设计尚未决定 |
| `[RUNTIME VERIFY]` | 静态源码可见，但需要实际运行确认 |

---

# 1. 游戏总体设计

## 1.1 高层定位

以下来自既有设计文档，当前继续保留为设计方向；尚未全部由游戏闭环验证：

- 非传统轮流回合制的肉鸽卡牌战斗。
- 战斗以**逻辑行动轴时间**为核心，而不是“玩家回合 / 敌人回合”交替。
- 地图探索中进入带敌人的房间后，从探索切换到卡牌战斗。
- 武器与牌组存在长期绑定关系；武器毁坏时对应牌组消失。`[PENDING DESIGN]`：当前代码尚未实现这条长期系统。
- 基地、物资、撤离、长期成长属于更高层循环，当前源码尚未形成完整闭环。

## 1.2 长期核心循环

```text
基地整备
→ 进入远征
→ 地图探索
→ 获得物资
→ 遭遇
→ 战斗
→ 奖励
→ 完成地图目标
→ 收集 / 存放
→ 撤离
→ 返回基地
→ 保存长期成长
```

当前纵向开发优先级更窄：

```text
探索
→ 遭遇
→ ExpeditionManager
→ BattleSystem
→ battle result
→ 同一次 mapdata / RoomData
→ 返回探索
```

`[CONFIRMED DESIGN]`

## 1.3 远征 / 战斗职责对玩法的约束

已确认：

- `ExpeditionManager` 是探索 ↔ 战斗唯一上层协调器。
- `BattleSystem` 最终常驻于 `ExpeditionSystem`。
- `WorldManager` 持有当前地图 / 房间 / encounter truth。
- `BattleManager` 只负责单场战斗生命周期，不拥有地图或长期玩家成长。
- 玩家长期数据由 `PlayerSaveManager` 持有。
- 当前原型阶段不要求旧存档兼容。
- 最终一个 expedition-level save module 负责整次远征，而不是 World / Battle 各维护一套独立真相。

这些是玩法状态如何跨系统流动的设计约束。`[CONFIRMED DESIGN]`

---

# 2. 卡牌静态数据

## 2.1 `CardData`

当前 `CardData` 字段包括：

```text
id
name
stamina_cost
mana_cost
damage
time_cost
priority
description
card_type
effects
```

`CardType`：

```text
Attack = 0
Skill  = 1
Power  = 2
```

`[IMPLEMENTED]`

## 2.2 当前卡牌基线

既有资源索引记录：

| ID | 名称 | 类型 | stamina | mana | damage | time | priority | 描述中的附加效果 |
| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1001 | 重劈 | Attack | 2 | 0 | 70 | 60 | 3 | 无 |
| 1002 | 迅跃斩 | Attack | 1 | 0 | 25 | 30 | 3 | “伤害提升10%” |
| 1003 | 致命斩击 | Attack | 2 | 0 | 20 | 30 | 3 | “下一次攻击增加15点” |
| 1004 | 快砍 | Attack | 1 | 0 | 20 | 10 | 3 | 无 |
| 1005 | 劈砍 | Attack | 1 | 0 | 30 | 30 | 3 | 无 |
| 2001 | 蓄力 | Skill | 0 | 1 | 0 | 5 | 0 | “下一次攻击提升25点伤害” |
| 2002 | 崩势步 | 当前数据为 Attack | 0 | 2 | 0 | 5 | 0 | “下一次攻击伤害增加50%” |

**注意：**具体数值在相关任务中必须重新读取当前 `.tres`；本表是机制文档基线，不应覆盖真实资源文件。

## 2.3 描述 ≠ 已实现效果

当前旧文档审计显示，相关 `.tres` 的 `effects` 为空，而当前主战斗链主要依赖：

```text
RuntimeCard
→ CombatAction
→ Timeline
→ EntityManager
```

因此：

```text
迅跃斩 +10%
致命斩击 下一次攻击 +15
蓄力 下一次攻击 +25
崩势步 下一次攻击 +50%
```

只能视为**卡牌描述中的设计意图**，不能视为当前实际生效机制。

`[CONFLICT]`

## 2.4 Legacy CardEffect 路径

工程中仍存在：

```text
CardData.play()
→ CardEffect.execute()
```

以及：

```text
RuntimeCard
→ CombatAction
```

新主链明显偏向后者，但旧 CardEffect 路径尚未正式清理。

规则：

> 未经明确迁移任务，不应批量删除旧 CardEffect；也不应继续在两套效果系统中同时新增同一种机制。

`[LEGACY]`

---

# 3. CardInstance 与 RuntimeCard

## 3.1 `CardInstance`

设计角色：

```text
局外 / 长期 / 可持久化的一张卡
```

当前可保存的信息包括：

```text
card_id
modifiers
unique_id
```

具体字段以当前 `CardInstance.gd` 为准。

## 3.2 `RuntimeCard`

设计角色：

```text
单场战斗内的一张卡
```

持有：

```text
card_id
card_data
active_buffs
```

并负责基于当前 battle state 计算：

```text
resource_cost
time_cost
priority
damage
shield
CombatAction
```

`[IMPLEMENTED]`

## 3.3 当前转换缺口

当前 `BattleManager.start_battle()` 的 `CardInstance → RuntimeCard` 转换主要使用：

```text
card_id
card_data
```

当前审计发现：

```text
CardInstance.modifiers
CardInstance.unique_id
```

没有完整传入 `RuntimeCard`。

是否必须保留两者属于长期卡牌持久化设计的一部分。

`[PENDING DESIGN]`

---

# 4. 卡牌资源消耗

## 4.1 RuntimeCard 的资源成本

当前 `RuntimeCard.get_resource_cost()`：

```text
Attack
→ stamina_cost

Skill / Power
→ mana_cost

然后经过 CardBuff 的 resource_cost modifier
→ round()
→ int
→ clamp >= 0
```

`[IMPLEMENTED]`

## 4.2 BattleManager 当前实际支付

当前 `BattleManager` 对出牌请求固定使用：

```text
entity_manager.can_player_afford(cost, "stamina")
entity_manager.consume_player_resource(cost, "stamina")
```

因此实际出现：

```text
Attack:
stamina_cost → 扣 stamina

Skill / Power:
mana_cost → 仍扣 stamina
```

`[CONFLICT]`

### 待确认

`[PENDING DESIGN]`

需要明确：

```text
Attack 消耗什么？
Skill 消耗什么？
Power 消耗什么？
```

在决定前，不应让 AI 自行把 Skill / Power 改成 mana，哪怕这看起来最直觉。

---

# 5. 资源回复

`EntityData` 当前包含：

```text
stamina_regen_rate = 1.0
mana_regen_rate = 0.5
```

但当前 Timeline time advancement 只明确推进：

```text
CardManager.advance_hand_buffs_time(delta_time)
```

尚未看到稳定的 stamina / mana regeneration 结算。

因此：

```text
regen fields = 已存在
regen gameplay = 尚未完成
```

`[CONFLICT / PENDING DESIGN]`

需要定义：

- stamina 是否随 logical time 自动恢复？
- mana 是否自动恢复？
- regen rate 是“每 1 logical time”的量，还是其他单位？
- 回复是否允许超过初始/最大值？
- regen 在 action 前、action 后还是 time segment 推进时结算？

---

# 6. 逻辑时间轴

## 6.1 核心原则

逻辑时间和现实动画时间分离：

```text
logical time
≠
animation duration
```

Timeline 可以等待视觉表现完成，但动画播放几秒不应改变 `time_cost`。

`[IMPLEMENTED / DESIGN CONSISTENT]`

## 6.2 玩家卡排期

当前 `Timeline.receive_card()` 逻辑：

```text
time_cost = runtime_card.get_time_cost()
priority  = runtime_card.get_priority()

target_time = current_time + time_cost

if priority == 0:
    action.trigger_time = current_time
else:
    action.trigger_time = target_time

Timeline 最终仍推进到 target_time
```

所以当前：

> `priority == 0` 会造成“效果立即触发，但逻辑时间仍消费 time_cost”。

`[IMPLEMENTED]`

### 是否为最终设计

`[PENDING DESIGN]`

尚未确认：

```text
priority == 0
```

是否永久代表“瞬发”，还是未来应增加单独的 instant / cast timing 字段。

## 6.3 行动排序

当前排序规则：

```text
1. trigger_time 小的先
2. 同 trigger_time：priority 大的先
3. 同 trigger_time + 同 priority：player action 先
```

`[IMPLEMENTED]`

但：

> 该排序目前只应视为当前代码事实，不自动升级为最终玩法规则。

`[PENDING DESIGN]`

## 6.4 Timeline 推进

当前推进模型：

```text
advance_timeline_to(target_time)

→ 找下一条 <= target_time 的 action
→ current_time 推到 action.trigger_time
→ time_advanced(delta)
→ action_triggered(action)
→ 等 notify_action_finished()
→ 继续下一条
→ 最终推进剩余时间
→ timeline_advancement_finished
```

`[IMPLEMENTED]`

---

# 7. Enemy AI

## 7.1 当前模型

Enemy AI 使用：

```text
EnemyData
→ action_pool: Array[EnemyAction]
→ EnemyAI
→ CombatAction
```

每个 `EnemyAction` 当前可包含：

```text
time_cost
cooldown
weight
effect_data
```

## 7.2 加权随机与 cooldown

当前规则：

```text
available actions
= cooldown 已结束的 actions

从 available actions
按 weight 轮盘赌选择

trigger_time
= current_plan_start + time_cost

选中后 next_available_time
= trigger_time + cooldown
```

`_last_planned_time` 用于避免新的规划早于已安排的行动。

`[IMPLEMENTED]`

## 7.3 所有行动都在 cooldown 时

当前逻辑：

```text
_last_planned_time = current_plan_start + 10
return
```

但没有稳定的“10 logical time 后自动重新尝试规划”的闭环。

`[CONFLICT / INCOMPLETE]`

## 7.4 当前测试敌人伤害

EnemyAI 对 `"attack"`：

```text
damage = effect_data.get("damage", 10.0)
```

因此当 `effect_data` 不提供 damage 时，默认产生：

```text
10 damage
```

`[IMPLEMENTED]`

具体敌人 `.tres` 值在相关任务中应重新读取真实资源。

## 7.5 Continuous planning

目前：

```text
EntityManager.initialize()
→ setup_ai()
→ plan_initial_actions()
```

但尚未形成：

```text
enemy action completed
→ next planning trigger
→ plan_next_action(current_timeline_time)
```

`[INCOMPLETE]`

### 设计约束

`Timeline` 的职责是逻辑时间和 queue，不应该成为 AI 决策 owner。

谁触发下一次 planning 仍需确定。

`[PENDING DESIGN]`

---

# 8. CombatAction

`CombatAction` 是当前战斗系统的统一行动 payload。

来源：

```text
RuntimeCard
EnemyAI
```

主要可携带：

```text
attribute impacts
entity buffs
card buffs
timing / priority / source / target information
```

流向：

```text
RuntimeCard / EnemyAI
→ Timeline
→ BattleManager
→ EntityManager
→ CombatEntity / CardManager
```

`[IMPLEMENTED ARCHITECTURE]`

原则：

> 新的玩家 / 敌人战斗效果应优先考虑能否表达为 `CombatAction`，避免再造平行的 action protocol。

---

# 9. 伤害、护盾与属性

## 9.1 当前伤害模型

玩家卡伤害：

```text
base_damage = CardData.damage
→ RuntimeCard modifiers
→ CombatAction hp negative impact
```

敌人 damage 最终也进入：

```text
hp < 0
```

当前没有明确实现：

```text
defense formula
critical hit
accuracy / evasion
elemental resistance
```

除非未来设计确认，不应假设这些系统存在。

## 9.2 Shield absorption

当：

```text
attribute_name == "hp"
value < 0
```

当前：

```text
incoming_damage = abs(value)

if shield > 0:
    shield absorbs first
    overflow → hp
else:
    all damage → hp
```

`[IMPLEMENTED]`

当前尚未定义：

- shield 是否自动衰减
- battle end 是否清空
- 是否有上限
- 是否允许负 shield
- shield 是否可以被特殊伤害绕过

`[PENDING DESIGN]`

## 9.3 Attribute calculation

一个 `Attribute` 当前包含：

```text
computed_value
optional custom_formula
Array[AttributeBuff]
```

取值：

```text
base =
    custom_formula() if present
    else computed_value

then apply buffs in current array order:
+ add
- subtract
* multiply
/ divide (if divisor != 0)
```

当前没有统一 min/max clamp。

`AttributeSet.bind_custom_formula_to_attribute()` 可让依赖属性变化时触发目标属性更新。

`[IMPLEMENTED]`

---

# 10. CardBuff

## 10.1 Lifetime

`CardBuff` 可以同时有：

```text
time_left
count_left
```

`-1` 表示该维度不消耗。

当前：

```text
logical time advance
→ tick_time(delta)

successful card-action consumption
→ consume_action_event()
→ tick_count()
```

达到 `<= 0` 后移除。

`[IMPLEMENTED]`

## 10.2 Modifier order

当前 `ModifierType`：

```text
SET
ADD
MULTIPLY
```

`RuntimeCard._calculate_property()` 按 modifier type 排序后应用。

最终：

```text
round(value)
→ int
→ max(0, value)
```

应用到：

```text
resource_cost
time_cost
priority
damage
shield
```

`[IMPLEMENTED]`

### 同类型 Buff 顺序

多个同类型 modifier 的稳定顺序是否影响最终设计尚未明确。

`[PENDING DESIGN]`

## 10.3 当前双重应用风险

当前同一 `action.card_buffs` 有两条入口：

```text
EntityManager.execute_action()
→ card_buff_requested
→ BattleManager
→ CardManager
```

同时：

```text
BattleManager._on_timeline_action_triggered()
→ directly loops action.card_buffs
→ CardManager
```

所以同一 Buff 可能应用两次。

`[CONFLICT]`

目标：

> 未来必须只保留一个权威 CardBuff application path。

---

# 11. Card pile rules

`CardManager` 是三个逻辑牌堆的 authority：

```text
draw_pile
hand_pile
discard_pile
```

当前规则：

```text
battle init
→ all RuntimeCard enter draw pile
→ shuffle

draw
→ draw → hand

play confirmed
→ hand → discard

discard
→ hand → discard

draw empty + discard not empty
→ discard copied into draw
→ discard cleared
→ draw shuffled
```

当前 `CardSystem.tscn`：

```text
hand_limit = 6
```

UI `PlayerHandDeck` 只负责表现节点和输入请求，不拥有逻辑 pile membership。

`[IMPLEMENTED]`

---

# 12. Map generation

## 12.1 Default blueprint baseline

既有审计记录的 `test_mapblueprint.tres`：

```text
base_room_count = 15
count_variance = 0.2
boss_count = 0
enemy_spawn_chance = 0.7
elite_chance = 0.25
room_type_weights = { NORMAL: 100 }
```

精确值相关任务必须读取当前 `.tres`。

## 12.2 Room count

当前逻辑：

```text
min = round(base_room_count * (1 - variance))
max = round(base_room_count * (1 + variance))
room_count = random integer [min, max]
```

在当前基线配置：

```text
15 ± 20%
→ 12..18 rooms
```

`[IMPLEMENTED]`

## 12.3 Geometry

当前：

```text
logical room size = 10.0
half size = 5.0
origin room = (0, 0)
expansion directions = N / S / E / W
CORRIDOR_BIAS = 0.1
```

扩展：

```text
10%:
prefer latest generated room

otherwise:
choose random existing room
```

相邻房间建立双向 `connected_doors`。

`[IMPLEMENTED]`

## 12.4 Enemy placement

起始房：

```text
no enemies
```

其他房：

```text
70% enemy spawn chance

if enemy:
    25% → enemy level 1
    75% → enemy level 0
```

具体 `enemy_id` 从 `AllEnemyData` 按 level 选择。

`[IMPLEMENTED BASELINE]`

## 12.5 Boss selection

当前算法已存在，即使默认：

```text
boss_count = 0
```

score：

```text
BFS depth * 10
+ dead-end bonus 60
```

当前 enemy database 基线只明确有 level 0 / 1 测试敌人。

如果未来：

```text
boss_count > 0
```

则需要确认 level 2 boss data 已存在，否则 generator 可能得到 invalid enemy id。

`[PENDING DATA]`

---

# 13. Exploration / encounter

## 13.1 Door

既有代码基线：

```text
door sink depth = 3.0 m
auto-close distance = 2.0 m
open/close animation = 0.5 s
interaction = KEY_E
```

## 13.2 Door close behavior

静态源码曾显示：

```text
door open + current_player exists

distance > 2
→ close

else
→ also close
```

因此可能导致门打开动画后很快关闭。

`[RUNTIME VERIFY]`

不要只根据静态可疑逻辑决定最终行为，需要运行确认。

## 13.3 Room identification

开门后，当前 WorldManager 基于：

```text
player position
door position
direction player → door
forward offset 4.0
room grid size 10.0
round to room center
```

推断门后的房间坐标。

`[IMPLEMENTED]`

## 13.4 当前 encounter transition

当前：

```text
EXPLORE
→ PREPARING_BATTLE
→ PlayerController inactive
→ wait 1.2s
→ BATTLE
→ current code re-enables PlayerController
```

但并没有正式调用：

```text
ExpeditionManager
BattleManager.start_battle()
```

`[INCOMPLETE]`

### 目标

```text
WorldManager reports encounter
→ ExpeditionManager owns handoff
→ BattleManager starts once
→ exploration control remains appropriately disabled
→ battle result returns through ExpeditionManager
→ same mapdata resumes
```

`[CONFIRMED DESIGN]`

---

# 14. Player movement / camera

## 14.1 Current scene movement values

脚本默认曾记录：

```text
walk = 3.5
sprint = 6.5
```

但当前场景覆盖基线：

```text
walk = 2.5
sprint = 4.5
```

因此 gameplay 实际值以当前 `.tscn` inspector data 为准。

## 14.2 Sprint

当前输入规则：

```text
WASD physical keys
+
Left Shift
+
forward direction required
```

才使用 sprint speed。

Acceleration 基线：

```text
10.0
```

Gravity 来自 Godot project setting。

`[IMPLEMENTED]`

## 14.3 Camera look

当前基线：

```text
body yaw sensitivity = 0.001
head pitch sensitivity = 0.002
pitch clamp = -60° .. +60°
```

`[IMPLEMENTED]`

## 14.4 Head bob

基线：

```text
walk:
freq = 10
amp = 0.04

sprint:
freq = 14
amp = 0.08
```

`[IMPLEMENTED]`

---

# 15. Save / persistence mechanics

## 15.1 SaveManager file format

当前基础：

```text
user://saves/<slot_id>.json
```

root：

```json
{
  "metadata": {},
  "modules_data": {
    "<module_key>": {}
  }
}
```

`SaveModule` contract：

```text
get_module_key()
get_save_data()
load_save_data()
clear_data()
```

`[IMPLEMENTED INFRASTRUCTURE]`

## 15.2 Long-term player data

目标 owner：

```text
PlayerSaveManager
```

负责：

```text
long-term progression
long-term deck
equipment
```

目前实现仍是 placeholder。

`[CONFIRMED DESIGN / NOT IMPLEMENTED]`

## 15.3 Expedition persistence

长期目标：

```text
one expedition-level save module
```

统一保存一次远征需要恢复的：

```text
world / map state
current encounter context
expedition state
battle-related expedition state (if required by restore granularity)
```

而不是：

```text
WorldSave truth
+
BattleSave truth
```

`[CONFIRMED DESIGN]`

## 15.4 BattleSaveModule

当前 `BattleSaveModule.gd`：

- 文件仍存在；
- 未挂载到当前 BattleSystem；
- 未形成可靠当前注册链；
- 与当前 `EntityData` / `EnemyData` 模型不兼容；
- 旧接口和当前 BattleManager 预期不一致。

因此：

```text
BattleSaveModule = LEGACY
```

不应再用它推导新的战斗存档机制。

当前不要求旧存档兼容。

`[LEGACY / CONFIRMED DESIGN]`

## 15.5 Battle restore granularity

未来 expedition save 是否支持：

```text
战斗中途精确恢复
```

以及恢复到什么粒度，目前尚未决定。

可能涉及：

```text
Timeline.current_time
action_line
RuntimeCard active_buffs
draw / hand / discard
entity Attribute state
EnemyAI cooldown / planning state
visual wait state
```

`[PENDING DESIGN]`

在决定恢复粒度前，不应为了“完整存档”提前序列化所有 runtime transient state。

---

# 16. RuntimeCard / battle save implications

当前已知：

```text
RuntimeCard.to_dictionary()
```

不包含：

```text
active_buffs
```

同时：

```text
CardInstance.modifiers
```

尚未完整转换为 battle runtime modifiers。

这两个问题是否必须修复，取决于：

```text
CardInstance modifier semantics
+
battle restore granularity
```

`[PENDING DESIGN]`

---

# 17. 当前需要用户决定的机制

这些问题仍然开放。AI 不得自行补成最终规则。

1. **Card resources**
   - Attack / Skill / Power 分别消耗 stamina 还是 mana？

2. **Resource regeneration**
   - stamina 是否随 logical time 回复？
   - mana 是否回复？
   - regen_rate 的时间单位是什么？
   - 是否有 max clamp？

3. **Timeline ties**
   - 同 `trigger_time`、同 `priority` 时，玩家先是否为最终规则？

4. **Instant actions**
   - `priority == 0` 是否永久代表 instant？
   - 还是新增独立字段？

5. **CardBuff ordering**
   - 同类型 SET / ADD / MULTIPLY 中多个 Buff 的顺序是否需要稳定规则？

6. **Buff consumption timing**
   - 出牌 request、confirm、action trigger、action resolve、time advance 中，何时扣 count / duration？

7. **Damage extensions**
   - defense / armor / critical / accuracy / evasion / elemental resistance 是否进入最终伤害模型？

8. **Shield**
   - 是否衰减？
   - battle end 是否清空？
   - 是否有上限？

9. **Enemy re-planning**
   - 下一次 `EnemyAI.plan_next_action()` 由 `BattleManager`、`EntityManager` 还是其他 coordinator 触发？

10. **RNG**
    - 地图 / AI / shuffle 是否需要 deterministic seed？
    - seed 是否进入 expedition save？

11. **Failure / retreat**
    - battle loss / retreat 如何影响 rewards、RoomData、expedition state？

12. **Battle restore**
    - 是否需要 battle mid-state save？
    - 如果需要，精确恢复到什么粒度？

13. **CardInstance → RuntimeCard**
    - `unique_id` 是否需要在 battle runtime 保留？
    - `modifiers` 如何转为 RuntimeCard / CardBuff？

---

# 18. AI 修改机制时的规则

涉及 gameplay mechanics 的任务：

```text
1. 先读本文件相关 section
2. 用 CODE_INDEX.md 定位真实源码 / .tres
3. 读取真实文件确认当前实现
4. 区分：
   IMPLEMENTED
   CONFIRMED DESIGN
   CONFLICT
   PENDING DESIGN
5. 不把 card description 当成已实现效果
6. 不因当前代码行为就自动把它升级为最终设计
7. 不替用户决定 PENDING DESIGN
8. 改变 mechanics 后同步更新本文件
9. 若改变 SceneTree / public contract / data flow，同时更新 ARCHITECTURE.md
10. 若改变当前 blocker / milestone，同时更新 AI_PROGRESS.md
```

---

# 19. 当前重点机制债务

当前最值得在 gameplay vertical slice 中优先处理：

```text
World encounter
→ ExpeditionManager handoff
→ Battle start
→ battle result
→ same map / room restore
```

在该闭环内部，与战斗可运行直接相关的机制债务：

```text
BattleSystem wiring
EnemyAI continuous planning
stamina / mana payment conflict
CardBuff duplicate application
battle lifecycle cleanup
```

以下可以延后：

```text
legacy BattleSaveModule repair
old-save compatibility
full mid-battle restore
unused CardEffect cleanup
large-scale balance tuning
advanced damage formulas
```

除非当前任务明确要求。

---

# 20. 文档维护边界

更新本文，当：

- gameplay rule 改变；
- cost / time / damage / priority semantics 改变；
- Buff 生命周期改变；
- enemy planning rule 改变；
- map-generation rule 改变；
- exploration / encounter gameplay behavior 改变；
- save / restore gameplay semantics 改变；
- 某个 `[PENDING DESIGN]` 被用户正式决定。

通常不因为以下情况更新：

- private refactor；
- 单纯路径移动；
- SceneTree 接线但 mechanics 不变；
- 工具 / Codex workflow 改动；
- 纯 UI 外观变化。

本文的首要目标：

> **让实现事实、已确认设计、冲突和未决机制保持清晰分离。**
