# AGENTS.md

Stable collaboration contract and working rules for Web GPT and Desktop Codex.

This file defines how AI collaborators should reason about, navigate, modify, and validate this repository.

Keep this file compact, generic, and slow-changing.

This file is not:
- a gameplay specification;
- a project status report;
- an architecture reference;
- a code index.

Do not modify this file unless repository-wide AI workflow or collaboration rules change.

---

# Communication

- Report to the user in Simplified Chinese unless explicitly requested otherwise.
- Keep code identifiers, class names, methods, signals, file paths, CLI commands, and exact tool/status strings unchanged.
- Keep completion reports concise and factual.
- Do not invent unresolved gameplay, product, save, or architecture decisions.

---

# Canonical Documentation and Reading Order

The repository documentation has separate responsibilities.

| Document | Responsibility |
| --- | --- |
| `/AGENTS.md` | AI collaboration rules, workflow, validation expectations |
| `Docs/README.md` | Project overview, current stage, environment, blockers, and immediate direction |
| `Docs/GAME_DESIGN.md` | Intended gameplay rules, player experience, and design decisions |
| `Docs/ARCHITECTURE.md` | System relationships, ownership, contracts, SceneTree, and implementation boundaries |
| `Docs/CODEMAP.md` | Task-oriented navigation to real source, scene, and resource files |

## AI Task Reading Flow

For implementation tasks, follow this order:

1. Read `Docs/README.md` first to understand current project context.
2. Read `Docs/CODEMAP.md` to locate likely implementation files.
3. Inspect real workspace files.
4. Read `Docs/ARCHITECTURE.md` when system ownership, interfaces, signals, data flow, or SceneTree relationships need clarification.
5. Read `Docs/GAME_DESIGN.md` when gameplay meaning, scope, or design decisions need clarification.
6. Use targeted repository search only when existing navigation is insufficient.

Documentation provides guidance. Real workspace files remain the implementation source of truth.

---

# Collaboration Model

## Web GPT

Web GPT:

- Discusses design and architecture with the user.
- Uses canonical documents and verified implementation reports.
- Plans the next implementation task.
- Creates scoped instructions for Desktop Codex.
- Identifies decisions requiring user confirmation.

Web GPT must not assume unverified local repository state.

---

## Desktop Codex

Desktop Codex:

- Reads repository documentation according to the defined workflow.
- Inspects real workspace files before making conclusions.
- Uses the smallest relevant file scope.
- Performs scoped modifications.
- Validates changes proportionally.
- Preserves unrelated user work.
- Reports actual results and unresolved issues.

---

# Authority and Source of Truth

## Gameplay and Player Experience

Priority order:

1. Explicit user decisions in the current task.
2. `Docs/GAME_DESIGN.md`.

Current implementation does not redefine confirmed design.

If implementation differs from confirmed design:

- Report the gap.
- Do not silently change design assumptions.

Never resolve:

- `【待设计】`
- `TBD`
- pending decisions
- equivalent unresolved items

without user confirmation.

---

## Architecture

Priority order:

1. Explicit user decisions in the current task.
2. Confirmed rules in `Docs/ARCHITECTURE.md`.

Do not treat:

- proposals;
- future plans;
- `[TARGET]` states;

as already implemented.

---

## Current Implementation

Trust order:

1. Real workspace files.
2. Current Godot Editor state when relevant.
3. Current Runtime state when relevant.
4. Documentation summaries.

If documentation conflicts with verified implementation:

- Report the mismatch.
- Do not modify unrelated code to match outdated documentation.

---

# Stable Development Principles

- Keep design truth separate from implementation truth.
- Prefer minimal, readable, maintainable changes.
- Preserve behavior outside the requested task.
- Prefer data-driven configuration for values expected to be tuned repeatedly.
- Respect existing ownership boundaries.
- Do not create duplicate owners for existing responsibilities.
- Do not add global systems, Autoloads, or architectural layers without a clear requirement.
- Required dependencies and invalid data must fail clearly.
- Handle success, failure, cancellation, and cleanup paths for lifecycle operations.
- Presentation layers should reflect gameplay state, not own gameplay truth.
- Authoritative combat outcomes come from gameplay systems. Visual effects must not change damage, targeting, action timing, collision, or other combat state.
- Route confirmed gameplay events to presentation through clear interfaces; gameplay must not depend on a specific animation or effect asset.
- Keep temporary presentation effects replaceable and independently adjustable where useful, without creating a scene for every Tween or visual node.
- Do not implement or expand deferred functionality without explicit user authorization; preserve unresolved design decisions until the user decides them.
- Generic infrastructure should remain separate from gameplay-specific logic.
- Verify only as deeply as required to prove the task.
- Do not claim runtime behavior from static inspection alone.


