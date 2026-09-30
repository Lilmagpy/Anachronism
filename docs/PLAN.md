# Anachronism — Plan

**Current phase:** Phase 2 — 3D world (Godot) on the Phase 1 engine (branch `claude/phase-2-3d`).
**Next action:** step 2.14 — new regions and moments (Mediterranean first).

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
- [x] 2.1 Engine bridge: JSON messages over stdin/stdout (`anachronism-server`), tested
- [x] 2.2 Map layout in content: province positions and sea zones; linted
- [x] 2.2b Real Earth map (D-053): measured elevation, NASA satellite colour, Natural Earth
      rivers; East Asia first. The fictional test world stays only for tests (`--map=testworld`)
- [x] 2.2c Real historical scenario: the Warring States, 350 BC, playing Qin (D-054..D-056):
      18 states and peoples, 53 provinces, 10 seas, borders grown over real terrain
- [x] 2.3 Godot client: 3D terrain, water, sky, Rise of Kingdoms-style camera (pan, zoom)
- [x] 2.4 Borders coloured by owner, province labels, selection and hover
- [x] 2.5 Game UI: top bar with trends, ideas and details, projects, end turn, events
- [x] 2.6 Settlements scaled by population: walled capitals with palace halls, towns,
      villages and fields on the flattest land (D-058); hand-made models can come later
- [x] 2.7 Screenshot pipeline in the cloud; CI builds a downloadable Mac app (D-057)
- [x] 2.8a Owner played the Mac app (2026-09-30): it works, but the look and feel fall short
      of what the owner wants (D-059). Phase 2 continues with 2.9–2.16 before its gate.

### Phase 2, part two — look, characters and choice (D-059..D-061)
- [x] 2.9 Title screen and civilisation picker: choose a civilisation and a starting
      moment (portrait, description, bonus, Confirm), like Rise of Kingdoms
- [x] 2.10 Engine: list scenarios and playable civs; start as any civ in a scenario
- [x] 2.11 Bright cartoon map over the real geography: painted biomes (classified from the
      satellite image), toon light bands, sea painted by depth with coastal foam, cartoon
      forests; cream-and-gold game screens. Still to come: animated water, clouds
- [ ] 2.11b Animated water, drifting clouds, better cartoon mountains
- [x] 2.12 Characters: rulers, advisers and rivals pop up and speak (scripted lines as
      content data in core/dialogue.yaml and speakers.yaml; placeholder portraits, D-060)
- [ ] 2.13 Cartoon cities from CC0 art packs; a close-up capital view where adopted ideas
      appear as buildings
- [ ] 2.14 New regions and moments (D-061): the "europe" map (Ireland to Persia, Sahara to
      Scandinavia) is built; [x] Rome and Carthage, 264 BC (19 states, 70 provinces);
      [ ] Egypt / Near East; [ ] Medieval Europe; [ ] more East Asian starts (Korea, Japan)
- [ ] 2.15 Polish: tooltips, charts over time, save/load and settings menus, sound
- [ ] 2.16 Gate: owner plays the new build on their Mac and merges the phase PR

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
