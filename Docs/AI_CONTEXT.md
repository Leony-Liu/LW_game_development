# AI_CONTEXT.md

> **文件作用（给人和 AI）：**这是项目的“地图层”。它说明当前工程由哪些系统组成、系统职责边界、关键场景如何装配、重要状态由谁持有，以及跨系统任务应该先去哪里找。  
> **它不负责：**保存全部源码、记录每日进度、枚举全部函数、替代玩法公式，或作为旧快照的副本。函数/文件定位请查 `CODE_INDEX.md`；玩法规则请查 `MECHANICS.md`；当前里程碑和阻塞请查 `AI_PROGRESS.md`；脚本/节点拓扑与跨系统数据流由 `ARCHITECTURE.md` 维护。  
> **更新建议：**系统职责、状态所有权、顶层场景装配、主要入口、长期数据归属或工作流基础设施发生稳定变化时更新。  
> **事实优先级：**用户当前指令 > 当前真实工作区文件 / 当前 Godot Editor 或 Runtime 状态 > `project.godot` > 本文件 > 旧文档 / Git 历史 / 外部快照。若冲突，AI 必须指出冲突，不应为了迁就本文而修改源码。

## 0. 当前基线

### 0.1 活动开发环境

- Godot 项目名：`LW_game_development`
- 当前活动工作区：`D:/Game project/Godot/LW_game_development_upgrade_test`
- 当前开发引擎：Godot `4.7.2 stable`
- Godot Editor：`D:/APP/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe`
- Godot CLI backend：`D:/APP/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe`
- Canonical CLI wrapper：`tools/godot_cli.ps1`
- MCP server：`godot-mcp-472-test`
- Editor MCP：已完成连通性验证，可读取当前打开场景和编辑器信息
- Runtime Bridge：已观察到 `127.0.0.1:9877` 监听；Runtime MCP 的最终端到端工具验证仍需单独完成
- `.codex_runtime/`：Codex/Godot 自动化隔离目录，不属于项目源码

### 0.2 受保护回退项目

- Godot 4.4.1 项目：`D:/Game project/Godot/LW_game_development`
- 该目录是升级前的安全回退项目。
- 除非用户明确要求，不应由新版 Godot 打开、迁移或修改。

### 0.3 Agent 与网页模型的事实来源

**Agent / Codex 工作流：**

```text
真实仓库文件
+ 本组指导文件
+ Godot CLI
+ Editor MCP / Runtime MCP（按需）
```

Agent 不依赖 `PROJECT_DUMP.md` 才能工作；定位到文件后应读取真实工作区内容。

**网页大模型工作流：**

```text
PROJECT_DUMP.md
+ 本组指导文件
```

`PROJECT_DUMP.md` 仅用于无法直接读取仓库时提供源码快照。它是“网页模型适配层”，不是实时工程状态，也不能覆盖更新的真实工作区事实。

## 1. 项目基础

### 1.1 Godot 项目配置

当前开发引擎已经升级到 Godot 4.7.2。涉及以下配置时，必须直接读取当前 `project.godot`，不要根据旧快照推断：

- `config/features`
- renderer
- viewport / window
- stretch
- physics interpolation
- 2D HDR
- transparent background
- input actions
- Autoload
- main scene

上一次已知的视觉配置包括：

- 渲染器：`Forward Plus`
- 主视口：`1920 × 1080`
- 窗口覆盖：`1280 × 720`
- Stretch：`canvas_items / expand`
- 物理插值：开启
- 2D HDR：开启
- 透明背景：开启

这些值若成为任务依赖，应以当前 `project.godot` 重新确认。

### 1.2 Gameplay Autoload

| Autoload | 路径 | 设计/当前角色 |
| --- | --- | --- |
| `GameManager` | `res://Scripts/GameManager.gd` | 应用级流程；当前实现仍需逐步落地 |
| `SaveManager` | `res://Scripts/SaveManager.gd` | 存档槽位、模块注册与文件 I/O |
| `AllCardData` | `res://Scripts/CardData/AllCardData.gd` | 卡牌静态模板数据库 |
| `AllEnemyData` | `res://Scripts/EnemyData/AllEnemyData.gd` | 敌人静态模板数据库 |

开发工具产生的 MCP Runtime Bridge 属于**开发基础设施**，不应被当成 gameplay 架构依赖。

### 1.3 主场景

当前主场景已经修复为：

- 路径：`res://MainMenuSystem/MainMenu.tscn`
- UID：`uid://cu8ebs30en5qs`

`project.godot` 的 `run/main_scene` 应指向该有效 UID。若主入口以后变化，必须同时更新这里、`project.godot` 和相关架构文档。

## 2. 系统地图

