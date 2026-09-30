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

## D-026 Build, lock and Python pin — DELEGATED (Phase 0)
`uv_build` backend, `.python-version` = 3.12, `uv.lock` committed. The lock is written by the
cloud image's uv (0.8.17); verified 2026-09-30 that the newest uv (0.12.21, what the Mac and
CI install) accepts it with `--locked` and does not rewrite it, so the owner's checkout never
shows a modified lockfile.

## D-027 Dependencies arrive when first used — DELEGATED (refines D-005)
Now: `pydantic`, `pyyaml`; dev: `pytest`, `ruff`, `mypy`, `types-pyyaml`.
`anthropic` is added in Phase 2 and `pygame-ce` + `pygame_gui` in Phase 3.

## D-028 Guard rails are tests — DELEGATED
- `tests/test_architecture.py` reads the source and fails on forbidden imports per layer
  (engine: no network, pygame, clocks, threads, randomness, llm/ui/tools; content: no engine,
  llm, ui; llm: no pygame/ui).
- ruff bans `import random` project-wide (TID251).
- An autouse fixture blocks outbound network connections in every test.
- Hygiene tests: CLAUDE.md ≤ 100 lines, persistent docs exist, no API keys in tracked files,
  `.env` is git-ignored.
Each rule was verified by deliberately breaking it and watching the check fail.

## D-029 Continuous integration — DELEGATED
GitHub Actions runs `scripts/check.sh` plus the launcher on **Ubuntu and macOS** for every push
and pull request. The repo is public, so minutes are free. If it ever becomes private, macOS
minutes count 10×: then run macOS only on pull requests.

## D-030 GameRng is our own generator — DELEGATED (implemented in Phase 1)
Python only guarantees that `random.random()` keeps its sequence across versions; other
methods (`randrange`, `choice`, `shuffle`…) may change. Saves must replay identically on any
Python version, so `engine/rng.py` will implement a small documented PRNG (e.g. PCG32) whose
whole state is a few integers stored in `GameState`.

## D-031 Where the project lives — RESOLVED by D-033
`Lilmagpy/Lilmagpy` is the owner's GitHub **profile repository** (public): a `README.md` at its
root is displayed on the owner's public GitHub profile page. Until the owner decides, no root
README is added and setup instructions live in `docs/GETTING_STARTED.md`. Options: move to a
dedicated repo (recommended) or keep it here (the README would then appear on the profile).

## D-032 Licence — DEFERRED (owner decision, only needed before publishing a release)
No licence file yet, which legally means "all rights reserved": others may view the public repo
but not reuse it. Choose one before any public release.

