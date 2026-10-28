# CODEMAP

## 0. Purpose and usage

This is the repository navigation map for Codex. Use it before a broad repository search: locate the likely implementation files here, then inspect those real files. Real workspace files override this document. This file does not define gameplay rules, architecture rules, milestone status, or production scope.

核对日期：2026-10-28。当前导航包括武器双牌组、玩家存档、主菜单、Base 设施 E/确认/编辑、远征 L 和开门战斗；P 临时入口已移除。未重做全仓审计；早期 52 脚本/22 场景/12 资源仅是历史基线，不是当前总量。逻辑证据与历史记录见 `Docs/ARCHITECTURE.md` 第 12 节。`[LIVE]` 表示保存接线，`[SOURCE]` 表示源码证据，均不代表视觉验收。

```text
task
-> Docs/CODEMAP.md
-> relevant Docs/ARCHITECTURE.md or Docs/GAME_DESIGN.md section when needed and present
-> real files
-> targeted search only if necessary
```

## 1. Project entry points

| Entry | Class / attachment | Primary role | Inspect when |
| --- | --- | --- | --- |
| `project.godot` | Godot project configuration | Main scene, Autoloads, input map, plugins, project settings | Any entry-point, global-service, configuration, or input task |
| `MainMenuSystem/MainMenu.tscn` | Root `MainMenu`; `MainMenu.gd`, `Control` | Configured main scene (`uid://cu8ebs30en5qs`); Start/Quit buttons | Start calls GameManager; Base normally, fresh Expedition on interrupted-session marker |
| `BaseSystem/Base.tscn` | Root `Base`; `Node3D`, `BaseSystem/Scripts/Base.gd` | Existing Field, Facility/testentrance, Facility/testcardeditor, Lights, PlayerVisual and BaseUI | Nearest Area3D target + E opens confirmation/editor; confirmation calls save-aware GameManager.start_expedition() |
| `Scripts/GameManager.gd` | Autoload `GameManager`; `Node` | Application flow and save-before-transition coordination | `start_game()`, `start_expedition()`, `return_to_base()`, death return and recovery |
| `Scripts/SaveManager.gd` | Autoload `SaveManager`; `Node` | Save slots, module registry, checked JSON I/O | Atomic file commit; bool operation results; legacy BattleSaveModule remains inactive |
| `Scripts/PlayerSaveManager.gd` | Autoload `PlayerSaveManager`; after static databases | Weapon persistence coordinator | save/load, current weapon access, combat deck handoff and marker; initial choice belongs to GameManager |
| `Scripts/CardData/AllCardData.gd` | Autoload `AllCardData`; `Node` | Loads `CardData` resources by ID | Card lookup, card database, persistent card construction |
| `Scripts/WeaponData/AllWeaponData.gd` | Autoload `AllWeaponData`; `Node`, after `AllCardData` | Validates and indexes static `WeaponData` | Two starting arrays; testweapon 3001; missing optional card references warn and skip during creation |
| `Scripts/EnemyData/AllEnemyData.gd` | Autoload `AllEnemyData`; `Node` | Loads `EnemyData` resources by ID | Enemy lookup, map enemy assignment, battle entity setup |
| `ExpeditionSystem/ExpeditionSystem.tscn` | Top-level root; no attached script | Expedition assembly | Expedition, World/Battle composition, or saved node-reference wiring |
| `ExpeditionSystem/Scripts/ExpeditionManager.gd` | Attached to `ExpeditionManager`; `Node` | Expedition-level World/Battle coordination location | Explore/Battle handoff or expedition lifecycle |
| `ExpeditionSystem/BattleSystem/BattleSystem.tscn` | Root script `BattleManager.gd` | Resident battle subsystem assembly | Battle scene wiring and subsystem ownership |
| `tools/godot_cli.ps1` | PowerShell wrapper | Canonical Godot 4.7.2 CLI entry point | Automated parse, load, editor, or targeted scene validation |

Configured Autoloads in `project.godot`:

```text
GameManager      -> Scripts/GameManager.gd
SaveManager      -> Scripts/SaveManager.gd
AllCardData      -> Scripts/CardData/AllCardData.gd
AllWeaponData    -> Scripts/WeaponData/AllWeaponData.gd (after AllCardData)
AllEnemyData     -> Scripts/EnemyData/AllEnemyData.gd
PlayerSaveManager -> Scripts/PlayerSaveManager.gd (after static databases)
godot_mcp_runtime -> development infrastructure, not gameplay ownership
```

### Current input routes

| Input | Source and route |
| --- | --- |
| E / `interact` in Base | `project.godot` → `BaseSystem/Scripts/Base.gd`; proximity to entrance/editor required, nearest target only; entrance confirm calls GameManager.start_expedition() |
| P | Temporary expedition shortcut and its dedicated InputMap action removed; use entrance facility |
| L / `return_to_base` | `project.godot` → `ExpeditionManager.can_return_to_base()` / `return_to_base_requested` → `GameManager.return_to_base()`; active Expedition EXPLORE only, no battle/result/transition in progress |
| F / `combat_draw_to_full`, Space / `combat_advance_time` | `project.godot` → `BattleManager._unhandled_input()`; battle input gates remain owned by BattleManager |
| WASD / mouse / Shift / Esc | Shared `PlayerController.gd` and `HeadController.gd` in `PlayerVisual.tscn`; Base has no separate movement implementation |
| E door interaction | `Door.gd` currently checks `KEY_E` directly; the declared `interact` InputMap action is not the door's active input route |

## 2. Task routing / Fast lookup