```text
Application
├─ GameManager (Autoload)                         [应用级总流程]
├─ SaveManager (Autoload)                         [存档基础设施]
├─ PlayerSaveManager                              [玩家长期数据权威所有者]
├─ AllCardData (Autoload)                         [卡牌模板数据库]
└─ AllEnemyData (Autoload)                        [敌人模板数据库]

Expedition
└─ ExpeditionManager                              [远征生命周期 / 探索↔战斗唯一协调器]
   ├─ WorldSystem
   │  ├─ WorldManager                             [地图 / 房间 / 遭遇真实状态]
   │  ├─ WorldGenerator                           [地图数据生成算法]
   │  ├─ RoomSet -> BattleRoom                    [房间实例化与局部表现]
   │  ├─ DoorSet -> Door                          [门实例化与交互]
   │  └─ PlayerVisualManager
   │     ├─ PlayerController
   │     ├─ HeadController
   │     ├─ CameraBobMount
   │     └─ DebugFreeCamera
   │
   ├─ BattleSystem                                [目标：常驻 ExpeditionSystem 子场景]
   │  ├─ BattleManager                            [战斗领域总协调器]
   │  ├─ Timeline                                 [逻辑时间 / 行动队列]
   │  ├─ EntityManager
   │  │  ├─ CombatEntity (player)
   │  │  │  └─ AttributeSet -> Attribute
   │  │  ├─ CombatEntity (enemy)
   │  │  │  └─ AttributeSet -> Attribute
   │  │  └─ EnemyAI
   │  └─ CardManager
   │     └─ PlayerHandDeck
   │        └─ CardLogic
   │           ├─ Card_Interaction
   │           └─ Card_Animation
   │
   └─ Expedition-level Save Module                [目标：整个远征共享一个存档模块]
```

上图同时包含“当前已存在系统”和“用户已确认的长期架构目标”。是否已经完成场景挂载，必须以真实 `.tscn` / MCP Editor 状态确认，不能仅凭本图判断。

## 3. 场景装配：当前状态与目标

### 3.1 `ExpeditionSystem/ExpeditionSystem.tscn`

上一次源码审阅确认包含：

- `WorldSystem`，脚本为 `WorldManager.gd`
- `WorldGenerator`
- `RoomSet`
- `DoorSet`
- `PlayerVisual`
- `UISystem`

上一次审阅时尚未确认：

- `ExpeditionManager.gd` 已实际挂载
- `BattleSystem.tscn` 已作为常驻子场景实例化

**已确认长期目标：**

```text
ExpeditionSystem
├─ ExpeditionManager
├─ WorldSystem
├─ BattleSystem       # 常驻
├─ UISystem
└─ Expedition-level Save Module
```

因此跨系统装配任务的方向不是“遭遇时动态创建 BattleSystem”，而是**让常驻 BattleSystem 在 ExpeditionManager 协调下进入/退出战斗状态**。

### 3.2 `ExpeditionSystem/BattleSystem/BattleSystem.tscn`

上一次源码审阅确认：

- 根节点 `BattleSystem` 使用 `BattleManager.gd`
- `card_manager = UI/CardSystem` 已绑定
- `timeline` / `entity_manager` 曾未见完整绑定
- `EntityManager.player_entity` / `enemy_entity` 已存在
- `EntityManager.enemy_ai` 曾未见完整 NodePath 绑定
- 场景曾引用旧 `CombatManager.gd`

这些属于“历史审阅观察”，不是永久事实。任何 BattleSystem 接线任务开始前，应直接重新读取当前 `.tscn` 或使用 Editor MCP 检查真实场景树与 Inspector 绑定。

## 4. 已确认的职责边界

| 系统 | 应负责 | 不应负责 |
| --- | --- | --- |
| `GameManager` | 应用级流程；基地 ↔ 远征切换；协调存档入口 | 地图生成、伤害、牌堆、战斗内部结算 |
| `ExpeditionManager` | 一次远征生命周期；探索 ↔ 战斗唯一上层协调；战斗输入交接；结果回传；远征级保存/恢复协调 | 地图算法、单次行动结算、直接实现卡牌/实体逻辑 |
| `WorldManager` | 当前地图、当前房间、遭遇状态、探索模式、遭遇事实上报、接收战斗结果 | 创建战斗牌组、伤害结算、长期成长 |
| `WorldGenerator` | 根据 `MapBlueprint` 生成房间、门、敌人分布 | 玩家移动、战斗启动、长期状态 |
| `BattleManager` | 战斗生命周期、操作合法性协调、卡牌/实体/Timeline 编排、胜负上报、输入锁与表现同步 | 地图生成、长期成长、直接写存档文件 |
| `Timeline` | 逻辑时间、行动队列、排序、推进、到期行动通知 | 伤害、资源扣费、AI 决策、存档 |
| `CardManager` | draw / hand / discard 权威状态、抽弃洗牌、出牌确认/取消、RuntimeCard Buff 分发 | 胜负、实体真实资源、Timeline 所有权 |
| `EntityManager` | 玩家/敌人初始化、实体路由、属性/资源改动、执行 `CombatAction`、实体事件中继 | 牌堆、Timeline、文件存档、卡牌动画 |
| `CombatEntity` + `AttributeSet` | 实体真实战斗属性与属性 Buff | 全局战斗编排 |
| `PlayerVisualManager` | 探索/战斗/调试表现模式、移动/镜头/输入表现开关 | 遭遇规则、战斗结果、真实战斗数值 |
| `SaveManager` | 槽位、元数据、模块注册、文件读写、结果报告 | 业务字段所有权、奖励计算、玩法流程决策 |
| `PlayerSaveManager` | 玩家长期成长、长期牌组、装备等长期玩家数据的权威所有者；存档模块适配 | 再实现一套文件 I/O；复制实时战斗状态 |
| `AllCardData` / `AllEnemyData` | 静态 Resource 模板加载、ID 查询、合法性检查 | 当前 HP、临时 Buff、当前行动队列 |

