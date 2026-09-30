# Decision Log

Every significant decision, why it was made, and who made it.
**Status:** `LOCKED` = from the owner's brief; `OWNER` = the owner answered directly;
`DELEGATED` = the owner asked Claude to decide ("figure it out"); the owner may overturn any
`DELEGATED` decision at any time. Newest entries at the bottom.

---

## D-001 Working title and package name — DELEGATED (2026-09-30)
"Anachronism" is the working title from the brief. An *anachronism* is something out of its
proper time — exactly what the player introduces. The Python package is `anachronism`;
it lives at the root of the `Lilmagpy` repository (no nested project folder). Renaming later
is a one-line search-and-replace, so this is cheap to change.

## D-002 Git workflow — DELEGATED
All work goes on the session branch assigned by the environment (`claude/new-session-8vxe44`
for the first session). The repo has no `main` branch yet. At the Phase 0 gate Claude will
propose creating `main` from the approved state; after that each phase is a pull request into
`main` that the owner approves by merging. Rationale: gives a concrete "approve = merge" step
without the owner needing to know git.

## D-003 Platform, Python and tooling — DELEGATED
- Owner is on **macOS** (OWNER). Target Python **3.12**, installed and managed by **uv**
  (uv downloads the right Python itself, so the owner's system Python doesn't matter).
- One command setup on Mac: install uv, then `uv run anachronism` (see README).
- Tooling: `pyproject.toml`, ruff (lint + format), mypy (strict on `engine/` and `llm/`), pytest.

## D-004 How the owner sees the game without running it — DELEGATED
Verified 2026-09-30: pygame-ce renders headlessly in the cloud container
(`SDL_VIDEODRIVER=dummy`) and can save screenshots. Claude will attach screenshots at each UI
milestone, so the owner can review visuals from the Claude app; running locally is optional.

## D-005 Dependencies — DELEGATED
Runtime: `pydantic` (validation), `pyyaml` (content), `pygame-ce` (window/graphics),
`pygame_gui` (widgets: text entry, scroll panels; built on pygame-ce), `anthropic` (LLM, Phase 2).
Dev: `pytest`, `ruff`, `mypy`. All test-installed successfully 2026-09-30
(pygame-ce 2.5.8, pygame_gui 0.6.14, pydantic 2.13, anthropic 1.9).
Why pygame-ce over pygame: same API, actively maintained, better Unicode/IME text input
(needed for Chinese/Korean/Japanese names). Brief decision #1 ("Pygame") is honoured.

## D-006 Content formats — DELEGATED
Hand-authored content: **YAML** (comments allowed, readable). Saves, caches, generated data:
**JSON**. Every file carries `schema_version`. Validation by Pydantic models.

## D-007 Resource model — DELEGATED (see DESIGN §4)
Stockpiles: food, materials, wealth, knowledge. Flow: labour (per turn, cannot be stored).
Civ-wide stats: population, literacy, unrest, suspicion, legitimacy, military strength,
trade income. Added **wealth** (treasury) because trade income needs somewhere to go and
armies/bureaucracies are paid in it; merged "stability/legitimacy" into one stat
(**legitimacy**) with **unrest** as its counterweight, to avoid two near-identical numbers.

## D-008 Map representation — DELEGATED
**Province graph**: irregular provinces with adjacency lists; terrain, resources and
ownership stored per province. ~20 provinces for the Phase 1 test world, ~100–140 for East Asia.
Rejected hex (poor fit for historical borders) and tile grid (most work, least historical).

## D-009 Map and data sources / licences — DELEGATED
Checked 2026-09-30: Seshat public data is **CC BY-NC-SA (non-commercial only)**;
aourednik/historical-basemaps is **GPL-3.0**; CShapes covers only 1886 onward.
Decision: keep the game free to be released under any licence later, so **no GPL or NC data
is copied into shipped files**. These sources may be *consulted* as references (facts are not
copyrightable; datasets and drawings are). Province shapes are drawn by us. Wikidata (CC0) may
be imported directly. Every shipped fact records its reference in `sources`.

## D-010 Turn length — DELEGATED
Years per turn set per scenario by an era table, default: ancient 20, classical 15,
medieval 10, early modern 5. The engine allows the length to shrink mid-game when the
player's civ crosses a technology threshold (tunable; off by default until balanced).

