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
a conquered people thinks of itself as its rulers.
own. The province card says whose people live there, how long ago they were conquered,
and what garrison holds them. Empires now cost soldiers to keep, not only to win.
