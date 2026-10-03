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

## D-059 Art direction: bright cartoon, full of character — OWNER (2026-09-30)
After playing the first Mac build the owner said the quality fell well short: the game must
look good in the manner of Rise of Kingdoms (screenshots shared), may be cartoony, and needs
characterisation (figures from each empire popping up and speaking) and an intro where the
player picks a civilisation and a starting moment. The map keeps real geography (D-053) but
is painted in a bright cartoon style instead of satellite colours (owner's choice). Sources:
CC0 art packs for 3D models (D-051), code for the map, water, UI and effects. Scripted
character lines come now; free AI conversation belongs to Phase 3. Phase 2 continues
(steps 2.9–2.16) and its PR stays open until the owner is happy.

## D-060 Character portraits: placeholders made in code for now — OWNER (2026-09-30)
Offered AI-generated, artist-made or in-game-generated portraits; the owner chose
placeholders for now. They are drawn in code (heraldic emblems and silhouettes in each
civilisation's colours) and loaded from one folder per character, so real art can replace
them without code changes.

## D-061 First starting moments: all four regions — OWNER (2026-09-30)
The picker will offer East Asia (already built; add Korea and Japan starts), the
Mediterranean (Rome, Greece), Egypt / Near East and Medieval Europe (Britain, France,
Vikings). Each needs its own map region and researched scenario; they arrive one at a time.

## D-062 Night shift: work through the brief without stopping — OWNER (2026-09-30)
The owner is asleep and asked Claude to keep going without asking questions: improve
graphics and UI scaling, colour cities and territories by owner, vary the characters, and
implement the rest of the brief, then keep improving graphics. For this stretch the phase
gates are waived (work continues on the open Phase 2 PR, Lilmagpy/Anachronism#2); every
decision Claude makes alone is logged here as DELEGATED for review in the morning.

## D-063 How a ruling on the player's idea is bounded — DELEGATED (2026-10-01)
The model (or the offline interpreter) returns loose numbers: percentages, 0-3 levels.
`llm/guard.py` converts them into an engine `Ruling`, and `engine/judge.py` bounds the
ruling again when it is applied, so even a ruling that skipped the guard is safe: effects
are cut to the era's caps (at most 3 per idea, no unlocks from rulings), a new idea is at
least as complex as its hardest prerequisite minus one and cannot be "invented" before
its prerequisites (so the anachronism cost and suspicion cannot be dodged), unknown
references are dropped, and the advisers' reactions add at most 2 unrest and 3 suspicion.
Costs are never taken from the model (D-020). At most 3 ideas per message are ruled on
(no bundling). The limits live in `rules.yaml` under `rulings`. Each ruling is stored in
the save inside a `RuleOnIdea` action, so replays apply it again without any model (D-021).

## D-064 Offline "Historical Advisors" mode matches words to the library — DELEGATED (2026-10-01)
Every advancement now has `keywords` (words players might use: "printing press",
"zero", "river"). Offline, a message is split into parts, each part is matched to the
best advancement, and the ruling comes from the engine's own feasibility check; anything
unmatched is "beyond this age" with a hint toward ideas within reach. The court's reaction
comes from scripted dialogue (`idea_feasible`, `idea_blocked`, `idea_implausible`). The
same interpreter is the fallback whenever a model call fails.

## D-065 No model name in the code — DELEGATED (2026-10-01)
Model names change often and must come from configuration (CLAUDE.md), so there is no
default model: online play needs both `ANTHROPIC_API_KEY` and `ANACHRONISM_MODEL` in the
environment or a git-ignored `.env` file (see `.env.example`), with an optional cheaper
`ANACHRONISM_FAST_MODEL`. Without them the game plays offline and says so. The provider
uses only Python's standard library (no new dependency), forces structured output through
a single tool, marks the fixed system prompt for prompt caching, and retries rate limits.
A monthly token cap (default 2 million) stops calls once reached.

## D-066 Rival scripts live in the scenario files — DELEGATED (2026-10-01)
Each civilisation in a scenario lists its intentions (`scripts`) and temperament
(`disposition`); the scenario lists starting `relations` (alliances, wars, grudges).
Scripts are conditional: they fire when their preconditions hold (year window, stability,
strength against the target, turmoil in the target, advancements known, other scripts
fired) and lapse when their moment passes or their target is gone, taking dependent scripts
with them. The player's own civilisation never follows a script. The scripts for all four
moments were drafted from well-known history (the notes cite what really happened); they
are drafts for the owner's review, in the spirit of the brief's review workflow (§9.2).

## D-067 War is abstract — DELEGATED (2026-10-01)
No individual armies to move yet. Strength = workforce x military effects x legitimacy;
allies at war with the same enemy lend half their strength. Each turn the stronger side
may take one frontier province (chance grows with its advantage, capped at 50%); both sides
lose people on the front, gain unrest and weariness; the side that tires first makes peace
and keeps a grievance. A lost capital moves the court and costs legitimacy; losing every
province destroys a state. The map shows crossed swords on war fronts. Moving armies and
battles can come later (Phase 7) without changing saves' meaning.

## D-068 Victory paths and how they are measured — DELEGATED (2026-10-01)
The brief asked the owner how to measure each path; tonight's measures, all tunable in
`rules.yaml`: military = rule 50% of the scenario's people; economic = trade partners,
allies and tributaries hold 60% of everyone else's people, and you hold the richest
treasury; cultural = 40% of the region's culture (people weighted by literacy and cultural
influence), and the largest. Each target is at least the starting share plus 20 points,
so a dominant start (Egypt in 1275 BC) must still gain ground. Every victory is regional
until games span several regions. The game can continue after the banner.

## D-069 Korea's moment: the Three Kingdoms in AD 400 — DELEGATED (2026-10-01)
For the East Asian starts the owner asked for (D-061), the first Korean moment is AD 400:
Gwanggaeto's Goguryeo, Baekje, Silla, Gaya and the Wa of Japan, with the northern
dynasties (Wei, Yan, Qin), Eastern Jin and the Rouran. Korea and Japan get finer
provinces than in 350 BC. It suits the game: a young conqueror-king, a weak Silla that
history says will win, and Japan across the strait. Notes and uncertainties are in
docs/history/three_kingdoms.md. A Japan-centred moment is left for later.
Also tonight: an ally or tributary under attack pulls in its AI protectors, but the player
is never dragged into a war automatically; their general asks instead.

## D-070 Drafted content needs a real source before it ships — DELEGATED (2026-10-01)
`uv run anachronism-draft --region "East Asia" --era classical` asks the model for new
library ideas and writes them to `drafts/` (git-ignored), each marked as a draft. The
`--promote` step refuses any entry still carrying the draft note, so an idea reaches a
pack only after someone has checked its date and written a real source (brief §9.2:
the model's memory is never the only source for shipped facts).

## D-071 Chance events are content — DELEGATED (2026-10-01)
Plague, floods, droughts, locusts, earthquakes, fires, bandits, storms, bumper harvests,
silver strikes, wandering sages and good omens live in `core/happenings.yaml`: a chance per
decade, where each can strike (terrain, river, coast), what it does, and what softens it
(health against plague, storage against flood and drought). At most one per state per turn,
rolled on the game's RNG so replays match. `rules.society.happening_frequency_bp` scales
them all (0 turns them off, as the exact-number tests do). The steward and diviner react.
Also tonight: capitals are twice as hard to take and rough terrain is harder (D-067 tuning);
armies appear on war fronts; sound and music are synthesised by scripts/make_sounds.py.

## D-072 Rulers age, die and are succeeded — DELEGATED (2026-10-01)
Every state's ruler ages each turn; the chance of dying each decade is 0.7% per year of
age above 30 (so about 21% at 60, capped at 90% a turn). The next ruler is the scenario's
next historical successor (with their own temperament where history is clear: King Wuling
of Zhao, Cnut, Emperor Taiwu), then unnamed heirs. A death costs 8 points of legitimacy;
below 40 legitimacy it brings a succession crisis (+15 unrest). The player's own ruler
dies too; the state goes on. Successor lists are drafts from general history.

## D-073 Trade and faith as first-class flows — DELEGATED (2026-10-01)
Brief §7.5 asks for trade, religion and cultural flows as first-class things. Every
friendly tie (trading, allied, tributary) now earns both sides wealth each turn, by the
smaller side's people. Each scenario lists its faiths and who holds them (the Zhou rites,
the thousand gods of Hatti, the Olympians, Latin and Orthodox Christianity, Sunni and Shia
Islam, Buddhism, the kami...); faiths marked as spreading cross to neighbours by chance,
more easily along friendly ties and from states of great cultural influence. States of one
faith forget old grudges faster; courts sharing your faith add half their culture to your
cultural victory share. You can send missionaries (a wealth cost, a 35% chance, a small
grudge if refused). Faith lists are drafts from general history.

## D-074 Japan's moment: the Warring States in 1560 — DELEGATED (2026-10-01)
The Japan-centred start the owner asked for (D-061) is May 1560, on the eve of Okehazama:
play Oda Nobunaga with 3,000 men as Imagawa marches on Kyoto, among the Takeda, Uesugi,
Hojo, Mori, Shimazu and the rest, with Joseon Korea, Ryukyu and the Ming coast across the
sea. The Ming appear only as the provinces within reach, and far smaller than the real
empire, so a regional victory stays possible (noted in docs/history/sengoku.md). New
portrait styles: armoured samurai and a Joseon official's gat.

## D-075 A bigger library of ideas — DELEGATED (2026-10-01)
The library grows from 55 to 90 advancements, mostly medieval to early modern (lenses,
eyeglasses, telescope, microscope, germ theory, vaccination, the printing press,
newspapers, universities, the scientific method, banking, double-entry bookkeeping,
joint-stock companies, ocean-going ships, cannon, muskets, star forts, new crops, spinning
machines, coke smelting, the steam engine, railways...), so later moments have curated
ideas and the offline court recognises more of what players type. Dates are approximate
first appearances (placeholders pending the source review, as D-040). Several now appear
as landmarks around the capital.


## D-076 Royal decrees, and cultural victory must be earned — DELEGATED (2026-10-01)
Playtests showed wealth piling up with nothing to spend it on, and some starts winning a
cultural victory without the player doing anything (a big faith the player never held
counted towards their share). Two royal decrees now spend wealth, priced by the size of
your people: a festival (raises legitimacy, calms unrest) and hiring mercenaries (30% more
strength for two turns). A faith now counts towards your cultural share only if you held it
at the start, and cultural victory also needs at least 10% cultural influence of your own.
Rival courts use the same decrees: at war they hire swords, in unrest they hold feasts,
always keeping half their treasury in reserve.

## D-077 Cities in their region's style — DELEGATED (2026-10-01)
Every city was drawn in the East Asian style. Buildings now follow the region of the
province's first owner (from its portrait family): tiled roofs and rammed earth in East
Asia; flat-roofed mud brick, a columned temple and a pyramid on the Nile; mud brick and a
stepped temple tower in the Near East; white walls, terracotta and a columned temple around
the Mediterranean; steep roofs, a stone keep, round towers and a church spire in the north;
felt tents and a great yurt on the steppe. Trees no longer grow inside city walls.
Fixed on the way: on large maps (Europe 1000) cities vanished, because each kind of
building was one batch for the whole map and Godot hides a batch by its centre's distance
from the camera; buildings are now batched by map tile like the trees.

## D-078 Economic victory measured by network and income — DELEGATED (2026-10-01)
Playtests showed economic victory either came on turn 3 (Egypt at Kadesh: one envoy a turn
to each neighbour, instant alliances) or never (the "richest treasury" test failed against
any bigger empire, and spending on decrees counted against you). Now:
- your trade network must reach 60% of other peoples, with trading partners counting half
  and allies and tributaries in full, and include at least half the other living states;
- your income per turn (own lands plus trade ties) must be at least half the largest
  rival's: what you spend no longer counts against you;
- one embassy a turn, and a court allies only after two turns of trade (or against a
  common enemy).
Egypt at Kadesh, the region's superpower, can still win by trade in about 60 years of
patient diplomacy; elsewhere it takes most of a game. The World tab ticks off each
path's extra conditions.

## D-079 A fair chance for small starts — DELEGATED (2026-10-01)
Playing Oda in 1560 (one province against Imagawa and Saito) ended in collapse within six
turns in half of all games, often on turn 2, before a player could do anything. Now a
state's last province is defended to the end (three times harder to take); the player
loses no provinces in the first two turns, to answer an opening war; and Oda starts
with the wealth of Owari's port trade (enough to hire mercenaries at once). Sengoku stays
the hard start: about one game in six still ends early.

## D-080 What every state of an age knows — DELEGATED (2026-10-01)
The 35 newer advancements (D-075) were never added to the starting moments, so Rome was
offered "written law" despite its Twelve Tables, and Byzantium "hospitals" and "glass".
Scenarios now list `common_techs`, ideas every state of the age knows, given to each
state that already has their prerequisites (so peoples without writing get no law code).
Written law everywhere it fits; soap at Kadesh and in AD 1000; household registers in
East Asia; glass, hospitals and registers in AD 1000. Drafts from general history,
for the source review with the rest (D-040). CONTENT_GUIDE documents the field.

## D-081 Collapse comes from within; world faiths hold — DELEGATED (2026-10-01)
Two rules misfired in AD 1000 playtests. (1) "Collapse" counted any lost province, so a
two-province state that lost one battle "collapsed" - and for the player that meant game
over. As DESIGN §5 intends, collapse is now breaking apart from within: half the starting
provinces lost to revolt. Conquest is the war system's business (a state with nothing
left is destroyed). (2) Faiths converted courts of other world faiths as easily as pagan
ones: the Fatimid caliphate and the Zirids turned Latin Christian within decades. A court
holding another spreading faith now converts at a tenth of the chance, and missionaries
sent to one succeed at 30% of theirs.

## D-082 Democracy and the republic; a more careful offline court — DELEGATED (2026-10-01)
Players will type "democracy", and the offline court called it implausible - for Rome,
with Athens next door. The library gains Elected magistrates (the republic, Rome 509 BC)
and Citizens' assembly (democracy, Athens 508 BC); Rome and Carthage start with the
first, Athens and Rhodes with both. The offline court now takes a one-word idea that is
exactly a keyword as a match, ignores generic words alone ("flying machines" is not
"spinning machines"), suggests the nearest ideas ahead of their time, and says when it is
offline that it only knows its library. The content linter now checks each civ's
starting ideas together with the age's common ones.

## D-083 Confidence tiers and a source-review checklist — DELEGATED (2026-10-01)
Brief §2.14 asks for internal source notes and confidence levels. Advancements,
civilisations and scenarios now carry `sources` and `confidence` (high / medium / low,
low by default). `anachronism-lint --review` prints the checklist. Today everything is
honestly "low, no source": it was drafted from general history, so the Phase 5 source
review (D-040) starts from a complete list instead of a guess.

## D-084 A seventh moment: the Great Khan, 1206 — DELEGATED (2026-10-01)
On the East Asia map: play Genghis Khan at the kurultai of 1206, among the Tangut Xia, the
Jurchen Jin, the Southern Song, Goryeo, Kamakura Japan, the Qara Khitai, the Uyghurs of
Qocho, the Ongut and Dali (10 states, 54 provinces; history notes in
docs/history/great_khan.md). To make the steppe's real strength possible, scenarios can now
set a state's mobilisation (`martial_bp`: the Mongols put fifteen times the usual share of
their people under arms; the Jin and Song less). Tested: a passive Mongol player takes
nothing; one who goes to war takes Xia and much of the Jin over about two centuries.
Where the map's province growth leaves gaps across the Gobi, the steppe and the Tibetan
plateau, a few historical routes are linked by hand. Steppe capitals are camps of felt
tents around the khan's great yurt.