| Task / concern | Read first | Then inspect | Notes |
| --- | --- | --- | --- |
| Main scene / Autoloads / input map | `project.godot` | Referenced scene or Autoload script | Main scene is UID-backed; verify both config and scene |
| Main menu / application or Base <-> Expedition flow | `Scripts/GameManager.gd` | `MainMenuSystem/MainMenu.gd`, `Scripts/PlayerSaveManager.gd`, `BaseSystem/Base.tscn`, `BaseSystem/Scripts/Base.gd` | Normal Start enters Base; interrupted Start directly creates Expedition; entrance E confirmation uses start_expedition(); direct Editor expedition receives same handoff |
| Base facilities / weapon deck editor | `BaseSystem/Scripts/Base.gd`, `BaseSystem/UI/BaseUI.tscn` | `BaseSystem/UI/WeaponDeckEditor.tscn`, `BaseSystem/UI/Scripts/WeaponDeckEditor.gd`, `BaseSystem/UI/Scripts/WeaponDeckCard.gd`, `BaseSystem/UI/Scripts/WeaponDeckRegion.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Card.tscn`, `Scripts/RefCounted/CardContainer.gd` | Base owns transfers; four-column vertical combat grid, foreground horizontal reserve row; adapter reuses CardLogic.display_instance with presentation_only; same persistent instance, no new save trigger |
| Expedition lifecycle / World <-> Battle coordination | `ExpeditionSystem/Scripts/ExpeditionManager.gd` | `ExpeditionSystem/ExpeditionSystem.tscn`, `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerVisualManager.gd`, `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd` | GameManager injects combat_deck instances; victory continues exploration; death_confirmed / return_to_base_requested notify GameManager to save and return Base |
| Persistent player / battle input | `Scripts/PlayerSaveManager.gd` | `Scripts/RefCounted/WeaponInstance.gd`, `Scripts/RefCounted/CardContainer.gd`, `Scripts/RefCounted/PlayerCardSaveModule.gd`, `ExpeditionSystem/Scripts/ExpeditionManager.gd` | WeaponInstance owns ordered combat/reserve containers; only combat goes to Battle; ExpeditionManager Inspector supplies current combat attributes |
| Initial weapon / authored starting references | `Scripts/NewGame.tres`, `Scripts/Resource/NewGameConfig.gd` | `Scripts/GameManager.gd`, `Scripts/WeaponData/Weapons/testweapon.tres`, `Scripts/RefCounted/WeaponInstance.gd` | initial_weapon_id 3001; create only when no saved weapon exists, preserve existing deck identities and contents |
| Map generation | `ExpeditionSystem/WorldSystem/Scripts/WorldGenerator.gd` | `Scripts/MapBlueprint.gd`, `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd`, `Scripts/EnemyData/AllEnemyData.gd` | `generate()` returns `rooms` and `doors` dictionaries |
| World state / current room / encounter pre-flow | `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd` | `ExpeditionSystem/ExpeditionSystem.tscn`, `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd`, `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/DoorSet.gd` | `WorldManager.mapdata` is the current runtime map container |
| Room data / encounter state | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd` | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/BattleRoom.gd`, `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd`, `ExpeditionSystem/WorldSystem/Scripts/WorldGenerator.gd` | Resource fields hold enemy and room state |
| Room assembly | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/RoomSet.gd` | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/BattleRoom.gd`, `ExpeditionSystem/WorldSystem/RoomSystem/BattleRoom.tscn` | Builds room instances from `mapdata` |
| Door interaction / room transition detection | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Door.gd` | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/DoorSet.gd`, `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd`, `ExpeditionSystem/WorldSystem/RoomSystem/Prefab/Door.tscn` | Door signals relay upward to `WorldManager` |
| Exploration movement / camera | `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerVisualManager.gd` | `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerController.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/HeadController.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/CameraBobMount.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/DebugFreeCamera.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/PlayerVisual.tscn` | Use the `PlayerVisual/` implementation, not the obsolete standalone debug scene |
| First-person lantern presentation | `ExpeditionSystem/WorldSystem/PlayerVisual/Lantern/Lantern.tscn` | `ExpeditionSystem/WorldSystem/PlayerVisual/Lantern/LanternController.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/Lantern/oil_lantern_001_production.tscn`, `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerVisualManager.gd` | PlayerVisual forwards head pitch and movement; separate gravity and motion pivots move model and light together, while `set_lit(enabled)` controls lighting |
| Combat feedback / action completion | `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd` | `ExpeditionSystem/Scripts/ExpeditionManager.gd`, `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Scripts/PlayerHandDeck.gd`, `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd`, `ExpeditionSystem/WorldSystem/RoomSystem/EnemyVisual/EnemyVisual.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerDamageFeedback.gd` | Battle tracks card exit and combat effect receipts before Timeline releases the next action |
| Battle lifecycle | `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd` | `ExpeditionSystem/BattleSystem/BattleSystem.tscn`, `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/EntityManager.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardManager.gd`, `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd` | `start_battle()` is the public start entry; `battle_ended` is the result signal |
| Prototype combat HUD | `ExpeditionSystem/BattleSystem/UI/CombatHUD.tscn` | `ExpeditionSystem/BattleSystem/Scripts/CombatHUD.gd`, `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd`, `ExpeditionSystem/BattleSystem/BattleSystem.tscn` | Edit hierarchy/style in HUD scene; `BattleManager._refresh_hud()` supplies values to `CombatHUD.display_state()`; HUD has no gameplay-system references |
| Timeline / logical time | `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd` | `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd`, `ExpeditionSystem/Scripts/CombatAction.gd` | Owns `current_time`, `action_line`, and advancement state |
| Enemy AI | `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/EnemyAI.gd` | `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/EntityManager.gd`, `Scripts/Resource/Enemy/R_EnemyData.gd`, `Scripts/Resource/Enemy/R_EnemyAction.gd`, `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd` | Converts `EnemyAction` resources to `CombatAction` |
| Entity initialization / action execution | `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/EntityManager.gd` | `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/CombatEntity.gd`, `ExpeditionSystem/BattleSystem/Scripts/EntityData.gd`, `ExpeditionSystem/Scripts/CombatAction.gd` | Mediates entities, resources, AI, and action resolution |
| Attributes / damage / entity buffs | `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/CombatEntity.gd` | `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/AttributeSet.gd`, `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/Attribute.gd`, `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/AttributeBuff.gd` | Damage/shield handling begins in `apply_attribute_impact()` |
| Unified battle action payload | `ExpeditionSystem/Scripts/CombatAction.gd` | Producers: `ExpeditionSystem/BattleSystem/CardSystem/Scripts/RuntimeCard.gd`, `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/EnemyAI.gd`; consumer: `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/EntityManager.gd` | Crosses cards/AI, Timeline, and entity resolution |
| Player card-play flow | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Logic.gd` | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/PlayerHandDeck.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardManager.gd`, `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd`, `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd` | UI requests; managers authorize and mutate state |
| Card pile state | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardManager.gd` | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/PlayerHandDeck.gd`, `ExpeditionSystem/BattleSystem/CardSystem/CardSystem.tscn` | Owns draw, hand, and discard piles |
| Battle-time card state | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/RuntimeCard.gd` | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardBuff.gd`, `ExpeditionSystem/Scripts/CombatAction.gd`, `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd` | Mutable per-battle representation |
| Persistent card instance | `Scripts/RefCounted/CardInstance.gd` | `Scripts/Resource/Card/R_carddata.gd`, `Scripts/CardData/AllCardData.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Scripts/RuntimeCard.gd` | Carries `card_id`, `modifiers`, and `unique_id` outside active battle |
| Static card data | `Scripts/Resource/Card/R_carddata.gd` | `Scripts/CardData/AllCardData.gd`, `Scripts/CardData/Cards/` | `CardData` resource type and templates |
| Static weapon definitions / database | `Scripts/Resource/Weapon/R_weapondata.gd` | `Scripts/WeaponData/AllWeaponData.gd`, `Scripts/WeaponData/Weapons/` | id/name/description plus starting_combat_deck_card_ids / starting_reserve_deck_card_ids; testweapon 3001; initial selection in Scripts/NewGame.tres |
| Card buffs | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardBuff.gd` | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/RuntimeCard.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardManager.gd`, `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd` | Runtime modifiers only |
| Enemy data | `Scripts/Resource/Enemy/R_EnemyData.gd` | `Scripts/Resource/Enemy/R_EnemyAction.gd`, `Scripts/EnemyData/AllEnemyData.gd`, `Scripts/EnemyData/EnemyDatas/` | Static enemy attributes and action pools |
| Save infrastructure | `Scripts/SaveManager.gd` | `Scripts/RefCounted/SaveModule.gd`, `Scripts/RefCounted/PlayerCardSaveModule.gd` | Player containers and expedition_was_active only; no room/battle runtime checkpoint |
| Persistent player data | `Scripts/PlayerSaveManager.gd` | `Scripts/RefCounted/WeaponInstance.gd`, `Scripts/RefCounted/CardContainer.gd`, `Scripts/RefCounted/PlayerCardSaveModule.gd` | get_current_weapon(), initialize_new_weapon(), get_expedition_deck(), validate_deck_handoff(); WeaponInstance owns both containers |
| Card UI visuals / interaction | `ExpeditionSystem/BattleSystem/CardSystem/Card.tscn` | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Logic.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Interaction.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Animation.gd` | Scene owns UI composition; `RuntimeCard` owns battle card state |
| Automated Godot validation | `tools/godot_cli.ps1` | Target `.gd` / `.tscn` plus `project.godot` | Use the smallest targeted CLI check that proves the task |

### 2.1 内容任务的最小起点

先读本行的创建与消费文件，再按具体影响追入第 3 节；不默认修改整条系统链。就绪等级、所有权与限制统一见 ARCHITECTURE 第 7、10–12 节。

| 任务 | 先看 / 最小文件组 | 需要扩大范围时才追入 | 定位注意事项 |
| --- | --- | --- | --- |
| 新增/修改基础伤害卡 | `Scripts/Resource/Card/R_carddata.gd`、`Scripts/CardData/Cards/`、`ExpeditionSystem/BattleSystem/CardSystem/Scripts/RuntimeCard.gd` | `Scripts/CardData/AllCardData.gd`；WeaponData 的两个 starting 数组 | 当前 7 模板；testweapon 3001 引用 5 Attack、2 Skill；已有存档不因新增模板补牌 |
| 新卡牌效果 / Buff | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/RuntimeCard.gd`、`ExpeditionSystem/Scripts/CombatAction.gd` | `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd`、`ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardManager.gd`、`ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardBuff.gd`；实体效果再看 EntityManager | 当前 create_action 只转伤害/可选盾；旧 effects 不执行，共享 Buff/计数时机待设计；资源金额按类型计算但统一扣 stamina |
| 新增/修改敌人及行动 | `Scripts/EnemyData/EnemyDatas/`、`Scripts/Resource/Enemy/R_EnemyData.gd`、`Scripts/Resource/Enemy/R_EnemyAction.gd` | `Scripts/EnemyData/AllEnemyData.gd`、`ExpeditionSystem/BattleSystem/CombatSystem/Scripts/EnemyAI.gd`、`ExpeditionSystem/BattleSystem/EntitySystem/Scripts/EntityManager.gd` | 行动为敌人 .tres 子资源；attack / 自身 shield 可消费，skill 为空；time_cost > 0、cooldown >= 0，人工检查权重/唯一 action_id |
| 修改地图参数 / 房间 / 遭遇 | `ExpeditionSystem/WorldSystem/Scripts/test_mapblueprint.tres`、`Scripts/MapBlueprint.gd` | `ExpeditionSystem/WorldSystem/Scripts/WorldGenerator.gd`；房间外观从 `ExpeditionSystem/WorldSystem/RoomSystem/BattleRoom.tscn` 与 `Prefab/`；遭遇从 `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd` 与 RoomData | 当前单一房间场景，只有 INITIAL/NORMAL、单 enemy_id；Boss 配额需 level 2 模板，现无此模板；设施房不是已存在入口 |
| 修改伤害结算 / 排期 / 时间 | `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/CombatEntity.gd`、`ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd` | `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/EntityManager.gd`、`ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd`、`ExpeditionSystem/Scripts/CombatAction.gd` | apply_attribute_impact / execute_action / receive_card / notify_action_finished；先核对 GAME_DESIGN 时机，不用 Tween 改逻辑时间 |
| 添加/替换战斗反馈 | `ExpeditionSystem/WorldSystem/RoomSystem/EnemyVisual/EnemyVisual.tscn` 与 `EnemyVisual.gd`；玩家反馈为 `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerDamageFeedback.gd` 与 `ExpeditionSystem/WorldSystem/PlayerVisual/PlayerVisual.tscn` | 新事件才追 `ExpeditionSystem/Scripts/ExpeditionManager.gd`、WorldManager、BattleManager | 保留 bool 启动结果、完成/取消 Callable 与 execution_id/effect_id；保持 EnemyRoot、碰撞与属性不受表现控制 |
| 修改 HUD / 卡牌表现 | `ExpeditionSystem/BattleSystem/UI/CombatHUD.tscn`、`ExpeditionSystem/BattleSystem/Scripts/CombatHUD.gd`；单卡从 `ExpeditionSystem/BattleSystem/CardSystem/Card.tscn` | 新快照字段再看 BattleManager._refresh_hud；手牌布局看 `ExpeditionSystem/BattleSystem/CardSystem/Scripts/PlayerHandDeck.gd`；交互/动画看 `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/` | HUD 只收值；卡牌保留 Visuals、导出控件与离场完成通知；行动预览用 action_instance_id |
| 修改玩家输入 / 远征状态 | `Scripts/PlayerSaveManager.gd`、`Scripts/RefCounted/PlayerCardSaveModule.gd`、`ExpeditionSystem/Scripts/ExpeditionManager.gd` | `ExpeditionSystem/ExpeditionSystem.tscn` 的玩家战斗属性配置；WorldManager / BattleManager 只在边界变化时检查 | 持久牌组由 GameManager 注入；每场 EntityData 属性仍由现有场景配置创建，不持久化 HP/Fuel |
| 玩家容器存档 / 中断恢复 | `Scripts/PlayerSaveManager.gd`、`Scripts/RefCounted/PlayerCardSaveModule.gd`、`Scripts/GameManager.gd` | `Scripts/SaveManager.gd`、`Scripts/RefCounted/SaveModule.gd`、`Scripts/RefCounted/CardContainer.gd` | 进入远征前保存并置 active；死亡确认保存并清 active；恢复为全新远征，未接通房间/Battle checkpoint |

