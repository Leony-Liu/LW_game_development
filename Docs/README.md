# LW_game_development

本文件是项目的快速首页，面向用户、Web GPT、Desktop Codex 与其他开发者。它说明项目是什么、当前环境是否可用、开发做到哪里、主要缺口是什么，以及接下来应从哪里继续。

详细内容由其他规范文档负责：

- 协作规则与文档路由 → `/AGENTS.md`
- 玩法、体验和 Demo / full-game 设计 → `Docs/GAME_DESIGN.md`
- 系统关系、状态归属和实现边界 → `Docs/ARCHITECTURE.md`
- 精确代码导航 → `Docs/CODEMAP.md`

## 1. 项目概况

`LW_game_development` 是一款以**第一人称程序生成远征、逻辑行动轴卡牌战斗和“武器即牌组”构筑**为核心的游戏。

**当前阶段目标：完成远征系统最基础的可运行闭环——地图生成 → 触发战斗 → 进行战斗 → 结束战斗 → 继续探索。**

这一阶段优先验证同一次远征内 World 与 Battle 的实际联动，不以完成基地、经济、存档或全部试玩版内容为验收条件。其中“进行战斗”的最小可玩范围尚待用户与 Web GPT 进一步讨论；既有战斗代码应优先复用，不将当前实现的临时规则视为最终设计。

| 项目 | 当前值 |
| --- | --- |
| 活动工作区 | `D:/Game project/Godot/LW_game_development_upgrade_test` |
| 活动分支 | `upgrade/godot-4.7-test` |
| 开发引擎 | Godot `4.7.2 stable` |
| 主场景 | `res://MainMenuSystem/MainMenu.tscn` |
| 主场景 UID | `uid://cu8ebs30en5qs` |
| 受保护回退项目 | `D:/Game project/Godot/LW_game_development` |
| 回退引擎 / 标签 | Godot `4.4.1` / `godot-4.4.1-safe` |

本文是当前状态摘要，不替代真实工作区。涉及当前源码、场景、Inspector、Resource 或运行时行为时，应重新检查对应文件或 Godot 状态。

## 2. 主要工程区域

| 区域 | 作用 |
| --- | --- |
| `MainMenuSystem/` | 当前应用入口；正式 Application flow 尚未完成 |
| `ExpeditionSystem/` | 一次远征的顶层组合，包括 World、resident Battle 和 UI |
| `ExpeditionSystem/WorldSystem/` | 地图生成、房间与门、探索移动和相机 |
| `ExpeditionSystem/BattleSystem/` | Battle lifecycle、Timeline、EnemyAI、Entity、Card 和 battle UI |
| `Scripts/` | 全局管理器、静态数据加载器、共享 Resource / RefCounted 类型 |
| `Docs/` | 项目规范文档；精确文件入口见 `CODEMAP.md` |
| `tools/` | Godot CLI 等开发验证工具 |

## 3. 当前开发阶段与阶段目标

**阶段目标：完成远征系统最基础的五步流程。**

```text
1. 地图生成：创建可探索的房间与门
2. 触发战斗：探索、开门遇敌，可靠进入 Battle
3. 进行战斗：玩家能够使用卡牌，Timeline / EnemyAI / 实体效果形成可运行的单场战斗
4. 结束战斗：产生明确的胜负结果并正确结束本场 Battle
5. 继续探索：结果交回 ExpeditionManager，更新同一 World / mapdata / RoomData，恢复探索
```

**当前进度边界：** 地图生成与探索、遇敌上报、Battle 启动和第一人称入场过场已具备实现并经过相应验证；“进行战斗”的内部机制已有代码基础，但完整可玩性仍需核查与补全；“结束战斗 → 继续探索”尚未接通。当前阶段尚不能标记为完成。

**下一步协作重点：** 用户与 Web GPT 先逐项确认“进行战斗”的最低可玩内容、既有实现是否符合预期及未定玩法规则，再向 Codex 下发具体补全任务。不可把 M2 的讨论项直接视为已批准的开发需求。

**阶段验收条件：** 玩家能够在同一张生成地图上探索并遭遇敌人，实际完成一场可结算的战斗，得到结果后回到原远征上下文继续移动、开门，并可再次正常触发战斗；不得通过重新生成地图或重建整次远征伪造返回探索的结果。

## 4. 已完成的关键基础

### Expedition / Battle 顶层装配

当前保存场景已经包含：