## D-085 Coalitions against a dominant player — DELEGATED (2026-10-01)
A player who grows to rule over 35% of a region's people (and ten points more than at the
start, so a state that began great is not punished for it) frightens its neighbours:
each turn, two of them at peace with each other may ally against the player (a 15%
chance, one new league a turn). Alliances already join defensive wars, so attacking one
member brings in the others. The steward warns you when a league forms.

## D-086 Demanding tribute — DELEGATED (2026-10-01)
Much of history ran on tribute, not conquest (Goryeo and Xia paid the Jin; Joseon and
Ryukyu the Ming). A court submits as your tributary if you are two and a half times
stronger, or, at war, once it has lost ground (submission is then the price of peace). It
resents it (a small grudge), and a refusal stings more. Tributaries already count fully
toward an economic victory and join your defensive wars. A "Demand tribute" button sits
with the other diplomacy buttons. Aggressive rival courts far stronger than a
neighbour take tribute instead of war half the time (never from the player).

## D-087 The library reaches the telephone — DELEGATED (2026-10-01)
Players love to rush far-future ideas ("electricity in Rome"), and the offline court
could not recognise them. Ten 19th-century advancements join the library (102 in all):
the electric battery, telegraph, telephone, photography, anaesthesia, steamships, canned
food, chemical fertiliser, cheap (Bessemer) steel and dynamite, each with prerequisites
reaching back through the tree, so asking for electricity in 264 BC shows the long road
there as goal stubs. Dates are approximate first appearances (D-040).

## D-088 Autosave and Continue — DELEGATED (2026-10-01)
The engine saves the game to an "autosave" slot after every turn; the title screen offers
CONTINUE whenever that slot exists, so a crash or an accidental quit costs at most one
turn. Named saves (Esc → Save) are unchanged. The title backdrop now centres on whichever
map is loaded (it pointed at East Asia even when the Europe map was shown).

## D-089 Difficulty levels — DELEGATED (2026-10-01)
Easy, Normal and Hard, chosen in the civilisation picker. Each level is a set of overrides
to the rival rules in rules.yaml (data, not code): Easy halves how often aggressive rulers
start wars, slows conquest and gives five quiet opening turns; Hard does the opposite with
one grace turn. Normal is the rules as written. The chosen rules are stored in the save,
so a game and its replay stay exactly the same.

## D-090 An eighth moment: Alexander's inheritance, 336 BC — DELEGATED (2026-10-01)
On the Europe map: play the twenty-year-old Alexander the moment his father Philip is
murdered, with Greece restless (Athens, Thebes, Sparta), Epirus allied, the Illyrians and
Thracians waiting to rebel, the Scythians on the Danube, and the Achaemenid empire of
Darius III from the Aegean to Bactria's edge; in the west, Carthage, Syracuse and Rome
(12 states, 54 provinces; history notes in docs/history/alexander.md). Scripted rivals
follow history loosely: the Theban and Illyrian revolts, Agis III's war, the Persian
counter-offensive in the Aegean, the Sicilian wars. Persia is much larger but raises a
smaller share of its people (`martial_bp`), and the Macedonian army a much larger one, so
the two start roughly level in strength. Tested over three seeds: a passive Macedon keeps
its lands; Persia slowly absorbs the Greek cities if nobody stops it.

## D-091 Rival rulers voiced by the model — DELEGATED (2026-10-01)
Rival rulers now speak to the player when they declare war on you, make peace, bow to a
tribute demand, or boast of something far ahead of its time. Each moment has stock lines in
the content (core/dialogue.yaml), so offline play is unchanged. When a model is
configured, the stock line and a few facts from the game (the ruler, their people, year,
temperament, faith, grudge and relative strength) go to the cheaper "fast" model, which
rewrites the line in that ruler's own voice. Why this is safe: the reply is only the text
of a speech bubble and changes nothing in the game, so replays need no record of it (rulings
still are recorded, D-021); the player's own words are never sent; the reply is cut to one
tidy line; any failure, odd shape or empty answer keeps the stock line; answers are cached
and count toward the monthly token cap. At most one rival speaks per turn.

## D-092 Explaining the court's new arts — DELEGATED (2026-10-01)
The design (§7) promised that suspicion could fall through "explanations", but nothing in
the game did that: the only cure was waiting. Measured: each idea far ahead of its time
adds up to 15% suspicion and talk settles into a framing at 25%, so two bold ideas in a row
are enough. A new royal decree gives the player a choice. **A divine gift**: priests
proclaim the arts sent by the gods (costs wealth like a festival; suspicion -20%; if the
people trust the throne - legitimacy 50% or more - talk of witchcraft or fraud turns to awe,
the "inspired" framing). **Foreign sages**: credit wise strangers from distant lands (costs
knowledge; suspicion -35%; but the story travels, and rivals learn of your inventions at
once). A story told too often is doubted: once every three turns. All numbers are in
rules.yaml. The buttons appear under Royal decrees only while people are asking.

## D-093 Keeping inventions secret — DELEGATED (2026-10-01)
The brief (§7.3) says information is a strategic resource: the player can keep inventions
secret, seal borders or feed disinformation. Advancements with a "secrecy" effect already
slowed news; two royal decrees now make it a choice. **Seal the borders** (free, three
turns): news of your inventions travels half as fast, but all trade with you stops - your
partners lose it too, and your economic path stalls while the gates are shut. **Spread
false rumours** (wealth): every true report of your arts already on the road arrives as a
muddle instead (rivals do not copy what they have only half heard), and the truth follows
much later. Only offered while there is news on the road; the panel says how many courts
it is heading to. Numbers in rules.yaml.

