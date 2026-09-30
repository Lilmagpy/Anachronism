# Phase 2 plan: the 3D world

Owner decisions: modern 3D world (D-047), built before the LLM layer (D-049).

## Shape
```
client/ (Godot 4, GDScript)  ──starts──▶  uv run anachronism-server  (Python, tools/server.py)
   renders, animates, UI      ◀── one JSON message per line on stdin/stdout ──▶  engine (unchanged)
```
- The client never computes rules. It shows a *view* built by the server and sends actions.
- Requests: `{"id": 1, "cmd": "new_game", "args": {...}}` → `{"id": 1, "ok": true, "result": {...}}`
  or `{"id": 1, "ok": false, "error": "..."}`. Commands: `new_game`, `view`, `act`,
  `end_turn`, `save`, `load`, `quit`.
- The view is plain JSON for the player's civilisation: status and trends, provinces
  (owner, population, terrain, resources, position), ideas with feasibility and costs,
  projects, the latest events, other civilisations' public facts.

## Map layout (content)
Each province gets a `position` (x, y in map units) in content; the loader checks that every
province in a scenario has one. The client builds terrain from it: each point of the ground
belongs to its nearest province (a Voronoi map), takes that province's terrain type for height
and colour, adds noise for relief, and becomes sea beyond the land's edge. Rivers follow
`river` provinces toward the coast. Borders are drawn where neighbouring points have different
owners, in the owner's colour.

## Client milestones
1. Terrain, water, sky, sun, camera (pan, zoom, orbit), screenshots from the cloud.
2. Borders, labels, hover and selection with a province card.
3. UI: top bar (people, stores, labour, unrest, suspicion with trend arrows), ideas panel
   with costs and blockers, project list with progress, End Turn, event log.
4. Settlements and scenery: villages, towns and cities sized by population; forests,
   farms and herds by terrain; openly licensed (CC0) models, licences recorded.
5. CI exports a macOS app; the owner downloads it from the pull request.

## Tests
- Python: the server protocol (every command, bad input, error replies), view contents.
- Client: headless smoke test in CI (the project opens, a scripted session renders frames,
  no script errors), plus screenshots attached for the owner at each milestone.

## Risks
- Bundling Python inside the Mac app: first builds may ask the owner to have `uv` installed;
  a fully self-contained app is the target by the gate.
- Cloud screenshots use software rendering; the Mac shows higher quality.
