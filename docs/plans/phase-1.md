# Phase 1 plan: headless engine on a test world

Detailed design for PLAN.md Phase 1. The owner approved starting Phase 1 (2026-09-30) and
delegated the technical design; choices are logged in DECISIONS.md (D-035 onwards).

## Goals
A deterministic, headless engine where a civilisation can propose ideas, fund multi-turn
projects, adopt advancements, grow, overextend and collapse; savable, replayable, simulated for
hundreds of turns by bots; playable in a text console. No LLM, no pygame.

## Ground rules
- **Integers only** in state and engine maths (D-035). Rates in basis points: `10_000 bp = 100%`.
  0–100 stats (literacy, unrest, legitimacy, suspicion, strain) are stored as bp.
  Rounding goes through `engine/fixed.py`, so results are identical on every OS.
- **One RNG**: PCG32 in `engine/rng.py` (D-030); its state lives in `GameState.rng`.
- **Pure from outside**: `apply_action(state, action)` and `end_turn(state)` return new states;
  internally they deep-copy and mutate. Frozen content models are shared, not copied.
- **Self-contained saves**: `GameState` embeds the world definition (rules, terrain, eras,
  province geography, tech nodes), so saves survive content changes and replay identically.
- **Turn length**: economic flows are defined per decade and scaled by `years_per_turn`, so
  scenarios with 5- or 20-year turns keep the same balance.

## Content (YAML, validated by pydantic, `extra="forbid"` catches typos)
- `packs/core/`: `rules.yaml` (every tunable number), `eras.yaml`, `effects.yaml` (caps per
  era), `terrain.yaml`, `resources.yaml`, `techs/*.yaml` (generic backbone, ~40 nodes now).
- `packs/testworld/`: `provinces.yaml` (geography: terrain, river, coast, resources,
  neighbours, capacity), `civs.yaml` (3 fictional civs), `scenarios/*.yaml` (start year,
  turn length, ownership, starting populations, player civ).
- Loader collects **all** errors with file + field path; cross-reference checks: unknown ids,
  duplicate ids, prerequisite cycles, asymmetric adjacency, ownership of unknown provinces.
- `anachronism-lint` runs the loader over every pack; tests run it too.

## Tech nodes
Fields: `id, name, category, year` (approximate first historical appearance, drives
suspicion), `complexity` 1–5 (drives cost and duration), `visibility` 1–3, `prerequisites`,
`requires {materials, literacy_bp, widespread}`, `resistance` (clergy / nobility / guilds,
level 1–3), `effects` (fixed menu, DESIGN §9), `flavour`, `provenance`, `stub`, `sources`.
- Hard blockers: prerequisites not adopted, materials not accessible in an owned province,
  `widespread` infrastructure not widespread, node is a stub. Soft: literacy below
  `literacy_bp` raises the setback chance.
- Stages: `concept → experimenting → adopted → widespread`. Proposing makes a concept (free)
  and marks unknown missing prerequisites as **goals** (visible, free). Stubs (Phase 2's
  LLM placeholders) are supported now: visible, but cannot be started until ruled.
- Effects apply from `adopted`, scaled by spread (0–100%), capped per **current** era, and
  stacked with diminishing returns: strongest ×100%, next ×80%, then ×64%, …

## Economy (per civ, per turn, in this order)
1. **Workforce** = population/1000 × labour efficiency (effects, minus the unrest penalty).
   A share (default 20%) is **surplus**: projects can use it without hurting production.
2. **Project funding**: by priority tier, proportional within a tier. A project needs all its
   inputs (labour from the workforce; materials, wealth, knowledge from start-of-turn
   stockpiles), so its funding is its scarcest input's fraction.
3. **Diversion**: labour used beyond the surplus is taken from fields and workshops, cutting
   production proportionally (floor 30%).
4. **Production** per province from terrain yields, map resources, literacy and effects.
5. **Upkeep**: food eaten by the population, wealth for administration; granary cap and
   spoilage.
6. **Starvation** if food runs out: deaths, unrest.
Free capacity (shown to the player) = surplus labour and stockpile headroom minus commitments.

## Projects
Cost per turn and duration come from complexity (engine formulas, never from the LLM): labour
6·c(c+1)/2, materials 4c (×2 for metallurgy/construction/military), knowledge 5c, wealth 3c;
duration 1/2/3/4/6 decades. Progress each turn = funding × rate; seeded rolls for setbacks
(raised by literacy shortfall) and occasional breakthroughs. Funding under 50% for 3 turns →
progress decays. Completion → adopted with 20% spread; spread grows each turn (literacy and
mobility help); widespread at 80%.

## Society
- **Strain** rises with project shortfall and labour diversion, decays when relieved.
- **Unrest** rises with strain, famine, resistance to new ideas and a "witchcraft" framing;
  recovers slowly, faster with legitimacy. High unrest cuts labour efficiency (the spiral).
- **Riots** above 60% unrest (chance per turn): lose materials and wealth, legitimacy falls.
  **Revolt** above 80%: a non-capital province breaks away. Losing half the provinces logs a
  collapse.
- **Legitimacy** drifts to a baseline; hurt by famine, riots and a "fraud" framing; helped by
  "inspired" framing and effects.
- **Suspicion**: on adoption, + gap years × rate × visibility (cap 15 points); decays per turn.
  Above a threshold the framing drifts to inspired / witchcraft / fraud, weighted by legitimacy,
  clergy and nobility influence.
- **Population**: logistic growth toward terrain capacity (+ population_cap effects).

## Turn, actions, saves
Actions (logged with turn number): propose, start, pause, resume, cancel, set priority.
`end_turn` runs the pipeline (ARCHITECTURE §4, Phase 1 subset) and returns a report of events.
Save = canonical JSON (sorted keys). Replay = initial state + logged actions → identical JSON.

## Tools
- `anachronism-console`: play the player civ in text (status with trend arrows, ideas with
  feasibility, start/pause/cancel, end turn, save/load).
- `anachronism-sim`: headless runs with bots, printing summaries (balance work).
- Bots: idle, growth (respects free capacity), military, greedy (starts everything).

## Tests
Unit tests per module; content lint on all packs; save/load byte-identical; replay identical;
simulation invariants (no negative stocks or populations, stats in range, references valid)
over 150+ turns × several seeds × every bot; balance tests: greedy collapses, growth and idle
stay stable.

## Out of scope (later phases)
Armies, combat, diplomacy, information spread, rival scripts (Phase 4); events beyond riots,
revolts and famine (Phase 7); per-province adoption; buildings and units (unlock flags only).
