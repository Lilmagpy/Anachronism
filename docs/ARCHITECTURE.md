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
                          cache, budget, prompts, voice, counsel (rival rulers)   (Phase 2)
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

A pack may also point at dataset files outside itself with `external:` in `pack.yaml` (glob
patterns relative to the pack folder). The `rome` pack uses it to read
`data/rome/city/monuments*.yaml` in place (no copy, so the 3D client and the engine share one
source). External files have no `schema_version` and hold one list kind (`monuments`); the lint
reports a pattern that matches nothing.

## 7. Save format
One JSON file with sorted keys: the whole `GameState`. Tests check that save → load → save
is byte-identical, that a replay from the initial state and the action log is identical, and
that saving mid-game does not change what happens next.

## 8. Configuration and secrets (Phase 2)
`ANTHROPIC_API_KEY` from the environment or a git-ignored `.env`. Model and effort per task,
monthly spending cap and debug-log toggle in config. `.env.example` documents the keys.

## 9. The Roman Republic (R2, D-286)
In a scenario with `republic: true` (the `rome_*` scenarios) the player's state is governed by
the Republic, not one ruler. Other scenarios keep the ruler model; `punic_wars` is unchanged until
it is migrated.

**Content** (`content/schema/republic.py`; packs: `packs/rome/`). Every entry has `sources`.
- `magistracies`: an office with `eras` (by year): seats, how often it is chosen (`every`), order
  rules (`patricians_only`, `plebeians_only`, `plebeian_min/max`), `replaced_by` (consular
  tribunes for consuls, with a chance), `term_months`, and the cursus rules after the Lex Villia
  annalis (`min_age`, `interval_years`, `reelect_gap_years`, `prior_office`). `appointed` +
  `companion` make a dictator and his master of the horse; `census: true` marks the censors.
- `gentes`: order, `nomen`, praenomina and cognomina, `standing` snapshots (dignitas, auctoritas,
  wealth, clients), `stances` on Senate issues, `popular_lean_bp`.
- `people`: historical persons (birth, death, gens, `offices` by year, traits). A birth that is
  unknown is estimated from the first office.
- `fasti`: one entry per year: colleges of holders (a person id, or name + gens for a man not
  modelled; `suffect` for replacements).
- `republic_rules` (optional single file): every tunable number, and the Senate's blocs by era
  (orders until 287, nobles, then optimates and populares from 133).
`checks.py` validates the references. The sample pack covers 509-500 and 264-260 BC; the real
data in `data/rome/` is converted into this shape.

**State** (`engine/republic_state.py`, `GameState.republic`): `people` (alive or dead, with
offices, glory), `families` (a gens in play), `magistrates` (those in office now),
`record` (the game's own Fasti of senior offices), `census`, `influence`, `backing`,
`emergency_bp`, `diverged`. The frozen content copies go into `World` (`magistracies`,
`gentes`, `people`, `fasti`, `republic_rules`).

**Rules** (`engine/republic.py`), run from `end_turn` for each year the turn covers
(`run_year`), after the year advances:
1. Old terms end; senior offices go to the record. A dictator's term is six months; censors
   carry into the next year (18 months).
2. People: a death draw for each (age table in `republic_rules`), births in each gens, real
   persons come of age. In a chronicle a historical person is spared until his last recorded
   office and dies in his real year.
3. Families' dignitas fades; influence grows by an income.
4. Magistrates: in a chronicle, the Fasti seat the historical holders. A holder who is dead, or
   displaced by the player's backing, is replaced by election and `diverged` becomes true. Other
   offices are elected in rank order by weighted draw on `engine.rng` (weights: family standing,
   glory, wealth, faction share, backing). The laws of the year decide who may stand; if no one
   may, the best of the rest, then a new man.
5. A dictator is named (with a master of the horse) when war and threats raise the emergency
   level (`emergency_bp`) and the era allows it; never in a year the Fasti covers.
6. The census when censors are chosen.
`civ.ruler` is set to the senior magistrates so the old ruler fields still read; `age_and_succeed`
is skipped for the Republic. Player influence: `persuade(family, issue)` and
`back_candidate(person, office, year)` (not yet wired as logged actions); `senate_vote(issue)`
and `senate_mood()` give the Senate's will. Hooks for other systems: `award_glory`,
`kill_person`, `declare_emergency`.

**View** (`tools/republic_view.py`, key `republic` in the server's view, `null` otherwise):
`year_label`, `influence`, `emergency_bp`, `history_turned`, `magistrates[]` (office, name,
rank, months, suffect, appointed, from_fasti, master_of), `senate.factions[]` (weight and mood in
bp, per-issue leaning), `senate.votes[]`, `families[]`, `notable[]`, `census[]`, `fasti[]`.

## 10. The city of Rome (U7)
In Republic scenarios the engine also knows the city, so the 3D client (Urbs) is driven by the
game and the city is saved with it.

**Content** (`content/schema/monuments.py`): kind `monuments` is the dataset
`data/rome/city/monuments*.yaml` (extra fields are kept, so client-only fields do no harm);
kind `city_timeline` (`rome/city_timeline.yaml`) gives the turning points as data (`vowed`,
`begun`, `completed`, `fire`, `demolished`, `flood`, each with a source), because the dataset's
`events` are free text and are not parsed; `republic_rules.city` holds the games calendar
(`ludi`: festival, month, first year, venue), the funeral-games rule (`munus_*`) and the
Senate's houses. `TechNode.builds` names a great work an idea raises when adopted. All are
copied into `World` (`monuments`, `city_timeline`, `republic_rules.city`).

**State** (`engine/city_state.py`, `GameState.city`, `None` outside the Republic): `standing`
(monument id to `MonumentStatus`: `state` planned/building/standing/burnt/ruined, `years_left`,
`since`), `changed`, `anachronisms`, `events` (frozen `CityEvent`s of the turn), `funerals`.

**Rules** (`engine/city.py`): a monument's status in a year is a pure function of its
dataset dates and the timeline (`status_map`), so a new game starts at the right place;
`run_year`, called at the end of `republic.run_year`, recomputes it and emits events:
`sacrifice` (`vow`, `dedication`), `fire`, `flood` from the timeline; `games` (every festival of
the calendar whose first year has come; `munus` for a dead man who held an office of rank 5 or
more, from 264 BC); at the turn's last year `triumph` (the senior magistrate in office; for a
battle the engine marks `decisive` or an enemy capital taken, with the spoils) and anachronisms
(an adopted project with `builds`). `senate_vote(..., record=True)` adds a `senate` event.
A burnt monument keeps its state while it is rebuilt; `years_left` tells how long.

**View** (`tools/city_view.py`, key `city`, `null` outside the Republic):
`{year, senate_house, monuments: [{id, status, years_left}], changed: [id], anachronisms:
[{id, tech, name, builds, year, ahead}], events: [{kind, year, ref, monument, person, value,
other}]}`. `monuments` lists everything not still `planned`.