## D-094 Aware rival courts decide with the model — DELEGATED (2026-10-01)
Brief §7.2: courts that have heard of the player should have the model reason about how
their ruler responds; on-script courts cost nothing. Now, when a model is configured, once a
turn the aware (or free-agent) court with the deepest grudge against the player is asked
what its ruler does: **make war**, **send an envoy** or **wait**, and what they say. The
model sees only game facts (ruler, temperament, faith, relation, grudge, relative
strength, what they have heard of the player's arts, and which moves are allowed). A guard
offers war only when the court is at least two thirds the player's strength and not
already at war, and an envoy only when it can pay; anything else, or any failure, means
waiting. The move becomes an ordinary action, validated again by the engine and recorded in
the save, so replays never call the model (D-021). The ruler's line opens the turn's
speech bubbles. Alliances were left off the menu on purpose: a rival proposing one would
have to be accepted on the player's behalf. Offline play is unchanged.

## D-095 The story so far — DELEGATED (2026-10-01)
Brief §6.7 asks for a chronicle that reads like an alternate history. The Chronicle screen
now opens with "The story so far": the game in chapters of five turns, newest first, each
telling what the player's people learned, their wars and peaces, lands won and lost,
rulers who died, how the people saw the court, and which states fell, with the population
in round figures. Offline, chapters are told plainly from those facts. With a model
configured, each finished chapter is rewritten once by the chronicler (two to four
sentences, facts only) and cached; at most two new chapters are written per visit to keep
the screen quick and cheap. Like rival speech, this is presentation only and changes
nothing in the game.

## D-096 Consequences of new ideas — DELEGATED (2026-10-01)
Brief §6.7 asks for second-order effects: consequences the player did not plan for, like
printing's effect on religion. These are now content, in core/happenings.yaml, as a third
kind of happening ("consequence") that can only strike a state using the advancement it
follows. Fourteen to start: pamphlet wars and cheap scriptures (printing: the clergy lose
influence), the end of the knights (gunpowder: the nobles do), inflation (paper money), the
tyranny of the clock, the heavens are wrong (telescope: suspicion), public opinion
(newspapers), restless scholars (universities), machine breakers (spinning machines),
railway fever, ships held in quarantine, fear of the needle (vaccination), adventurers who
sail with the compass, and lawyers (written law). Happenings can now also move suspicion
and the influence of clergy, nobles and guilds. Fixed content rather than model-written:
deterministic, free, and reviewable; the model may later phrase them.

## D-097 A ninth moment: the Mauryan dawn, 321 BC — DELEGATED (2026-10-01)
India was missing. The East Asia map already reaches it (67.5°E to the Pacific, south to
Lanka), so no new map was needed; three Indian seas were added. Play Chandragupta, with
Chanakya's vow to destroy the Nandas, against the vast Nanda empire of the Ganges, the
Macedonian satraps left on the Indus (later Seleucus), Kalinga, the Chola, Pandya and Chera
kingdoms and Lanka (8 states, 35 provinces; history notes in docs/history/maurya.md).
Tested over three seeds: a passive Mauryan player keeps the Punjab; one who goes to war
survives every time and sometimes takes most of the Ganges. India gets its own look: new
portraits (a king in a jewelled turban, a brahmin, a minister) and buildings (whitewash
and brick under flat roofs, and a white stupa beside the palace hall).

## D-098 The court's counsel — DELEGATED (2026-10-01)
The brief's offline "Historical Advisors" mode (§10, DESIGN §14) had the matching of typed
ideas but not the advisers' own suggestions. Now, every turn, the Ideas tab opens with
"Your court's counsel": the steward, the general, the scholar and the diviner each
recommend one advancement you can begin now, with a reason in their own voice (lines in
core/dialogue.yaml). Each values different effects (food and wealth; strength; knowledge;
legitimacy and calm), and the one whose worry is pressing - thin granaries, a war or a
stronger hostile neighbour, restless streets or wild rumours - speaks first and urgently.
Advisers think within their age: an idea a little ahead of its time pleases them, but what
lies centuries away is the ruler's own strange knowledge, not theirs to suggest.

## D-099 A war of armies — owner request (2026-10-01)
The owner asked for far richer fighting and strategy. War was abstract: each turn the
stronger side had a chance to take one border province. Now wars are fought by armies
(DESIGN §10b): raised from a province's people with costs and upkeep, made of the kinds of
soldier the state's advancements and resources allow (13 kinds in core/units.yaml - data,
so a new kind needs no code), marching across the map, fighting battles weighed by unit
match-ups, terrain, walls, morale, generals and fortune, besieging provinces until the
walls fall, and wasting away to supply and attrition. Every rival court raises and directs
its armies by simple rules (mass at the capital, march on the nearest reachable enemy
province only with good odds, defend its land, go home at peace); the player's armies
defend their land unless told otherwise. Wars last longer than before (peace at 8,000
weariness, a winning side tires at half speed) because campaigns take several turns.
Battles, sieges and lost armies are spoken of by the general and recorded in the chronicle
and its chapters. Tested: twelve engine tests; sims across scenarios show campaigns,
battles, sieges and conquests, and deterministic replays. This replaces the "tactical
battles out of scope" line of DESIGN §16 at the owner's request.

## D-100 Armies on the map — DELEGATED (2026-10-01)
Every army stands beside its province's city in its owner's colours, larger for larger
hosts, with its strength above it (and siege progress while it besieges); a marching army's
road is drawn ahead of it; crossed swords mark last turn's battlefields. Clicking a province
lists the armies there (soldiers, morale, general, what they are doing) and, for your own,
the orders March… (then click the destination), Hold, Defend and Disband; your provinces
also offer "Raise a levy here" in three sizes and five mixes, with the cost shown. Orders
are ordinary recorded actions, so replays stay exact.

## D-101 Generals, mercenaries, land for peace and elephants — DELEGATED (2026-10-01)
- **Generals**: scenarios name each state's commanders (Parmenion and Craterus, Memnon of
  Rhodes, Hamilcar Barca and Xanthippus, Bai Qi and Sun Bin, Subutai and Jebe, Shibata
  Katsuie and the young Hideyoshi, Yamagata Masakage...), with a skill of 1-5 and a gift:
  master of horse, siege master, stubborn defender, bold attacker, careful quartermaster,
  or beloved by the men (strengths in rules.yaml). New armies take the next free general;
  one whose army disbands returns to court; one who falls in battle is gone. Generals
  whose careers came later are noted as such.
- **Mercenaries** are now a real company of professionals that musters at the capital
  for two turns, costs no men of your own, and then marches away.
- **Land for peace**: at war, "Demand land" asks for every province your armies stand
  in; only a side that is losing (more battles and provinces lost, and tired or clearly
  outmatched) agrees, and it never signs itself out of existence.
- **Elephants** are a map resource where war elephants came from (the Ganges and Kalinga,
  Assam, Lanka, Numidia and Carthage, Kush, and the Seleucid stud at Apamea).

## D-102 Walls, pillage and the price of levies — DELEGATED (2026-10-01)
More choices in war, each with a cost:
- **Walls**: build up to three levels in any of your provinces (stone walls, then towers
  and gates with Fortification, then star bastions with the Star fort). Each level adds
  to how long a siege takes. Costs materials and wealth.
- **Pillage**: an army in enemy land can ravage it instead of besieging: people killed or
  driven off, wealth carried off, half the crops and goods lost for two turns, the enemy
  wearier - and a lasting grudge. Pillaging armies live off the land (no campaign
  attrition). Steppe peoples (four times the usual mobilisation and more) raid what they
  cannot take quickly.
- **Levies breed unrest**: calling up men angers their families, in proportion to how many,
  less among warlike peoples.
- **Field battles weigh only the ground** (hills, mountains, marsh); walls, capitals and
  last stands count in sieges. Before, a lone capital's defenders counted triple in the open
  field and evenly matched rivals (Sengoku Japan) never dared attack. Rival courts now
  accept an even fight if warlike and want a modest edge if cautious, judged against the
  enemy armies near their objective.

## D-103 Battles told as stories — DELEGATED (2026-10-01)
Battle reports were formulaic. Now each battle is told by a fitting tale from content
(core/tales.yaml): horsemen sweeping round a flank on open ground, horse archers wearing
down an army on the steppe, a hedge of spears holding a pass, arrows darkening the sky, a
long grinding slaughter of infantry, elephants scattering horses, an army caught crossing
a river or strung out in a forest. The engine picks the tale that best fits the soldiers
who decided it, the ground, and whether it was a rout, then adds the losses and any fallen
general. A new way to tell a battle is a YAML entry.

## D-104 Dilemmas — DELEGATED (2026-10-01)
Brief §6.7 asks for events generated from the situation; the owner asked for storytelling
and strategy. Dilemmas are choices put to the ruler, as content: when one's conditions hold
it may arise (its chance per decade), a card in the middle of the screen tells the
situation and offers two or three answers, each showing what it will do (stores, unrest,
legitimacy, suspicion, the favour of clergy, nobles and guilds, a new idea, volunteers).
Unanswered at the end of the turn, the court takes the first answer. General ones (a comet,
a hungry city, a wandering preacher, whispers of sorcery, a merchants' charter, a library
for sale, deserters, veterans who want land, strangers from afar, a fever in the slums)
and historical ones: the Gordian knot and Diogenes for Alexander, the corvus for Rome,
the year 1000, Shang Yang's reforms for Qin, Chanakya's Arthashastra for the Mauryas, the
Yassa and the captured craftsmen for the Mongols, and the Portuguese guns of Tanegashima
in Sengoku Japan. Answers are recorded actions, so replays stay exact.

## D-105 Envoys come to you — DELEGATED (2026-10-01)
Diplomacy was all one way: the player sent envoys, rivals only acted. Now rival courts send
envoys with proposals the player must answer, shown on the same card as dilemmas: a beaten,
weary enemy **sues for peace**; a far stronger, aggrieved, warlike neighbour delivers an
**ultimatum** (pay a quarter of the treasury and become its tributary, or face war); a
friendly trading partner at war with the player's enemy **proposes an alliance** (accepting
means joining its war); a merchant court **proposes a trade pact**. A court with something
to propose sends envoys with a 25% chance per decade, one proposal at a time. Unanswered,
the court refuses for the player - which, for an ultimatum, means war. Answers are recorded
actions, so replays stay exact.

## D-106 Conquered peoples remember — DELEGATED (2026-10-01)
Conquest was permanent the moment the walls fell. Now every province has a people (its
owner at the start). A conquered province keeps its people, and while it has no garrison
(an army of its rulers with at least one man per hundred people) it may rise - 15% a decade,
more when the realm is restless - going back to its old state if that still stands, or
breaking free if not (a capital, with its court and guards, never rises). After 150 years
a conquered people thinks of itself as its rulers' own. The province card says whose people live there, how long ago they were conquered,
and what garrison holds them. Empires now cost soldiers to keep, not only to win.

## D-107 Navies: fleets, sea battles, command of the sea — DELEGATED (2026-10-01)
Armies crossed seas freely: Carthage's great fleet and Rome's lack of one meant nothing.
Now warships are content (`ships.yaml`: galleys, heavy warships, war junks, carracks, gun
ships, each needing its advancements), built as squadrons of 10, 25 or 60 in a coastal
province and launched into the sea on its shore. Fleets sail two seas a turn; enemy fleets
that meet fight once a turn (the stronger, with luck, wins; the beaten fall back to home
waters or a safe sea); sea battles are told like land battles, from content tales fitted to
the winners' ships and people (rams in the narrows, fire-bombs from Song junks, broadsides,
Greek fire for Byzantium, the corvus for Rome, turtle ships for Joseon). **Whoever commands
a sea decides who crosses it**: an army may cross only where no stronger enemy fleet holds
the water. **Blockades**: where enemy fleets command every sea on a province's shore, its
harbours close - it loses most of its trade, and its people tire of the war. Fleets cost
wealth every turn; unpaid crews desert. States start with fleets in proportion to their
coastal people and a historical seafaring factor per scenario (`navy_bp`: Carthage 4x,
Rome almost none in 264 BC; Venice, Denmark and Norway strong in 1000). Rival courts at
war build ships when out-matched at sea and send their fleets to meet the enemy's - or to
blockade its coasts.

## D-108 Battle plans and veterans — DELEGATED (2026-10-01)
Battles were decided by numbers, soldiers and ground alone. Now every army fights with a
battle plan (content, `core/tactics.yaml`): steady line, headlong charge, shield wall
(defence only), skirmishing (needs archers), envelopment (needs horse), feigned retreat
(needs much horse) and ambush (defence in forest, hills or marsh). Each beats some plans
and loses to others (a shield wall breaks a charge; arrows wear down a shield wall; a
feigned retreat draws an envelopment away), and the side whose plan wins gets +30% (+60%
with a general gifted for it). Plans also change the ground's worth, the blood spilt (a
charge is bloody, skirmishing is not) and how badly the beaten are destroyed (Cannae).
A general left to choose answers what he expects the enemy to do; a great general (3 stars
or more) reads the enemy's real plan. The player may order a plan for each army, and sees
the likely plan of rival armies. Battles are told by plan (Cannae, the Mongol feigned
retreat, the Teutoburg forest). Armies also learn: victories (and surviving defeats) make
veterans, up to +30%; raw recruits dilute them; mercenaries come as veterans.

