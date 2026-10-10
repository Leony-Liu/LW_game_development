# CODEMAP

## 0. Purpose and usage

This is the repository navigation map for Codex. Use it before a broad repository search: locate the likely implementation files here, then inspect those real files. Real workspace files override this document. This file does not define gameplay rules, architecture rules, milestone status, or production scope.

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
| `MainMenuSystem/MainMenu.tscn` | Root `MainMenu`; no attached script | Configured main scene (`uid://cu8ebs30en5qs`) | Application startup or main-menu scene work |
| `Scripts/GameManager.gd` | Autoload `GameManager`; `Node` | Application-flow entry | Base/main-menu/Expedition transition work; see its `[PLACEHOLDER]` warning below |
| `Scripts/SaveManager.gd` | Autoload `SaveManager`; `Node` | Save slots, module registry, JSON I/O | Save infrastructure and slot lifecycle |
| `Scripts/CardData/AllCardData.gd` | Autoload `AllCardData`; `Node` | Loads `CardData` resources by ID | Card lookup, card database, persistent card construction |
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
AllEnemyData     -> Scripts/EnemyData/AllEnemyData.gd
godot_mcp_runtime -> development infrastructure, not gameplay ownership
```

## 2. Task routing / Fast lookup

| Task / concern | Read first | Then inspect | Notes |
| --- | --- | --- | --- |
| Main scene / Autoloads / input map | `project.godot` | Referenced scene or Autoload script | Main scene is UID-backed; verify both config and scene |
| Application or Base <-> Expedition flow | `Scripts/GameManager.gd` | `MainMenuSystem/MainMenu.tscn`, `ExpeditionSystem/ExpeditionSystem.tscn` | No Base scene is present; see the `[PLACEHOLDER]` warning below |
| Expedition lifecycle / World <-> Battle coordination | `ExpeditionSystem/Scripts/ExpeditionManager.gd` | `ExpeditionSystem/ExpeditionSystem.tscn`, `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerVisualManager.gd`, `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd` | Startup and presentation readiness are live; result handoff remains incomplete |
| Prototype player / deck input | `ExpeditionSystem/Scripts/PrototypePlayerDataProvider.gd` | `ExpeditionSystem/BattleSystem/Scripts/EntityData.gd`, `Scripts/RefCounted/CardInstance.gd`, `Scripts/CardData/AllCardData.gd` | Prototype-only input route; persistent player data is separate |
| Map generation | `ExpeditionSystem/WorldSystem/Scripts/WorldGenerator.gd` | `Scripts/MapBlueprint.gd`, `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd`, `Scripts/EnemyData/AllEnemyData.gd` | `generate()` returns `rooms` and `doors` dictionaries |
| World state / current room / encounter pre-flow | `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd` | `ExpeditionSystem/ExpeditionSystem.tscn`, `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd`, `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/DoorSet.gd` | `WorldManager.mapdata` is the current runtime map container |
| Room data / encounter state | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd` | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/BattleRoom.gd`, `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd`, `ExpeditionSystem/WorldSystem/Scripts/WorldGenerator.gd` | Resource fields hold enemy and room state |
| Room assembly | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/RoomSet.gd` | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/BattleRoom.gd`, `ExpeditionSystem/WorldSystem/RoomSystem/BattleRoom.tscn` | Builds room instances from `mapdata` |
| Door interaction / room transition detection | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Door.gd` | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/DoorSet.gd`, `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd`, `ExpeditionSystem/WorldSystem/RoomSystem/Prefab/Door.tscn` | Door signals relay upward to `WorldManager` |
| Exploration movement / camera | `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerVisualManager.gd` | `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerController.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/HeadController.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/CameraBobMount.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/DebugFreeCamera.gd`, `ExpeditionSystem/WorldSystem/PlayerVisual/PlayerVisual.tscn` | Use the `PlayerVisual/` implementation, not the obsolete standalone debug scene |
| Battle lifecycle | `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd` | `ExpeditionSystem/BattleSystem/BattleSystem.tscn`, `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/EntityManager.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardManager.gd`, `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd` | `start_battle()` is the public start entry; `battle_ended` is the result signal |
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
| Card buffs | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardBuff.gd` | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/RuntimeCard.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardManager.gd`, `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd` | Runtime modifiers only |
| Enemy data | `Scripts/Resource/Enemy/R_EnemyData.gd` | `Scripts/Resource/Enemy/R_EnemyAction.gd`, `Scripts/EnemyData/AllEnemyData.gd`, `Scripts/EnemyData/EnemyDatas/` | Static enemy attributes and action pools |
| Save infrastructure | `Scripts/SaveManager.gd` | `Scripts/RefCounted/SaveModule.gd` | Registered modules supply serializable data |
| Persistent player data | `Scripts/PlayerSaveManager.gd` | `Scripts/SaveManager.gd`, `ExpeditionSystem/Scripts/PrototypePlayerDataProvider.gd` | Placeholder only; not an Autoload and not current data authority |
| Card UI visuals / interaction | `ExpeditionSystem/BattleSystem/CardSystem/Card.tscn` | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Logic.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Interaction.gd`, `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Animation.gd` | Scene owns UI composition; `RuntimeCard` owns battle card state |
| Automated Godot validation | `tools/godot_cli.ps1` | Target `.gd` / `.tscn` plus `project.godot` | Use the smallest targeted CLI check that proves the task |

