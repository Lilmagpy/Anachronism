# Anachronism — Plan

**Current phase:** Phase 2 — 3D world (Godot) on the Phase 1 engine (branch `claude/phase-2-3d`).
**Next action:** step 2.1.

Each phase ends at a **gate**: Claude stops, summarises, shows how to run it, lists known
problems, and waits for approval (D-002: approval = merging the phase PR).

## Phase 0 — Foundations
- [x] 0.1 Read brief, ask questions, record decisions (DECISIONS.md), draft docs
- [x] 0.2 Owner approves DESIGN.md, ARCHITECTURE.md, PLAN.md (approved 2026-09-30)
- [x] 0.3 `pyproject.toml` (uv, Python 3.12), ruff, mypy, pytest config; package skeleton;
      `uv run anachronism` launcher
- [x] 0.4 Mac setup guide (`docs/GETTING_STARTED.md`, see D-031); `.env.example`
- [x] 0.5 Guard-rail tests (layers, network, secrets, docs); `scripts/check.sh`;
      GitHub Actions CI on Ubuntu + macOS
- [x] 0.6 SessionStart hook so cloud sessions can run tests and linters
- [x] 0.7 Repo moved to `Lilmagpy/Anachronism` with `main` (D-033); gate passed 2026-09-30

## Phase 1 — Headless engine on a test world (design: plans/phase-1.md)
- [x] 1.1 `GameRng` (PCG32, seeded, serialisable) + integer maths helpers
- [x] 1.2 Content schemas + loader + linter for `core` and `testworld` packs
- [x] 1.3 Test world: 3 fictional civs, 20 provinces, 55 core tech nodes
- [x] 1.4 GameState models; new game; save/load round-trip
- [x] 1.5 Economy: workforce, surplus, production, upkeep, granary, history snapshots
- [x] 1.6 Projects: priority funding, scarcest input, progress, luck, stalling, decay
- [x] 1.7 Strain → unrest → riots → revolts → collapse spiral
- [x] 1.8 Tech graph: stages, feasibility, goals, stubs, effects with caps and stacking
- [x] 1.9 Suspicion and framings
- [x] 1.10 Turn pipeline; action log; replay
- [x] 1.11 Interactive console (`uv run anachronism`)
- [x] 1.12 Bots, simulation tool, long-game invariant and balance tests
- [x] 1.13 Gate: approved and merged by the owner (2026-09-30)

## Phase 2 — 3D world (design: plans/phase-2.md; replaces the Pygame front end, D-047)
- [ ] 2.1 Engine bridge: JSON messages over stdin/stdout (`anachronism-server`), tested
- [ ] 2.2 Map layout in content: province positions, heights, rivers, coasts; linted
- [ ] 2.3 Godot client: 3D terrain from the map, water, sky, camera (pan, zoom, orbit)
- [ ] 2.4 Borders coloured by owner, province labels, selection and hover
- [ ] 2.5 Game UI: top bar with trends, ideas and details, projects, end turn, events
- [ ] 2.6 Settlements and scenery scaled by population (openly licensed models)
- [ ] 2.7 Screenshot pipeline in the cloud; CI builds a downloadable Mac app
- [ ] 2.8 Gate: owner plays the 3D game on their Mac

## Phase 3 — LLM ruling pipeline (moved after the 3D world, D-049)
- [ ] 3.1 Output schemas; guard (validate, clamp, reject)
- [ ] 3.2 Compact summary builder (token budget test: ≤ 500 tokens)
- [ ] 3.3 Fake provider; pipeline interpret/clarify/split/rule/flavour
- [ ] 3.4 Ruling cache; ruling records in saves; replay without calls
- [ ] 3.5 Offline provider + small hand-made library
- [ ] 3.6 Anthropic provider (config models, prompt caching, structured output, retries)
- [ ] 3.7 Budget tracking + monthly cap; debug log
- [ ] 3.8 Prompt-injection and failure-fallback tests; free-text idea box in the 3D UI
- [ ] 3.9 Gate (owner needs an Anthropic API key for live testing)

## Phase 4 — Scripts, awareness, information (headless)
- [ ] Scripts with preconditions; awareness states; news propagation with garbling;
      script dependency graph; relations with memory; intelligence reports; tech leakage; gate

## Phase 5 — East Asia pilot
- [ ] Finalise schemas; review workflow (`drafts/` → `packs/`); choose flagship scenario;
      author 8–10 civs; timeline UI; CJK fonts; balance pass; gate

## Phase 6 — Europe (schema stress test) + steppe connector; gate
## Phase 7 — Depth: events, rival rulers via LLM, chronicle, advisors, victory, suspicion tuning; gate
## Phase 8+ — More regions, first contact, tiered victory, art/sound, packaging
