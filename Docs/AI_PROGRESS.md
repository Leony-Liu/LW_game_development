# AI_PROGRESS.md

> **文件作用（给人和 AI）：**这是项目的“当前工作台”。它只记录现在做到哪里、正在解决什么、哪些问题阻塞下一步、下一里程碑如何验收。  
> **它不负责：**保存长期架构原则、玩法公式或全部函数索引。稳定架构放 `AI_CONTEXT.md`，机制放 `MECHANICS.md`，代码定位放 `CODE_INDEX.md`。  
> **更新建议：**每完成一个明显里程碑、开始新任务、发现关键阻塞或完成一次运行验证后更新。不要把它写成历史日志；旧历史交给 Git / 看板 / issue。  
> **基线：**静态分析 `PROJECT_DUMP.md`（2026-09-20 19:17 +08:00）以及旧版 `AGENTS.md`。没有实际运行项目。

## 0. 当前里程碑

### 候选当前目标

**[待确认：以下目标来自旧版 AGENTS.md，请确认目前 Restart 分支仍以此为当前目标]**

打通完整纵向流程：

```text
地图探索
→ 遭遇敌人
→ 进入战斗
→ 战斗结束
→ 返回同一次远征地图
→ 继续探索
```

### 候选验收标准

**[待确认]**

- 一次敌人遭遇只启动一次战斗。
- 探索暂停；玩家 / 牌组 / 敌人战斗输入只交接一次。
- 战斗只初始化一次。
- 战斗结束事件只处理一次。
- 战斗结果返回同一次远征和对应房间，而不是重新生成地图。
- 已处理遭遇的房间状态被更新。
- 返回探索后移动、镜头和输入恢复。
- 上一场战斗的行动队列、临时 Buff、信号、回调、表现等待、输入锁不泄漏到下一阶段。

## 1. 当前静态状态总览

> “已存在”只表示源码结构存在；不等于运行验证通过。

| 子系统 | 静态状态 | 说明 |
| --- | --- | --- |
| `GameManager` | ⛔ 占位 | `_ready/_process` 都是空实现 |
| `ExpeditionManager` | ⛔ 占位 | 尚未实现远征生命周期和探索↔战斗协调 |
| `PlayerSaveManager` | ⛔ 占位 | 尚未实现长期玩家数据 |
| `SaveManager` | 🟡 基础存在 | JSON 槽位 + SaveModule 注册框架已写 |
| `AllCardData` | 🟢 结构存在 | 自动扫描卡牌 `.tres` |
| `AllEnemyData` | 🟢 结构存在 | 自动扫描敌人 Resource |
| `WorldGenerator` | 🟢 主要算法存在 | 随机房间、门、敌人分配、Boss 选址代码已写 |
| `RoomSet / DoorSet / BattleRoom` | 🟢 结构存在 | 可把 mapdata 转为场景实例 |
| `WorldManager` | 🟡 部分完成 | 地图生成与探索状态已写；真正战斗启动未接上 |
| `PlayerVisualManager` | 🟢 探索表现存在 | 探索/调试相机与移动开关已写 |
| `BattleManager` | 🟡 代码存在 | 战斗编排逻辑较完整，但场景依赖/接线不完整 |
| `CardManager` | 🟢 主要牌堆逻辑存在 | draw/hand/discard、抽弃牌、出牌确认、Buff 时间推进 |
| `Card UI` | 🟢 结构存在 | 交互、悬浮、抽牌/出牌/弃牌动画 |
| `Timeline` | 🟢 核心流程存在 | 排期、排序、推进、等待行动完成 |
| `EntityManager` | 🟡 部分完成 | 属性结算、资源扣除、敌人初始化；AI 接线未完整 |
| `CombatEntity / AttributeSet` | 🟢 结构存在 | HP/Shield 等通用属性和 Buff |
| `EnemyAI` | 🟡 部分完成 | 首次行动生成存在；连续规划链缺失 |
| `BattleSaveModule` | 🔴 接口不一致 | 当前与 BattleManager / EntityData / EnemyData 多处不匹配 |

## 2. 当前 P0 阻塞：先让纵向流程具备可运行条件

### P0-1 主场景无法从快照解析

`project.godot`：

`run/main_scene="uid://0rtgdscsodly"`

快照中没有对应 UID 的 `.tscn`。

