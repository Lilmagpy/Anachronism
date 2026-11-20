# F2: everything that should be in Rome is there, and in the right place

The owner (2026-11-20): "I'm almost less concerned on it looking crazy graphically as much as I
care that everything that is meant to be there is there and it is in the right place, and that
is something that you can undoubtedly do with code."

Read first: `CLAUDE.md`, `docs/plans/briefs/urbs.md` (rules, Godot, render queue, sources,
commit+push), `docs/plans/city.md`, `data/rome/city/README.md`, `client/scripts/urbs/geo.gd`
(the frame: `UrbsGeo.to_local(lat, lon)`, origin 41.8925 N 12.4853 E, x east, z south, metres),
the header of `client/scripts/urbs/urbs.gd`, `monuments.gd` (how a record's lat/lon, `offset_m`,
`bearing_deg`, `footprint_m`, `model` become a placed building), and `docs/DECISIONS.md`
D-289 to D-299.

## The job: a measured audit, then the fixes
Build the audit as code that can be re-run (`uv run anachronism-city-audit`, a new tool in
`src/anachronism/tools/city_audit.py` with tests), not a one-off reading. It writes
`docs/reports/city_audit.md` (human) and `data/rome/city/audit.json` (machine). Then fix every
finding in the data, and re-run until the report is clean or each remaining item is explained.

### 1. Completeness: is everything there?
- Reference lists: (a) **Pleiades** (CC BY: attribute; the dump at
  `https://atlantides.org/downloads/pleiades/dumps/pleiades-places-latest.csv.gz`, reachable from
  this machine): every place within 3.5 km of the Forum with a time period before AD 120;
  (b) **Platner-Ashby** (public domain; LacusCurtius `penelope.uchicago.edu/Thayer/E/Gazetteer/
  Places/Europe/Italy/Lazio/Roma/Rome/_Texts/PLATOP*/` is up today, archive.org has the full text):
  every entry that is a building, monument, street, gate, bridge, aqueduct, altar, grove, statue
  base or shrine with a date or reign before AD 120. Cache downloads under `data/rome/sources/`
  only if their licence allows it (Pleiades CC BY yes, with attribution in the README; P-A is
  public domain); keep the raw dumps out of git if large (store a trimmed, filtered extract).
- Match each reference entry to a dataset record (by name variants, Pleiades id, P-A s.v.).
  Output: **missing** (in the references, not in our data), grouped by kind and period, ranked
  by importance (how many sources mention it; whether it stood in the Forum, Capitol, Palatine,
  Circus, Campus Martius core; whether events in the game happen there).
- Add the missing ones to `monuments.yaml` / `monuments_empire.yaml` with the full record
  format (dates, location, footprint, bearing, model key, sources, `verified`), using an existing
  model key where one fits (temple types, altar, shrine, portico, statue base, arch, fountain).
  Target: every Republican temple, altar, shrine, basilica, portico, arch, gate, bridge and
  public building that Platner-Ashby dates before 27 BC with a known or arguable location; and
  the major imperial buildings to AD 120. Where a location is unknown in the sources, record the
  argued location with `location_confidence: low` and say whose argument it is; never invent.

### 2. Position: is everything where it stood?
- For every record with a Pleiades id or known remains, compare our placed centre (lat/lon plus
  `offset_m`, as `monuments.gd` places it; port that arithmetic to Python and test it against
  `UrbsGeo`) with the reference coordinates; report the distance and flag over 20 m (over 10 m
  for the Forum and Capitol). Pleiades precision varies: report its own accuracy value and do not
  "fix" ours toward a rougher reference.
- Orientation: bearings from the excavated plans where known (Platner-Ashby and the remains
  visible today; e.g. the Forum temples, the Curia, the Basilicae, the Circus, the Theatre of
  Pompey, the Pantheon); flag differences over 10 degrees.
- Size: footprint vs published dimensions; flag over 15%.
- Relations the sources fix: Saturn at the foot of the Clivus Capitolinus; Castor beside the
  Lacus Iuturnae; the Regia and Vesta at the Sacra Via's east end; the Curia on the Comitium's
  north side; the Rostra between Comitium and Forum; the Basilica Aemilia north and Iulia south
  of the Forum; the Carcer under the Capitol; the Circus between Palatine and Aventine with its
  carceres at the west; the Servian gates on the wall's line; bridges spanning the river;
  aqueducts entering where the sources say (Aqua Appia at the Porta Capena, ad Salinas).
  Encode these as checks.
- Topography: the hills' summit heights and the valley floors against `topography.yaml` and the
  modern DEM minus known fill; the river's course against the modern Tiber (bridges); the
  Servian wall's course through its gates.

### 3. Placement in the built scene: nothing overlapping, buried or floating
Add a Godot audit mode to `monuments.gd` or a new `client/scripts/urbs/audit.gd` run by a flag
(`--urbs-audit=YEAR` prints JSON and quits): for each year 509, 390, 264, 133, 44 and 27 BC, list
monuments whose solid boxes overlap another standing monument; monuments whose base is more than
0.5 m above or 1 m below the ground under any corner; houses standing inside a monument's
footprint or on a street; monuments inside the river; streets passing through monuments. Feed
its output into the report and fix the causes.

### 4. Time: is everything there in the right year?
Each record's built/destroyed/rebuilt dates against the sources (the Fasti dedication dates,
Livy's notices); the dataset's `events` and `rome/city_timeline.yaml` must agree; a building
must not stand before it was built or after it was destroyed (render 509, 390, 264, 133, 44 BC
and check the counts per year in the report).

## Rules
- Edit only: `data/rome/city/*.yaml` (+ exported JSON via `uv run anachronism-city-export`),
  `src/anachronism/tools/city_audit.py` (new, plus its `pyproject.toml` script entry, a marked
  one-line addition), `tests/tools/test_city_audit.py`, `client/scripts/urbs/audit.gd` (new) and
  a marked hook block in `monuments.gd` or `urbs.gd` for the flag, `docs/reports/`,
  `data/rome/city/README.md`, `data/rome/sources/`. Not the gameplay engine.
- Every added or moved record carries its source; `# unverified` where the passage was not read.
- Screenshots before and after for the five standard views (`docs/plans/briefs/u8.md`) and one
  aerial per year (509, 264, 44 BC); look at them.
- Commit in small batches and **push after every commit** (`git push -u origin claude/f2-accuracy`).
  Trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` then
  `Claude-Session: https://claude.ai/code/session_01S4H1oAxyYWS6R8Xwk3CuAJ`.
- Final report: counts before/after (missing, misplaced, overlapping, buried), what was added,
  what was moved and by how much, what stays unresolved and why, screenshot paths.