## 3. System maps

### Application

Primary:
- `project.godot`
- `MainMenuSystem/MainMenu.tscn`
- `MainMenuSystem/MainMenu.gd`
- `BaseSystem/Base.tscn`
- `Scripts/GameManager.gd`
- `BaseSystem/Scripts/Base.gd` (nearest facility E input, modal ownership and live container transfers)
- `BaseSystem/UI/BaseUI.tscn` / `BaseSystem/UI/Scripts/BaseUI.gd` (prompt, confirmation and editor composition)
- `BaseSystem/UI/WeaponDeckEditor.tscn` / `BaseSystem/UI/Scripts/WeaponDeckEditor.gd` (four-column combat grid and overlapping foreground reserve row; native single-axis scrolling)
- `BaseSystem/UI/WeaponDeckCard.tscn` / `BaseSystem/UI/Scripts/WeaponDeckCard.gd` (Card.tscn composition, uniform scaling, drag and right-click adapter; card presentation remains in CardLogic)
- `BaseSystem/UI/Scripts/WeaponDeckRegion.gd` (native scroll and background drop target)
- `Scripts/NewGame.tres` / `Scripts/Resource/NewGameConfig.gd` (initial weapon 3001)

Related:
- `Scripts/SaveManager.gd`

Key entry points:
- `run/main_scene`
- Autoload declarations

