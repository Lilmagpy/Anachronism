# Anachronism — Architecture

Status: engine, content and tools are built (Phase 1). Later parts are marked with their phase.

## 1. Layers and the one rule that matters
```
ui/  (pygame-ce, pygame_gui)      ── view/controller only                        (Phase 3)
tools/ (console, sim, lint)       ── command-line front ends
  │  call
  ▼
engine/game.py                    ── public entry points: new_game, apply_action, end_turn, replay
  │                     │
  ▼                     ▼
engine/ (pure Python)   llm/ (network, sandboxed)                                (Phase 2)
  ▲                     │  returns validated proposals
  └──── content/ (YAML packs, validated) ────┘
```
- `engine/` imports **nothing** from `ui/`, `llm/`, `tools/`, pygame, the network, clocks,
  threads or `random`. It runs headless and deterministically.
- `content/` imports nothing from the engine, LLM or UI layers; the engine uses its models.
- `llm/` never mutates state. It returns validated proposals; the engine decides.
- `ui/` and `tools/` never compute game rules; they render state and submit actions.
- Enforced by `tests/test_architecture.py` (reads the source) and ruff's ban on `random`.

## 2. Module layout
```
pyproject.toml  uv.lock  .python-version  CLAUDE.md  README.md  .env.example
scripts/check.sh          every automated check; CI runs the same script
.github/workflows/ci.yml  CI: Linux on every push, macOS on pull requests and main
.claude/                  SessionStart hook for cloud sessions
docs/                     BRIEF, DESIGN, ARCHITECTURE, PLAN, DECISIONS, CONTENT_GUIDE,
                          GETTING_STARTED; plans/phase-N.md for each phase's detailed design
src/anachronism/
  __main__.py             `uv run anachronism`: the text console until Phase 3
  engine/
    game.py               public API: new_game, apply_action, end_turn, replay
    state.py              GameState, World, CivState, ProvinceState, Project, Snapshot, Event
    actions.py            action types (propose, start, pause, resume, cancel, priority), log
    commands.py           validating and applying actions
    setup.py              building the starting state from content + scenario + seed
    turn.py               the turn pipeline (§4)
    economy.py            workforce, project funding, diversion, production, upkeep, famine
    projects.py           progress, luck, stalling, completion
    tech.py               feasibility, goals, stubs, adoption, discoveries, spread
    effects.py            combining effects: era caps, spread, diminishing stacking
    society.py            strain, unrest, legitimacy, riots, revolts, collapse
    suspicion.py          suspicion and framings
    population.py         logistic growth toward capacity
    reports.py            read-only summaries: free capacity, snapshots
    timeflow.py           eras; scaling per-decade rules to the turn length
    events.py             collecting a turn's events
    bots.py               automated players for rivals and balance tests
    rng.py                PCG32: the ONLY source of randomness
    fixed.py              integer basis-point maths
    save.py               canonical JSON save/load
    information.py, scripts.py, relations.py                              (Phase 4)
    combat.py, victory.py, summary.py (compact LLM state summary)         (Phases 2-7)
  content/
    schema/               pydantic models: tech, world, rules, civ, scenario, pack kinds
    loader.py             discover packs, parse YAML (duplicate keys rejected), validate
    checks.py             cross-references: ids, cycles, borders, scenario consistency
    registry.py, issues.py
    packs/core/           rules (every tunable number), eras, effect caps, terrain,
                          resources, generic tech backbone (55 nodes)
    packs/testworld/      fictional 3-civ world and the Bronze Dawn scenario
    packs/east_asia/      pilot                                                (Phase 5)
  llm/                    provider, fake, offline, anthropic, schemas, guard, pipeline,
                          cache, budget, prompts, voice (rival speech)           (Phase 2)
  ui/                     app, screens, widgets, theme, assets                  (Phase 3)
  tools/
    console.py            `anachronism-console`: play in a terminal
    simulate.py           `anachronism-sim`: bot-played games for balance work
    lint_content.py       `anachronism-lint`: check every pack
tests/                    per-module tests, long simulations, console sessions
```

## 3. Core data (pydantic models, all JSON-serialisable, integers only — D-035)
- `GameState`: `schema_version`, `engine_version`, `seed`, `rng`, `turn`, `year`,
  `player_civ`, `world`, `tech_nodes{}`, `provinces{}`, `civs{}`, `action_log[]`, `events[]`.
- `World` (frozen, shared between copies): scenario id and name, content digest, turn length,
  rules, eras, effect caps, terrain, resources, province geography.
- `TechNode` (frozen): `id, name, category, year, complexity, visibility, prerequisites,
  requires{materials, literacy_bp, widespread}, resistance[], effects[], flavour, provenance,
  stub, sources`.
- `CivState`: identity, capital, influence per social group, `stockpiles`, `stats`,
  `framing`, `tech{node: stage, spread, goal}`, `projects{node: progress, priority, …}`,
  `unlocked[]`, `history[Snapshot]`, `collapsed`.
- `ProvinceState`: `owner`, `population`, current resource access.
- `LoggedAction`: turn, action, whether it was accepted, and the message.
- Phase 2 adds `RulingRecord` (idea, validated proposal, applied numbers, model, prompt
  version); replays read these instead of calling the model (D-021).

## 4. Turn pipeline (`engine/turn.py`)
Actions are applied as they are taken (`apply_action`), then `end_turn` runs, for each
civilisation in id order:
1. Combine effects (caps, spread, stacking).
2. Economy: workforce → project funding by priority → diversion → production → upkeep →
   granary and spoilage → famine deaths.
3. Projects: progress, two luck draws each, stalling and decay, adoption (discoveries,
   opposition, suspicion).
4. Society: strain toward its target, unrest, legitimacy, riots, revolts, collapse.
5. Spread of adopted advancements.
6. Suspicion: fading, framings and their consequences.
7. Literacy: teaching minus attrition.
Then population growth for every province, turn and year advance, and a snapshot per
civilisation. Later phases insert information spread, rival scripts, events, movement,
combat and the victory check (DESIGN §3).
`end_turn` deep-copies the state first, so it is pure from the outside; frozen content is
shared rather than copied.

## 5. LLM boundary (Phase 2)
`Provider` protocol with three implementations (fake, offline, anthropic). Pipeline:
`summary.build(state, idea)` → provider → `schemas.parse` → `guard.validate_and_clamp` →
engine applies the ruling. Failure path: retry once with the validation error → offline
provider → an in-world "the scholars could not agree". Player text is wrapped as data; the
system prompt is static and cached. Calls run off the UI thread.

## 6. Content packs
A pack is a folder with `pack.yaml` (id, name, version, depends_on) and any number of YAML
files, each holding `schema_version` and exactly one kind (D-036). Packs load in dependency
order; list items are validated one by one; cross-references are checked afterwards; every
problem is reported with its file and location. See CONTENT_GUIDE.md.

## 7. Save format
One JSON file with sorted keys: the whole `GameState`. Tests check that save → load → save
is byte-identical, that a replay from the initial state and the action log is identical, and
that saving mid-game does not change what happens next.

## 8. Configuration and secrets (Phase 2)
`ANTHROPIC_API_KEY` from the environment or a git-ignored `.env`. Model and effort per task,
monthly spending cap and debug-log toggle in config. `.env.example` documents the keys.
