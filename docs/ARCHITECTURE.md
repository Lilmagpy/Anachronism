# Anachronism — Architecture

## 1. Layers and the one rule that matters
```
ui/  (pygame-ce, pygame_gui)      ── view/controller only
  │  calls
  ▼
app services (session, commands)  ── thin façade: load scenario, submit idea, end turn
  │                     │
  ▼                     ▼
engine/ (pure Python)   llm/ (network, sandboxed)
  ▲                     │  returns validated Proposal objects
  └──── content/ (YAML packs, validated) ────┘
```
- `engine/` imports **nothing** from `ui/`, `llm/`, pygame or the network. It runs headless.
- `llm/` never mutates state. It returns validated `Proposal` objects; the engine decides.
- `ui/` never computes game rules; it renders state and sends commands.
- Enforced by an import-boundary test (`tests/test_architecture.py`).

## 2. Module layout
```
pyproject.toml  uv.lock  .python-version  CLAUDE.md  .env.example
scripts/check.sh          every automated check; CI runs the same script
.github/workflows/ci.yml  CI on Ubuntu + macOS
.claude/                  SessionStart hook for cloud sessions
docs/                     BRIEF, DESIGN, ARCHITECTURE, PLAN, DECISIONS, CONTENT_GUIDE,
                          GETTING_STARTED (Mac setup; becomes README once D-031 is settled)
src/anachronism/
  __main__.py             entry point: `python -m anachronism` / `anachronism`
  config.py               settings from env + git-ignored local config
  engine/
    state.py              GameState, Civ, Province, Project, Army (pydantic models)
    rng.py                GameRng: seeded, serialisable; the ONLY source of randomness
    actions.py            player/AI Action types; the action log
    turn.py               turn pipeline (ordered phases, §4)
    resources.py          production, upkeep, strain
    projects.py           project funding and progress
    tech_graph.py         nodes, stages, prerequisites, stubs, feasibility checks
    effects.py            effect menu, caps, stacking
    suspicion.py
    map.py                province graph queries
    combat.py
    scripts.py            rival scripts, preconditions, awareness states  (Phase 4)
    information.py        news items and propagation                     (Phase 4)
    relations.py          pairwise relations and memory                  (Phase 4)
    events.py
    victory.py
    save.py               serialise/deserialise, replay from seed + log
    summary.py            compact state summary (pure; used by llm/)
  llm/
    provider.py           Provider protocol: interpret(), rule(), flavour()
    fake.py               deterministic fake provider for tests
    offline.py            serves the curated library
    anthropic_provider.py real API (config-selected models, retries, timeouts)
    schemas.py            pydantic output schemas
    guard.py              validation, clamping, injection defence
    pipeline.py           interpret → clarify → split → rule → flavour
    cache.py              ruling cache (idea → node mapping; node rulings)
    budget.py             token/cost accounting and monthly cap
    prompts/*.md          versioned prompt templates
  content/
    schema/               pydantic models for pack files
    loader.py             load + validate packs, resolve cross-references
    packs/core/           effect menu data, generic tech backbone, resource & terrain types
    packs/testworld/      fictional 3-civ world (Phase 1)
    packs/east_asia/      pilot (Phase 5)
    library/              offline idea library
  ui/
    app.py                main loop, screen stack, async task pump
    screens/  widgets/  theme.py  assets/
  tools/
    lint_content.py       content linter (CLI)
    simulate.py           headless N-turn runner with bots
    console.py            interactive text play mode
    gen_library.py        LLM draft generator → drafts/ (Phase 5)
drafts/                   unreviewed generated content (never loaded by the game)
tests/
```

## 3. Core data (sketch; pydantic models, all JSON-serialisable)
- `GameState`: `schema_version`, `seed`, `rng_state`, `turn`, `year`, `scenario_id`,
  `player_lineage`, `civs{}`, `provinces{}`, `tech_graph`, `projects{}`, `armies{}`,
  `relations{}`, `news[]`, `action_log[]`, `ruling_records[]`, `history` (stat series).
- `TechNode`: `id`, `name`, `category`, `tags[]`, `era`, `complexity` (1–5),
  `prerequisites[]`, `requirements{materials, skills, infrastructure, acceptance}`,
  `effects[]`, `provenance` (`library` / `llm` / `player_idea`), `flavour`, `is_stub`.
- `CivTechState`: per civ per node: `stage`, `progress`, `spread` (provinces).
- `Project`: `id`, `civ`, `node_id`, `stage_target`, `cost_per_turn{}`, `turns_left`,
  `funding_history`.
- `RulingRecord`: the normalised idea, the validated proposal, the engine's final applied
  numbers, model name, prompt version. Replay reads these instead of calling the model (D-021).

## 4. Turn pipeline (fixed order, each phase a pure function `state → state` + log)
1. Apply queued player actions.
2. Production (food, labour, materials, wealth, knowledge).
3. Upkeep (population food, army wages, building upkeep).
4. Project funding (proportional under shortfall) and progress rolls.
5. Strain → unrest → legitimacy updates; starvation.
6. Adoption spread across provinces.
7. Suspicion update and framing drift.
8. Information propagation (Phase 4).
9. Rival scripts: evaluate preconditions, fire intentions, awareness transitions (Phase 4).
10. Events.
11. Movement and combat.
12. Population growth.
13. Victory check; history snapshot; advance year.
Determinism: phases iterate civs/provinces in sorted-id order; RNG draws only via `GameRng`.

## 5. LLM boundary
`Provider` protocol with three implementations (fake, offline, anthropic). Pipeline:
`summary.build(state, idea)` → provider → `schemas.parse` → `guard.validate_and_clamp` →
engine `apply_ruling`. Failure path: retry once with the validation error → fall back to
offline provider → if nothing matches, a polite in-world "the scholars could not agree".
Player text is wrapped in delimited data blocks; the system prompt is static and cached.
All calls run on a worker thread; the UI polls a result queue (never blocks the frame loop).

## 6. Content packs
Each pack: `pack.yaml` (id, schema_version, depends_on), plus `civs/`, `provinces/`,
`techs/`, `scripts/`, `relations/`, `timeline/`, `scenarios/`. Loader validates each file,
then resolves cross-references across packs. The linter runs the same loader and reports all
errors with file + field path. Tests run the linter on every pack.

## 7. Save format
Single JSON file: full `GameState` plus `engine_version`. Round-trip test: save → load →
save produces byte-identical output. Replay test: seed + action log + ruling records rebuild
an identical state.

## 8. Configuration and secrets
`ANTHROPIC_API_KEY` from environment or git-ignored `config.local.toml`. Model per task,
effort per task, monthly cap, debug-log toggle — all in config. `.env.example` documents keys.