### Expedition

Primary:
- `ExpeditionSystem/Scripts/ExpeditionManager.gd`
- `ExpeditionSystem/ExpeditionSystem.tscn`

Related:
- `Scripts/PlayerSaveManager.gd`
- `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd`
- `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd`

Key entry points:
- `GameManager.start_game()` / `start_expedition()` / `return_to_base()` (save owned data, clear marker, reuse death-return transition)
- `PlayerSaveManager.get_expedition_deck()` / `validate_deck_handoff()`
- `ExpeditionManager.initialize_player_deck()` / `get_player_deck()` / `death_confirmed`
- `ExpeditionManager.can_return_to_base()` / `return_to_base_requested`: InputMap `return_to_base` (L), EXPLORE only without battle startup/active battle/pending result; GameManager validates active scene and transition latch again
- `BattleManager.is_starting_battle()`: read-only startup gate for Expedition return validation
- `ExpeditionManager._on_world_encounter_requested()`
- `ExpeditionManager._on_world_state_changed()`

### World

Primary:
- `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd`
- `ExpeditionSystem/WorldSystem/Scripts/WorldGenerator.gd`

Data / resources:
- `Scripts/MapBlueprint.gd`
- `ExpeditionSystem/WorldSystem/Scripts/test_mapblueprint.tres`
- `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd`

Key entry points:
- `WorldManager.init_map()`
- `WorldManager.report_encounter()` / `encounter_requested`
- `report_encounter()` returns notification-dispatched status; acceptance is a separate `resolve_encounter_request()` command
- `WorldManager.is_encounter_pending()`
- `WorldManager.world_state_changed`
- `WorldManager.resolve_encounter_request()`
- `WorldManager.enter_explore_mode()`
- `WorldManager.enter_preparing_battle_mode()`
- `WorldManager.enter_battle_mode()`
- `WorldManager.has_valid_encounter_approach()`
- `WorldManager.finish_battle()`
- `WorldGenerator.generate()`

### Rooms / Doors

Primary:
- `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/RoomSet.gd`
- `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/BattleRoom.gd`
- `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/DoorSet.gd`
- `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Door.gd`

Scenes:
- `ExpeditionSystem/WorldSystem/RoomSystem/BattleRoom.tscn`
- `ExpeditionSystem/WorldSystem/RoomSystem/Prefab/Door.tscn`
- `ExpeditionSystem/WorldSystem/RoomSystem/Prefab/`

Key entry points / signals:
- `RoomSet.build_rooms()`
- `BattleRoom.set_room_data()` / `room_data_changed`
- `RoomSet.get_room_instance()` / `get_encounter_approach_target()`
- `BattleRoom.get_encounter_approach_target()`
- `BattleRoom.clear_enemies()`
- `DoorSet.build_doors()` / `door_opened_relay`
- `Door.open_door()` / `door_opened`

### Player Visual / Exploration

Primary:
- `ExpeditionSystem/WorldSystem/PlayerVisual/PlayerVisual.tscn`
- `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerVisualManager.gd`

Related:
- `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerController.gd`
- `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/HeadController.gd`
- `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/CameraBobMount.gd`
- `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/DebugFreeCamera.gd`
- `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerDamageFeedback.gd`