## D-011 Dynasties and player continuity — DELEGATED (resolves brief #13 / open question #7)
Each dynasty/polity is a **separate data entry** (Tang, Song, Ming…) with `lineage` links
(predecessor/successor, cultural family). The player's guiding hand attaches to a **lineage**,
not a single polity. If the player's polity falls, the player chooses which successor polity
to continue with (default: the direct lineage successor). The game ends only if the lineage
has no surviving successor. Rationale: historical accuracy in data plus a continuous game.

## D-012 Imperfect knowledge (insight) — DELEGATED
No separate insight-points pool. Instead every advancement passes through **adoption stages**:
`concept → experimenting → adopted → widespread`. Experimentation costs resources, takes time
and can fail or partially succeed. This implements "the player remembers concepts, not details".

## D-013 Visibility of rival scripts — DELEGATED
**Intelligence reports that can be wrong.** Quality depends on relations, trade contact,
spies and distance. Ties directly into the information system.

## D-014 Combat — DELEGATED
Abstract strength comparison (troops × tech × terrain × supply × morale, plus seeded
randomness). No tactical battles unless the owner asks later.

## D-015 Victory measurement — DELEGATED (proposal, tuned in Phase 7)
Tiers: region → hemisphere → world. Per tier, any one path wins:
- Military: control or tributary overlordship of ≥ 60% of the tier's population.
- Economic: ≥ 50% of the tier's trade value flows through routes you own or tax.
- Cultural: ≥ 50% of the tier's population follows your religion, script or legal code
  (tracked per province as culture-layer shares).

## D-016 LLM models and cost — DELEGATED
Model names come from config, never code. Defaults (checked against current Anthropic docs
2026-09-30): `claude-opus-5-5` ($4 / $20 per million tokens in/out) for all tasks, with
effort `low` for interpretation/clarification and `medium` for rulings. Structured output
via the SDK's `messages.parse()` with Pydantic schemas; prompt caching on the stable prefix.
A cheaper model can be set per task in config (e.g. `claude-haiku-4-5` for interpretation) —
switching is the owner's choice. Estimated cost ~$0.02–0.05 per idea; a **monthly spend cap**
setting (default $10) automatically drops to offline mode when reached.

## D-017 Art direction and resolution — DELEGATED
Placeholder: "ink and parchment" palette (warm paper background, ink-dark lines, muted
province fills, one accent colour). Minimum window 1280×800, resizable, layouts use
proportional anchors. Retina (HiDPI) handled by scaling.

## D-018 Names and scripts — DELEGATED
English names primary; native-script names stored in data and shown as a subtitle
(e.g. "Goguryeo 高句麗"). Font: Noto Sans/Serif CJK subset bundled in Phase 5.

## D-019 Sharing tech trees — DELEGATED
Saves are self-contained JSON, so sharing a save shares a run. A dedicated "export tech tree"
feature is deferred to Phase 8+.

## D-020 Tech backbone and engine-computed costs — DELEGATED
A curated **core tech graph** (a few hundred generic advancements with structured
requirements) ships in `packs/core`. The LLM's first job is to **map** the player's idea onto
an existing node; it creates a new node only when nothing matches. The LLM never outputs
numbers directly for costs: it outputs a *complexity tier* and requirement tags, and the
engine computes cost/duration/effect magnitudes by formula. Rationale: consistency between
rulings, strong caching, and immunity to "make it free" manipulation.

## D-021 Replay safety — DELEGATED
Every LLM ruling is stored in the action log. Replaying a save re-applies recorded rulings
and never calls the model again. Seed + action log ⇒ identical game.

## D-022 Suspicion target — DELEGATED
Suspicion attaches to the **ruling house** (the guiding hand is invisible). It can shift
between "inspired", "witchcraft" and "fraud" framings based on events and religion.

## D-023 Phase 1 playability and balance bots — DELEGATED
Phase 1 includes an interactive **text console mode** (not just a printout) and scripted
**bot players** (growth, military rush, build-everything) used by headless balance tests.

## D-024 Rivals learn inventions — DELEGATED
When news of an advancement reaches a rival, that rival may begin its own `experimenting`
stage. Secrecy therefore protects a real advantage.

## D-025 Scenario authoring — DELEGATED
Layered timeline data (polity exists X–Y, border changes in year Z, relation changes in year W)
from which snapshots are assembled, plus per-scenario override files. East Asia will be built
one scenario at a time, starting with one flagship moment (chosen in Phase 5).
