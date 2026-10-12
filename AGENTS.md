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
- Generic infrastructure should remain separate from gameplay-specific logic.
- Verify only as deeply as required to prove the task.
- Do not claim runtime behavior from static inspection alone.

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