Key entry points / signals:
- `PlayerVisualManager.change_mode()`
- `PlayerVisualManager.start_encounter_approach()` / `encounter_approach_finished`
- `PlayerController.start_cinematic_approach()` / `cinematic_approach_finished`
- `PlayerController.set_active()` / `movement_state_changed`
- `HeadController.smooth_face_world_position()` / `set_active()`
- `DebugFreeCamera.set_active()`

### Battle

Primary:
- `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd`
- `ExpeditionSystem/BattleSystem/BattleSystem.tscn`

Related:
- `project.godot` `[input]` (`combat_draw_to_full`, `combat_advance_time`)
- `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd`
- `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/EntityManager.gd`
- `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardManager.gd`

Key entry points / signals:
- `BattleManager.start_battle(Array[CardInstance], EntityData, int) -> bool`
- `BattleManager.set_presentation_ready()`
- `BattleManager.is_battle_input_locked()`
- `BattleManager.request_draw_to_full()` / `request_advance_time()`
- `BattleManager.notify_visual_completed(execution_id, effect_id)`
- `battle_started`
- `battle_ended(is_player_victory)`
- `input_lock_changed(is_locked)`
- `visual_effect_requested(visual_type, data)`
- `enemy_attack_started(source_id, execution_id, effect_id)` / `health_damage_applied(..., execution_id, effect_id)`
- `action_presentation_cancelled(execution_id)`

### Timeline / Enemy AI

Primary:
- `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd`
- `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/EnemyAI.gd`

Data:
- `ExpeditionSystem/Scripts/CombatAction.gd`
- `Scripts/Resource/Enemy/R_EnemyAction.gd`

Key entry points / signals:
- `Timeline.add_action()`
- `Timeline.receive_card()`
- `Timeline.advance_timeline_to()`
- `Timeline.notify_action_finished(action)`
- `Timeline.reset_for_battle()`
- `Timeline.cancel_advancement()`
- `Timeline.has_pending_action()`
- `Timeline.get_scheduled_enemy_action_snapshots()`
- `action_triggered`
- `time_advanced`
- `timeline_advancement_finished`
- `EnemyAI.setup_ai()`
- `EnemyAI.plan_initial_actions()`
- `EnemyAI.plan_next_action()` / `action_planned`

### Entity / Attributes

Primary:
- `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/EntityManager.gd`
- `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/CombatEntity.gd`

Related:
- `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/AttributeSet.gd`
- `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/Attribute.gd`
- `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/AttributeBuff.gd`
- `ExpeditionSystem/BattleSystem/Scripts/EntityData.gd`

Key entry points / signals:
- `EntityManager.initialize()`
- `EntityManager.plan_next_enemy_action()`
- `EntityManager.can_initialize()`
- `EntityManager.validate_configuration()`
- `EntityManager.get_enemy_entities()`
- `EntityManager.can_player_afford()`
- `EntityManager.consume_player_resource()`
- `EntityManager.advance_player_resource_regeneration()`
- `EntityManager.execute_action()`
- `enemy_action_generated`
- `entity_died`
- `CombatEntity.initialize_from_data()`
- `CombatEntity.apply_attribute_impact()`
- `CombatEntity.apply_entity_buff()`
- `AttributeSet.register_attribute()`
- `AttributeSet.get_attribute()`

### Cards

Primary:
- `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardManager.gd`
- `ExpeditionSystem/BattleSystem/CardSystem/Scripts/RuntimeCard.gd`
- `Scripts/RefCounted/CardInstance.gd`

UI:
- `ExpeditionSystem/BattleSystem/CardSystem/Scripts/PlayerHandDeck.gd`
- `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Logic.gd`
- `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Interaction.gd`
- `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Animation.gd`

Data / resources:
- `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardBuff.gd`
- `Scripts/Resource/Card/R_carddata.gd`
- `Scripts/CardData/AllCardData.gd`
- `Scripts/CardData/Cards/`

Key entry points / signals:
- `CardManager.initialize()`
- `CardManager.can_initialize()`
- `CardManager.validate_configuration()` / `set_input_locked()`
- `CardManager.draw_cards()`
- `CardManager.execute_player_draw_action() -> int`
- `CardManager.confirm_play_card() -> bool` (whether the card exit visual started)
- `PlayerHandDeck.card_play_exit_finished` / `CardManager.card_play_presentation_completed`
- `CardManager.discard_card()`
- `CardManager.advance_hand_buffs_time()`
- `RuntimeCard.create_action()`
- `RuntimeCard.add_buff()`
- `PlayerHandDeck.add_card_to_hand()`
- `CardLogic.card_played_request`
- `PlayerHandDeck.card_play_requested`
- `CardManager.card_play_requested`
- `CardInstance.new(id, template, instance_uid = "")` / `from_dictionary(data, template)` preserve UID; missing saved templates retain persistent records and are skipped in battle; WeaponInstance creates initial cards, PlayerCardSaveModule restores them
- `BattleManager._convert_deck_to_runtime()` passes `CardInstance.unique_id` to `RuntimeCard.source_instance_uid`; both dictionary APIs preserve identity

### Static Data / Resources

