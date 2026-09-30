# Anachronism — Plan

**Current phase:** Phase 0 gate — foundations done, waiting for the owner's approval and
their answer on where the project lives (D-031).
**Next action:** on approval, step 0.7 (repo location, `main` branch), then Phase 1 step 1.1.

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
- [ ] 0.7 Settle repo location (D-031); create `main`; gate

## Phase 1 — Headless engine on a test world
- [ ] 1.1 `GameRng` (seeded, serialisable) + tests
- [ ] 1.2 Content schemas + loader + linter for `core` and `testworld` packs
- [ ] 1.3 Test world: 3 fictional civs, ~20 provinces, ~40 core tech nodes
- [ ] 1.4 GameState models; save/load round-trip
- [ ] 1.5 Resources: production, upkeep, free capacity, stat history
- [ ] 1.6 Projects: funding, proportional shortfall, progress, decay
- [ ] 1.7 Strain → unrest → collapse spiral
- [ ] 1.8 Tech graph: stages, feasibility checks, goal stubs, effects + caps + stacking
- [ ] 1.9 Suspicion
- [ ] 1.10 Turn pipeline wiring; action log; replay
- [ ] 1.11 Interactive console mode (`anachronism-console`)
- [ ] 1.12 Bots + simulation tests (invariants over hundreds of turns, several seeds)
- [ ] 1.13 Gate

## Phase 2 — LLM ruling pipeline
- [ ] 2.1 Output schemas; guard (validate, clamp, reject)
- [ ] 2.2 Compact summary builder (token budget test: ≤ 500 tokens)
- [ ] 2.3 Fake provider; pipeline interpret/clarify/split/rule/flavour
- [ ] 2.4 Ruling cache; ruling records in saves; replay without calls
- [ ] 2.5 Offline provider + small hand-made library
- [ ] 2.6 Anthropic provider (config models, prompt caching, structured output, retries)
- [ ] 2.7 Budget tracking + monthly cap; debug log
- [ ] 2.8 Prompt-injection and failure-fallback test suite
- [ ] 2.9 Gate (owner needs an Anthropic API key for live testing)

## Phase 3 — Minimal Pygame front end
- [ ] 3.1 App shell, screen stack, theme, async task pump
- [ ] 3.2 Title, disclaimer, civ pick, settings (API key status, model, offline toggle)
- [ ] 3.3 Main game: province map (zoom/pan), resource bar with trends, projects panel
- [ ] 3.4 Idea input (robust text entry) with "scholars deliberating" state
- [ ] 3.5 Tech tree view with stubs
- [ ] 3.6 Save/load screens; developer overlay (tokens/cost)
- [ ] 3.7 End-to-end play in both modes; screenshots for owner; gate

## Phase 4 — Scripts, awareness, information (headless)
- [ ] Scripts with preconditions; awareness states; news propagation with garbling;
      script dependency graph; relations with memory; intelligence reports; tech leakage; gate

## Phase 5 — East Asia pilot
- [ ] Finalise schemas; review workflow (`drafts/` → `packs/`); choose flagship scenario;
      author 8–10 civs; timeline UI; CJK fonts; balance pass; gate

## Phase 6 — Europe (schema stress test) + steppe connector; gate
## Phase 7 — Depth: events, rival rulers via LLM, chronicle, advisors, victory, suspicion tuning; gate
## Phase 8+ — More regions, first contact, tiered victory, art/sound, packaging