## 5. 状态所有权

### 5.1 当前运行时权威状态

| 状态 | 权威持有者 |
| --- | --- |
| 地图字典 `mapdata` | `WorldManager` |
| 当前房间坐标 | `WorldManager.current_room_coords` |
| 世界模式 | `WorldManager.current_state` |
| 战斗是否活动 | `BattleManager.is_battle_active` |
| 逻辑时间 / 行动队列 | `Timeline.current_time` / `Timeline.action_line` |
| draw / hand / discard | `CardManager` |
| 单张战斗卡临时 Buff | `RuntimeCard.active_buffs` |
| 战斗实体属性 | 每个 `CombatEntity.attribute_set` |
| 单属性 Buff | `Attribute.buffs` |
| 存档槽位 / 文件 I/O / 模块注册 | `SaveManager` |

### 5.2 已确认的长期所有权

- 应用阶段 / 当前应用流程 → `GameManager`
- 一次远征生命周期 / 探索↔战斗上下文 / 远征结果 → `ExpeditionManager`
- 玩家长期成长 / 长期牌组 / 装备 → `PlayerSaveManager`
- 当前地图 / 房间 / 遭遇事实 → `WorldManager`
- 当前战斗领域状态 → `BattleManager` 及其子系统的各自权威状态

AI 不应为单个需求另建第二套“临时全局状态管理器”绕开这些所有者。

## 6. 存档架构方向

### 6.1 基础设施

`SaveManager` 继续负责：

```text
slot / metadata
module registration
JSON file I/O
load/save result reporting
```

它不拥有具体 gameplay 字段。

### 6.2 玩家长期数据

`PlayerSaveManager` 是已确认的玩家长期数据权威所有者，负责：

- 长期成长
- 长期牌组
- 装备
- 对应的存档模块适配

### 6.3 远征级存档

当前代码历史上在 World/Battle 侧存在多个存档模块/路径，其中 `BattleSaveModule.gd` 已知为 legacy，接口与当前数据模型不一致。

**已确认目标：**

> 整个 `ExpeditionSystem` 最终只使用一个远征级存档模块，统一负责一次远征需要持久化的状态，而不是 WorldSystem 和 BattleSystem 各维护一套独立存档真相。

因此目标关系应为：

```text
SaveManager
    ↑ module registration / file I/O
    │
Expedition-level Save Module
    ↑
ExpeditionManager
    ├─ World state snapshot
    ├─ encounter / expedition state
    └─ battle-related expedition state（若该阶段需要持久化）
```

当前阶段**不保证旧存档兼容**。如果新增/替换存档结构，可以优先保证新结构一致性；若未来决定恢复旧档兼容，应作为单独迁移任务处理，而不是在无关任务中隐式兼容。

## 7. 关键数据模型关系

```text
CardData (.tres 静态模板)
  ↓ CardInstance(card_id, modifiers, unique_id)
  ↓ BattleManager / battle initialization
RuntimeCard(card_data, active_buffs)
  ↓ create_action()
CombatAction
  ↓ Timeline 排期
  ↓ action_triggered
BattleManager
  ↓
EntityManager.execute_action()
  ↓
CombatEntity -> AttributeSet -> Attribute

EnemyData (.tres)
  ├─ attributes
  └─ action_pool: Array[EnemyAction]
       ↓
     EnemyAI
       ↓
   CombatAction

MapBlueprint (.tres)
  ↓
WorldGenerator
  ↓
mapdata {
  rooms: Dictionary[Vector2, RoomData],
  doors: Dictionary[Vector2, orientation]
}
  ↓
WorldManager + RoomSet + DoorSet
```

具体 public method、signal、节点挂载和跨脚本数据边将在 `ARCHITECTURE.md` 维护；这里仅保留领域级关系。