## D-109 Graphics pass toward Rise of Kingdoms; heraldic symbols — DELEGATED (2026-10-01)
The owner asked for graphics "incredible", modelled on Rise of Kingdoms, rated 0-10 against
it and improved past 8; and for empires to bear symbols rather than letters. Done so far:
the coastline is drawn from the real heights as a smooth line with sand beaches and surf
(no more staircase cells); turquoise shallows deepen to rich blue, with painted swells
offshore; land is lush green; owned land carries a light wash and a glowing border in its
owner's colour; mountain ranges are fuller, with snowy peaks. Real 3D models from the
Kenney kits (CC0): forests of oaks, pines and palms; capitals as castles with towers,
gatehouses and banners whose roofs take the owner's colour; fleets as sailing warships;
siege trains with trebuchets. Armies are ranks of soldiers with shields in their colours
under a mounted commander and a standard. Every civilisation has a heraldic symbol (content
`symbols.yaml`, chosen from its history: the Roman eagle, the Athenian owl, the Seleucid
anchor, the Chola tiger, the Gojoseon bear, the Mongol wolf...), drawn on a shield in the
picker, the top bar and over its lands; art from game-icons.net (CC BY 3.0, credited on
the title screen). The Mac renderer's global illumination washed colours out, so it is off
and colours are graded instead. Labels of armies and fleets give way to more important
names. Clouds only appear over the whole-world view.
Second round: towns are now real little houses put together from Kenney fantasy-town pieces
(plaster or timber walls with doors and shuttered windows, gabled, steep or pointed roofs in
terracotta, slate or thatch, with a touch of the owner's colour). The landmarks your ideas
raise round your capital are kit buildings too: a stone windmill with turning sails, a water
mill, a clock tower, an observatory, a school hall, smoking forges, a market with stalls, a
harbour sailboat. A Roman-style temple has a stepped platform and columns all round. Seen
from far off, where the towns are hidden, each chief city stands as one larger-than-life
icon (a walled castle for a capital, a cluster of houses for a town) in its owner's
colours, as cities do on Rise of Kingdoms' map. Trade, alliance and tribute ties are
dashed lines flowing out from your capital, and fade out as you zoom into a city. The
owner wash is paler, so red over green land turns rosy rather than muddy. Province names
sit on dark name plates with a gold rim and their owner's colour at one end. Armies and
fleets are drawn large to read from afar and shrink toward life size as the camera comes
down to a city; soldiers carry tall rimmed shields and crested helmets. Mountain peaks are
faceted grey rock on a green foot with snow caps only on top (they were all-white blobs up
close), and settle into lower hills as the camera comes down so they never wall off a town.
East Asian towns have grey-tiled roofs and a palace of red pillars under a double roof; an
inland capital no longer shows a harbour boat on dry land.

## D-110 CI uses far fewer free minutes — DELEGATED (2026-10-01)
GitHub Actions stopped running because the repository's free monthly minutes ran out (the
owner confirmed). Every push had run the whole workflow twice (once as a push, once for the
open pull request), each time with the Mac app build, and the macOS checks whose minutes
count tenfold. Now the Linux checks run once per pull request update (and on pushes to
main); the macOS checks and the Mac app build run only when started by hand from the
Actions tab. The checks and the app are run and built in the cloud session anyway before
each commit. Roughly a tenth of the minutes per push.
Later the same day the owner made the repository public (free, unlimited minutes for
public repositories); the macOS checks and the Mac app build run on every pull request
update again, and each update still runs only once.

## D-111 Province buildings; cities that grow on the map — DELEGATED (2026-10-02)
The owner asked to stop polishing graphics and perfect the gameplay against the brief, and
for cities to visibly spread out and fill with buildings as a civilisation develops. The
brief's effect menu (§5.10) named `unlocks_building`, but there were no buildings: every
improvement was realm-wide. Now each province holds buildings (content
`core/buildings.yaml`; schema `content/schema/buildings.py`; engine
`engine/buildings.py`), gated by advancements, coast, river or ore, paid up front, built
over one or two decades and kept with upkeep. They raise the province's own output, growth
and room for people, or calm the realm, teach reading and train soldiers; upgrades take the
place of older buildings. A province holds two plus one per 250,000 people (up to eight),
and each standing building makes the next a quarter dearer, so growth and building feed
each other without one city taking everything. Pillage burns the newest building, which
gives raiding a lasting cost. Rival courts (and the simulation bots) build one a turn in
their biggest city when their stores hold three times the price, so rivals develop too.
On the map, each building appears in its city (a round temple, market stalls, a granary
barn, forges with smoke, a water mill, an aqueduct's arches...), the middle of the city is
kept for them, and cities are rebuilt larger whenever they have grown by a quarter or
raised something new. The numbers are a first pass, to be tuned with play.

## D-112 Rival courts no longer starve themselves; low priority is steady work — DELEGATED (2026-10-02)
Playing the Punic Wars with the simulation tool showed small rival states (Pergamon,
Rhodes, Sparta, Syracuse, Pontus) in famine and riots for most of the first 30 turns. The
cause: when a rival court heard of an idea, or a script told it to adopt one, it started the
project without checking whether it could staff it; one idea needed more labour than its
whole workforce, so farmers were pulled from the fields. Now (1) low-priority projects are
"steady work": funded only from spare hands (the surplus left after higher tiers), they
never divert farmers, never count as a shortfall, and do not decay while they keep moving;
(2) rival courts start a project at full pace only if their spare hands cover it, otherwise
as steady work, one at a time. In the same 30 turns there is no famine or riot anywhere and
small states still adopt a few ideas. The player gains the same choice: push an idea hard
(and risk hunger) or let it ripen slowly. Also, courts choosing buildings value calming
ones more as unrest rises, and the simulation bots start nothing new while unrest is above
half (the balance test "careful growth stays stable" caught a growth bot that built five
schools and no temple while unrest climbed).

## D-113 The fall is not the end: new dynasties and restored states — DELEGATED (2026-10-02)
D-011 said the player's guiding hand follows the lineage across dynastic change and the game
ends only when no successor survives; in practice every scenario gives each lineage a single
state, so a collapse or conquest simply ended the game. Now: a state that collapses from
within but still holds land passes to a new dynasty (revolts counted afresh, half the unrest
released, legitimacy reset to an untested 40%); a state destroyed by conquest is restored
where its remembering people rise against an unguarded conqueror (they rise twice as eagerly
as other peoples, and the state takes that province as its capital); the player is defeated
only when no province still remembers their state. This applies to rival states too, so
history keeps its restorations. New spoken moments: `dynasty`, `restoration`; the collapse
line no longer says "it is over". The side panel tells an exiled player where their people
still remember them.

## D-114 Infrastructure: some ideas need buildings standing in the realm — DELEGATED (2026-10-02)
Brief §5.4 lists infrastructure (roads, workshops, mills...) among what makes an idea
buildable. Until now that meant only other advancements. Tech requirements now include
`buildings`: printing press, movable type and spinning machines need workshops; blast
furnaces, crucible steel and cannon need forges; coke smelting needs forges and mines; the
steam engine and railways need mines (historically, engines first pumped mines);
universities need a school; banking a market; hospitals a temple; caravels, sternpost
rudders and steamships a harbour. An upgrade counts for what it replaced (a bank is still a
market). Blocked ideas say what is missing ("needs forges built somewhere in the realm").
Courts building for themselves favour what unlocks an idea they are waiting on, and the
language model's state summary lists the realm's buildings. This makes the bootstrapping
puzzle concrete: to print, first build the workshops.

## D-115 Spies and intelligence: rival plans you can learn (and misread) — DELEGATED (2026-10-02)
D-013 decided rival scripts are seen through intelligence reports that can be wrong, their
quality set by relations, trade, distance and spies; brief §7.3 lists spies among the ways
news travels. Nothing showed the player a rival's intentions. Now each turn the player
gets a report on every court in touch whose source is good enough: allied envoys (60%
reliable), tribute bearers (50%), merchants (40%), captured soldiers in wartime (30%),
less 10 points per border beyond the first. Each of up to two pending intentions is told
truly with that chance, otherwise with the wrong target (a planted or garbled story). A new
decree, **Send spies** (25 wealth hundredths per 1,000 people, five turns), adds 40 points,
the court's current projects and its men under arms; each decade spies have a 20% chance to
steal the methods of the court's oldest advancement you lack (30% of the work done when you
start it) and a 12% chance to be caught (they are lost and the court bears a grudge).
Rivals do not spy yet. Warnings that a court "means to make war on us" are shown in red.

## D-116 Rival courts make their own history once their scripts run out — DELEGATED (2026-10-02)
A 60-turn simulation of the Punic Wars showed every rival war came from the historical
scripts in the first 17 turns; after that the world went quiet for 400 years and borders
froze. Courts only acted on their temperament once they became "free agents" (by being
affected by the player). Now a court whose scripted intentions have all fired or lapsed
acts on its temperament too: aggressive rulers attack a neighbour they outmatch by half
again; cautious, scholarly and pious rulers also go to war, a fifth as often, and only
against a neighbour they bear a deep grudge (30%+) and outmatch twice over; mercantile
courts open trade. In the same simulation wars now continue throughout the game (53 wars,
15 conquests, one state swallowed), while uprisings and peace keep it from snowballing.

## D-117 Rival courts quiet suspicion and win back doubting peoples — DELEGATED (2026-10-02)
In a 60-turn simulation the strongest states (Rome, the Seleucids, Macedon) sat near 0%
legitimacy for centuries, branded frauds by suspicion they never answered: only the player
could explain the court's arts, and rival courts feasted only in unrest. Now rival courts
(and the simulation bots) have priests proclaim their new arts divine when suspicion passes
40% (if the treasury holds twice the price and the people have not heard the story too
recently), and hold festivals when legitimacy falls below 20% as well as in unrest. In the
same simulation Rome ends at 92% legitimacy and the Seleucids at 67%.

## D-118 Wars end on terms: the side that tires first pays — DELEGATED (2026-10-02)
Testing a conquering player showed armies winning battle after battle and besieging a
capital, only for the war to end in a plain peace the moment the losing side grew weary:
whoever tired first, the war simply stopped and every siege was lifted. Now, when one side
is worn out first, it sues for peace and cedes every province the other's armies stand in;
if that is all it has left, it becomes the other's tributary instead of vanishing. If none
of its land is held, or both sides tire together, it is a plain peace. The same for a player
demanding land when the enemy's only province is occupied (it used to "cede" nothing):
the enemy submits as a tributary. The simulation's military bot now really campaigns
(declares war on a neighbour it outmatches by 40%, marches on its weakest border province,
sues for peace only once nothing is under siege and the war is eight turns old), so the
balance tests exercise conquest: as Qin it grows from 3 to 5 provinces in 60 turns.

## D-119 Spend the stores: hastening work, and hoards that waste away — DELEGATED (2026-10-02)
Over 60 simulated turns Rome piled up 115,000 materials, 108,000 wealth and a million
knowledge while producing about 4,000 a turn: labour is what limits projects, so stores
became meaningless numbers. Two changes: (1) **Hasten**: once a turn a project can be
pushed on by a full turn's work, paid from the stores (wealth for hired craftsmen at three
times the turn's labour and wealth, and twice its materials and knowledge); rival courts and
bots hasten when their stores hold five times the price. (2) Stores of materials, knowledge
and wealth beyond ten turns' production waste away, a fifth of the excess each decade
(timber rots, scrolls are lost, treasure is embezzled), like the granary's spoilage. In the
same simulation Rome's wealth now ends near 26,000 and it adopts 74 ideas instead of 68.

