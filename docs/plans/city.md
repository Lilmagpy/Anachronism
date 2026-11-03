# Urbs: the city of Rome you can walk into (D-289)

The owner's target: zoom from the map into Rome, look at the Circus Maximus, the Forum, the
Capitol, the Colosseum and every other significant building, click one, go inside, and watch
what happens there: a chariot race from the seats, a fight in the arena, the Senate in session,
a sacrifice, a triumph passing. Every building at its real place and size, in its real year.

This is a separate mode of the client, **Urbs**, in `client/scripts/urbs/`. The strategy map
stays as it is; Urbs opens when you zoom into Rome or press *Visit Rome*.

## The three layers

1. **The city as a place.** Real ground (the seven hills, the Tiber and its island, the
   Campus Martius, the ancient valley floors), the real street plan where it is known, the
   Servian wall with its gates, and every monument from `data/rome/city` at its coordinates,
   oriented as it stood, appearing in the year it was built and changing with its fires and
   rebuildings. Between the monuments, the insulae, domus, shops and workshops that fill the
   regions, dense in proportion to the population of the year.
2. **Zoom all the way in.** Map → city (orbit, whole city) → street (walk or fly at eye
   height, collision with walls) → inside (click a monument: a card names and dates it with
   its sources and an *Enter* button takes you in).
3. **Life inside.** Driven by the engine's events, not random:
   - **Circus Maximus**: the Ludi Romani each September; chariot races, four factions,
     seven laps, watched from the seats.
   - **Games**: in the Republic, gladiator munera in the Forum in temporary wooden stands (the
     first at the Forum Boarium, 264 BC, Livy *Per.* 16); after AD 80, in the Colosseum.
   - **Curia**: the Senate in session when the engine votes.
   - **Temples**: a sacrifice at the altar when the engine records a vow, a dedication or an
     expiation.
   - **Triumph**: along the Via Sacra to the Capitol after a victory the engine grants one for.
   - **Fires, floods, building work**: scaffolding on what is going up.

## The data

- `data/rome/city/monuments.yaml` (509-27 BC, 160 entries; verification in progress) and
  `monuments_empire.yaml` (27 BC - AD 120: the Augustan city, the Colosseum, the imperial fora,
  the Pantheon, the baths), same format. Every entry carries its sources.
- `streets.yaml`: the known streets as point lists (Via Sacra, Clivus Capitolinus, Vicus
  Tuscus, Vicus Iugarius, Argiletum, Subura, Nova Via, Via Lata, Via Appia, the Clivus
  Palatinus...), with sources.
- `spectacles.yaml`: how each spectacle ran, with sources (the carceres and the spina, the
  factions, the pompa circensis; the munus; the Senate's procedure; the ritual of sacrifice;
  the order of a triumph).
- `topography.yaml`, `population.yaml` as before.
- `uv run anachronism-city-export` turns all of it into `client/data/city/*.json` (committed).

## The coordinate frame

`client/scripts/urbs/geo.gd`: local metres, origin at the centre of the Forum Romanum,
x east, z south, y height above sea level. 1 unit = 1 metre. Everyone uses it.

## The engine's part

The engine keeps the city's state in the save: which monuments stand this year (from the data
and from the player's own anachronistic projects), what is being built, and the events of the
turn that Urbs plays out. `tools/view.py` exposes it under `city`.

## The Colosseum question (for the owner)

The campaign ends in 27 BC; the Colosseum opened in AD 80. The data and the model cover the
city to about AD 120, so the Colosseum exists in Urbs the moment the campaign reaches it, or
the moment a player's idea brings it forward. Extending the campaign into the Empire is the
owner's call (logged in D-289).

## Steps

- U1 Frame and data: geo.gd, the exporter, streets and spectacles data, the Empire monuments.
- U2 Ground: terrain, Tiber, ancient levels, the Servian wall and gates.
- U3 Monuments placed, dated, oriented, clickable; the fill between them by regio and year.
- U4 Cameras and modes: map → city → street → inside; chunked loading; performance budget.
- U5 Interiors: temple, curia, basilica, circus, domus, insula, arena.
- U6 Spectacles: race, munus, Senate, sacrifice, triumph, driven by engine events.
- U7 The engine's city state and the `city` view; the player's anachronisms appear in the city.
- U8 Polish: lighting, time of day, crowds, sound; screenshots and a playthrough for the owner.

## U8: the gap with Rome Reborn (owner's review, 2026-10-29)

The owner judged the first full pass "incredibly janky" against Rome Reborn. Side by side (a
Rome Reborn still viewed as reference only), the gap is:

| Rome Reborn | Ours before U8 |
|---|---|
| Deep sky, hard sun, crisp shadows, subtle aerial haze | Grey-pink wash, overexposed, flat light |
| Veined marble, travertine, brick with mortar, painted stucco, ridged tiles, bronze and gilt | Flat colours; black holes for openings |
| Fluted columns, real capitals, mouldings, pediment sculpture, acroteria, steps, bronze doors | Boxes with a brick texture; the Forum drawn as a courtyard with one roof |
| Travertine paving, honorific statues, the Rostra | Sand |
| Real valleys, towering Capitol, ramps, retaining walls | Flat ground; houses on bare slopes |
| Pines, cypresses, gardens | No trees; farms as striped stickers |
| People everywhere | Empty streets |
| Tiled roofs, shutters, railed balconies | Flat slabs; laundry as coloured squares |

Five parallel passes close it: rendering and materials (one shared library,
`urbs/materials.gd`), monuments (real orders, the Forum's furniture), site (carved valleys,
ramps, quays, trees), life (crowds, markets, spectacles wired to events) and houses.

A first run of all five was lost on 2026-10-30 when the cloud container restarted before any
of it was pushed (D-293). The second run pushes every agent branch as it commits.

## After the city: moments (owner's request, 2026-10-29)

Once Urbs is done, every discovery, building and event gets its own cinematic: the game
flies into the place where it happens and plays it out in full. The idea's breakthrough in
the workshop; the aqueduct's arches rising span by span over the years; the temple vowed in
battle, then built, then dedicated; a fire sweeping a district; the Senate's decisive vote;
a triumph; a battle. Each is built on the Urbs scene and the spectacles, with its own camera
path, timing and sound, and can be skipped. Planned as U9 after U8. Not started.
