# CODE_INDEX.md

> **Purpose:** Fast navigation index for humans and coding agents. Use this file to locate the relevant `.gd`, `.tscn`, or `.tres`, then read the real file in the current workspace.
>
> **Not responsible for:**
> - Full SceneTree / runtime data flow → `ARCHITECTURE.md`
> - Long-term responsibilities / state ownership → `AI_CONTEXT.md`
> - Current blockers / milestones → `AI_PROGRESS.md`
> - Gameplay rules / balance → `MECHANICS.md`
>
> **Source of truth:** Real workspace files override this index. Codex/Agent should not depend on `PROJECT_DUMP.md`; that snapshot is only for web-model workflows.
>
> **Active workspace:** `D:/Game project/Godot/LW_game_development_upgrade_test`  
> **Godot:** 4.7.2 stable

## 0. Fast lookup

| Need | Read first |
| --- | --- |
| Main scene / Autoloads | `project.godot` |
| Base ↔ Expedition app flow | `Scripts/GameManager.gd` |
| Expedition lifecycle / World↔Battle coordinator | `ExpeditionSystem/Scripts/ExpeditionManager.gd` |
| Current project structure / data flow | `ARCHITECTURE.md` |
| Map generation | `ExpeditionSystem/WorldSystem/Scripts/WorldGenerator.gd` + `Scripts/MapBlueprint.gd` |
| Current room / encounter state | `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd` + `RoomData.gd` |
| Rooms / doors | `RoomSet.gd`, `BattleRoom.gd`, `DoorSet.gd`, `Door.gd` |
| Exploration movement / camera | `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/` |
| Battle start / end / subsystem coordination | `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd` |
| Timeline / logical time | `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd` |
| Enemy AI | `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/EnemyAI.gd` |
| Entity / attribute resolution | `EntityManager.gd` → `CombatEntity.gd` → `AttributeSet.gd` → `Attribute.gd` |
| Unified battle action payload | `ExpeditionSystem/Scripts/CombatAction.gd` |
| Player card-play chain | `Card_Logic.gd` → `PlayerHandDeck.gd` → `CardManager.gd` → `BattleManager.gd` → `Timeline.gd` |
| Battle-time card instance | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/RuntimeCard.gd` |
| Card Buffs | `CardBuff.gd` + `RuntimeCard.gd` + `CardManager.gd` |
| Persistent card instance | `Scripts/RefCounted/CardInstance.gd` |
| CardData database | `Scripts/CardData/AllCardData.gd` |
| EnemyData database | `Scripts/EnemyData/AllEnemyData.gd` |
| Save infrastructure | `Scripts/SaveManager.gd` + `Scripts/RefCounted/SaveModule.gd` |
| Long-term player data | `Scripts/PlayerSaveManager.gd` |
| Old battle save implementation | `ExpeditionSystem/BattleSystem/Scripts/BattleSaveModule.gd` **[LEGACY]** |
| Godot CLI automation | `tools/godot_cli.ps1` |

## 1. Entry points and key scenes

### `project.godot`
- Main scene: `res://MainMenuSystem/MainMenu.tscn`
- UID: `uid://cu8ebs30en5qs`
- Gameplay Autoloads: `GameManager`, `SaveManager`, `AllCardData`, `AllEnemyData`
- `godot_mcp_runtime`: development infrastructure, not gameplay architecture

### `MainMenuSystem/MainMenu.tscn`
Current root `MainMenu` has no attached script. For app-entry work, also inspect `Scripts/GameManager.gd`.

### `ExpeditionSystem/ExpeditionSystem.tscn`
Current saved structure:

```text
ExpeditionSystem
├─ WorldSystem [WorldManager.gd]
│  ├─ RoomSet [RoomSet.gd]
│  ├─ DoorSet [DoorSet.gd]
│  ├─ PlayerVisualRoot
│  │  └─ PlayerVisual [PlayerVisual.tscn]
│  └─ WorldGenerator [WorldGenerator.gd]
└─ UISystem
```

Currently absent:
- `ExpeditionManager` node
- `BattleSystem` instance
- expedition-level save module

These are `[TARGET]`, not current state.

### `ExpeditionSystem/BattleSystem/BattleSystem.tscn`
Current saved structure:

```text
BattleSystem [BattleManager.gd]
├─ CombatManager [missing legacy CombatManager.gd]
│  ├─ Timeline [Timeline.gd]
│  ├─ EnemyAI [EnemyAI.gd]
│  └─ EntityManager [EntityManager.gd]
│     ├─ PlayerEntity [CombatEntity.gd]
│     │  └─ AttributeSet [AttributeSet.gd]
│     └─ EnemyEntity [CombatEntity.gd]
│        └─ AttributeSet [AttributeSet.gd]
└─ UI
   ├─ CardSystem [CardManager.gd]
   └─ PlayerInformation
```

