# AI_CONTEXT.md

> **文件作用（给人和 AI）：**这是项目的“地图层”。它说明工程由哪些系统组成、各系统的职责边界、关键场景如何装配、重要状态应该由谁持有，以及遇到任务时应该先去哪里找。  
> **它不负责：**保存全部源码、记录每日进度、详细列出每个函数，或替代具体玩法公式。源码事实请查 `PROJECT_DUMP.md`；函数定位请查 `CODE_INDEX.md`；机制请查 `MECHANICS.md`；当前进度请查 `AI_PROGRESS.md`。  
> **更新建议：**系统边界、目录结构、主要入口或场景装配发生变化时更新。  
> **事实优先级：**用户当前指令 > 当前真实源码 / 最新 `PROJECT_DUMP.md` > 本文件 > 旧文档。若冲突，AI 必须指出冲突，不应为了迁就本文而修改源码。

## 0. 文档基线

- 项目：`LW_game_development`
- 本文依据的源码快照：`2026-09-20T19:17:14+08:00`
- Git 分支：`Restart`
- Git commit：`3ffab1c75d5ad1c3b070576671159ff909f6db5a`
- 本文还参考了旧版 `AGENTS.md` 中的架构意图；凡是不能由当前源码直接证明的内容均标为 **[待确认]**。
- 本次仅做静态源码分析，没有运行 Godot 项目。

## 1. 项目基础

### 1.1 Godot 配置（源码已确认）

- Godot feature：`4.4`
- 渲染器：`Forward Plus`
- 主视口：`1920 × 1080`
- 窗口覆盖：`1280 × 720`
- Stretch：`canvas_items / expand`
- 物理插值：开启
- 2D HDR：开启
- 透明背景：开启

### 1.2 Autoload（源码已确认）

| Autoload | 路径 | 当前状态 |
| --- | --- | --- |
| `GameManager` | `res://Scripts/GameManager.gd` | 占位脚本 |
| `SaveManager` | `res://Scripts/SaveManager.gd` | 已有基础 JSON 存档框架 |
| `AllCardData` | `res://Scripts/CardData/AllCardData.gd` | 扫描卡牌 `.tres` 并按 ID 建库 |
| `AllEnemyData` | `res://Scripts/EnemyData/AllEnemyData.gd` | 扫描敌人 `.tres/.res` 并按 ID 建库 |

### 1.3 主场景

`project.godot` 当前配置：

`run/main_scene="uid://0rtgdscsodly"`

**[待确认 / 重要]**：当前源码快照中没有任何已收录 `.tscn` 的 UID 与 `uid://0rtgdscsodly` 对应。请在 Godot 编辑器中确认当前真正的启动场景，并把实际路径补在这里：

- 当前主场景路径：`[请用户填写，例如 res://ExpeditionSystem/ExpeditionSystem.tscn]`
- 是否可从项目 Run 按钮正常启动：`[请用户填写：是 / 否 / 未测试]`

## 2. 系统地图

```text
Application
├─ GameManager (Autoload)                         [当前占位]
├─ SaveManager (Autoload)                         [基础框架存在]
├─ AllCardData (Autoload)                         [卡牌模板数据库]
└─ AllEnemyData (Autoload)                        [敌人模板数据库]

Expedition
├─ ExpeditionManager                              [当前占位，且未见场景挂载]
├─ WorldSystem
│  ├─ WorldManager                                [地图状态 / 探索状态]
│  ├─ WorldGenerator                              [地图数据生成算法]
│  ├─ RoomSet -> BattleRoom                       [房间实例化与局部表现]
│  ├─ DoorSet -> Door                             [门实例化与交互]
│  └─ PlayerVisualManager
│     ├─ PlayerController
│     ├─ HeadController
│     ├─ CameraBobMount
│     └─ DebugFreeCamera
│
└─ BattleSystem                                   [代码存在，场景接线目前不完整]
   ├─ BattleManager                               [战斗编排]
   ├─ Timeline                                    [逻辑时间 / 行动队列]
   ├─ EntityManager
   │  ├─ CombatEntity (player)
   │  │  └─ AttributeSet -> Attribute
   │  ├─ CombatEntity (enemy)
   │  │  └─ AttributeSet -> Attribute
   │  └─ EnemyAI
   └─ CardManager
      └─ PlayerHandDeck
         └─ CardLogic
            ├─ Card_Interaction
            └─ Card_Animation
```