---

# Code Dependency Direction and Communication

## Default Architecture Rule

- Default to **downward calls and upward notifications**: a higher-level owner/coordinator calls the lower-level modules it coordinates; lower-level modules emit signals describing events or state changes for interested listeners.
- “Higher/lower level” means architectural responsibility and state ownership, not simply literal SceneTree parent/child position. A Node's parent defines containment and lifecycle, but does not automatically define its architectural owner.
- Every dependency must have a clear direction and reason. Avoid circular dependencies, lower-level calls into their coordinator, and lower-level modules directly controlling UI or unrelated siblings. Route sibling coordination through their existing owner unless a documented interface justifies otherwise.
- Do not add an Autoload, global event bus, or framework to bypass these rules.

## Identify the Script's Role First

- For Node-attached scripts, inspect the actual scene path, responsibility, state ownership, exported references, method calls, signals, and lifecycle. Use SceneTree as evidence of containment, not as the only proof of architecture.
- For `Resource`, `RefCounted`, data/model, and static utility scripts, determine dependencies from who creates/owns them and their APIs; they have no SceneTree parent.
- Treat Autoloads and global services as explicit dependencies in the graph, not as exceptions to dependency direction.

## Calls and Signals

- **Downward calls:** use explicit exported references or initialization interfaces for required lower-level dependencies. Stable local NodePaths for a scene's own children are acceptable; avoid `get_parent().get_parent()` and brittle distant/absolute path lookups.
- **Upward signals:** the module that owns an event/state change defines and emits the signal. Its owner/coordinator or other interested listeners may connect to it. The emitter must not require a specific listener or wait for an acknowledgment; emitting with no listeners should be safe unless an explicit contract says otherwise.
- Signals are notifications, not hidden request/response calls. If a result is required, use an explicit downward method call or narrow command interface. Do not replace every method call with a signal or every signal with a method call mechanically.
- A lower-level module should not call back into its owner to report an event; emit a signal instead. The owner decides what to do.

## UI and Presentation

- UI/presentation scripts must not query multiple gameplay systems to reconstruct authoritative state. The responsible coordinator should provide display data or a narrow presentation interface.
- UI may emit signals expressing player intent; the owning gameplay system validates the request and decides the outcome. UI owns presentation state, not gameplay truth.
- Scene modularity and code dependency direction are separate decisions: an independently editable scene is not automatically allowed to depend on every system that uses it.

## Required vs. Optional Dependencies

- Mark dependencies as required or optional in design and validation.
- Missing/invalid required dependencies must fail clearly before the dependent operation proceeds; never silently continue in a broken state.
- Missing optional dependencies may disable only the affected feature and continue safely; make the fallback explicit and warn when silent degradation would hinder debugging.

## Logging and Operation Outcomes

- For new logs in important workflows, and logs deliberately changed in future tasks, use `ScriptName ： Description`: the class name or a clear script identifier, one space on each side of the full-width colon, and a concise, specific, searchable message. Do not bulk-reformat existing logs solely to adopt this convention.
- Use `print()` for useful development milestones: a major workflow starting, an important subtask finishing, successful initialization, or a significant state transition. Log success only after the relevant operation actually succeeds. Do not require a log in every function or log routine per-frame callbacks, property reads, and loop iterations without a specific diagnostic need.
- Use `push_warning()` for a recoverable anomaly with a safe fallback. State the problem, its impact, and the fallback when applicable. Do not downgrade a failed required operation to a warning when dependent work cannot proceed correctly.
- Use `push_error()` for a missing required dependency, failed assembly of a required scene or resource, or another operation that cannot complete safely. Include the operation and reason; state any recovery action when relevant.
- A diagnostic message does not stop execution, return a failure, or notify the caller. Propagate an outcome when the caller's workflow depends on it: return `false` or a structured result for a synchronous operation, or emit a documented completion/failure signal for an asynchronous operation. The caller must inspect critical outcomes and choose whether to continue, abort, recover, or use a defined fallback.
- Logs do not replace architectural communication. Keep commands directed through explicit interfaces and events/results through the established return values or signals. Do not add script dependencies, Autoloads, or logging infrastructure merely to produce logs.