```text
ExpeditionSystem
├─ ExpeditionManager
├─ PrototypePlayerDataProvider
├─ WorldSystem
├─ BattleSystem
└─ UISystem
```

已确认：

- `BattleSystem` 是 `ExpeditionSystem` 的常驻子场景。
- `ExpeditionManager` 已绑定 World、Battle 与 prototype provider。
- `BattleManager` 已绑定 Timeline、EntityManager 与 CardManager。
- `EntityManager` 已绑定 player、enemy 与 EnemyAI。
- 旧 `CombatManager` 节点及缺失脚本引用已移除。

这些接线已经过定向场景加载 / probe 验证，但完整 battle lifecycle 尚未运行验证。

### Prototype player / deck input

`PrototypePlayerDataProvider` 当前可从显式 Inspector 配置生成：

```text
player fields → EntityData
CardData IDs → AllCardData lookup → CardInstance[]
```

默认未配置时不会伪造数据；无效 Card ID 会明确失败且不返回部分牌组。保存配置、字段映射、空牌组、重复有效 Card ID 与无效 Card ID 已通过隔离运行探针验证。该 provider 是原型期临时输入，不是长期玩家数据 owner。

### World encounter reporting

`WorldManager` 现在通过 `encounter_requested(room_data, enemy_id)` 向 `ExpeditionManager` 上报有效遭遇。请求期间使用门闩拒绝重复或重入上报；空房间、无敌房间、无效 / 不存在的敌人 ID 会明确失败。

`ExpeditionManager` 已完成 M1-03 Battle startup handoff：校验原 `RoomData`、provider 与 Battle 状态，组装 `EntityData + CardInstance[] + enemy_id`，并仅在 `BattleManager.start_battle()` 明确返回成功后接受 encounter。失败请求会释放，World 保持可重试状态。

M1-04 Exploration-to-Battle transition 及第一人称遇敌接近补充已完成：World 依次进入 `EXPLORE → PREPARING_BATTLE → BATTLE`；准备期停用手动移动与视角，保留原第一人称相机，并让真实 `CharacterBody3D` 沿碰撞几何接近原 `RoomData` 对应房间的敌人锚点。玩家到达安全距离且身体 / 镜头朝向完成后才进入 `BATTLE`，Battle UI / 卡牌输入只在最终状态开放。transition id、原 `RoomData` 与目标节点身份共同拒绝旧回调和错误目标；Battle 的内部锁与远征表现门闩继续采用合并锁。

M1-05 Battle startup failure handling 已完成：encounter 返回最终接受结果，匹配请求在接受或拒绝后都会释放 pending；`ExpeditionManager` 在启动前额外预检敌人锚点和玩家表现依赖，并允许修正配置后重试；`BattleManager` 在任何 Entity、Timeline、牌堆或卡牌 UI 写入前完成 Entity / Card 预检，并拒绝重入及已激活 Battle。正常启动、四个接近方向、旧回调、错误房间、无效 / 释放目标与 Battle 表现门闩已通过隔离运行探针验证。入场过场已由用户进行初步人工体验，当前效果暂时符合预期；最终表现品质可在后续迭代调整。

因此 M1-01 至 M1-05 的“探索遇敌并可靠进入 Battle”启动阶段可视为完成；这不包含战斗结果返回、正常恢复探索或第二场 Battle cleanup。

### Battle 内部基础

当前已有：

- `Timeline` logical time / action queue 基础；
- `EntityManager` 初始化与 action execution 基础；
- `CardManager` draw / hand / discard 基础；
- Card UI / interaction / animation 基础；
- `EnemyAI` initial planning 基础。

## 5. 当前主要缺口

### Battle → Expedition → World

`BattleManager` 已发出 `battle_ended(is_player_victory: bool)`，但没有正式 receiver，也没有完整 result contract。

战斗结束后保持同一 `mapdata`、更新原 `RoomData`、恢复探索移动 / 镜头 / 输入的闭环尚未实现。

Battle 已激活后若准备阶段被外部强制中断，目前没有安全的取消 / rollback contract。旧计时器不会恢复 UI 或输入，但 Battle 会保持 active、隐藏且锁定；该状态需要后续正式 cleanup / result lifecycle 处理，不能视为可重试启动失败。

### Battle 内部已知问题

- `EnemyAI` continuous planning 尚未形成完整循环。
- stamina / mana 当前支付路径不一致。
- `CardBuff` 存在重复施加路径风险。
- `CardInstance → RuntimeCard` 尚未完整继承 `modifiers / unique_id`。
- resident BattleSystem 的第二场战斗 cleanup 尚未验证。