| Type / database | Definition | Instances / loader |
| --- | --- | --- |
| `MapBlueprint` | `Scripts/MapBlueprint.gd` | `ExpeditionSystem/WorldSystem/Scripts/test_mapblueprint.tres` |
| `RoomData` | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd` | Created by `WorldGenerator.gd` at runtime |
| `CardData` | `Scripts/Resource/Card/R_carddata.gd` | `Scripts/CardData/Cards/`; loaded by `AllCardData.gd` |
| `WeaponData` | `Scripts/Resource/Weapon/R_weapondata.gd` | `Scripts/WeaponData/Weapons/`; indexed by `AllWeaponData.gd`; testweapon.tres ID 3001, 20 combat / 10 reserve references |
| `EnemyData` | `Scripts/Resource/Enemy/R_EnemyData.gd` | `Scripts/EnemyData/EnemyDatas/`; loaded by `AllEnemyData.gd` |
| `EnemyAction` | `Scripts/Resource/Enemy/R_EnemyAction.gd` | Subresources inside enemy data resources |
| `EntityData` | `ExpeditionSystem/BattleSystem/Scripts/EntityData.gd` | Constructed from ExpeditionManager's existing Inspector combat attributes |
| `WeaponInstance` | `Scripts/RefCounted/WeaponInstance.gd` | Persistent weapon UID, static definition, combat/reserve containers; starting factory and dictionary APIs |
| `CardContainer` | `Scripts/RefCounted/CardContainer.gd` | Ordered CardInstance collection; combat capacity 20, reserve unlimited; transfers retain existing object and UID |
| `CombatAction` | `ExpeditionSystem/Scripts/CombatAction.gd` | Constructed by `RuntimeCard.gd` and `EnemyAI.gd` |

### Save / Persistence

Primary:
- `Scripts/SaveManager.gd`
- `Scripts/RefCounted/SaveModule.gd`
- `Scripts/RefCounted/PlayerCardSaveModule.gd`
- `Scripts/RefCounted/WeaponInstance.gd`
- `Scripts/RefCounted/CardContainer.gd`

Related:
- `Scripts/RefCounted/CardInstance.gd`
- `Scripts/PlayerSaveManager.gd`

Key entry points / signals:
- `SaveManager.register_module()`
- `SaveManager.create_new_save()`
- `SaveManager.load_slot()`
- `SaveManager.save_game()`
- `SaveManager.unload_current_save()`
- `SaveModule.try_load_save_data()` / `can_save()` (checked extension, preserves legacy void load API)
- `CardContainer.get_cards()` / `add_card()` / `remove_card()` / `transfer_to()` / dictionary APIs
- `PlayerSaveManager.save_with_expedition_marker()` (default slot: user://saves/player_cards.json)
- `save_started` / `save_finished`
- `load_started` / `load_finished`

### UI

Combat HUD:
- `ExpeditionSystem/BattleSystem/UI/CombatHUD.tscn` (editable layout; 13 exported control references, including intent template and tooltip)
- `ExpeditionSystem/BattleSystem/Scripts/CombatHUD.gd` (`display_state(snapshot)`, no gameplay queries)
- `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd` (collects subsystem updates and produces display values)

Combat feedback:
- `ExpeditionSystem/WorldSystem/RoomSystem/EnemyVisual/EnemyVisual.tscn` and `EnemyVisual.gd` (enemy model lunge and hit reaction)
- `ExpeditionSystem/WorldSystem/PlayerVisual/PlayerVisual.tscn` and `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerDamageFeedback.gd` (camera shake pivot and damage overlay)
- `ExpeditionSystem/Scripts/ExpeditionManager.gd` (Battle event to World presentation routing)

Expedition result UI:
- `ExpeditionSystem/ExpeditionSystem.tscn/UISystem`
- `ExpeditionSystem/UISystem/Scripts/ExpeditionResultUI.gd`
- `ExpeditionSystem/Scripts/ExpeditionManager.gd` (result signal coordination)

Primary card UI area:
- `ExpeditionSystem/BattleSystem/CardSystem/CardSystem.tscn`
- `ExpeditionSystem/BattleSystem/CardSystem/player_hand_deck.tscn`
- `ExpeditionSystem/BattleSystem/CardSystem/Card.tscn`

Navigation rule:
- Inspect `CardManager.gd` for pile/state ownership.
- Inspect `PlayerHandDeck.gd` and `Card_Logic.gd` for request relays and UI lifecycle.
- Inspect `Card_Interaction.gd` and `Card_Animation.gd` for input and presentation only.

### Development tooling

Primary:
- `tools/godot_cli.ps1`
- `addons/godot-mcp/`

Related:
- `.codex_runtime/` (generated isolated automation state; not gameplay source)
- `build_godot_snapshot.py` (existing standalone Python source-snapshot generator; default output `PROJECT_DUMP.md`; not a test runner or live implementation authority; no removal decision is inferred)

Validation entry points:

- `tools/godot_cli.ps1 --version` resolves the installed 4.7.2 executable; `GODOT_472_PATH` can override discovery. The wrapper isolates automation user/temp data in `.codex_runtime/`.
- `tools/godot_cli.ps1 --headless --path . --script <absolute_probe.gd>` runs a scoped external probe. Avoid preloading typed gameplay dependencies before Autoload names are registered in a SceneTree script; defer business-script loading until initialization. Track the probe PID and confirm its final marker as well as the exit code.
- Direct gameplay entry: `tools/godot_cli.ps1 --headless --path . res://ExpeditionSystem/ExpeditionSystem.tscn --quit-after 120`; this checks bounded startup, not a complete encounter or visual quality.
- No dedicated, versioned automated regression suite was found among project sources/tooling. Older audit probe counts are not runnable test entry points. Build a task-scoped probe outside gameplay source when needed.
- Editor plugin: `addons/godot-mcp/plugin.gd` (9876); runtime Autoload: `addons/godot-mcp/runtime_bridge.gd` (9877). Avoid launching a second Editor against the user's session; clean up only task-created processes and verify released ports.

## 4. Important data lifecycle routes

```text
Scripts/MapBlueprint.gd
-> WorldGenerator.generate()
-> WorldManager.mapdata
-> RoomSet.build_rooms() / DoorSet.build_doors()
-> BattleRoom / Door instances
```

```text
Door.open_door()
-> Door.door_opened
-> DoorSet.door_opened_relay
-> WorldManager._on_door_opened()
-> WorldManager.report_encounter(RoomData)
-> encounter_requested(RoomData, enemy_id)
-> ExpeditionManager._on_world_encounter_requested()
-> WorldManager.is_encounter_pending(RoomData)
-> ExpeditionManager._create_player_data() / get_player_deck()
-> previously injected persistent CardInstance objects (no per-encounter card creation)
-> BattleManager.start_battle(...) -> bool (internally checks EntityManager.can_initialize() / CardManager.can_initialize())
-> WorldManager.resolve_encounter_request(RoomData, startup_succeeded)
-> PREPARING_BATTLE resolves RoomData -> BattleRoom -> EncounterApproachAnchor
-> real PlayerController moves and faces target with collision; absent optional target skips approach and enters BATTLE
-> completion validates transition id + RoomData + target identity
-> WorldManager.world_state_changed(..., BATTLE)
-> ExpeditionManager._on_world_state_changed()
-> BattleManager.set_presentation_ready(true)
```