- 状态：**[需人工确认]**
- 当前主场景实际路径：`[请用户填写]`
- 项目 Run 是否成功：`[请用户填写]`

### P0-2 `BattleSystem.tscn` 仍引用缺失的旧脚本

场景引用：

`res://ExpeditionSystem/BattleSystem/CombatSystem/Scripts/CombatManager.gd`

但当前源码快照没有该文件。

- 状态：**静态确认的断引用**
- 处理方向：**[待确认]** 按当前 `BattleManager` 职责修复场景接线，而不是重新引入重复职责的 `CombatManager`。

### P0-3 `BattleManager` 导出依赖未完整绑定

`BattleManager.gd` 需要：

- `timeline`
- `entity_manager`
- `card_manager`

当前 `BattleSystem.tscn` 只看到 `card_manager` 绑定。

- `timeline`：未绑定
- `entity_manager`：未绑定
- `battle_save_module`：可选，未绑定

### P0-4 `EntityManager.enemy_ai` 未绑定

`EntityManager.gd` 有：

`@export var enemy_ai: Node`

当前场景只绑定了：

- `player_entity`
- `enemy_entity`

未见 `enemy_ai` NodePath。

### P0-5 远征顶层未装配

`ExpeditionSystem.tscn` 当前只有 WorldSystem / UISystem，没有看到：

- `ExpeditionManager`
- `BattleSystem`

因此纵向闭环当前没有顶层协调对象。

## 3. 当前 P1 战斗逻辑问题

### P1-1 Skill / Power 资源扣费不一致

`RuntimeCard` 对非 Attack 返回 `mana_cost`，但 `BattleManager` 始终从 `stamina` 校验并扣除。

- 状态：**静态确认**
- 设计决定：`[请用户确认 Skill / Power 是否扣 mana]`

### P1-2 敌人只能可靠生成首个行动

初始化会调用：

`EnemyAI.plan_initial_actions()`

但当前未看到每次行动后继续请求 `plan_next_action()` 的闭环。

- 状态：**静态确认**
- 下一次规划责任方：`[请用户确认]`

### P1-3 CardBuff 可能重复施加

同一个 `action.card_buffs`：

1. `EntityManager.execute_action()` → `card_buff_requested`
2. `BattleManager._on_entity_card_buff_requested()` → CardManager
3. `BattleManager._on_timeline_action_triggered()` 又直接遍历 `action.card_buffs`

- 状态：**静态确认的双入口**
- 目标：保留唯一权威结算路径。

### P1-4 stamina_regen 只存在数据，没有执行

`EntityData` 有 `stamina_regen` / `mana_regen`，Timeline 的注释也提到回复体力，但当前 `time_advanced` 只推进手牌 Buff 时间。

- 状态：**未实现**

### P1-5 卡牌描述中的多个效果没有实现

当前 `.tres` 文本描述包含下一次攻击加伤等效果，但 `effects` 都为空，RuntimeCard 也未根据描述生成对应 Buff。

- 状态：**数据描述超前于实现**
- 处理前应确认这些牌是否仍是当前设计。

### P1-6 旧 `CardData.play()` 路径与 RuntimeCard 路径并存

当前主战斗链看起来已经转向：

`RuntimeCard -> CombatAction`

旧：

`CardData.play() -> CardEffect.execute()`

仍留在源码。

- 状态：**架构迁移未完全清理**
- 目标：`[待确认]` 选定唯一效果结算链后再清理旧路径。

## 4. 当前 P1 世界/遭遇问题

### P1-7 `WorldManager.enter_battle_mode()` 没有真正启动战斗

当前只：

- 改 `WorldState`
- 打印日志
- 重新启用 PlayerController

没有：

- 构造玩家战斗输入
- 调用 `BattleManager.start_battle()`
- 订阅 `battle_ended`

### P1-8 准备战斗时没有保存目标 RoomData

`enter_preparing_battle_mode(target_room)` 接收目标房间，但当前只用它打印位置，没有把目标房间/敌人 ID 存为待处理遭遇上下文。

### P1-9 战斗结束返回探索尚未闭环

`WorldManager.finish_battle()` 当前：

- 把当前 RoomData 的 `has_enemies = false`
- 返回 explore

但真正的 `BattleManager.battle_ended` 尚未接到该流程。

并且这里没有同步：

`enemy_id = -1`

是否需要清空请统一使用 `BattleRoom.clear_enemies()` 或明确的数据层更新规则。