## 3. 场景装配现状

### 3.1 `ExpeditionSystem/ExpeditionSystem.tscn`

当前确认包含：

- `WorldSystem`，脚本为 `WorldManager.gd`
- `WorldGenerator`
- `RoomSet`
- `DoorSet`
- `PlayerVisual`
- `UISystem`

当前没有在该场景中看到：

- `ExpeditionManager.gd` 的挂载
- `BattleSystem.tscn` 的实例

因此当前源码层面尚未形成“远征协调器 + 世界 + 战斗”的完整顶层装配。

### 3.2 `ExpeditionSystem/BattleSystem/BattleSystem.tscn`

当前根节点 `BattleSystem` 使用 `BattleManager.gd`，并绑定了：

- `card_manager = UI/CardSystem`

但 `BattleManager` 的以下导出引用未见绑定：

- `timeline`
- `entity_manager`
- `battle_save_module`（可选）

同时场景仍引用：

`res://ExpeditionSystem/BattleSystem/CombatSystem/Scripts/CombatManager.gd`

**[当前快照异常]**：该文件不在源码快照的项目文件索引中。

另外 `EntityManager` 场景绑定了 `player_entity` / `enemy_entity`，但没有看到 `enemy_ai` 的 NodePath 绑定。

结论：战斗逻辑脚本已经形成多个子系统，但当前 `BattleSystem.tscn` 不能被视为已完成装配。

## 4. 主要职责边界

以下分两类：

- **源码已确认**：由当前实现直接表现出来。
- **[待确认：旧架构意图]**：来自旧版 `AGENTS.md`，建议用户确认后继续作为长期约定。

| 系统 | 当前源码体现的职责 | 旧架构意图 / 需要确认 |
| --- | --- | --- |
| `GameManager` | 当前为空 | **[待确认]** 应用级流程、基地/远征切换、调用存档服务 |
| `ExpeditionManager` | 当前为空 | **[待确认]** 一次远征生命周期、探索↔战斗交接、远征结果、撤离/收集编排 |
| `WorldManager` | 生成地图、维护 `WorldState`、记录当前房间、处理开门后进入房间、切换探索/准备战斗状态 | **[待确认]** 当前地图/房间/遭遇真实状态所有者 |
| `WorldGenerator` | 根据 `MapBlueprint` 生成房间、门、敌人分布 | 与旧架构意图一致 |
| `BattleManager` | 战斗启动、出牌仲裁、时间轴/实体/卡牌系统中继、胜负事件、输入锁、表现等待 | **[待确认]** 战斗领域总协调器 |
| `Timeline` | 当前逻辑时间、行动队列、排序、逐行动推进 | 与旧架构意图基本一致 |
| `CardManager` | draw/hand/discard 三个逻辑牌堆、抽弃牌、确认/取消出牌、RuntimeCard Buff 分发 | 与旧架构意图基本一致 |
| `EntityManager` | 玩家/敌人初始化、资源读取与扣除、执行 `CombatAction`、实体事件中继 | 与旧架构意图基本一致 |
| `CombatEntity` + `AttributeSet` | 实体实际战斗属性与属性 Buff | 与旧架构意图基本一致 |
| `PlayerVisualManager` | 探索/调试表现模式、移动/视角开关 | **[待确认]** 将来增加战斗表现模式时仍不拥有真实战斗数值 |
| `SaveManager` | 槽位、元数据、模块注册、JSON 文件读写 | 与旧架构意图基本一致 |
| `PlayerSaveManager` | 当前为空 | **[待确认]** 玩家长期数据与存档模块适配 |
| `AllCardData` / `AllEnemyData` | 静态 Resource 模板数据库 | 与旧架构意图一致 |

## 5. 状态所有权

### 5.1 当前源码能够确认的所有权

| 状态 | 当前持有者 |
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
| 存档槽位与注册模块 | `SaveManager` |

### 5.2 仍待真正落地的所有权

**[待确认：沿用旧架构意图？]**

- 应用阶段 / 当前游戏会话 → `GameManager`
- 一次远征进度 / 待收集与已收集结果 → `ExpeditionManager`
- 玩家长期成长 / 长期牌组 / 装备 → `PlayerSaveManager` 或其他明确的玩家长期数据模块

