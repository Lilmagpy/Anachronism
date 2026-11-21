# data/rome/city: dataset for the 3D city of Rome (phase R5)

Not loaded by the game yet. Covers the city between 509 and 27 BC (a few Augustan items
begun in range but finished slightly later are kept, flagged in their `built` text).

## Files
- `monuments.yaml`: top-level key `monuments`, a list of structures.
- `population.yaml`: census figures, grain dole, city-population estimates, built-up area.
- `topography.yaml`: hills, valleys, Tiber, Campus Martius.
- `streets.yaml`: 30 streets and roads as `[lat, lon]` polylines with width, `exists_from`, `paved_from` (Livy 41.27.5: city streets paved with silex from 174 BC), precision and sources.
- `regions.yaml`: the 14 Augustan regiones and 4 Servian regions (rough polygons, Platner-Ashby s.v. Regiones) and the `districts` (circles with building-type mix per era) that drive the 3D fill.

## Monument fields
| field | meaning |
|---|---|
| `id` | unique snake_case id |
| `latin`, `english` | names |
| `type` | temple, basilica, forum, portico, aqueduct, bridge, wall, gate, theatre, circus, curia, comitium, rostra, horrea, market, arch, road, sewer, house, tomb, ... |
| `regio` | later Augustan regio number (1-14); `0` means outside the regions (walls, aqueducts, roads) |
| `lat`, `lon` | WGS84 degrees, representative point |
| `precision` | `exact` (identified remains, a few metres), `approx` (100-300 m), `rough` (site only known by area, 300 m or worse) |
| `location` | plain-text place description |
| `built` | `{year, certainty, by}`: negative year = BC; `null` if unknown; certainty is `certain`, `probable`, `traditional` (legend or late tradition) or `uncertain`; `by` names the builder and office and the source of the claim |
| `events` | list of `{year, what}`: rebuilds, fires, destructions |
| `ended` | `{year, what}` if it went out of use before 27 BC |
| `form`, `materials` | size and shape; building materials (tufa, travertine, concrete, marble) |
| `route` | `[[lat, lon], ...]` point list for linear features (aqueducts, sewer, wall, roads) |
| `sources` | ancient authors and `Platner-Ashby s.v. ...` entries |
| `pleiades` | Pleiades id where known, else `null` (not yet cross-checked; Pleiades data is CC BY) |
| `notes` | doubts and disagreements |
| `location_confidence` | (F2) `high` (on identified remains), `medium` (placed from a description that fixes the site within about 50 m) or `low` (an argued site: `location_source` says whose argument it is) |
| `location_source` | (F2) where the position comes from: the remains (Pleiades id, OpenStreetMap outline) or the passage that places it |
| `twin_of` | the Republican record an Empire record continues (`monuments_empire.yaml`): the twin is drawn only while that record is absent, so one building is never drawn twice |
| `route_measured` | (F2, `murus_servianus` only) the gate circuit with the bends of the surviving stretches; not drawn yet |

## Method and caveats
- Primary source: Platner and Ashby, *A Topographical Dictionary of Ancient Rome* (1929, public domain; LacusCurtius). Dates come from Livy, Dionysius, Frontinus, Plutarch, Dio, Suetonius and Cicero as cited on each entry. Text is paraphrased.
- **Coordinates are estimates**, placed from the identified standing or excavated remains where these exist (Forum, Largo Argentina, Theatre of Marcellus, bridges, Circus Maximus) and from Platner-Ashby / Lanciani's *Forma Urbis Romae* descriptions elsewhere. The Servian gates, many Capitoline and Quirinal temples, Navalia, the houses and the aqueduct source points are `rough`. Pleiades coordinates were cross-checked in F2 (see below).
- Citations were written from knowledge of the sources and many individual passage numbers have not been re-read on LacusCurtius. Treat passage numbers marked or doubtful as to be verified. Entries with `certainty: uncertain` or `precision: rough` need review.
- **F2 city audit** (`uv run anachronism-city-audit`, report in `docs/reports/city_audit.md`, data in `audit.json`): compares the dataset with Pleiades (places within 3.5 km of the Forum, CC BY; extract in `data/rome/sources/pleiades_rome.json`) and Platner-Ashby (public domain; `data/rome/sources/platner_ashby.json`) for completeness, position, orientation, size, the relations the sources fix, the built Godot scene (`--scene`) and dates. The curated verdicts and the explanations of what remains flagged are in `data/rome/sources/references.yaml`. Since F2 the Pleiades positions have been cross-checked: a record matched to Pleiades is within 20 m of the remains (10 m on the Forum and Capitol) or the report says why not.
- **F2 terraces**: where the ground falls more than 3 m under a monument, `topography.yaml` `terrain_model.platforms` has a terrace cut into the hill at the level of the monument's centre, with retaining and substructure walls (the block between `# F2 TERRACES` and `# END F2 TERRACES`, written by `uv run anachronism-city-audit --scene --terraces`; it keeps what it wrote before and adds new ones). The terraces are the modeller's: the Romans terraced their hills, but these outlines are the monuments' footprints grown by 6 m, not excavated terraces. A terrace exists in every year, also before its monument is built. Below 3 m, `monuments.gd` stands the monument on a podium or foundation down to its lowest ground.
- Heights and floor levels in topography are approximate modern values; the ancient valley floors were lower than today.
