# Content Guide

How to author content packs. Written for Phase 1 (tech nodes, map, civs, scenarios, rules);
scripts, relations, rulers and the timeline are added in Phases 4-5.

## Principles
- All content is YAML in `src/anachronism/content/packs/<pack>/`. Every file starts with
  `schema_version: 1` and holds exactly one kind: `rules`, `eras`, `effect_caps`, `terrain`,
  `resources`, `techs`, `provinces`, `civs` or `scenarios`. Split files however is clearest.
- Run `uv run anachronism-lint` after every change. It lists every problem with its file and
  location, e.g. `core/techs/craft.yaml: techs[3] (piston_bellows).prereqs: Extra inputs are
  not permitted` (a misspelt field). It must report zero problems.
- Ids are lower-case `snake_case` and unique within their kind across all loaded packs.
- Numbers are integers. Percentages and 0-100 stats are **basis points**: `100 = 1%` or one
  point, `10000 = 100%`. Field names say so with `_bp` where it is not obvious.
- Facts in shipped data need a `sources:` note (internal, never shown to players), and
  advancements, civilisations and scenarios carry a `confidence:` tier (`high` / `medium` /
  `low`; `low` when left out, meaning drafted and not yet checked). Contested facts: pick
  the most defensible version and note the alternatives in `sources`.
  `uv run anachronism-lint --review` lists every entry still without a source.
- LLM-drafted content goes to `drafts/` and moves into `packs/` only after owner review.
  Model memory is never the only source for a shipped fact. Licences: D-009.

## Packs
```yaml
# packs/<id>/pack.yaml — the folder name must equal the id
schema_version: 1
pack:
  id: testworld
  name: Fictional test world for engine development
  version: 1            # bump when content changes meaningfully
  depends_on: [core]    # packs this one builds on; loaded first
```
`core` holds everything shared: rules, eras, effect caps, terrain, resources and the
generic tech backbone. Region packs add provinces, civs, scenarios and region-specific techs.

## Tech nodes
```yaml
techs:
  - id: iron_working
    name: Iron working
    category: metallurgy        # agriculture metallurgy construction craft knowledge
                                # governance military trade maritime health
    year: -1200                 # first historical appearance (negative = BC); drives suspicion
    complexity: 3               # 1-5: the engine derives cost and duration from this
    visibility: 2               # 1-3: how noticeable adopting it is (suspicion multiplier)
    prerequisites: [bronze_working, charcoal_burning]    # must be adopted
    requires:
      materials: [iron]         # map resources accessible in an owned province
      literacy_bp: 0            # soft: below it, more setbacks
      widespread: []            # infrastructure that must already be widespread
    resistance: [{group: clergy, level: 1}]   # clergy / nobility / guilds, level 1-3
    effects:
      - {type: materials_output, bp: 800}     # +8%
      - {type: military_strength, bp: 1000}
    flavour: Hammered, folded, quenched. The bloom becomes a blade.
    keywords: [iron, ironworking, smithing, blacksmith, forge]   # words players might type
    sources: ["Approximate date; see D-040"]
```
- **Keywords** are how the offline court recognises a typed idea ("a blacksmith's forge"
  finds this node) and how the online court is shown related ideas. Give several everyday
  words and short phrases; multi-word phrases count most when typed exactly.
- **Effects** come from a fixed menu (DESIGN §9); anything else is rejected. Percentage
  effects: `bp: 1000` = +10%. `literacy_growth`, `unrest` and `legitimacy` are points per
  decade (`100` = one point). `suspicion` is added once, on adoption. Unlocks take a
  `target` instead of `bp` (`unlocks_resource` must name a known resource).
- Each effect type appears at most once per node. `unrest` and `legitimacy` may be negative.
- Effects are capped per era by `effect_caps.yaml`; writing a larger number is allowed (the
  node grows stronger in later eras) but the cap applies in play (D-038).
- Do not put costs or durations in nodes: the engine computes them (D-020).

## Provinces and map resources
```yaml
provinces:
  - id: veyra_heartland
    name: Veyran Heartland
    terrain: river_plains       # see terrain.yaml
    river: true                 # trade bonus
    coastal: false              # trade bonus
    capacity: 140000            # optional; overrides the terrain's default capacity
    resources: {clay: accessible, timber: limited, iron: unexplored}
    neighbours: [veyra_upper_river, veyra_delta]   # must be listed on both sides
```
Resource access: `accessible` (full), `limited` (usable, less output) or `unexplored`
(unusable until an advancement with `unlocks_resource` reveals it). Provinces hold fixed
geography only; ownership and population belong to scenarios (D-037).

