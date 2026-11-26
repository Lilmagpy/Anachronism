# F3: no overlaps, no glitches, anywhere in the city (read all of it first)

The owner (2026-11-21): "There are so many screenshots where there are clear overlaps in
buildings and the graphics are glitched. Go through everything and ensure that this is fixed
fully." The F2 audit made the DATA right (nothing missing or misplaced against Pleiades and
Platner-Ashby; monuments' solid boxes not buried, floating or built over). This round makes the
PICTURE right: what the player sees at any spot, in any year.

Read first: `CLAUDE.md`, `docs/plans/briefs/urbs.md` (rules, Godot, render queue), the F2 report
`docs/reports/city_audit.md` and its tool `src/anachronism/tools/city_audit.py` + the scene audit
`client/scripts/urbs/audit.gd`, and the headers of `urbs.gd`, `monuments.gd`, `fill.gd`,
`site.gd`, `site_flora.gd`, `terrain.gd`, `tiber.gd`, `streets.gd`, `life.gd`, `interiors.gd`.

## The tools
- **The sweep** (`client/scripts/urbs/sweep.gd`): one Godot run opens the city and photographs a
  list of viewpoints. Pose files from `python3 scripts/dev/sweep_poses.py <dir>`
  (`monuments.json`: every standing monument's front; `street_NN.json`: a grid of eye-height views
  in batches of 60; `air_NN.json`: a grid of low aerials, four bearings). Run, at 1280x720:
  `cd client && /tmp/claude-0/render.sh --path . --resolution 1280x720 -- --urbs --year=-44
  --mode=city --at=0,0,400 --hour=10 --sweep=<poses.json> --sweep-out=<dir> --screenshot=<dir>/x.png`
  Each shot prints `SWEEP <name> x z y`. About 2 minutes to open the city, then a few seconds per
  shot. The 15-minute queue limit allows about 100 shots per run: split big pose files.
- **Reviewing the pictures costs tokens.** Make contact sheets (2x2 or 3x2 tiles at half size,
  labelled with the shot name; Pillow is available via `uv run --no-project --with pillow`), look
  at each sheet, and open a full-size shot only where a sheet shows something wrong.
- **The code checks**: extend `city_audit.py --scene` / `audit.gd` with every check that finds a
  class of fault by geometry, so the fix can be proved and stays fixed: house against house,
  house against terrace wall or platform, tree inside a building, a street or the river; people,
  stalls and carts inside solids; parts of one monument intersecting another monument's parts
  (use the real mesh AABBs of the parts, not one box per monument); surfaces at the same height
  in the same place (z-fighting: paving over ground, two platforms); geometry under the river
  surface showing through; holes in the ground; cameras of the standard views and of every
  monument's `--at` view inside a solid.

## What "glitched" means here (fix every one you see, at its cause)
Buildings intersecting buildings (monument with monument, house with monument, house with
house), roofs through walls, parts floating or sunk, flickering where two surfaces meet
(z-fighting), saw-tooth edges (the river banks), black or unlit ground, terrace walls running
across empty hillsides, pavings that stop short of the buildings they belong to, trees through
roofs, people walking through walls, stalls in streets' carriageways, a camera inside a wall,
a monument's card view not showing its monument, interiors with gaps, black voids or furniture
through walls. Known from the lead's own look on 2026-11-21: Saturn's `--at` view faces along
its podium, not its front; the Forum paving (120 x 56 m) stops short of the Basilica Aemilia
and Iulia steps; the Tiber banks are saw-toothed; on the 509 BC hills, terrace walls run across
empty slopes; the Area Capitolina's front stands ~20 m over the Clivus Capitolinus cutting.

## Rules
- Fix causes, not single instances: a fault seen once is usually a rule that is wrong
  everywhere. Each fix gets a code check if a check can see it.
- Years to sweep: 509, 264, 133, 44 BC (and 27 BC for the monuments).
- Report before/after: the count of faults the review found per sweep, and the code checks'
  counts. Keep contact sheets of before and after in `/tmp/claude-0/f3/<you>/` and name the
  worst five before/after pairs in your report.
- Accuracy is not traded for looks: never move a monument off its sourced place to hide an
  overlap. Where two sourced buildings truly overlap, say so in the report.
- Edit only the files your task names; marked blocks elsewhere. Commit in small batches and push
  after every commit (you may be paused by usage limits). `--smoke` prints SMOKE OK; parse-check;
  `scripts/check.sh` before the final report. Trailer: `Co-Authored-By: Claude Opus 5.5
  <noreply@anthropic.com>` then `Claude-Session: https://claude.ai/code/session_01S4H1oAxyYWS6R8Xwk3CuAJ`.