Important saved wiring:

```text
BattleManager.timeline            = unbound
BattleManager.entity_manager      = unbound
BattleManager.card_manager        = UI/CardSystem
BattleManager.battle_save_module  = unbound

EntityManager.player_entity       = PlayerEntity
EntityManager.enemy_entity        = EnemyEntity
EntityManager.enemy_ai            = unbound
```

The missing `CombatManager.gd` reference is legacy. Do not recreate a second battle coordinator.

### Card UI scenes
- `ExpeditionSystem/BattleSystem/CardSystem/CardSystem.tscn` → `CardManager.gd`
- `.../player_hand_deck.tscn` → `PlayerHandDeck.gd`
- `.../Card.tscn` → `Card_Logic.gd`
  - `InteractionComponent` → `Card_Interaction.gd`
  - `AnimationComponent` → `Card_Animation.gd`

### `PlayerVisual.tscn`
```text
PlayerVisual [PlayerVisualManager.gd]
├─ Player [PlayerController.gd]
│  └─ Head [HeadController.gd]
│     └─ CameraBobMount [CameraBobMount.gd]
│        └─ PlayerCamera
└─ DebugFreeCamera [DebugFreeCamera.gd]
```

## 2. Application / Expedition

| Path | Class / extends | Role | Key entry |
| --- | --- | --- | --- |
| `Scripts/GameManager.gd` | `Node` | Target application-flow owner | placeholder |
| `ExpeditionSystem/Scripts/ExpeditionManager.gd` | `Node` | Target single explore↔battle coordinator | placeholder, not mounted |
| `Scripts/PlayerSaveManager.gd` | `Node` | Target long-term player-data owner | placeholder, not mounted |
| `ExpeditionSystem/Scripts/CombatAction.gd` | `CombatAction` / `RefCounted` | Unified battle action payload | `_init()`, `add_attribute_impact()`, `add_entity_buff()`, `add_card_buff()` |

For responsibilities/ownership, read `AI_CONTEXT.md`.

## 3. WorldSystem

### Core

| Path | Class / extends | Role | Key interface |
| --- | --- | --- | --- |
| `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd` | `WorldManager` / `Node` | mapdata, current room, WorldState, encounter pre-flow | `init_map()`, `enter_explore_mode()`, `enter_preparing_battle_mode()`, `enter_battle_mode()`, `finish_battle()` |
| `ExpeditionSystem/WorldSystem/Scripts/WorldGenerator.gd` | `WorldGenerator` / `Node` | room / door / enemy placement generation | `generate()` |
| `Scripts/MapBlueprint.gd` | `MapBlueprint` / `Resource` | map-generation config | Resource fields |
| `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd` | `RoomData` / `Resource` | room / encounter state | Resource fields |

`WorldManager.mapdata` is the current runtime map authority.

### Room / Door

| Path | Class | Key interface |
| --- | --- | --- |
| `.../RoomSystem/Scripts/RoomSet.gd` | `RoomSet` | `build_rooms()`, `clear_rooms()` |
| `.../RoomSystem/Scripts/BattleRoom.gd` | `BattleRoom` | `set_room_data()`, `build_room()`, `clear_enemies()`; `room_data_changed` |
| `.../RoomSystem/Scripts/DoorSet.gd` | `DoorSet` | `build_doors()`, `clear_doors()`; `door_opened_relay` |
| `.../RoomSystem/Scripts/Door.gd` | `Door` | `open_door()`, `close_door()`; `door_opened` |

### PlayerVisual
Directory: `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/`

| File | Class | Key entry |
| --- | --- | --- |
| `PlayerVisualManager.gd` | `PlayerVisualManager` | `change_mode()` |
| `PlayerController.gd` | `PlayerController` | `set_active()`; `movement_state_changed` |
| `HeadController.gd` | `HeadController` | `set_active()` |
| `CameraBobMount.gd` | `CameraBobMount` | `apply_bob()` |
| `DebugFreeCamera.gd` | `DebugFreeCamera` | `set_active()` |

## 4. BattleSystem

### `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd`
`BattleManager` / `Node`

```text
start_battle(
    external_deck: Array[CardInstance],
    external_player_data: EntityData,
    enemy_id: int
) -> void

notify_visual_completed() -> void
```

Signals:

```text
battle_started
battle_ended(is_player_victory: bool)
input_lock_changed(is_locked: bool)
visual_effect_requested(visual_type: String, data: Dictionary)
```

### `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd`
`Timeline` / `Node`

Key API:

```text
add_action()
receive_card()
advance_timeline_to()
notify_action_finished()
pop_next_action_before_or_equal()
get_last_enemy_action_time()
clear_enemy_actions()
```