## 8. 探索 ↔ 战斗纵向流程

### 8.1 当前已知世界流程

上一次源码审阅确认：

```text
WorldManager._ready()
→ init_map(default_blueprint)
→ WorldGenerator.generate()
→ RoomSet.build_rooms()
→ DoorSet.build_doors()
→ enter_explore_mode()

玩家开门
→ DoorSet.door_opened_relay
→ WorldManager._on_door_opened()
→ 推算门对面房间
→ 若房间 has_enemies
→ enter_preparing_battle_mode()
→ 准备表现
→ enter_battle_mode()
```

历史实现中 `enter_battle_mode()` 尚未真正完成到 `BattleManager.start_battle()` 的权威交接。该状态必须在实际任务中重新检查。

### 8.2 战斗内部主链

```text
BattleManager.start_battle()
→ EntityManager.initialize()
→ CardManager.initialize()
→ battle_started

Card UI request
→ CardManager
→ BattleManager
→ resource / legality check
→ CardManager.confirm_play_card()
→ Timeline.receive_card()
→ Timeline.action_triggered
→ BattleManager
→ EntityManager.execute_action()
→ presentation / completion
→ Timeline.notify_action_finished()
→ timeline_advancement_finished
→ input unlock
```

### 8.3 已确认目标纵向闭环

```text
WorldManager
→ 发现并上报 Encounter fact
→ ExpeditionManager

ExpeditionManager
→ 读取/组装一次战斗需要的玩家数据、牌组、enemy_id
→ BattleManager.start_battle()

BattleManager
→ 运行战斗
→ battle_ended(BattleResult)
→ ExpeditionManager

ExpeditionManager
→ 将结果交还 WorldManager
→ 更新原 RoomData / 遭遇状态
→ 恢复同一次 mapdata
→ 恢复探索移动 / 镜头 / 输入
→ 继续远征
```

约束：

- 一次遭遇只启动一次战斗。
- 探索暂停与恢复由明确生命周期控制。
- 战斗输入只交接一次。
- 战斗结果只处理一次。
- 返回探索时必须保持同一次远征和同一份地图状态。
- 战斗临时状态、信号、回调、等待和输入锁不能泄漏到下一阶段。

## 9. 目录导航

| 目录 | 主要内容 |
| --- | --- |
| `Scripts/` | 全局管理器、静态数据 Resource 类型、存档基础类、卡牌/敌人数据库 |
| `Scripts/CardData/` | 卡牌模板与旧 CardEffect 路径 |
| `Scripts/EnemyData/` | 敌人 Resource 实例 |
| `ExpeditionSystem/` | 远征顶层与跨系统编排 |
| `ExpeditionSystem/WorldSystem/` | 地图、房间、门、玩家探索表现 |
| `ExpeditionSystem/BattleSystem/` | 战斗协调、时间轴、实体、卡牌 |
| `MainMenuSystem/` | 当前启动入口 |
| `Arts/` | Shader、Theme、美术和字体资源 |
| `Docs/` | AI/Agent 指导文档 |
| `tools/` | 自动化工具；当前包括 canonical Godot CLI wrapper |

## 10. Agent 接到任务后的阅读顺序

不要机械读取全部文档。按任务最小化上下文：

1. 先读 `AGENTS.md` 的稳定工作规则。
2. 若任务涉及系统职责、状态所有权、顶层场景关系或跨系统交接，读本文件。
3. 用 `CODE_INDEX.md` 定位目标文件；然后读取**真实工作区文件**。
4. 涉及玩法/数值规则时，读 `MECHANICS.md` 对应章节。
5. 涉及当前里程碑、临时例外、已知阻塞时，读 `AI_PROGRESS.md`。
6. 涉及节点树、脚本契约、public method、signal 或数据流时，读 `ARCHITECTURE.md` 对应章节。
7. 修改后优先通过 `tools/godot_cli.ps1` 做合适的 CLI 验证；只有需要真实 Editor/Runtime 状态时再使用 MCP。
8. 如果文档与真实源码/场景冲突，以真实工作区事实为准，并报告文档需要更新。

## 11. 已确认的长期架构决定

以下内容由用户明确确认，可作为长期设计约束，直到用户重新决定：

1. `GameManager` 负责应用级总流程，包括基地 ↔ 远征切换与存档协调。
2. `ExpeditionManager` 是探索 ↔ 战斗的唯一上层协调器。
3. `PlayerSaveManager` 是玩家长期数据的权威所有者。
4. `BattleSystem` 目标为 `ExpeditionSystem` 下的常驻子场景，而不是每次遭遇动态实例化。
5. 当前原型阶段不保证旧存档兼容。
6. World/Battle 各自独立的存档模块不是最终架构；目标是整个远征共用一个 expedition-level save module。