## D-120 Chronicle mode: live through history and try to outdo it — owner's direction (2026-10-02)
The owner asked for a more scaffolded playthrough along history as it really happened, with
better storytelling, lightly romanticised but never at the cost of the history, keeping the
ideas ahead of their time and everything already built. Asked four questions, the owner
chose: **history bends, then catches up** (your choices change the world, but the great
turning points still come while their conditions hold; a turning point whose world no
longer exists is passed over, and the chronicle tells how history turned); **compare with
real history** (each chapter's aftermath tells what really happened and how your state
stands against the real one at that date; the goal is not to win but to outdo history);
**Rome against Carthage first** (19 chapters, Messana in 264 BC to the fall of Carthage in
146 BC, and 20 almanac entries of what happened elsewhere); **short turns** (two years a
turn in a chronicle; `campaign_years_per_turn` in the scenario).
How it works: chapters and almanac entries are content (`chapters`, `almanac` pack kinds).
One chapter waits at a time and the turn cannot end while it does (in the client); answering
is a recorded action, so replays stay exact; a chapter left unanswered is settled as history
did. Choices carry a dilemma's effects plus deeds in the world (war, peace, alliances,
tributaries, land taken or given, fleets, men). A choice may need an idea in use: these are
the anachronisms of the player's own making (a crossbow line at Cannae, a rudder-steered
fleet), shown locked with what they need until then, so the core idea game feeds the story.
Free play stays as it was; the picker offers "Follow history" where a scenario has chapters.