Signals: `timeline_data_updated`, `action_triggered`, `timeline_advancement_finished`, `time_advanced`

Authority: `current_time`, `action_line`, `is_advancing`

### `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/EnemyAI.gd`
`EnemyAI` / `Node`

```text
setup_ai()
plan_initial_actions()
plan_next_action(current_timeline_time)
```

Signal: `action_planned(action: CombatAction)`

Continuous planning is not wired yet.

## 5. EntitySystem

Directory: `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/`

| File | Class / extends | Role | Key interface |
| --- | --- | --- | --- |
| `EntityManager.gd` | `EntityManager` / `Node` | entity init, resource payment, CombatAction execution, AI relay | `initialize()`, `can_player_afford()`, `consume_player_resource()`, `execute_action()` |
| `CombatEntity.gd` | `CombatEntity` / `Node` | entity attributes / damage / death | `initialize_from_data()`, `apply_attribute_impact()`, `apply_entity_buff()` |
| `AttributeSet.gd` | `AttributeSet` / `Node` | entity attribute collection | `register_attribute()`, `get_attribute()`, `get_value()`, `bind_custom_formula_to_attribute()` |
| `Attribute.gd` | `Attribute` / `RefCounted` | single attribute + formula + buffs | arithmetic / formula / buff API |
| `AttributeBuff.gd` | `AttributeBuff` / `RefCounted` | attribute modifier | `_init()` |

`EntityManager` signals:

```text
visual_effect_generated(visual_type, data)
card_buff_requested(target_id, buff)
enemy_action_generated(action)
entity_died(entity)
```

Battle input type:

```text
ExpeditionSystem/BattleSystem/Scripts/EntityData.gd
→ EntityData / RefCounted
```

## 6. CardSystem

Directory: `ExpeditionSystem/BattleSystem/CardSystem/Scripts/`

| File | Class / extends | Role | Key interface |
| --- | --- | --- | --- |
| `CardManager.gd` | `CardManager` / `Node` | draw / hand / discard authority | `initialize()`, `draw_cards()`, `confirm_play_card()`, `discard_card()`, `advance_hand_buffs_time()` |
| `PlayerHandDeck.gd` | `PlayerHandDeck` / `HBoxContainer` | hand UI / request relay | `add_card_to_hand()`, `set_input_locked()`, confirm/reject methods |
| `RuntimeCard.gd` | `RuntimeCard` / `RefCounted` | battle card state / CardBuff / CombatAction creation | `add_buff()`, `advance_time()`, cost/time getters, `create_action()` |
| `CardBuff.gd` | `CardBuff` / `RefCounted` | runtime card modifier | `tick_time()`, `tick_count()`, `apply_modifier()` |

CardManager authority:

```text
draw_pile
hand_pile
discard_pile
```

UI is not pile authority.

### Card UI
Directory: `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/`

| File | Class | Signals |
| --- | --- | --- |
| `Card_Logic.gd` | `CardLogic` | `card_played_request`, `card_discarded_request`, `exit_finished` |
| `Card_Interaction.gd` | `Node` | `left_clicked`, `right_clicked`, `hover_started`, `hover_ended` |
| `Card_Animation.gd` | `Node` | `draw_finished`, `exit_finished` |

## 7. Static data / Resources

### Cards
- Type: `Scripts/Resource/Card/R_carddata.gd` → `CardData`
- DB: `Scripts/CardData/AllCardData.gd` → Autoload `AllCardData`
- Templates: `Scripts/CardData/Cards/`

Known templates from the current index:
`Heavyblow.tres`, `Inspringsk.tres`, `Lethalsk.tres`, `Quickslash.tres`, `Slash.tres`, `S_Chargeup.tres`, `S_Staggerstep.tres`.

For exact values, read the current `.tres`.

Legacy CardEffect path:
`Scripts/CardData/CardEffect/`

Known files:
`E_AddPoison.gd`, `E_Priority.gd`, `E_cost.gd`

Do not bulk-delete this path without an explicit migration task.

### Enemies
- Type: `Scripts/Resource/Enemy/R_EnemyData.gd` → `EnemyData`
- Action type: `Scripts/Resource/Enemy/R_EnemyAction.gd` → `EnemyAction`
- DB: `Scripts/EnemyData/AllEnemyData.gd` → Autoload `AllEnemyData`
- Templates: `Scripts/EnemyData/EnemyDatas/`
- Known templates: `testenemy1.tres`, `testenemy2.tres`

## 8. Persistent / Save

### `Scripts/RefCounted/CardInstance.gd`
`CardInstance` / `RefCounted`

```text
_init()
to_dictionary()
from_dictionary()
get_card_name()
```

### `Scripts/SaveManager.gd`
Autoload.

