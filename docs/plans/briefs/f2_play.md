# F2: play the Republic from inside Rome (read all of it first)

The owner (2026-11-20): "You've fallen short on implementing the gameplay that I want you to
create." What the owner asked for, from the brief (docs/BRIEF.md §1, §5-7) and this project's
conversations (D-286, D-289): Rome governing itself; ideas that need materials, skills and
acceptance and become projects and buildings; rivals following history until they learn of your
changes; and the city as a place you interact with: "zoom into Rome ... click on them and zoom
even further to look inside them, and there will be interactions with them, like battles in the
Colosseum that you are able to watch from inside", and "in-depth animations as things are
discovered, built or just occur".

Today the city is look-only: the Senate, the treasury, the temples and the games are played from
side panels on the map. This pass makes **the city the interface**: what you do in Rome you do at
the place where Romans did it, through the engine's existing logged actions (and new ones where
needed), so a replay applies them again.

Read first: `CLAUDE.md`, `docs/DESIGN.md`, `docs/ARCHITECTURE.md` §9-10 (and the sections the
F1 passes added: Italy, religion/economy/army, Roman ideas), `docs/plans/briefs/urbs.md` (rules,
Godot, render queue), `engine/senate.py`, `engine/actions.py`, `engine/commands.py`,
`tools/server.py`, the urbs headers (`urbs.gd`, `monuments.gd`, `urbs_hud.gd`, `interior.gd`,
`spectacles/spectacles.gd`, `anachronisms.gd`), `hud.gd`, `republic_panel.gd`, `city_feed.gd`.

## Places and what you do there (each a card action in Urbs and in the interior)
Every action goes through `bridge.request("act", ...)` as a logged engine action, costs what the
engine says (influence, wealth, favour), shows its forecast before you commit, and its result
in the card and the city feed. Availability follows the year and the buildings standing.
1. **Curia / Comitium** (the Senate's house of the year): put a matter to the Senate (the
   existing `senate` action, with the proposals and forecasts of `view.republic.proposals`),
   persuade a family (`persuade`), and **watch the vote**: the Senate spectacle plays the real
   division (`yes_bp`, `no_bp`, tribune).