```text
Scripts/Resource/Card/R_carddata.gd (CardData)
-> AllCardData
-> GameManager selects Scripts/NewGame.tres for a new WeaponInstance; PlayerSaveManager coordinates PlayerCardSaveModule restoration
-> WeaponInstance.combat_deck -> GameManager -> ExpeditionManager.initialize_player_deck()
-> BattleManager.start_battle()
-> BattleManager._convert_deck_to_runtime()
-> RuntimeCard
-> Timeline.receive_card()
-> RuntimeCard.create_action()
-> CombatAction
```

```text
Scripts/EnemyData/EnemyDatas/*.tres
-> AllEnemyData
-> EntityManager.initialize()
-> EnemyAI
-> CombatAction
-> Timeline
```

```text
EntityData / EnemyData
-> EntityManager
-> CombatEntity
-> AttributeSet
-> Attribute
```

```text
SaveManager
-> registered SaveModule implementations
-> modules_data
-> user://saves/<slot>.json
```

## 5. Scene and resource navigation

### Important scenes

| Scene | Root / attached script | Inspect for |
| --- | --- | --- |
| `MainMenuSystem/MainMenu.tscn` | `MainMenu` / `MainMenu.gd`; `Control` | Start calls GameManager.start_game(): Base normally, newly generated Expedition on active recovery marker; Quit exits |
| `BaseSystem/Base.tscn` | `Base` / `BaseSystem/Scripts/Base.gd` | Existing facilities, Area3D proximity, PlayerVisual, BaseUI; E opens confirmation/editor; P no longer starts expedition |
| `BaseSystem/UI/BaseUI.tscn` | `CanvasLayer` / `BaseUI.gd` | Unique prompt, ConfirmationDialog and DeckEditor; presentation only |
| `BaseSystem/UI/WeaponDeckEditor.tscn` | `Control` / `WeaponDeckEditor.gd` | DeckLayers: vertical four-column CombatGrid, opaque foreground ReservePanel with horizontal ReserveRow; counts, close and status |
| `BaseSystem/UI/WeaponDeckCard.tscn` | `Control` / `WeaponDeckCard.gd` | Instanced Card.tscn with presentation_only and display_instance(CardInstance); adapter owns only scaling and deck input |
| `ExpeditionSystem/ExpeditionSystem.tscn` | Top-level root; no root script | ExpeditionManager with combat attributes and injected deck, WorldSystem, resident BattleSystem, UISystem assembly |
| `ExpeditionSystem/BattleSystem/BattleSystem.tscn` | `BattleSystem` / `BattleManager.gd` | Battle composition and exported references; `Timeline`, `EnemyAI`, and `EntityManager` remain inline |
| `ExpeditionSystem/BattleSystem/UI/CombatHUD.tscn` | `CombatHUD` / `CombatHUD.gd` | Independently editable HUD hierarchy, layout, styles, and internal label references |
| `ExpeditionSystem/WorldSystem/PlayerVisual/PlayerVisual.tscn` | `PlayerVisual` / `PlayerVisualManager.gd` | Exploration player, head, camera bob, damage shake pivot, player camera, damage overlay, debug camera |
| `ExpeditionSystem/WorldSystem/RoomSystem/EnemyVisual/EnemyVisual.tscn` | `EnemyVisual` / `EnemyVisual.gd` | Replaceable model-only lunge and hit reaction |
| `ExpeditionSystem/WorldSystem/PlayerVisual/Lantern/Lantern.tscn` | `Lantern` / `LanternController.gd` | Editable gravity/motion pivots, light and model composition |
| `ExpeditionSystem/WorldSystem/PlayerVisual/Lantern/oil_lantern_001_production.tscn` | Imported model wrapper; no script | Model from `Arts/Props/Lantern/Oil_Lantern_001.glb` |
| `ExpeditionSystem/WorldSystem/RoomSystem/BattleRoom.tscn` | `BattleRoom` / `BattleRoom.gd` | Dynamic room walls, floor, ceiling, enemy visual root |
| `ExpeditionSystem/WorldSystem/RoomSystem/Prefab/Door.tscn` | `Door` / `Door.gd` | Door body, interaction area, open/close behavior |
| `ExpeditionSystem/BattleSystem/CardSystem/CardSystem.tscn` | `CardSystem` / `CardManager.gd` | Card-system UI root and PlayerHandDeck binding |
| `ExpeditionSystem/BattleSystem/CardSystem/player_hand_deck.tscn` | `PlayerHandDeck` / `PlayerHandDeck.gd` | Hand container and card scene factory |
| `ExpeditionSystem/BattleSystem/CardSystem/Card.tscn` | `Card` / `Card_Logic.gd` | Card visual tree, interaction component, animation component |

### Important resource locations

| Path | Type / use |
| --- | --- |
| `Scripts/MapBlueprint.gd` | `MapBlueprint` resource definition |
| `ExpeditionSystem/WorldSystem/Scripts/test_mapblueprint.tres` | Current Expedition scene's default map blueprint |
| `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd` | Runtime room/encounter resource type |
| `Scripts/Resource/Card/R_carddata.gd` | `CardData` resource definition |
| `Scripts/CardData/Cards/` | Card template resources |
| `Scripts/Resource/Weapon/R_weapondata.gd` | `WeaponData` static metadata and two ordered starting card-template ID arrays |
| `Scripts/Resource/NewGameConfig.gd` / `Scripts/NewGame.tres` | Separate new-game configuration; initial_weapon_id 3001, not a saved weapon model |
| `Scripts/WeaponData/AllWeaponData.gd` | Weapon database Autoload; loading, ID/deck-reference validation and queries |
| `Scripts/WeaponData/Weapons/` | User-authored definitions; existing testweapon.tres ID 3001 |
| `Scripts/Resource/Enemy/R_EnemyData.gd` | `EnemyData` resource definition |
| `Scripts/Resource/Enemy/R_EnemyAction.gd` | `EnemyAction` resource definition |
| `Scripts/EnemyData/EnemyDatas/` | Enemy template resources |
| `Arts/Theme/GlobalTheme.tres` | Project custom theme referenced by `project.godot` |

## 6. Legacy / hazardous paths