## D-121 The game is called Meritus; a new app icon — owner's direction (2026-10-02)
The owner renamed the game **Meritus** and asked for an icon about "the asymmetry of you
changing history with today's advancements". The icon is a tile split by a jagged seam of
light: on the left, the ancient world (parchment, a gold laurel wreath, a light bulb of
cracked stone with a bronze base); on the right, today (a night-blue blueprint grid, glowing
circuit traces finishing the wreath, the same bulb lit in glass and steel). Its source is
`client/icon.svg`. Renamed wherever players see the name: the title screen, the disclaimer,
the app (Meritus.app), the download (Meritus-mac), and how the AI's prompts name the game.
Kept, deliberately (DELEGATED): the code name `anachronism` for the Python package, the
commands, the repository and the environment variables (renaming them would break the
owner's settings file and every link for no visible gain); the bundle identifier; and the
folder that holds saves and settings (a custom user folder keeps it at "Anachronism", so
nothing is lost). The word "anachronism" still names the in-game idea of an advancement
ahead of its time.

## D-122 The second chronicle: Qin unifies China (350-221 BC) — DELEGATED (2026-10-02)
28 chapters from Shang Yang's second reform to the First Emperor, after Sima Qian's Shiji
and the Zhanguo ce, plus 18 almanac entries (Mencius, Alexander in India, Ashoka, Euclid,
Eratosthenes...). Three ideas carry over from the brief: the great figures speak in their
own names (a chapter may name its speaker: "Shang Yang", "Bai Qi", "Li Si"); dark history is
told plainly (Changping's prisoners) but a choice history did not take can spare them; and
ideas brought in early open new paths (stirrups at Changping, gunpowder at Handan, examined
officials in 237 BC, printing the one script in 221 BC).
Playtesting with the simulation bot showed what the chapters needed to be playable:
- **Decisive battles end, they don't linger.** A historical victory (Danyang, Yique, Ying)
  now takes its land and leaves a grudge instead of an open war; open wars had left Shu
  bare for Chu to take.
- **Reforms last.** A chapter's choice may change how many of the people the state can arm
  (`martial_bp`): carrying Shang Yang's reform through makes Qin the war machine it was;
  repealing it does the opposite.
- **Land taken in a chapter comes with a garrison.** The conquering army stays (half again
  as many men as the province needs, at no cost, holding its ground), and a garrison told to
  hold no longer merges into a passing army and marches off with it - a fix for every
  player and court, not only chronicles.
- **Great conquests need the strength to make them.** A chapter can require the player to
  outmatch a state (`needs_stronger_than`): Han falls only to a Qin half as strong again;
  otherwise history turns, and the chronicle says so. A choice may `conquer` a whole state.
In the same simulation Qin now stays level with history to 300 BC and unifies China in
220-218 BC, a few years after the real one.

## D-123 Seamless zoom: nothing pops, the camera glides — owner's direction (2026-10-02)
The owner asked for smoother transitions when zooming and moving around. What popped:
towns, trees, peaks, landmarks, armies and roads each appeared or vanished at a hard camera
distance (some in square map tiles at once), names blinked on and off as they made room
for each other, the camera zoomed toward the middle of the screen in uneven steps, and
"visit the capital" jumped. Now:
- **Fades, not pops.** Every distance cutoff fades over the last fifth of its range
  (`scripts/lod.gd`); near towns crossfade with their far-away icons. Godot's own fade
  hides our custom-shaded models (Kenney kit buildings, mountain peaks) outright, so those
  dissolve themselves with a fine dither, each building by its own distance
  (`shaders/lod.gdshaderinc`) - which also works on the simpler renderer. Per-object shader
  values ran out of room (thousands of buildings), so the fade distances sit in a few
  copies of each material instead.
- **Names fade.** Map names ease in and out, both at the ends of their distance range and
  when one gives way to another, instead of blinking.
- **The camera.** Zoom glides in equal steps of scale and keeps the point under the mouse
  still, as maps do; a dragged map carries on and slows when let go; keyboard panning
  eases in; flying to a place arcs up and back down over long journeys.

## D-124 Each turn plays out on the map — owner's direction (2026-10-02)
The owner asked for animations of what happens between turns, the marches and attacks, to
make it feel epic. After End Turn the map now shows the turn before its results ("350 BC →
340 BC, the years pass"; the panels slide aside): armies march along their roads with dust
and drums and fleets sail their courses trailing spray (the camera follows the player's);
the player's battles on land and sea are visited one by one (the hosts lunge at each other, dust, sparks and
flashes, the battle's name, VICTORY or DEFEAT and a horn), other battles flare where they
were fought; destroyed armies and fleets sink away; besieged cities burn while stones arc
into them from the siege lines ("Siege of Hexi · 45%"); the map recolours and every province that changed
hands raises its new owner's banner and arms, with a ring sweeping over the land and a
line ("Etruria is ours!"); new armies rise from the ground; the camera returns. Any click
or key skips to the end, and Settings can turn it off. The engine is untouched: the server
compares the map before and after the turn (`tools/replay.py`). New synthesised sounds:
marching drums, a battle clash, a victory horn and a defeat horn. Painted "moment" cards
for disasters and the like will follow when the art from docs/ART_PROMPTS.md comes in.

## D-125 The future is yours alone; rivals get it only by spying on you — owner's direction (2026-10-02)
The owner: "you as the person playing should be the only person who has these technologies
unless other places come and spy on you to steal the technologies". Until now rival courts
(run by the same planner as the test bots) started any advancement whose prerequisites
they had, however far ahead of its time, and copied the player's ideas from mere hearsay.
Now a rival court can only work on advancements whose time has come (at most 25 years
before history had them, `foresight_years`) or whose secret it stole: history keeps its
own pace for everyone but the player. A court that has heard of the player's arts sends
spies to steal one (1.8 chances in 10 a decade per court, the earliest it could use);
the player's people catch 4 in 10 of them (twice as many while the borders are sealed,
which also halves the attempts), and the player hears of every theft and every foiled
attempt. A stolen secret starts the thief's work with a head start. In a 15-turn test as
Rome the player held 8 ideas from the future and the rivals one between them, while five
thefts and three foiled attempts were reported.

Also fixed: the Mac build never carried the game's font files, so every screen used
Godot's plain default font, and panels such as the dilemma box measured their text with
an empty font and shrank to slivers under their own words. The export now carries the
fonts, and the font loader falls back to the imported copy if the raw file is missing.

## D-126 The time traveller's notebook — owner's direction (2026-10-02)
The owner: the premise ("what if you went back in time with today's knowledge") did not
feel significant enough, and choosing advancements was awkward. Now:
- **The notebook from the future** (N, or the gold NOTEBOOK button beside End Turn, or the
  banner atop the Ideas tab) is a two-page journal of everything the player remembers of
  the world to come - every idea from the future, not only those within reach, sorted into
  Ready now, Needs groundwork, Being made, In use (brought from the future) and Of this
  age. Each page gives how many years before its time it is, the player's note, **In our
  history** (who first made it, where and when - written for all 102 advancements), what
  it will do, what it takes (per turn, and as a share of free hands), the risks (suspicion,
  spies) and what it builds on (click to turn to that page), with one big button: Bring it
  into the world.
- **Breakthroughs are an event.** When an idea from the future works, the turn's replay
  flies to the capital, where a pillar of golden light rises with its name and "N years
  before its time", and a card tells what really happened in our history and what changes.
- **The mark on history**: the game remembers the year each idea came into use, and counts
  how many were brought early and by how many years in all.

## D-127 Developing your cities: real numbers, ranks you can see, one screen for it all — owner's direction (2026-10-02)
The owner: building was awkward, it was unclear what a building actually gives, and cities
should visibly expand and develop so that one can stop and develop one's base. Now:
- **The Cities screen** (🏛 CITIES beside the notebook, C, or "Develop the city" on a
  province card) lists every city with its rank and whether it has room to build; the open
  city shows what it makes each turn, what it could build - each with what it would add
  **there**, in plain numbers ("+119 food a turn, its people grow 10% faster, room for
  61,000 more people"), what it costs, how long it takes and what it costs to keep, with the
  best value marked - and its building plots: built, going up, empty, and when the next one
  opens. One building goes up at a time in each city, so building more means building in
  more cities, all from one screen. The engine computes one province's output with or
  without a building (`economy.province_output`); production itself is unchanged.
- **Ranks**: a city is a Village, Town, City, Great city or Metropolis by its buildings and
  people (a point a building, a point per 250,000 people). On the map a city spreads wider
  and fills with houses as it rises; a City gets walls of its own, a Great city spills out
  into suburbs beyond them. Building work stands on the map as the new building half-risen
  in timber scaffolding, with a crane.
- Place names now float above their cities, so a city's buildings show beneath its name.

## D-128 A building queue in every city — DELEGATED (2026-10-02)
Follow-on to D-127 ("ergonomically smoother to build more"): while builders are at work
in a city, BUILD becomes QUEUE, and up to three buildings wait their turn there. Each is
paid for only when it starts; if the stores cannot pay yet it waits; if it can no longer
go up (no plot, the city lost) it is dropped. A queue belongs to whoever made it and lapses
when the city changes hands. Queued buildings can be taken off the plans (✕).

## D-129 The future stands out on the map — DELEGATED (2026-10-02)
Follow-on to D-126: landmarks around the capital that were built from an idea brought in
before its time now carry a slowly turning golden halo, a soft glow and rising sparkles,
and up close their name and how early they came ("✦ Paper · 144 yrs early"), so the
player's mark on history can be seen at a glance.

## D-130 The third chronicle: Oda Nobunaga, 1560-1582 — DELEGATED (2026-10-02)
Follows the owner's "keep building" and the plan's "more chronicles". Sixteen chapters
from Okehazama to Honno-ji and Yamazaki, with a Sengoku almanac (Lepanto, Manila, Tycho's
new star, Yasuke, the Gregorian calendar). Decisions:
- **One year a turn.** Nobunaga's career is 22 years of crowded events; at two years a
  turn the chapters queued up and lapsed.
- **Muskets at the start.** Matchlocks were everywhere in Japan by 1560 (Tanegashima,
  1543), so every daimyo and the Ming now start with them; Joseon (none until the 1590s)
  and Ryukyu do not. This also affects free play of the scenario, which is more accurate.
- **A chapter can end a reign** (`ruler_falls` in a choice's deeds): the ruler dies as the
  chapter tells it and the next in line takes over, with the usual cost to legitimacy.
  Honno-ji's historical choice kills Nobunaga and loses Kyoto to Mitsuhide.
- **The chronicle's leader is spared old age** until the year their reign really ended
  (`leader_until` on a scenario state; only in chronicle mode, only the first ruler of the
  player's state). In tests Nobunaga kept dying of old age in the 1570s.
- **No Tokugawa state on this map**, so Ieyasu's Mikawa counts as Oda land once the
  Kiyosu alliance is made; the chapters say so plainly.
- Choices only the player's future ideas open: coke-smelted gun barrels, a joint-stock
  company at Sakai, printed broadsheets against Mount Hiei, spyglasses at Nagashino and
  Honno-ji, an academy at Azuchi, steamships in Osaka bay, tinned rations over the winter
  passes into Kai.
- With a passive test player (no wars of its own) all 16 chapters are played on every
  seed tried, ending with 5 to 7 provinces against history's 12. A player who fights does
  better.

## D-131 The fourth chronicle: Goguryeo, AD 400-475 — DELEGATED (2026-10-02)
Fourteen chapters from Gwanggaeto's rescue of Silla to Jangsu's capture of Hanseong (the
monk Dorim and his game of baduk), with an almanac (Faxian, the sack of Rome, Zu
Chongzhi's pi, the Yungang Buddhas). Decisions:
- **Two years a turn**, and Gwanggaeto is spared old age until 416 (D-130's rule), so his
  death is the chapter 'The Great King Dies' (412): every choice in it ends his reign,
  because the choice is what he tells his son, not whether he dies.
- **Two new deeds for chapters:** `capital` (the court moves; Jangsu to Pyongyang in 427)
  and `break_away` (an ally or tributary turns wary; Silla leaving Goguryeo's orbit in
  433). Both show in the choice's summary.
- Where the map has no state for something (Eastern Buyeo, the Ye of the east coast) the
  chapter takes an unclaimed province (the Mohe forests, the eastern mountains).
- The Feng Hong chapter opens while Yan still stands and Wei is at its gates, since Wei
  does not reliably take Longcheng on its own in play; one choice lets you take it first.
- A passive test player plays all 14 chapters on the seeds tried.

## D-132 Chronicle rulers keep history's calendar — DELEGATED (2026-10-03)
Follow-on to D-130. Sparing a ruler until their reign's real end was not enough: after
that, old age was left to the dice, and in testing Duke Xiao of Qin lived until 294 BC
(he died in 338). A scenario now says, for its first ruler and each named heir, either
`died` (a natural death: in a chronicle the player's ruler lives until that year and dies
in the turn that contains it) or `until` (a violent end a chapter tells, like Nobunaga at
Honno-ji: spared until then, and if the player changes history the ruler lives on with
the usual odds). Free play is unchanged. Qin now has its real line through Xiaowen and
Zhuangxiang to King Zheng (the future First Emperor), who takes the throne just as his
chapter opens in 246 BC; Jangsu of Goguryeo reigns to 491.

## D-133 The fifth chronicle: Ramesses II's Egypt, 1275-1208 BC — DELEGATED (2026-10-03)
The owner asked (going to sleep) for storylines for every civilisation and age, to be built
until they wake. Egypt comes first because the Kadesh moment had none. Twelve chapters:
the march north, Kadesh (the planted Shasu spies), the Sherden bodyguard, carving the Kadesh
poem, Amurru lost, the fugitive Hittite king, the silver-tablet treaty, Abu Simbel and
Nefertari, the Hittite bride, Prince Khaemwaset, the Libyan forts, and Merneptah at Perire
(the stela that first names Israel). Three years a turn; Ramesses dies in 1213 BC as he
did (D-132), followed by Merneptah and Seti II. The ideas that open choices history never
had: iron weapons, relay riders at Kadesh, the alphabet, concrete, schools. All twelve
chapters play with a passive test player.

## D-134 The sixth chronicle: Alexander, 336-323 BC; crowded years — DELEGATED (2026-10-03)
Sixteen chapters at one year a turn: Philip's murder, Diogenes, Thebes, the Granicus,
the Gordian knot, Issus, Darius's offer ("if I were Parmenion"), Tyre, Alexandria and Siwa,
Gaugamela, Persepolis, Darius's death, Cleitus, the Hyphasis mutiny, the Susa weddings,
and Babylon, where every historical choice ends the reign and one anachronism (germ theory)
lets Alexander live. Two engine changes, because Alexander's years are crowded:
- **Several chapters a year.** Answering a chapter now opens the next one whose year has
  come, instead of waiting a turn; the client shows "what really happened" first and the
  next chapter after it. Before, chapters fell behind their years and some lapsed.
- **Same-year chapters keep the order they are written in** (they were sorted by id,
  which put Darius's death before Persepolis and made Persepolis lapse).
Conquering Persia brings a regional victory mid-chronicle; "keep playing" carries on.
All five earlier chronicles still play through.

## D-135 The seventh chronicle: the Mauryas, 321-232 BC — DELEGATED (2026-10-03)
Seventeen chapters across three reigns, at three years a turn: Chanakya and the porridge,
the fall of the Nandas, Rakshasa's ring, the Greeks leaving the Indus, Seleucus's 500
elephants, Megasthenes, the Arthashastra, the Girnar lake, Chandragupta becoming a Jain
monk (a chapter ends his reign; staying king is allowed), Bindusara's Deccan, the letter
asking Antiochus for figs and a philosopher, Ashoka's disputed throne, Kalinga, the
conquest by dhamma, the edicts, Mahinda in Lanka and the half-fruit. Bindusara and Ashoka
die in their real years (D-132). Many of these stories come from legends written down
centuries later; each history note says which. All 17 chapters play with a passive test
player.

## D-136 The eighth chronicle: the Mongols, 1206-1279 — DELEGATED (2026-10-03)
Twenty-one chapters across five Great Khans, at three years a turn: the assembly on the
Onon, the shaman Teb Tengri, the forest peoples, the dyke at Zhongxing, the Uyghurs' letter,
the Badger's Mouth, Zhongdu, Yelu Chucai, Jebe and Kuchlug, Otrar, the last campaign,
'pasture or taxes', Goryeo's island court, the fall of the Jin, Karakorum and the yam,
news from Hungary, Dali, Diaoyu, Xiangyang, the kamikaze and Yamen. Genghis, Ogedei,
Guyuk, Mongke and Kublai die in their real years (D-132). Khwarazm, Russia and Hungary are
off this map, so those campaigns are told from the khan's camp. With a passive test player
20 of 21 chapters play; Xiangyang steps aside when the player has taken it already.

## D-137 The ninth chronicle: England, 1002-1066 — DELEGATED (2026-10-03)
Every moment on the timeline now has a chronicle for its leading state. England's has
fifteen chapters at two years a turn: Emma of Normandy, St Brice's Day, Danegeld, the
lost fleet, Archbishop Ælfheah, Sweyn Forkbeard, the king over the water, Assandun,
Cnut's North Sea empire, the waves, Alfred the Ætheling, Edward the Confessor, Harold's
oath, Stamford Bridge and Hastings. The chronicle follows the crown, not a family: the
English successors are now the real line (Edmund Ironside, Cnut, Harold Harefoot,
Harthacnut, Edward, Harold Godwinson, then Edgar the Ætheling), which also makes free play
more accurate. Where two reigns ended in the same two-year turn, the earlier death is
dated a year early so each king appears at his chapter. Hastings's historical choice
kills Harold and gives Wessex and East Anglia to Normandy; England lives on in the north.

## D-138 A second chronicle for 264 BC: Carthage — DELEGATED (2026-10-03)
Following the owner's "storylines for each civilisation and empire", moments now get
chronicles for their other great states, starting with Carthage: fifteen chapters from
the garrison at Messana through Xanthippus, Drepana, Hamilcar 'the lightning', the
Aegates, the Truceless War, Sardinia, the oath at the altar, Saguntum, the Alps, Cannae,
the Metaurus, Zama and Hannibal as suffete, to "Carthage must be destroyed". Carthage
was a republic, so it has no named ruler and the chapters speak to its council. Two
tuning notes: Messana's historical choice hires 30,000 mercenaries and Xanthippus brings
20,000, because without them Rome's AI took the city of Carthage itself by 250 BC; and the
court no longer gives a eulogy when an unnamed ruler 'dies' (it read "the seal passes to
the ruler of Carthage"). With a passive test player 12-14 of 15 chapters play.

## D-139 A second chronicle for 336 BC: Darius III of Persia — DELEGATED (2026-10-03)
Alexander's war from the other side, in nine chapters: Bagoas's poisoned cup, Memnon's
scorched-earth plan at Zeleia, Memnon's death, leaving the open plain for Issus, the offer
of half the empire, Batis at Gaza, the night before Gaugamela, the Persian Gates, and
Patron's warning before Bessus's betrayal. Persia left no account of these years, so the
historical choices are the Greek writers' version, and the other choices are mostly the
advice Darius's own commanders gave him (Memnon, Amyntas, Patron) - this is the chronicle
in which the player can make Persia listen. Darius is spared old age until the end a chapter
tells (D-130); Bessus until his execution. All nine chapters play with a passive test player.

## D-140 A second chronicle for 1275 BC: the Hittites — DELEGATED (2026-10-03)
Eleven chapters at three years a turn: the planted Shasu spies at Kadesh, Amurru, the
scornful letter to Assyria ("were you and I born of the same mother?"), Hattusili's coup
against his nephew (a chapter ends that reign), the silver treaty, Puduhepa's dowry letter,
the first trade embargo after Nihriya, Yazilikaya, the grain letters ("a matter of life or
death"), the first recorded sea battle off Cyprus, and the abandonment of Hattusa. Hatti's
line is now Muwatalli II, Mursili III, Hattusili III, Tudhaliya IV, Arnuwanda III and
Suppiluliuma II, each dying (or deposed) in his real years. All eleven chapters play with a
passive test player.

## D-141 A second chronicle for AD 1000: the dukes of Normandy — DELEGATED (2026-10-03)
Twelve chapters from Emma's marriage to William the Conqueror's death: the English exiles,
Herleva the tanner's daughter, Robert's pilgrimage, Val-ès-Dunes, Matilda of Flanders,
Mortemer, the fleet at Dives, Hastings from the Norman side, the Harrying of the North,
Domesday and the fall at Mantes. Normandy's dukes now follow the real line (Richard II,
Richard III, Robert, William, Robert Curthose). One tuning note: Mortemer's historical
choice no longer declares war on France - the French were beaten and went home - because
an open-ended war let France's AI swallow the one-province duchy before 1066. All twelve
chapters play with a passive test player.

## D-142 A second chronicle for 1206: the Southern Song — DELEGATED (2026-10-03)
The Mongol century from Hangzhou, in eleven chapters: Han Tuozhou's head, stopping the
tribute to the Jin, Zhao Gong's report on the Mongols, Shi Miyuan's chosen emperor, the
march on the three capitals, Song Ci's forensic handbook, Diaoyu and the gift of fish,
Jia Sidao's secret truce, Xiangyang, the surrender of Lin'an and Yamen. The Song now have
their real line of emperors, from Ningzong to the boy Zhao Bing; Emperor Gong is taken
north and Zhao Bing drowns in chapters, so the player can change both. All eleven chapters
play with a passive test player.

## D-143 A second chronicle for 1560: the Takeda of Kai — DELEGATED (2026-10-03)
Nine chapters: the woodpecker plan at the fourth Kawanakajima, Shingen's rebel heir,
Suruga and the sea, Kenshin's salt, the shogun's call and Mikatagahara (Shingen dies on
the way home in his real year), Katsuyori at Takatenjin, the fence at Nagashino (the old
generals' advice to retreat is the choice history did not take), the new castle at Shinpu,
and Tenmokuzan. Katsuyori is spared old age until the chapter that ends the house. All nine
play with a passive test player.

## D-144 A second chronicle for 350 BC: Zhao — DELEGATED (2026-10-03)
Qin's great rival, in eleven chapters: King Wuling's trousers and horse archers, Zhongshan,
Wuling's abdication (a chapter ends his reign), the jade returned intact, Lian Po's thorns,
'two rats in a hole' at Yuyu, the gift of Shangdang, Zhao Kuo at Changping, Mao Sui's awl in
the bag, Li Mu on the frontier and Li Mu betrayed. Many of these are still Chinese proverbs.
Zhao now has its real line of rulers, from Marquis Cheng to King Youmiu and Jia of Dai. The
first chapter is in 307 BC, so the chronicle opens with some forty years of free play.

## D-145 A second chronicle for AD 1000: Byzantium; how reigns end — DELEGATED (2026-10-03)
Ten chapters: Basil II's annual campaigns, Kleidion and the blinded army, the keys of
Ohrid, Basil's lack of an heir, Romanos III's bath, Maniakes in Sicily (with Harald
Hardrada), the people rising for Zoe, the bull on the altar in 1054, Manzikert and the
Venetian golden bull. 'You' are whoever holds the throne: the chronicle follows thirteen
emperors and empresses in their real years. Two engine details:
- A scenario's heir can say how the reign really ended (`ends`: "abdicates, ill, and
  becomes a monk"), used when the chronicle ends it on time instead of "has died".
- Such ends, and reigns ended by chapters, are recorded as `ruler_fell`, not `ruler_died`,
  so the court's eulogy (added earlier this night) is kept for real deaths.
All ten chapters play with a passive test player.

## D-146 A second chronicle for AD 400: Baekje — DELEGATED (2026-10-03)
Goguryeo's chronicle seen from the south, in eight chapters: the hostage prince in Yamato
and the Wa alliance, Jeonji waiting on the island, ships to the Jin court (and Baekje's
learning passed on to Japan), white falcons for Silla, the prince born on Kakara island
(King Muryeong), the letter to Wei, Dorim's game of baduk, and the court's flight to
Ungjin. Baekje's line now runs from Asin to Muryeong, with Munju and Dongseong murdered as
history says (D-145's `ends`). All eight chapters play with a passive test player.

## D-147 A third chronicle for 1206: Kamakura Japan — DELEGATED (2026-10-03)
Ten chapters: the Wada rising, Sanetomo murdered on the shrine steps (a chapter ends his
reign), Masako's speech and the Jokyu war, the Goseibai Shikimoku, Nichiren's prophecy,
Kublai's letter, the Bun'ei invasion, the beheaded envoys and the stone wall at Hakata,
the Koan invasion and the 'divine wind', and the warriors' unpaid rewards that doomed the
shogunate. After Sanetomo the chronicle follows the real rulers, the Hojo regents, each in
his real years. No chapter declares war on the Mongols: the invasions are told from the
beach, and the player's ideas (a printed law code, steamships) change how they go. All ten
chapters play with a passive test player.

## D-148 A third chronicle for AD 1000: the Western Empire — DELEGATED (2026-10-03)
Eight chapters from Otto III to Henry IV: the Congress of Gniezno and Charlemagne's tomb,
"are you not my Romans?", Henry II's war with Bolesław beside the pagan Liutizi, Conrad
II's coronation between Cnut and Rudolf of Burgundy, the three popes deposed at Sutri,
the boy king's leap from Anno's boat, the letter to "Hildebrand, now not pope but false
monk", and Canossa. The crown passes through Ottonians and Salians in their real years.
All eight chapters play with a passive test player.

## D-149 A fourth chronicle for AD 1000: Kievan Rus — DELEGATED (2026-10-03)
Nine chapters: Vladimir's feasts for the poor, Novgorod refusing tribute, the murder of
Boris and Gleb (played as Sviatopolk), Bolesław at the Golden Gate and the Alta (a chapter
ends Sviatopolk's reign), the Russkaya Pravda, the Pechenegs and St Sophia, the last sea
raid on Constantinople, Anna Yaroslavna's marriage to the King of France, and Yaroslav's
testament. The 1043 raid no longer declares a lasting war (peace came in 1046; an
open-ended war let Byzantium's AI take Kiev). All nine chapters play.

## D-150 A third chronicle for 350 BC: Chu — DELEGATED (2026-10-03)
Eight chapters: the conquest of Yue, Zhang Yi's 'six hundred li', King Huai seized at the
Wu pass (a chapter ends his reign), Qu Yuan's exile and the Li Sao, the fall of Ying and
Qu Yuan's death in the Miluo (the Dragon Boat festival), Lord Chunshen smuggling the prince
out of Qin, Lu and Xunzi, and Xiang Yan against Wang Jian. Chu's line runs from King Xuan to
Fuchu. The 'six li' war is a lost campaign that ends, not an open war, because a permanent
war let Qin's AI swallow a passive Chu decades early. All eight chapters play.

## D-151 A third chronicle for 1275 BC: Middle Assyria — DELEGATED (2026-10-03)
Six chapters across three kings: the claim to be a 'brother' of the great kings, the end of
Mitanni, Nihriya, Marduk carried off from Babylon, the new city of Kar-Tukulti-Ninurta,
and Tukulti-Ninurta murdered by his son (a chapter ends that reign). Assyria now has its
real line: Adad-nirari I, Shalmaneser I, Tukulti-Ninurta I. Nihriya is a battle won, not an
open war, because a lasting war with Hatti brought in Hatti's ally Egypt (which never fought
Assyria). All six chapters play.

## D-152 A third chronicle for 1560: Uesugi Kenshin — DELEGATED (2026-10-03)
Six chapters: the siege of Odawara and the Uesugi name, Kawanakajima from Kenshin's side,
the salt sent to an enemy, the road west against Nobunaga, the Tedori river, and Kenshin's
sudden death and the war between his adopted sons. Kenshin dies at the turn of 1577-78 so
that the last chapter is played as Kagekatsu. All six chapters play.

## D-153 A fifth chronicle for AD 1000: the fall of Córdoba — DELEGATED (2026-10-03)
A short, tragic chronicle in five chapters: al-Mansur's last campaign, Sanchuelo's
fatal winter march, the sack of Madinat al-Zahra, Ibn Hazm's Ring of the Dove, and the
abolition of the caliphate in 1031. The 'ruler' is whoever really held power: al-Mansur's
sons, then six caliphs of the civil war, each removed in his real year in the way history
records (killed in the fighting, executed, murdered in his bath, poisoned, deposed). All
five chapters play.

Follow-up rule (applies to every chronicle): a reign that history ended by murder, coup
or deposition (`ends`) is only ended on schedule while the player's most recent chapter
answer was history's. Once the player has turned history aside, those violent ends no
longer happen by themselves and the ruler lives on with the usual odds; natural deaths
keep their dates either way.

## D-154 A third chronicle for AD 400: Silla — DELEGATED (2026-10-03)
The weakest kingdom of AD 400, which would unite Korea in 668, across 160 years in nine
chapters: Goguryeo's rescue, Bak Je-sang, the alliance with Baekje, the name 'Silla' and the
title of king, the wooden lions of Usan, Ichadon's white blood and the coming of Buddhism,
the surrender of Geumgwan Gaya (ancestors of Kim Yu-sin), the seizure of the Han river,
and the hwarang Sadaham at Daegaya. Eight kings in their real years, Silseong killed in
Nulji's plot as history says. The 'chapters within their moment' test now allows 170 years.
All nine chapters play.

## D-155 A sixth chronicle for AD 1000: the Fatimids of Cairo — DELEGATED (2026-10-03)
Seven chapters: al-Hakim and the regent in the garden, the House of Knowledge and Ibn
al-Haytham's feigned madness, the destruction of the Holy Sepulchre, al-Hakim's
disappearance in the Muqattam hills (a chapter ends his reign; the Druze still await him),
Nasir-i Khusraw's Cairo, the Great Calamity, and Badr al-Jamali. Al-Hakim, al-Zahir and
al-Mustansir in their real years. All seven chapters play.

## D-156 A third chronicle for 264 BC: the Seleucids — DELEGATED (2026-10-03)
Nine chapters from Antiochus II to Antiochus III: Berenice's dowry, the Laodicean war, the
young king against Molon, Raphia's elephants, the eastern anabasis, Panium, Hannibal at
court, Magnesia, and the death at the temple of Bel (a chapter ends that reign). Six kings
in their real years, with Seleucus II's fall from his horse and Seleucus III's murder as
history records. All nine chapters play.

## D-157 A fourth chronicle for 264 BC: the Ptolemies — DELEGATED (2026-10-03)
Five chapters of Alexandria's golden age: the Library's seized books, Ptolemy III's march
to avenge his sister (and the Lock of Berenice), Eratosthenes measuring the Earth, the
Egyptian phalanx at Raphia (and the revolts it led to), and the Memphis decree that became
the Rosetta Stone. Four Ptolemies in their real years. The Syrian expedition takes the coast
without an open-ended war (peace came in 241); the Seleucid AI still fights its scripted
Syrian Wars, so a passive Egypt loses ground, as an active one need not. All five chapters
play.

## D-158 Chronicles are easy to find in the picker — DELEGATED (2026-10-03)
With 29 chronicles, a player could only discover one by clicking each state. Now every
state with a chronicle wears a small gold seal on its shield showing its number of
chapters (and its tooltip says so), and those states come first in the row of shields.

## D-159 A fourth chronicle for 1560: Joseon and the Imjin War — DELEGATED (2026-10-03)
Ten chapters from King Seonjo's accession (1567) to Noryang (1598): the sarim scholars and
Yi Hwang, the split into Easterners and Westerners, Yi I's plea for a hundred thousand
soldiers, the envoys who came back from Japan disagreeing, Yi Sun-sin's turtle ships, the
fall of Busan and the flight from Hanyang, Hansan Island, the Ming relief army, the twelve
ships at Myeongnyang and Yi's death at Noryang. Myeongjong dies in 1566 and Seonjo rules to
1608, as in history. The invasion strips Joseon to two provinces and the Ming return them,
so the benchmark follows the real war; all ten chapters play on two seeds.

## D-160 A fourth chronicle for 1206: Goryeo — DELEGATED (2026-10-03)
Ten chapters from 1211 to 1274, told to the kings while the Choe dictators rule: Huijong's
failed palace plot against Choe Chung-heon (Choe hid behind a paper screen; the king was deposed),
the brotherhood with the Mongols at Gangdong, Pak Seo's defence of Guju, the flight to
Ganghwa Island, the first book printed with cast metal type, the carving of the Tripitaka
Koreana, the fall of the last Choe, the crown prince's meeting with Kublai, the
Sambyeolcho revolt (and the northwest lost to the Mongols, as in history), and the fleet
built for the invasion of Japan. Five kings in their real years (Huijong's reign ends in
the chapter; the others die when they did). All ten chapters play on two seeds.

## D-161 A fifth chronicle for 1206: the fall of the Jurchen Jin — DELEGATED (2026-10-03)
Ten chapters, 1206-1234, from the other side of the Mongol conquest: Han Tuozhou's head
and the peace of 1208, Genghis Khan spitting at the news of Yongji's accession and the
Badger's Mouth, Hushahu the kingmaker, the princess paid to the Khan and the flight to
Kaifeng (Zhongdu and Liaoxi go to the Mongols in the historical choice), Puxian Wannu's
breakaway kingdom (Liaodong and the Jurchen homeland pass to nobody), the war on the Song
for lost revenue, Aizong's peace on two fronts, the Loyal and Filial Army, the gunpowder
bombs of Kaifeng, and Caizhou. Six emperors in their real years; Xuanzong's death (January
1224) is set a year early so that Aizong is on the throne at the 1224 chapter on the
three-year turn grid. All ten chapters play on three seeds; a passive Jin outlasts history,
because the Mongol AI does not press as hard as the real Mongols did.

## D-162 A sixth chronicle for 1206: Western Xia — DELEGATED (2026-10-03)
Seven chapters, 1206-1227, of the kingdom the Mongols erased: Huanzong deposed by his
cousin and his own mother, the Yellow River dyke that flooded Genghis Khan's camp, the
examination champion who became emperor and turned on the Jin, Asha Gambu's "if he has
not enough soldiers", the peace of brothers with the Jin, the frozen river at Lingzhou and
the month's grace at Zhongxing, while the Khan lay dead. Five rulers in their real years:
the reigns end by coup, coup, abdication, death and execution, each in the year it did.
The Hexi corridor and the Ordos pass to the Mongols in the historical choice at Lingzhou.
All seven chapters play on two seeds.

## D-163 A fourth chronicle for 1275 BC: Kassite Babylon — DELEGATED (2026-10-03)
Nine chapters over 110 years, 1266-1155 BC: Kadashman-Turgu's offer to Hattusili, the
vizier who froze the Hittites out, Sin-leqi-unninni's standard Gilgamesh, the foundation
inscription Nabonidus would dig up seven centuries later, Tukulti-Ninurta's sack of
Babylon (the capital goes to Assyria in the historical choice), the nobles' revolt that
put Adad-shuma-usur on the throne (Babylon taken back), Meli-Shipak's daughter sent to
Susa, Shutruk-Nakhunte carrying Hammurabi's stele to Susa, and Marduk taken to Elam.
Thirteen kings in their real years (Brinkman's dates), including the three Assyrian-era
puppets who each fall in turn; where a death fell between turns, the turn grid already
put the right king on the throne, so no date needed shifting. Gilgamesh's editor is
dated only "Kassite period"; the history note says so. All nine chapters play on two seeds.

## D-164 A fifth chronicle for 1275 BC: Mycenae — DELEGATED (2026-10-03)
Six chapters, 1251-1180 BC, built only on what documents and digs show, not on Homer:
the Tawagalawa letter about Piyamaradu (the one time a Greek king was a Hittite 'brother'),
the Lion Gate, Linear B accounts (preserved only because the palaces burned), Millawanda
lost to Tudhaliya IV (and 'Ahhiyawa' rubbed out of the Sausgamuwa treaty), the hidden
cistern and the Isthmus wall as Thebes burns, and the Pylos tablets' 'watchers guarding
the coast' before the palace fell. No Mycenaean king's name survives from his own time,
so the ruler stays unnamed ('the wanax'). Where a historical answer is unknown (how the
king answered Hattusili), the choice taken is the one the later letters imply, and the
history note says that the answer is unknown. All six chapters play on two seeds.

## D-165 A third chronicle for 336 BC: Athens — DELEGATED (2026-10-03)
Nine chapters, 336-322 BC, of the last free years of the democracy: Demosthenes's garland
for Philip's murder, Thebes left to its fate, Alexander's demand for the orators (and
Demades's fee), Lycurgus's stone theatre and the official texts of the tragedians (the
ones Ptolemy III later kept: the two chronicles point at each other), Agis's war, On the
Crown, Harpalus's gold, the Lamian War and Antipater's terms. Athens had no king, so the
"ruler" is the leading statesman: Demosthenes until his conviction in 324, Hyperides until
his execution in 322, Phocion until his hemlock in 318, then Demetrius of Phalerum. The
Lamian War is told with grudges and men, not an open-ended war, so a one-province Athens is
not swallowed by the Macedon AI (the lesson of D-149/D-150). All nine chapters play on two
seeds.

## D-166 A fourth chronicle for 336 BC: Epirus and Pyrrhus — DELEGATED (2026-10-03)
Twelve chapters across 64 years, 336-272 BC: Philip murdered at Alexander of Epirus's
wedding, the call from Tarentum and the oracle of Acheron and Pandosia, the first Greek
treaty with Rome, the death at the river, the infant Pyrrhus at the Illyrian king's knees,
Ipsus, Cineas's "why not rest now?", Heraclea and the Senate "of kings", Asculum (the
Pyrrhic victory), Sicily, Beneventum and the roof tile at Argos. Magna Graecia and western
Sicily are taken and lost in the historical choices, so the benchmark tracks both Italian
adventures. Five kings: Alexander I and Aeacides end in chapters, Alcetas II is murdered
in 307, and Pyrrhus rules from 306 to his death. Pyrrhus's five years of exile (302-297)
are folded into the Ipsus chapter's outcome rather than modelled as a second reign. All
twelve chapters play on two seeds.

## D-167 A fourth chronicle for AD 400: Northern Wei — DELEGATED (2026-10-03)
Thirteen chapters over 92 years, 402-494, of the Xianbei emperors who reunited the north
and then made themselves Chinese: Chaibi, the custom of killing the heir's mother (and
Daowu's murder), Liu Yu's crescent formation, the siege of Hulao, the boy emperor at
Shengle, the White City, the Gobi campaign, Northern Yan's fall, the persecution of
Buddhism, Cui Hao's history in stone, the Yungang Buddhas, the equal-field law and the move
to Luoyang. Luoyang, the Ordos, Chang'an, Longcheng and Youzhou are taken in historical
choices, so the benchmark rises from three provinces to eight as the real Wei's did (the
conquest of Shandong in 469 is not modelled). Seven emperors in their real years; the
short-lived Prince of Nan'an (452) is skipped. All thirteen chapters play on two seeds;
a passive Wei loses a province to a late uprising, as passive players do elsewhere.

## D-168 An eighth chronicle for AD 1000: Denmark — DELEGATED (2026-10-03)
Ten chapters, 1000-1035, from the Danish side of the England chronicle: Svolder, revenge
for St Brice's Day, Sweyn's forty days as King of England, Harald II's fleet for his
brother, Olaf the Saint taking Norway, Cnut's letter to the English, the Holy River and
Ulf's murder, Cnut walking beside the emperor in Rome, Norway bought with English silver,
and "Aelfgifu's time". Norway is a tributary from Svolder to Nesjar and again from 1028 to
1035. Cnut's England is modelled as an ally, not a tributary: in testing, a tributary
England with an old grudge declared war on Denmark in 1030, which is the opposite of
Cnut's reign; as one king's two realms, an alliance holds. Sweyn's death (3 February 1014)
is set to 1013 so that Harald is king at the 1014 chapter; Harald II's death is uncertain
(c. 1018) and set to 1017 so that Cnut is king at the 1019 chapter. All ten chapters play
on three seeds.

## D-169 A ninth chronicle for AD 1000: Piast Poland — DELEGATED (2026-10-03)
Nine chapters, 1000-1054: the Congress of Gniezno, the blinded duke of Bohemia, the Peace
of Bautzen, the Golden Gate of Kiev (the Cherven towns, Volhynia on this map, are taken),
Bolesław's coronation, the double invasion of 1031 that broke Mieszko II (Volhynia goes
back to Rus), Bretislav carrying off St Adalbert's body (Silesia goes to Bohemia; Kraków
becomes the capital), Masław of Masovia, and Silesia regained at Quedlinburg for a
tribute. Mieszko II appears twice in the line of rulers, either side of Bezprym's year,
as he really reigned. Masław's Masovia stays on the Polish map, because one choice can
pass provinces to only one state; the story says it was his. All nine chapters play on
two seeds. This is the Polish side of the Rus chronicle's 1018 (D-149).

## D-170 A tenth chronicle for AD 1000: Hungary — DELEGATED (2026-10-03)
Ten chapters, 1000-1055: the crown from Rome rather than Constantinople, Gyula's
Transylvania, the pilgrims' road to Jerusalem, Ajtony's salt tolls and Bishop Gerard,
Conrad II starved out, Prince Imre's death and the blinding of Vazul, Peter "the
Venetian" driven out, Ménfő, the Vata rising and Gerard's martyrdom, and the Tihany
charter with the oldest written Hungarian sentence. Six reigns in eleven years after
Stephen: Peter Orseolo appears twice in the line (1038-41, 1044-46), either side of Samuel
Aba, and each reign ends in its chapter. Legends (Kund the diver, Vazul's plot) are told
as "it is said". All ten chapters play on two seeds.

## D-171 An eleventh chronicle for AD 1000: the Ghaznavids — DELEGATED (2026-10-03)
Nine chapters, 1000-1040: Jayapala's pyre, Firdawsi paid in silver (told as the later
tradition it is), al-Biruni carried off from Khwarazm, Mathura and Kannauj, Somnath, the
Turkmen let into Khorasan, the library of Rayy (Jibal is taken), al-Biruni refusing an
elephant-load of silver for the Masudic Canon, and Dandanaqan. The map has no India, so
the raids are told in outcomes as wealth and legitimacy; Khorasan stands for the
Ghaznavid heartland. The raids on Hindu temples are told plainly, as the sources and
their modern critics (Thapar) tell them, with the rebuilding and the long memory, neither
celebrated nor softened. Mahmud dies in 1030 and Masud's reign ends at Dandanaqan; his
brother Muhammad's months on the throne in 1030 are left out. All nine chapters play on
two seeds.

## D-172 A twelfth chronicle for AD 1000: Ireland — DELEGATED (2026-10-03)
Eight chapters, 1000-1064: Christmas in Dublin after Glenmama, Máel Sechnaill's
submission, "Imperator Scottorum" in the Book of Armagh, the hostages of the north, the
chess game at Kincora and the failed siege of Dublin, Clontarf (Brian dies in his tent;
the north, Ulster on this map, slips away), Donnchad's law of 1040, and Donnchad's last
road to Rome. The Cogad and Njal's saga are a century later and partisan, so their
stories (the chess game, Brodir) are told as the saga's, beside what the annals say.
Brian is spared old age until Clontarf; Donnchad until his fall in 1063-64. All eight
chapters play on three seeds.

## D-173 A thirteenth chronicle for AD 1000: Venice — DELEGATED (2026-10-03)
Seven chapters, 1000-1084: Pietro II Orseolo's Ascension Day voyage down the Dalmatian
coast, the Byzantine princess with the golden fork, the fall of the Orseolo, the law
against co-doges, the new St Mark's on the model of the Holy Apostles, Alexios I's Golden
Bull, and the defeat off Corfu. Seven doges in their real years; the elected doges are
the "rulers" (an "Otto Orseolo ... takes the throne" message is a small stretch for an
elected office). Alliances with Byzantium were left out of the deeds: a two-province
Venice allied to Byzantium would be dragged into Basil II's Bulgarian war (the lesson of
D-149/D-150). All seven chapters play on two seeds.

## D-174 A fifth chronicle for 1560: the late Ming — DELEGATED (2026-10-03)
Ten chapters, 1561-1619: Qi Jiguang's Yiwu army against the wokou, Hai Rui's memorial
and his coffin, Moon Harbour and the silver trade, the Altan Khan peace, Zhang Juzheng's
land survey and his posthumous disgrace, Wanli's thirty-year "strike", the Korean war,
Matteo Ricci's clocks, and Sarhu (Liaodong is lost in the historical choice). Three
emperors in their real years: Jiajing (died January 1567, set to 1566, the Chinese year),
Longqing and Wanli; Taichang's month on the throne follows. Ray Huang's "1587" is the
guiding modern source for Wanli's reign. All ten chapters play on two seeds.

## D-175 A fifth chronicle for 264 BC: Syracuse — DELEGATED (2026-10-03)
Nine chapters, 263-212 BC: Hiero changing sides to Rome, his tithe law (which Rome kept),
Archimedes and the crown (told as Vitruvius's story), grain for Carthage in the Mercenary
War (Polybius's balance-of-power remark), the Syracusia sent to Ptolemy, the golden
Victory sent to Rome after Cannae, Hieronymus going over to Carthage, Archimedes' claws,
and the fall of the city. Hiero dies at ninety-one in 215, Hieronymus is killed at
Leontini in 214, and the general Epicydes leads until the fall; the "burning mirrors" are
left out as a later story. Its chapters point at the Carthage, Rome and Ptolemy
chronicles. All nine chapters play on two seeds.