## D-033 The project lives in Lilmagpy/Anachronism — OWNER (2026-09-30)
The owner chose a dedicated repository and created **`Lilmagpy/Anachronism`** (private) themselves:
the Claude GitHub App is not allowed to create repositories. History moved over intact; `main`
holds approved work. "Anachronism" stays a **placeholder name** (owner: "can we do a placeholder
for now"); renaming later is easy. The old profile repo `Lilmagpy/Lilmagpy` still holds a copy on
branch `claude/new-session-8vxe44` (its default branch). It has no README, so nothing shows on the
owner's profile; the owner can delete that repo or leave it.

## D-034 CI on a private repo — DELEGATED (amends D-029)
Mac minutes count 10x on private repos. Linux checks run on every push and pull request; the macOS
job runs only for pull requests, pushes to `main` and manual runs. Phase work is developed on a
`claude/phase-N-*` branch and reaches `main` through the phase's pull request (D-002).

## D-035 Integer maths everywhere — DELEGATED (Phase 1)
All engine state and maths use Python integers; rates and 0-100 stats are basis points
(10_000 bp = 100%). Floating-point maths can differ in the last digit between macOS and Linux
libraries, which would make saves replay differently across machines. `engine/fixed.py` holds
the rounding rules.

## D-036 Content file format — DELEGATED
Each YAML file holds `schema_version` plus exactly one kind (`techs`, `provinces`, `rules`…),
so authors can split files freely. List items are validated one at a time, so a broken item is
reported without hiding its valid siblings, and references to it are not reported twice.
Duplicate YAML keys are errors (PyYAML would silently keep the last). Numbers are in basis
points with `_bp` in the field name wherever that is not obvious.

## D-037 What lives where in content — DELEGATED
Province files hold fixed geography only; civ files hold lasting identity only; a scenario
holds the moment: ownership, populations, stockpiles, stats, social-group influence and known
techs. This keeps the Phase 5 layered timeline (D-025) possible without reshaping data.

## D-038 Effect caps follow the current era — DELEGATED
An advancement's effect is capped by the era the game is in, not the era it belongs to. An idea
adopted centuries early is held back until society catches up with it.

## D-039 Adoption spread is civilisation-wide in Phase 1 — DELEGATED
Spread is one percentage per civilisation and advancement, not tracked province by province.
Per-province adoption can come later if the map needs it.

## D-040 Core tech years are placeholders — DELEGATED
The `year` of each core tech node (first historical appearance) is an approximate value from
general knowledge, good enough for the fictional test world. Before real-history packs rely on
them (Phase 5), each gets a source note and a confidence level.

## D-041 Literacy fades without teaching — DELEGATED (Phase 1)
A share of literacy (5% per decade) is lost each turn, so literacy effects set a sustainable
level: writing alone sustains about 6%, printing and schools push toward 20-30%. Without this,
writing alone reached 20% literacy and a careful player 70% by 600 BC, far above history.

## D-042 Knowledge from everyone, not only the literate — DELEGATED
A small base amount of knowledge comes from the whole population (crafts, lore, observation);
literate people add much more. Otherwise a society without writing could never invent anything,
yet steppe peoples invented riding and the composite bow.

## D-043 Strain follows current conditions — DELEGATED
Strain moves toward a target set by this turn's project shortfall, labour diversion and unpaid
administration, instead of accumulating without limit. It measures how stressed society is now;
unrest carries the memory.

## D-044 Bots take actions only, with no randomness — DELEGATED
Automated players choose actions from the state and nothing else, so bot-played games replay
exactly from their action log. They run rival civilisations until Phase 4's scripts arrive.

## D-045 `uv run anachronism` starts the text console until Phase 3 — DELEGATED
One command to remember. When the window arrives, `anachronism` opens it and the text version
stays available as `anachronism-console`.

## D-046 First-pass balance, to tune with the owner — OPEN (Phase 7 per the brief)
Current numbers make overextension collapse reliably and careful growth thrive. Known issues:
a careful player is comfortable (the 55-node test tree is nearly exhausted by 600 BC) and
suspicion bites only when the "witchcraft" or "fraud" framing comes up. The brief asks for the
owner's help tuning suspicion; pacing is tuned when real content and conflict exist.

## D-047 Godot 4 replaces Pygame for the game's visuals — OWNER (2026-09-30)
The owner wants "incredible graphics" and chose a modern 3D world over a 2D map. This overrides
brief decision #1 (Pygame). Godot 4 is free, open source (MIT), has a full 3D renderer and
exports to macOS. Verified 2026-09-30 that Godot 4.5.1 renders 3D in the cloud container
(Xvfb + Mesa software rendering, Compatibility renderer), so screenshots can be sent to the
owner. The Python engine is unchanged; the text console remains a developer tool.

## D-048 Client-engine bridge — DELEGATED
The Godot client starts the Python engine as a child process and they exchange one JSON
message per line over its stdin/stdout. No network sockets (nothing to firewall, nothing
exposed). The engine stays the only authority on rules; the client only renders and sends
actions. The bridge lives in `tools/server.py`, outside the pure engine.

## D-049 Phase order: 3D world before the LLM — OWNER
Phase 2 is now the 3D world; the LLM ruling pipeline becomes Phase 3 and plugs into the 3D UI.

## D-050 Getting builds to the owner — DELEGATED
CI exports a macOS app for every pull request so the owner downloads and double-clicks; no
Terminal. Unsigned at first (right-click → Open the first time). Bundling Python inside the
app is solved in this phase; Apple signing waits for packaging (Phase 8).

## D-051 3D art sources — DELEGATED
Terrain, water and borders are generated from content data. Models come from openly licensed
packs (CC0 only, licences recorded in `client/assets/LICENSES.md`) until custom art is made.

## D-052 Visual style: a Rise of Kingdoms-like "living map" — OWNER (2026-09-30)
Fixed-angle tilted map (no free 3D orbit). Zoomed out: the strategic map with territories,
borders, names and banners. Zooming in reveals detail that fades in by distance: towns sized by
population, capitals with walls, farms, forests, and later units. Stylised, colourful low-poly
art rather than photorealism. Built on the Godot 3D client (D-047) using distance-based
level of detail.

## D-053 The map is the real Earth — OWNER (2026-09-30)
The owner's goal is maximum realism, so the fictional map is replaced by real geography
(the test world stays only for automated tests). This overrides the "stylised, not
photorealistic" part of D-052; the living-map camera and zoom-in detail stay.
- **Elevation:** Terrarium tiles (Mapzen / AWS Open Data; built from SRTM, GMTED2010, ETOPO1
  and others; attribution required), stitched by `client/tools/build_heightmap.gd`.
- **Colour:** NASA Blue Marble satellite mosaic (public domain, about 10 km per pixel),
  reprojected by `client/tools/build_colour.gd`. Chosen over colours guessed from climate,
  which looked wrong. Its snow cover is from one season. Higher-resolution imagery (Sentinel-2
  cloudless, NASA servers) is blocked from cloud sessions; revisit on the owner's Mac.
- **Rivers:** Natural Earth 10 m rivers (public domain), `scripts/build_rivers.py`.
- **Projection:** Web Mercator, one world unit ≈ 5 km at the equator; heights exaggerated
  about 14× so mountains read from a strategy camera. Regions are built one at a time,
  East Asia first (67.5–151.9°E, 5.6–55.8°N).
- Sources and licences are listed in `client/data/SOURCES.md`.

## D-054 First real scenario: the Warring States, 350 BC, playing Qin — DELEGATED (2026-09-30)
The owner asked Claude to pick. Chosen because it is the best-documented early East Asian
moment with many rival states (7 great states, 6 smaller ones, 5 frontier peoples), it sits
where the "ideas ahead of their time" play is richest (paper, cast iron, crossbows, canals,
civil service all within reach), and 350 BC is a clean anchor: Qin moves its capital to
Xianyang under Shang Yang's reforms. The player is Qin, the best-known state; other starts
can be added later as extra scenarios. Populations, borders and techs are Claude's estimates
from general historical knowledge; uncertainties are listed in `docs/history/warring_states.md`.

## D-055 Real-map content: latlon, map and cost scale — DELEGATED (2026-09-30)
Provinces and seas on the real Earth use `latlon` (degrees; content only, not used by the
simulation, so floats are safe for determinism). Scenarios name their `map`. Real
populations are about ten times the test world's, which made every invention trivially
cheap, so scenarios carry a `cost_scale` that multiplies project costs; shown populations stay
real. Old saves load unchanged (new fields default to "no map" and scale 1).

## D-056 Provinces are drawn by terrain-aware growth from their centres — DELEGATED (2026-09-30)
Hand-drawing historical borders would be slow, and the historical-basemaps polygons are GPL
(D-009). Instead each province grows from its centre over the real elevation, with steep
and high ground costly to cross, so frontiers settle on ridges and rivers stay inside
provinces. The client and the checking tool (`client/tools/province_report.gd`) use the same
code, so the rules' neighbours always match what the player sees. Borders are about 20 km
accurate. Hand-made border polygons can replace this later if the owner wants exact lines.

## D-057 How the Mac app carries the Python engine — DELEGATED (2026-09-30)
The exported Godot app contains the engine's Python source, its lock file and the `uv` tool
(both Mac chip types). On first launch it unpacks them into the game's user-data folder and
uv downloads its own Python 3.12 and the exact locked libraries (about a minute, once);
the Mac's own Python is never used. Nothing is installed system-wide and the owner needs no
Terminal. The app is ad-hoc signed only (no paid Apple developer account), so macOS asks
for "Open Anyway" once. CI proves the packaging on every push by exporting the same
package for Linux and starting it with an empty home folder. Elevation data moved from EXR
(readable only by the Godot editor) to a raw 16-bit file that exported games can read.
Later options: bundle Python itself for offline first launch; sign and notarise (Phase 8).

## D-058 Settlements are drawn larger than life — DELEGATED (2026-09-30)
At true scale a city on the continental map is a few pixels wide even fully zoomed in, so,
as in Rise of Kingdoms, settlements are drawn about 2.5 times larger than life and appear
when the camera comes within about 1,000 km. Each province has its chief city at its
centre (capitals walled in rammed earth, with gate towers and a palace hall on a terrace,
laid out on the cardinal directions as cities of the period were), plus towns and villages
by population, placed on the flattest, lowest land. Simple built shapes for now; the CC0
models of D-051 or custom art can replace them. Map lines (borders, rivers) now keep a
constant thickness on screen at every zoom.