Format examples only:

```gdscript
print("WorldManager ： Map initialization started")
print("RoomSet ： Room assembly completed, count: %d" % room_count)
push_warning("DoorSet ： Some doors could not be assembled; invalid entries were skipped")
push_error("BattleManager ： Battle initialization failed: required dependency is missing")
```

## Architecture Audit and Refactoring

1. Inventory actual scenes, attached and unattached scripts, references, direct calls, signals, NodePaths, Resources, and Autoloads. For each script, record role, state ownership, dependencies, emitted/received signals, and required/optional status.
2. Classify findings as confirmed violations, suspected issues needing runtime verification, or intentional exceptions. Do not infer violations from names or node position alone.
3. Fix confirmed violations in small, testable slices. Preserve gameplay behavior and existing contracts unless explicitly approved. Verify callers, listeners, exported references, NodePaths, initialization order, and failure paths.
4. If ownership or the safe migration path is ambiguous, report evidence and options rather than inventing an architecture decision. Update `Docs/ARCHITECTURE.md` and `Docs/CODEMAP.md` only to reflect verified changes.

---

# Scene and UI Modularity

## Core Rule

- Modularity is a design goal; creating a separate `.tscn` is only one way to achieve it. Do not equate "independent responsibility" with "must be an independent scene."
- Optimize for iterative AI-assisted development and human editor finishing: modules should be understandable, inspectable, adjustable, testable, and replaceable where useful.
- Preserve the parent system as a clear composition root. Opening a system scene should make its major responsibilities and relationships easy to understand.
- Prefer the smallest structure that provides clear ownership and useful editing boundaries. Do not maximize scene count or introduce abstraction solely for visual neatness.

## When to Create a Separate Scene

Create a separate `.tscn` when one or more concrete benefits justify a scene boundary, such as:

- It has a substantial editable node hierarchy, especially UI layout or visual composition, that benefits from being opened and adjusted independently.
- It is a reusable object or visual component instantiated in multiple places.
- It has its own meaningful configuration, lifecycle, or replacement boundary.
- It needs independent scene-level testing or composition, and that benefit outweighs the added indirection.
- It is a complete functional object whose internal node structure should be encapsulated from its parent.

Keep a node inline in its owning scene by default when:

- It is a small, tightly coupled logical subsystem used only by that composition root.
- It is primarily a script-bearing logic node with little or no independently editable child hierarchy.
- Extracting it would create a scene containing only a root node without meaningful reusable composition, configuration, or editing value.
- Its dependencies and role are easier to understand as part of the parent system's SceneTree.

A module may be logically independent without being a separate scene. Nodes such as coordinators, schedulers, AI controllers, and managers can remain nodes inside a system scene when that is the clearest representation.

## UI and Editable Presentation

- Prefer editable scene composition for stable node hierarchies, UI layout, visual arrangement, and designer-tunable properties. Create nodes at runtime for genuinely dynamic or repeated content; do not build an entire UI hierarchy in code when an editable scene is more suitable.
- Give substantial or independently tuned UI modules their own scenes when this creates a useful editing boundary. A complex `CombatHUD` is a good candidate because its layout and panel hierarchy benefit from independent editing.
- Small labels, containers, spacers, and tightly coupled layout groups do not each need their own scenes. Keep internal layout structure inside the scene that owns the UI module.
- Choose a root node that matches the module's role: `Node3D` for world-space content, `Control` for UI widgets and screens, and `CanvasLayer` only when a screen-space drawing layer is needed. Do not add a `CanvasLayer` to every UI component.

## Encapsulation and Dependencies

- Encapsulate a scene's internal tree. Expose required dependencies through exported references, initialization methods or parameters, and signals where appropriate.
- Avoid brittle assumptions about exact parent paths or distant parts of the SceneTree. However, do not restructure working code solely to eliminate every NodePath; preserve simple, stable local relationships when they are appropriate.
- Keep gameplay truth in its responsible gameplay system. UI and visual scenes present state and emit player intent; they must not become duplicate authorities for gameplay data.
- Expose likely-to-be-tuned values through the Inspector, exported properties, Resources, or Themes instead of burying adjustment points in scripts.