```text
register_module()
get_save_summaries()
delete_save()
create_new_save()
load_slot()
save_game()
unload_current_save()
```

Signals: `save_started`, `save_finished`, `load_started`, `load_finished`

### `Scripts/RefCounted/SaveModule.gd`
`SaveModule` / `RefCounted`

```text
get_module_key()
get_save_data()
load_save_data()
clear_data()
```

### `ExpeditionSystem/BattleSystem/Scripts/BattleSaveModule.gd` **[LEGACY]**
Still present, but currently not mounted, not part of a reliable registration path, and incompatible with current `EntityData` / `EnemyData`.

Do not use it as the basis for new save architecture.

## 9. Common call-chain navigation

### World init
```text
WorldManager._ready()
→ init_map()
→ WorldGenerator.generate()
→ RoomSet.build_rooms()
→ DoorSet.build_doors()
→ enter_explore_mode()
```

### Door → encounter pre-flow
```text
Door.open_door()
→ door_opened
→ DoorSet.door_opened_relay
→ WorldManager._on_door_opened()
→ enter_preparing_battle_mode(RoomData)
→ enter_battle_mode()
```

No formal handoff to `ExpeditionManager` / `BattleManager` yet.

### Player card play
```text
Card_Interaction
→ Card_Logic
→ PlayerHandDeck
→ CardManager
→ BattleManager
→ EntityManager
→ CardManager confirm
→ Timeline.receive_card()
```

### Action resolution
```text
Timeline.action_triggered
→ BattleManager
→ EntityManager.execute_action()
→ CombatEntity
→ AttributeSet / Attribute
→ BattleManager
→ Timeline.notify_action_finished()
```

### Enemy action
```text
EntityManager.initialize()
→ EnemyAI.setup_ai()
→ plan_initial_actions()
→ action_planned
→ EntityManager.enemy_action_generated
→ BattleManager
→ Timeline.add_action()
```

Continuous re-plan is not wired yet.

### Save
```text
SaveManager.register_module()
→ save_game()
→ SaveModule.get_save_data()
→ user://saves/<slot>.json

load_slot()
→ JSON
→ SaveModule.load_save_data()
```

## 10. Current navigation warnings

### Scene wiring
```text
BattleSystem.tscn:
- missing legacy CombatManager.gd
- BattleManager.timeline unbound
- BattleManager.entity_manager unbound
- EntityManager.enemy_ai unbound
```

### World ↔ Battle
```text
ExpeditionManager not mounted
BattleSystem not instanced under ExpeditionSystem
World encounter has no formal report interface
battle_ended has no receiver
```

### Battle internals
```text
EnemyAI continuous planning not wired
CardBuff has duplicate application paths
stamina / mana payment rule is inconsistent
```

See `AI_PROGRESS.md` for priority and status.

## 11. Directory map

| Directory | Contents |
| --- | --- |
| `MainMenuSystem/` | main scene |
| `Scripts/` | global managers / Autoloads / shared types |
| `Scripts/CardData/` | card DB / `.tres` / legacy CardEffect |
| `Scripts/EnemyData/` | enemy DB / `.tres` |
| `Scripts/RefCounted/` | persistent / interface data objects |
| `Scripts/Resource/` | Resource type definitions |
| `ExpeditionSystem/Scripts/` | ExpeditionManager / CombatAction |
| `ExpeditionSystem/WorldSystem/` | world / room / door / player visual |
| `ExpeditionSystem/BattleSystem/` | battle / timeline / entity / card |
| `Docs/` | guidance docs |
| `tools/` | automation |

## 12. Recommended Agent reading flow

```text
AGENTS.md
→ CODE_INDEX.md to locate files
→ real target files

Need responsibility / ownership?
→ AI_CONTEXT.md

Need SceneTree / signals / runtime data flow?
→ relevant ARCHITECTURE.md section

Need current blocker / milestone?
→ AI_PROGRESS.md

Need gameplay rules?
→ MECHANICS.md

After edits:
→ tools/godot_cli.ps1
→ use MCP only when live Editor / Runtime state is needed
```

Avoid whole-repo scans for local tasks. Do not treat `PROJECT_DUMP.md` as Agent live truth.

## 13. Maintenance rules

Update this file when:
- important `.gd` files are added / deleted / moved
- `class_name` changes
- important scene/script paths change
- main scene / Autoloads change
- important public entry points are added/removed
- legacy paths are removed or promoted
- major Resource types / data directories change

Usually do not update for:
- private helpers
- local algorithm changes
- variable changes that do not affect navigation
- purely visual UI edits

Maintenance goal:

```text
short
searchable
path-accurate
non-duplicative with ARCHITECTURE
```

Primary purpose:

> **Get the Agent to the correct real file quickly.**
