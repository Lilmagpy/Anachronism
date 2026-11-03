# Urbs: common brief for the city agents (read all of it first)

## The project
"Meritus" (code name anachronism): a turn-based historical strategy game, Rome only, 509-27 BC.
Python engine in `src/anachronism/`, Godot 4.5 client in `client/`. The owner wants **the real
city of Rome you can walk into**: zoom from the map to street level, click a building, go
inside, watch what happened there (chariot races, games, the Senate, sacrifices, triumphs).

Read first: `CLAUDE.md`, `docs/plans/city.md` (the plan), `data/rome/city/README.md` (the
dataset), `client/scripts/urbs/geo.gd` (the coordinate frame), and the header of
`client/scripts/urbs/urbs.gd` (the scene, its flags and the interface every builder keeps).

## Rules for everyone
- **Accuracy above everything.** Every historical fact carries its source (ancient author and
  passage, or `Platner-Ashby s.v. ...`). Fetch the passage and read it (LacusCurtius for
  Polybius, Plutarch, Dio, Platner-Ashby; Perseus or Gutenberg for Livy). If you cannot read
  it, write `# unverified` next to the citation. Never invent a building, a date, a size or a
  ritual detail. Where scholars disagree, say so.
- **Licences:** public domain or openly licensed sources only; paraphrase. Rome Reborn is
  commercial: visual reference only, nothing copied. Pleiades is CC BY (attribute it).
- **Coordinates:** `UrbsGeo.to_local(lat, lon)` gives local metres (x east, z south), y is
  height above sea level in metres, 1 unit = 1 metre. The ancient Forum floor is about y = 10.
  Never invent another frame.
- **Data lives in `data/rome/city/*.yaml`** and reaches Godot as `client/data/city/*.json`
  via `uv run anachronism-city-export` (run it after editing YAML and commit the JSON).
- **Godot:** binary `/tmp/claude-0/godot` (4.5.1). Parse-check every script you touch:
  `cd client && /tmp/claude-0/godot --headless --path . --check-only -s res://scripts/urbs/X.gd`.
  After adding a script with a new `class_name`, run `/tmp/claude-0/godot --headless --path . --import`
  once. Render screenshots through the shared queue (max 3 at once on this 4-core machine):
  `cd client && /tmp/claude-0/render.sh --path . -- <game args> --screenshot=/tmp/claude-0/<you>.png`.
  A render takes 2-6 minutes; if the queue is full it waits. Look at your screenshots (Read
  the PNG) and fix what looks wrong. The smoke test `godot --headless --path . -- --smoke` must
  still print `SMOKE OK`.
- **Procedural meshes:** the client builds everything from code (`client/scripts/models/*.gd`,
  `roman.gd` for the Roman kit, `Kit` in `kenney_kit.gd`: boxes, columns, arches, roofs).
- **Performance:** the city is 4 km across with thousands of buildings; MultiMesh for repeated
  parts, chunked loading by distance, LOD. Aim for 60 fps at 1600x900 on a laptop GPU.
- **Edit only the files your task names.** Other agents work in parallel in other worktrees.
  Never touch other worktrees or `/home/user/anachronism`. Shared files (`main.gd`, `hud.gd`,
  `project.godot`) belong to nobody this round: if you need a hook, say so in your report.
- **Python:** `uv run ruff check . && uv run ruff format . && uv run mypy` and the relevant
  `uv run pytest -q tests/...` must pass. `uv run anachronism-lint` for content.
- **Commit AND PUSH** in small batches on your branch in your worktree, message ending:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01S4H1oAxyYWS6R8Xwk3CuAJ
  ```
  After every commit: `git push -u origin <your branch>`. **This is mandatory**: the cloud
  container was wiped once and a whole day of unpushed agent work was lost. Only ever push
  your own branch, never `claude/phase-2-3d` or `main`.
- **Final report:** what you made, the counts, the sources read, what is `# unverified`, any
  hooks the lead must wire, and the screenshots' paths.