## 3. System maps

### Application

Primary:
- `project.godot`
- `MainMenuSystem/MainMenu.tscn`
- `Scripts/GameManager.gd`

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
- `ExpeditionSystem/Scripts/PrototypePlayerDataProvider.gd`
- `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd`
- `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd`

Key entry points:
- `PrototypePlayerDataProvider.validate_configuration()`
- `PrototypePlayerDataProvider.get_player_data()`
- `PrototypePlayerDataProvider.get_player_deck()`
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
- `BattleManager.notify_visual_completed()`
- `battle_started`
- `battle_ended(is_player_victory)`
- `input_lock_changed(is_locked)`
- `visual_effect_requested(visual_type, data)`

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
- `Timeline.cancel_advancement()`
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
- `EntityManager.can_initialize()`
- `EntityManager.can_player_afford()`
- `EntityManager.consume_player_resource()`
- `EntityManager.execute_action()`
- `enemy_action_generated`
- `card_buff_requested`
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
- `CardManager.draw_cards()`
- `CardManager.execute_player_draw_action() -> int`
- `CardManager.confirm_play_card()`
- `CardManager.discard_card()`
- `CardManager.advance_hand_buffs_time()`
- `RuntimeCard.create_action()`
- `RuntimeCard.add_buff()`
- `PlayerHandDeck.add_card_to_hand()`
- `CardLogic.card_played_request`
- `PlayerHandDeck.card_play_requested`
- `CardManager.card_play_requested`

### Static Data / Resources

| Type / database | Definition | Instances / loader |
| --- | --- | --- |
| `MapBlueprint` | `Scripts/MapBlueprint.gd` | `ExpeditionSystem/WorldSystem/Scripts/test_mapblueprint.tres` |
| `RoomData` | `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd` | Created by `WorldGenerator.gd` at runtime |
| `CardData` | `Scripts/Resource/Card/R_carddata.gd` | `Scripts/CardData/Cards/`; loaded by `AllCardData.gd` |
| `EnemyData` | `Scripts/Resource/Enemy/R_EnemyData.gd` | `Scripts/EnemyData/EnemyDatas/`; loaded by `AllEnemyData.gd` |
| `EnemyAction` | `Scripts/Resource/Enemy/R_EnemyAction.gd` | Subresources inside enemy data resources |
| `EntityData` | `ExpeditionSystem/BattleSystem/Scripts/EntityData.gd` | Constructed by the current player-data provider |
| `CombatAction` | `ExpeditionSystem/Scripts/CombatAction.gd` | Constructed by `RuntimeCard.gd` and `EnemyAI.gd` |

### Save / Persistence

Primary:
- `Scripts/SaveManager.gd`
- `Scripts/RefCounted/SaveModule.gd`

Related:
- `Scripts/RefCounted/CardInstance.gd`
- `Scripts/PlayerSaveManager.gd`

Key entry points / signals:
- `SaveManager.register_module()`
- `SaveManager.create_new_save()`
- `SaveManager.load_slot()`
- `SaveManager.save_game()`
- `SaveManager.unload_current_save()`
- `save_started` / `save_finished`
- `load_started` / `load_finished`