### P1-10 门自动关闭逻辑疑似反向

`Door._process()` 当前在玩家仍靠近时也会执行 `close_door()`。

- 状态：**静态可疑**
- 需要：Godot 运行验证。

## 5. 当前 P1/P2 存档问题

`BattleSaveModule` 当前不能作为可靠战斗恢复实现，已确认至少有：

- `save_initial_state()` 调用方与实现方不匹配。
- `EntityData.base_attributes` 不存在。
- `EntityData.new()` 参数使用方式不匹配。
- `EnemyData.base_attributes` 不存在，当前字段是 `attributes`。
- `_compile_input_to_runtime()` 为空。
- RuntimeCard 没保存 active_buffs。
- CardInstance.modifiers 没进入 RuntimeCard。

**[待确认]** 当前纵向切换里程碑是否暂时不要求“战斗中读档恢复”。旧版 AGENTS 将其列为非当前硬依赖。

## 6. 建议的当前开发顺序

> 这是基于现有依赖关系整理的工作顺序，不代表用户已经批准所有改动。实际执行前仍以本次任务为准。

### Step 1：确认可运行入口

- [ ] **[用户]** 确认真实 main scene。
- [ ] 让 `ExpeditionSystem.tscn` 能作为明确测试入口加载。
- [ ] 修掉 `BattleSystem.tscn` 的缺失脚本引用。
- [ ] 把 `BattleManager.timeline/entity_manager/card_manager` 接好。
- [ ] 把 `EntityManager.enemy_ai` 接好。

### Step 2：建立最小探索 → 战斗输入交接

- [ ] 实现 `ExpeditionManager` 最小职责。
- [ ] WorldManager 遭遇时只“上报事实”，不自行造玩家牌组。
- [ ] 明确玩家 `Array[CardInstance]` 和 `EntityData` 的来源。
- [ ] 使用房间 `enemy_id` 启动 BattleManager。
- [ ] 防止同一遭遇重复启动。

### Step 3：建立战斗 → 探索返回

- [ ] 订阅 `battle_ended`.
- [ ] 胜利后清理当前房间敌人状态。
- [ ] 恢复同一份 `mapdata`。
- [ ] 恢复探索移动/镜头/输入。
- [ ] 清空战斗队列、等待状态和临时引用。

### Step 4：补齐战斗内部最小闭环

- [ ] 统一 stamina / mana 扣费规则。
- [ ] 敌人连续行动规划。
- [ ] 去掉 CardBuff 双重结算。
- [ ] 明确 priority=0 / 同刻排序。
- [ ] 决定是否在本里程碑实现 stamina regen。

### Step 5：再决定战斗存档范围

- [ ] 先定义恢复粒度。
- [ ] 再修 BattleSaveModule 数据模型。
- [ ] 不要在规则未确定前堆兼容代码。

## 7. 当前里程碑验收记录模板

> 每次真正运行后填写；AI 不得凭静态阅读自动写“通过”。

### 最近一次运行

- 日期：`[请用户填写]`
- Godot 版本：`[请用户填写]`
- 启动场景：`[请用户填写]`
- Git commit / 工作区状态：`[请用户填写]`
- 实际运行结果：`[请用户填写]`

### 纵向闭环

- [ ] 项目可启动
- [ ] 地图可生成
- [ ] 玩家可探索
- [ ] 进入有敌人房间只触发一次遭遇
- [ ] 探索控制正确暂停
- [ ] BattleManager 只初始化一次
- [ ] 玩家牌组正确进入战斗
- [ ] 玩家属性正确进入战斗
- [ ] enemy_id 正确进入战斗
- [ ] 玩家可以出牌
- [ ] 敌人可以连续行动
- [ ] 胜负可以结束战斗
- [ ] 战斗结果只处理一次
- [ ] 原房间敌人状态正确清除
- [ ] 没有重新生成地图
- [ ] 返回探索后移动/镜头/输入正常
- [ ] 第二场战斗不会继承第一场的队列/Buff/锁定

## 8. 用户维护区

- **当前正在做：** `[请用户填写]`
- **刚完成：** `[请用户填写]`
- **下一项：** `[请用户填写]`
- **当前最大阻塞：** `[请用户填写]`
- **已知但暂不处理：** `[请用户填写]`
- **需要 AI 特别避免碰的区域：** `[请用户填写]`