| Path | Status | Reason / preferred route |
| --- | --- | --- |
| `ExpeditionSystem/BattleSystem/Scripts/BattleSaveModule.gd` | `[LEGACY]` | No active construction/registration chain; incompatible with Battle's optional Node slot. Remains inactive; use PlayerCardSaveModule only for current player-container persistence. |
| `Scripts/CardData/CardEffect/` | `[LEGACY]` | Old `CardData -> CardEffect` execution path coexists with the battle `RuntimeCard -> CombatAction` path. Do not extend or delete it without an explicit migration task. |
| `ExpeditionSystem/WorldSystem/DebugFreeCamera.tscn` | `[DO NOT USE AS NEW ARCHITECTURE]` | Unreferenced by the saved current Expedition scene and points to missing `WorldSystem/Scripts/DebugFreeCamera.gd`. Use `PlayerVisual.tscn` plus `PlayerVisual/Scripts/DebugFreeCamera.gd`. |
| `ExpeditionSystem/ExpeditionSystem.tscn4534689310.tmp` | `[TEMPORARY]` | Tracked editor recovery artifact with obsolete scene wiring. Use `ExpeditionSystem.tscn`. |
| `ExpeditionSystem/BattleSystem/CardSystem/CardSystem.tscn58389123.tmp` | `[TEMPORARY]` | Tracked editor recovery artifact containing stale `res://Scene/Battle_Scene/...` paths. Use `CardSystem.tscn`. |

## 7. Common implementation chains

### Map initialization

```text
ExpeditionSystem.tscn
-> WorldManager._ready()
-> WorldManager.init_map()
-> WorldGenerator.generate()
-> RoomSet.build_rooms()
-> DoorSet.build_doors()
```

### Door interaction / encounter pre-flow

```text
Prefab/Door.tscn + Door.gd
-> DoorSet.gd
-> WorldManager._on_door_opened()
-> RoomData
-> WorldManager.report_encounter()
-> ExpeditionManager
-> BattleManager.start_battle()
-> WorldManager.enter_preparing_battle_mode()
-> PlayerVisualManager.start_encounter_approach()
-> PlayerController / HeadController complete movement and facing
-> WorldManager.enter_battle_mode()
-> ExpeditionManager._on_world_state_changed()
-> BattleManager.set_presentation_ready()
```

### Player card interaction

```text
Card.tscn / Card_Interaction.gd
-> CardLogic.card_played_request
-> PlayerHandDeck.card_play_requested
-> CardManager.card_play_requested
-> BattleManager._on_card_play_requested()
-> Timeline.receive_card()
```

卡牌悬停预览沿 `Card_Interaction.gd` → `CardLogic.hover_changed` → `PlayerHandDeck.card_hover_changed` → `CardManager.card_hover_changed` → `BattleManager` 传递当前 `RuntimeCard`；协调器把已排期行动的实例 ID 交给 `CombatHUD` 缩放现有图标。运行时卡牌属性更新由 `CardLogic.hovered_stats_updated` 触发同一路径刷新。

### Timeline action resolution

```text
Timeline.action_triggered
-> BattleManager._on_timeline_action_triggered()
-> register any in-flight confirmed card exit for this player action
-> EntityManager.execute_action()
-> CombatEntity
-> AttributeSet / Attribute
-> BattleManager dispatches action.card_buffs once to CardManager
-> ExpeditionManager -> WorldManager -> EnemyVisual / PlayerDamageFeedback
-> card exit or removal -> PlayerHandDeck -> CardManager -> BattleManager
-> combat Tween finished or canceled -> ExpeditionManager -> BattleManager.notify_visual_completed(execution_id, effect_id)
-> BattleManager waits for all receipts from this action
-> Timeline.notify_action_finished(action)

Battle 结束时：
BattleManager -> Timeline.cancel_advancement()
```

### Enemy action planning

```text
AllEnemyData / EnemyData
-> EntityManager.initialize()
-> EnemyAI.setup_ai()
-> EnemyAI.plan_initial_actions()
-> EnemyAI.action_planned
-> EntityManager.enemy_action_generated
-> BattleManager
-> Timeline.add_action()

Timeline.action_triggered (enemy action)
-> BattleManager._on_timeline_action_triggered()
-> EntityManager.execute_action()
-> action presentation receipts completed
-> EntityManager.plan_next_enemy_action()
-> EnemyAI.plan_next_action()
-> EnemyAI.action_planned
-> EntityManager.enemy_action_generated
-> BattleManager -> Timeline.add_action()
-> Timeline.notify_action_finished()
```

### Card data to battle action

```text
CardData
-> AllCardData
-> GameManager selects Scripts/NewGame.tres for a new WeaponInstance; PlayerSaveManager coordinates PlayerCardSaveModule restoration
-> WeaponInstance.combat_deck -> GameManager -> ExpeditionManager.initialize_player_deck()
-> BattleManager.start_battle()
-> BattleManager._convert_deck_to_runtime()
-> RuntimeCard
-> Timeline.receive_card()
-> RuntimeCard.create_action()
-> CombatAction
```

### Save pipeline

```text
SaveManager.register_module()
-> SaveModule.get_save_data()
-> SaveManager.save_game()
-> user://saves/<slot>.json

SaveManager.load_slot()
-> SaveModule.load_save_data()
```

## 8. Maintenance rules

Update `Docs/CODEMAP.md` when any of the following materially changes:

- important files are added, deleted, renamed, or moved;
- a major `class_name` changes;
- an important scene changes its attached script;
- main scene or Autoload configuration changes;
- major public entry points or signals used for cross-system navigation change;
- a system responsibility moves to another implementation file;
- a legacy path is removed or replaced;
- a new major gameplay/system area is introduced;
- an existing task route would lead Codex to the wrong files.

Normally do not update CODEMAP for:

- private helper changes;
- local algorithm changes;
- balance changes;
- visual-only changes;
- variable renames that do not affect navigation;
- implementation details already easy to locate from the mapped primary file.

```text
CODEMAP should change when "where Codex should look" changes,
not whenever "what the code does internally" changes.
```

A coding task that changes code locations or system routing should update CODEMAP in the same task. If Codex notices CODEMAP is stale while working, it should correct the affected entry as part of that task when safe and in scope. Do not rewrite unrelated CODEMAP sections merely for formatting consistency.