在这些类仍为空的阶段，AI 不应擅自另建第二套“临时全局状态管理器”来绕开它们。

## 6. 数据模型关系

```text
CardData (.tres 静态模板)
  ↓ CardInstance(card_id, modifiers, unique_id)
  ↓ BattleManager._convert_deck_to_runtime()
RuntimeCard(card_data Dictionary, active_buffs)
  ↓ create_action()
CombatAction
  ↓ Timeline 排期
EntityManager.execute_action()
  ↓
CombatEntity -> AttributeSet -> Attribute

EnemyData (.tres)
  ├─ attributes
  └─ action_pool: Array[EnemyAction]
       ↓ EnemyAI
       ↓
     CombatAction

MapBlueprint (.tres)
  ↓ WorldGenerator
  ↓
mapdata {
  rooms: Dictionary[Vector2, RoomData],
  doors: Dictionary[Vector2, orientation]
}
  ↓
WorldManager + RoomSet + DoorSet
```

## 7. 当前真实流程与目标流程

### 7.1 当前世界流程（源码已确认）

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
→ 1.2 秒计时
→ enter_battle_mode()
```

当前 `enter_battle_mode()` **没有真正调用 `BattleManager.start_battle()`**。

### 7.2 当前战斗内部流程（代码层面）

```text
BattleManager.start_battle()
→ EntityManager.initialize()
→ CardManager.initialize()
→ battle_started

卡牌 UI 请求出牌
→ CardManager.card_play_requested
→ BattleManager 资源检查 / 扣费
→ CardManager.confirm_play_card()
→ Timeline.receive_card()
→ Timeline 推进
→ action_triggered
→ BattleManager
→ EntityManager.execute_action()
→ Timeline.notify_action_finished()
→ timeline_advancement_finished
→ 解锁输入
```

### 7.3 目标纵向闭环

**[待确认：来自旧版 AGENTS.md，确认后可删掉“待确认”标记]**

```text
地图探索
→ 遭遇敌人
→ ExpeditionManager 接收遭遇
→ 组装玩家牌组 / 玩家实体数据 / enemy_id
→ BattleManager.start_battle()
→ 战斗
→ battle_ended(result)
→ ExpeditionManager 接收结果
→ WorldManager 更新原房间
→ 恢复同一次远征地图
→ 继续探索
```

## 8. 目录导航

| 目录 | 主要内容 |
| --- | --- |
| `Scripts/` | 全局管理器、静态数据 Resource 类型、存档基础类、卡牌/敌人数据库 |
| `Scripts/CardData/` | 卡牌模板与 CardEffect 旧路径 |
| `Scripts/EnemyData/` | 敌人 Resource 实例 |
| `ExpeditionSystem/` | 远征顶层 |
| `ExpeditionSystem/WorldSystem/` | 地图、房间、门、玩家探索表现 |
| `ExpeditionSystem/BattleSystem/` | 战斗协调、时间轴、实体、卡牌 |
| `Arts/` | Shader、Theme、美术和字体资源 |

## 9. AI 接到任务后的阅读顺序

1. 先读本文件确认目标属于哪个系统。
2. 在 `CODE_INDEX.md` 找到相关类 / 方法 / 场景 / Resource。
3. 在 `MECHANICS.md` 查看当前规则、公式和已知设计未决项。
4. 在 `AI_PROGRESS.md` 检查当前正在解决的里程碑与阻塞问题。
5. 最后去 `PROJECT_DUMP.md` 阅读目标文件真实正文以及调用方/场景接线。
6. 若任何说明文档与源码冲突，以源码为事实并报告文档过期。

## 10. 请用户确认的长期信息

> 以下内容无法从当前源码可靠确定。确认后建议直接改本文，而不是让 AI 猜测。

- **[请用户填写]** 当前主场景实际路径：
- **[请用户填写]** `GameManager` 最终是否负责基地 ↔ 远征的应用级切换：
- **[请用户填写]** `ExpeditionManager` 是否继续作为探索 ↔ 战斗唯一协调器：
- **[请用户填写]** 玩家长期数据最终放在 `PlayerSaveManager` 还是新的数据对象：
- **[请用户填写]** 是否计划让 `BattleSystem.tscn` 作为 `ExpeditionSystem.tscn` 的常驻子场景，还是遭遇时动态实例化：
- **[请用户填写]** 当前阶段是否需要兼容旧存档：