最终玩法语义以 `GAME_DESIGN.md` 为准；实现边界和 owner 见 `ARCHITECTURE.md`。

## 6. 存档当前状态

`SaveManager` 已具备 slot、metadata、module registry 与 JSON file I/O 基础。

长期方向是：

```text
SaveManager
├─ persistent player data adapter
└─ one expedition-level checkpoint module
```

试玩版恢复边界已经确定为 Room Entry Checkpoint 与 Battle Start Checkpoint；战斗中断后整场重开，不要求序列化战斗中途 transient state。

`BattleSaveModule.gd` 仍属于未挂载的 legacy 文件。其与 `EntityData` 的解析兼容错误已单独修复，但不代表旧存档流程可用，也不应作为新存档架构基础。`PlayerSaveManager.gd` 仍是 placeholder。

## 7. 工具链与验证边界

当前已验证：

| 能力 | 状态 |
| --- | --- |
| 真实项目文件访问 | 可用 |
| Godot 4.7.2 工作区 | 可用 |
| Canonical Godot CLI wrapper | 已验证 |
| Editor MCP | 已验证 |
| Runtime MCP direct access | 已验证 |
| Headless editor initialization | 已验证 |

Canonical CLI：

```powershell
.\tools\godot_cli.ps1 <Godot args>
```

已知工具例外：`get_status` 可能把 Runtime Bridge 汇总为 `not running / not enabled`，即使 `runtime_ping` 与 targeted runtime inspection 成功。判断 Runtime 是否可用时，应优先看直接调用结果。

`.codex_runtime/` 是自动化隔离目录，不属于 gameplay 源码。

当前验证不能自动证明以下行为完成：

- 入场过场的最终视觉品质（用户已初步体验，暂时无问题）；
- 完整 battle lifecycle；
- battle result return；
- 第二场战斗 cleanup；
- 完整探索 ↔ 战斗纵向闭环。

## 8. 当前直接开发方向

目前按照阶段目标推进，**先细化并验证“进行战斗”，再补全战斗结束与探索恢复**：

```text
1. 用户 + Web GPT：对照最新源码讨论“进行战斗”的最低可玩机制与验收条件
2. Codex：按确认后的规则，核查、修复并验证单场 Battle 内部运行闭环
3. Battle result → ExpeditionManager：明确胜败结果的交接与单场 Battle 结束
4. 更新同一 World / mapdata / 原 RoomData，并恢复探索控制与画面
5. 验证返回后继续开门、再次遭遇和第二场 Battle 的 transient state 清理
```

当前 M2 细节尚在讨论中，不能把旧版五项任务名当作最终需求。已确定的玩法遵循 `GAME_DESIGN.md`；遇到标记为【待设计】的规则必须先由用户确认。以上是阶段实施方向，不是具体排期，也不表示各项已经完成。

## 9. 重要注意事项

- `BattleSaveModule.gd` 是 legacy；不要为了无关任务顺手修补。
- 旧 `CardData → CardEffect` 路径仍与 `RuntimeCard → CombatAction` 并存；未经明确迁移任务不要扩展或批量删除。
- `ExpeditionSystem.tscn` 根节点名含不可见字符；精确导航风险见 `CODEMAP.md`。
- 当前工程状态、SceneTree 和运行行为以真实工作区为准，不以旧快照或本文摘要替代。

## 10. 文档导航

项目长期知识系统只包含：

| 文件 | 负责内容 |
| --- | --- |
| `/AGENTS.md` | Web GPT / Desktop Codex 共用协作契约、事实权威与工作方式 |
| `Docs/README.md` | 项目概览、当前环境、阶段、缺口与直接方向 |
| `Docs/GAME_DESIGN.md` | 游戏设计、体验规则、Demo / full-game scope 与设计 TBD |
| `Docs/ARCHITECTURE.md` | 实现架构、状态归属、系统关系、current / target 边界 |
| `Docs/CODEMAP.md` | Desktop Codex 使用的任务导向代码导航 |

## 11. 本文件何时更新

应更新：当前开发阶段、重要 blocker、环境 / branch / Godot 版本、直接开发方向、关键验证边界或重要 tooling exception 发生变化。

通常不更新：普通局部 bug fix、私有重构、数值微调、详细架构变化或完整历史记录。对应内容分别由真实代码、`GAME_DESIGN.md`、`ARCHITECTURE.md`、Git history / issue tracking 承担。