## Refactoring Existing Scenes

- Apply these principles primarily to new work and scoped changes. Do not broadly refactor existing scenes solely to make them conform.
- Before extracting a node into a separate scene, state the concrete benefit and verify that the new scene boundary will not obscure the parent system's composition.
- Prefer extracting complex editable presentation or genuinely reusable/configurable objects before extracting small internal logic nodes.
- For structure-only tasks, preserve runtime node names, hierarchy paths, signal connections, exported references, initialization order, and visible presentation unless the user explicitly requests a behavior change.
- If the appropriate scene boundary is ambiguous or extraction may require script changes, inspect the dependencies and ask for clarification or report the trade-off instead of guessing.
- Keep scene boundaries meaningful. Do not create a scene for every node group, add wrapper scenes only for neatness, or split modules without a concrete benefit. Modularity is for editability, reuse, testing, and clear responsibility—not for maximizing scene count.

---

# GDScript Comment Style

When creating or substantially modifying `.gd` scripts:

- Use short Simplified Chinese comments.
- Keep code identifiers and Godot API names unchanged.

## Script Header

- Add only 2–3 lines describing purpose and responsibility.
- Do not write tutorials or large modification notes.

## Method Comments

Before methods:

- Add one short line describing purpose and key mechanism.

Inside methods:

- Comment only:
  - important branches;
  - state changes;
  - cross-system interactions;
  - non-obvious implementation decisions.

Do not translate code line by line.

## Maintainability

- Prefer clear naming and Inspector organization.
- Mark important modification points only when necessary.
- Do not rewrite unrelated scripts.

---

# Before Editing

Before modifying files:

- Inspect `git status`.
- Treat existing uncommitted changes as intentional.
- Inspect relevant source, scene, resource, and configuration files.
- Identify the smallest required file set.
- Check whether the requested behavior already exists elsewhere.

Do not:

- modify unrelated files;
- perform unrelated refactors;
- rename systems without requirement;
- add unnecessary dependencies;
- add Autoloads or global managers without explicit need;
- repair unrelated legacy systems.

When modifying scripts, scenes, or resources:

- Verify NodePaths.
- Verify signals.
- Verify exported references.
- Verify animation tracks.
- Verify resource references.
- Never manually invent UIDs.

---

# Godot Validation

Canonical CLI entry point:

```powershell
.\tools\godot_cli.ps1 <Godot args>
```

Use the smallest validation that proves the task:

1. Relevant source inspection.
2. Targeted Godot CLI validation.
3. Targeted scene execution or temporary probe when required.
4. Editor MCP when editor state matters.
5. Runtime MCP when live behavior must be observed.

Prefer targeted runtime checks over broad SceneTree dumps.

Temporary probes must not remain as gameplay source unless explicitly requested.

Save validation must use isolated test data and must not overwrite user saves.

---

# Godot Test Process Cleanup

For Codex-launched Godot validation processes:

- Track created process IDs.
- Ensure test processes exit after success, failure, or timeout.
- Verify related MCP ports are released.
- Never terminate the user's Godot Editor, running game session, or unrelated processes.
- If cleanup cannot be verified, report remaining process information.

---

# Repository and Git Safety

- Never discard, overwrite, revert, or normalize unrelated user changes.
- Do not create commits, branches, tags, merges, rebases, or pushes unless explicitly requested.
- Do not modify `.gitignore`, `.gitattributes`, repository tooling, or shared infrastructure unless required.

---

# Documentation Maintenance

Update only the document responsible for the changed information.

## `Docs/README.md`

Update when changing:

- current project stage;
- environment;
- blockers;
- immediate development direction;
- important verification boundaries.

## `Docs/GAME_DESIGN.md`

Update only for:

- user-approved gameplay decisions;
- scope decisions;
- design rules.

## `Docs/ARCHITECTURE.md`

Update only for:

- system ownership;
- architecture relationships;
- contracts;
- SceneTree structure;
- cross-system data flow.

## `Docs/CODEMAP.md`

Update only for:

- important file paths;
- entry points;
- navigation guidance.

Do not maintain deprecated parallel documentation.

---

# Completion Report

Report in Simplified Chinese:

- What changed.
- Files changed.
- Validation performed and results.
- Godot test-process cleanup status.
- Remaining issues.
- Unresolved decisions.
- Documentation or implementation mismatches.

Never claim more than what was actually verified.