### UI

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
- `build_godot_snapshot.py` (temporary web-snapshot generator; not live repository truth and expected to leave the persistent documentation workflow during migration cleanup)

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
-> PrototypePlayerDataProvider.validate_configuration()
-> get_player_data() / get_player_deck()
-> EntityManager.can_initialize() / CardManager.can_initialize()
-> BattleManager.start_battle(...) -> bool
-> WorldManager.resolve_encounter_request(RoomData, startup_succeeded)
-> PREPARING_BATTLE resolves RoomData -> BattleRoom -> EncounterApproachAnchor
-> real PlayerController moves and faces target with collision
-> completion validates transition id + RoomData + target identity
-> WorldManager.world_state_changed(..., BATTLE)
-> ExpeditionManager._on_world_state_changed()
-> BattleManager.set_presentation_ready(true)
```

```text
Scripts/Resource/Card/R_carddata.gd (CardData)
-> AllCardData
-> CardInstance
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
| `MainMenuSystem/MainMenu.tscn` | `MainMenu`; no script | Configured application entry scene |
| `ExpeditionSystem/ExpeditionSystem.tscn` | Top-level root; no root script | ExpeditionManager, prototype provider, WorldSystem, resident BattleSystem, UISystem assembly |
| `ExpeditionSystem/BattleSystem/BattleSystem.tscn` | `BattleSystem` / `BattleManager.gd` | Battle subsystem nodes and exported references |
| `ExpeditionSystem/WorldSystem/PlayerVisual/PlayerVisual.tscn` | `PlayerVisual` / `PlayerVisualManager.gd` | Exploration player, head, camera bob, player camera, debug camera |
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
| `Scripts/Resource/Enemy/R_EnemyData.gd` | `EnemyData` resource definition |
| `Scripts/Resource/Enemy/R_EnemyAction.gd` | `EnemyAction` resource definition |
| `Scripts/EnemyData/EnemyDatas/` | Enemy template resources |
| `Arts/Theme/GlobalTheme.tres` | Project custom theme referenced by `project.godot` |

## 6. Legacy / hazardous paths

| Path | Status | Reason / preferred route |
| --- | --- | --- |
| `ExpeditionSystem/BattleSystem/Scripts/BattleSaveModule.gd` | `[LEGACY]` | Unmounted, not in a reliable registration chain, and references fields/signatures incompatible with current data types. Start save work at `SaveManager.gd` and `SaveModule.gd`. |
| `Scripts/CardData/CardEffect/` | `[LEGACY]` | Old `CardData -> CardEffect` execution path coexists with the battle `RuntimeCard -> CombatAction` path. Do not extend or delete it without an explicit migration task. |
| `ExpeditionSystem/WorldSystem/DebugFreeCamera.tscn` | `[DO NOT USE AS NEW ARCHITECTURE]` | Unreferenced by the saved current Expedition scene and points to missing `WorldSystem/Scripts/DebugFreeCamera.gd`. Use `PlayerVisual.tscn` plus `PlayerVisual/Scripts/DebugFreeCamera.gd`. |
| `ExpeditionSystem/ExpeditionSystem.tscn4534689310.tmp` | `[TEMPORARY]` | Tracked editor recovery artifact with obsolete scene wiring. Use `ExpeditionSystem.tscn`. |
| `ExpeditionSystem/BattleSystem/CardSystem/CardSystem.tscn58389123.tmp` | `[TEMPORARY]` | Tracked editor recovery artifact containing stale `res://Scene/Battle_Scene/...` paths. Use `CardSystem.tscn`. |
| `Scripts/PlayerSaveManager.gd` | `[PLACEHOLDER]` | Empty and unmounted. Do not treat it as implemented persistent-player ownership. |
| `Scripts/GameManager.gd` | `[PLACEHOLDER]` | Autoload exists, but application flow is not implemented. |

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

### Timeline action resolution

```text
Timeline.action_triggered
-> BattleManager._on_timeline_action_triggered()
-> EntityManager.execute_action()
-> CombatEntity
-> AttributeSet / Attribute
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
```

### Card data to battle action

```text
CardData
-> AllCardData
-> CardInstance
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