### Provinces on the real Earth
Scenarios on a real map (`map: east_asia`) place provinces by latitude and longitude instead
of `position`:
```yaml
  - id: qin_guanzhong
    name: Guanzhong (Wei valley)
    latlon: [34.4, 108.9]       # degrees north, degrees east of its centre (usually its chief city)
```
Sea zones take a `latlon` too. The game divides the real land between provinces by growing
each one out from its centre, with mountains costly to cross, so borders follow ridges.
`neighbours` and `coastal` must match that division. Check them, and get the correct lists,
with:
```
godot --headless --path client -s res://tools/province_report.gd -- warring_states out.json
```
It prints every disagreement (0 problems means the content matches the map); `out.json`
holds the land neighbours of each province and the shores of each sea. If a province comes
out the wrong shape, move its `latlon` or add a neighbouring province rather than editing
borders by hand.

## Civilisations
```yaml
civs:
  - id: veyra
    name: Kingdom of Veyra
    adjective: Veyran
    lineage: veyran             # the cultural line the player follows across dynasties (D-011)
    colour: "#b5523b"
    description: A populous river kingdom of scribes, granaries and temple priests.
```
Dynasties are separate civs sharing a `lineage`. Rulers and dispositions arrive in Phase 4.

## Scenarios
```yaml
scenarios:
  - id: bronze_dawn
    name: "Test world: Bronze Dawn"
    start_year: -1200
    years_per_turn: 10
    player_civ: veyra
    civs:
      veyra:
        capital: veyra_heartland                  # must be one of its provinces
        provinces: {veyra_heartland: 110000}      # owned provinces and populations
        stockpiles: {food: 600, materials: 150, wealth: 150, knowledge: 80}
        stats: {literacy_bp: 300, unrest_bp: 800, legitimacy_bp: 6000}
        influence: {clergy: 4500, nobility: 3000, guilds: 1500}   # weight of each group
        techs: {agriculture: widespread, writing: adopted, iron_working: concept}
    unowned: {desert_oasis: 3000}                 # provinces nobody controls
```
- `map: east_asia` puts the scenario on the real Earth (every province needs a `latlon`);
  leave it out for a map generated from `position`s.
- `cost_scale: 10` multiplies every project cost. Use it when populations are real
  historical numbers (millions): the testworld's costs suit states of a few hundred thousand.
- `common_techs: {written_law: widespread}` lists what every state of the age knows. Each
  state gets these only if it already has their prerequisites; its own entry wins.
- Only listed provinces are in the scenario; borders to unlisted provinces are dropped.
- Starting techs: `adopted` or `widespread` need their prerequisites adopted too;
  `experimenting` is not allowed (there is no project data); stubs are not allowed.
- Every civ, AI or player, needs an era-appropriate baseline of techs.

## Characters and dialogue
`core/speakers.yaml` lists the advisers at every court (title and placeholder portrait
style); `core/dialogue.yaml` lists what is said at each *moment* (an idea adopted, a riot,
the game starting…). One line is picked each time, the same way in every replay:
```yaml
dialogue:
  - id: adopted              # the moment (see content/schema/dialogue.py for the list)
    speaker: scholar         # an adviser, or `ruler` (yours) or `rival` (another state's)
    lines:
      - "It works! {subject} is ours."
```
Placeholders: `{civ}` `{ruler}` `{subject}` `{year}` `{adjective}` `{rival}` `{rival_ruler}` `{rival_adjective}` (write "the {adjective} realm" before a verb: some names are plural); the linter
rejects any other. Rulers' names come from each scenario civ's `leader`.

## Happenings and consequences
`core/happenings.yaml` holds chance events: disasters and blessings (plague, flood, a bumper
harvest) and **consequences** - second-order effects of an advancement that the ruler did
not plan for (printing breeds pamphlet wars against the priests; paper money brings
inflation). A consequence must name the advancement it follows in `needs_adopted`. Each
entry gives a chance per decade, where it can strike (terrain, river, coast), and changes
to people, stores, unrest, legitimacy, suspicion and the influence of clergy, nobles and
guilds (`influence: {clergy: -800}`), all bounded to 50% either way. `{civ}` and
`{province}` are filled into the message.

## Rules
`core/rules.yaml` holds every tunable number, grouped by system and documented field by field
in `content/schema/rules.py`. Balance changes go here, never into code. After changing
rules, run the simulations (`uv run anachronism-sim`) and the tests: the balance tests check
that overextension still collapses and careful growth still thrives.

## Still to come
Rulers and dispositions, scripts (intentions, preconditions, triggers, dependencies),
relations and memory (Phase 4); timeline layers (Phase 5); offline library entries
(Phase 2).