2. **Rostra**: address the people (a new `contio` action: costs influence, raises popular favour
   for a law or a candidate, more effective from a tribune's or consul's mouth; Cicero's and the
   Gracchi's contiones as sources), with a crowd spectacle.
3. **Saepta / Campus Martius (the comitia centuriata) and the Forum (tribal assembly)**: back a
   candidate (`back`) and **watch the election** as the voting units file through.
4. **Temple of Saturn (aerarium)**: the treasury: income and spending by line from the engine,
   and fund a project from the treasury (`fund:<node>` via the Senate) with its cost shown.
5. **Temples**: vow a temple (to a god, for a battle or a plague: a new `vow` action whose
   fulfilment is a dedicated monument in the city, with the city timeline), expiate a prodigy
   (religion's API), consult the Sibylline Books (decemviri; when the religion pass exposes it),
   **watch the sacrifice**.
6. **Circus Maximus / the Forum's wooden stands / the amphitheatre (Statilius Taurus 29 BC, or an
   anachronistic stone one)**: give games as an aedile or a triumphator (a new `games` action:
   wealth for popular favour and the family's standing), give a munus for a dead noble,
   **watch the race or the fight from the stands**. Fights in a Colosseum-like arena are possible
   in the Republic only by the player's own anachronism (the stone amphitheatre idea).
7. **Campus Martius / Porta Capena**: hold the levy (the army's era and census-class recruitment
   from the army pass) and **watch the army muster**; **the triumph** along its route when the
   Senate grants one.
8. **Workshops, harbour, the anachronism sites**: whisper an idea to the people who could build
   it (opens the idea box with the place as context: a forge for metal ideas, the harbour for
   ships), start a project, choose **where** a great work rises in the city when the idea builds
   one (from candidate sites), and **watch it being built**: scaffolding and progress by turn.
9. **Houses of the great families** (the domus on the Palatine and the Carinae, placed by the
   families data where the sources put them: Cicero, Crassus, Clodius, Scaurus on the Palatine;
   Pompey in the Carinae): visit the family, see its members, offices and stance, persuade it.

## Moments (U9, first slice)
When a turn brings one of these, the end-of-turn replay offers a **Watch** that flies the camera
from the map into the place and plays it with a short title card: a temple dedicated, a triumph,
a Senate vote you called, a great work completed (your anachronism rising, ahead of its time), a
fire, the games. Camera paths and timing per kind; skippable; no new art needed beyond the
existing spectacles and buildings.

## The turn in Rome
A player should be able to play a whole year from the city: open Rome, walk or fly to the
Curia, call a vote and watch it, go to the Rostra and speak, back a candidate at the Saepta,
whisper an idea at a forge, then end the turn from Urbs (an End Year button in the Urbs HUD) and
watch the year's events. The map stays for war and the world.

## Rules
Engine changes (new actions `contio`, `vow`, `games`, levy if the army pass lacks it) are logged
actions with tests across seeds, deterministic, integers, sorted ids, `GameRng` only, sourced
numbers in `republic_rules.yaml`; views carry what the cards need. Client changes are marked
blocks in shared files. Screenshots of each place's card and spectacle. Commit and push after
every commit. Trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` then
`Claude-Session: https://claude.ai/code/session_01S4H1oAxyYWS6R8Xwk3CuAJ`.

## The contract between the two halves (engine and client work in parallel)
**Engine** (agent `f2-engine`): a new `tools/places_view.py` adds `view["places"]`:
```
{ "<monument id>": {
    "role": "senate_house|rostra|assembly|treasury|temple|circus|arena|campus|gate|workshop|harbour|domus|anachronism",
    "title": "Curia Hostilia", "blurb": "Where the Senate meets this year",
    "actions": [ { "id": "senate:law:land_reform", "label": "Propose: a land law",
                   "action": {"kind": "senate", "issue": "land", "proposal": "law:land_reform"},
                   "cost": {"influence": 300, "wealth": 0}, "forecast": {"yes_bp": 4100, "no_bp": 5900,
                   "tribune": "veto", "tribune_bp": 1200, "note": "..."},
                   "enabled": true, "why": "", "watch": "senate" } ],
    "info": [ {"label": "Treasury", "value": "12,400", "tip": "..."} ] } }
```
`action` is exactly what the client sends to `act`; `watch` names the spectacle kind the result
plays (`senate`, `contio`, `election`, `sacrifice`, `race`, `munus`, `levy`, `triumph`, `building`, or
empty). Every action the engine applies that has a `watch` also emits a city event of that kind
with the real numbers, so the client plays it from `view["city"]["events"]`. New logged actions:
`contio` (issue, side), `vow` (god or temple id, cause), `games` (festival or munus, venue), `levy`
(if the army pass lacks one usable from Rome), `site` (choose where an anachronism rises). Places
for families (`domus` of a gens) come from a small sourced table of known houses (Cicero's,
Crassus', Clodius', Scaurus' on the Palatine; Pompey's in the Carinae...) placed in
`data/rome/city/` as records with `role: domus` and `gens`. Tests across seeds; replay-safe.

**Client** (agent `f2-client`): Urbs reads `view["places"]`: a building with actions shows them
on its card (outside) and in its interior (a panel at the spot: the Curia's floor, the Rostra's
front, the temple's altar, the Circus' box); pressing one sends `action` through the bridge
(Urbs gets a `bridge` hook from `main.gd` in a marked block), shows the result line, refreshes the
view, and when the turn's city events gain a matching `watch` event, plays that spectacle there
with the real numbers. An **End year** button in the Urbs HUD ends the turn without leaving Rome,
then plays the year's events in order as moments (U9 first slice: camera flight from where you
stand to each place, a title card, the spectacle, skip with Esc), then returns you where you were.
A "Rome this year" list in the Urbs HUD shows the places with actions available (a short to-do of
the year) and flies you there. Until the engine half lands, build against a fixture
`client/data/fixtures/places_264.json` written to the contract above.
