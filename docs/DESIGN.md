# Anachronism — Game Design

Derived from the owner's master brief (2026-09-30). Decisions referenced as `D-nnn` are in
[DECISIONS.md](DECISIONS.md). Numbers here are **starting values**; the live values are in
`packs/core/rules.yaml`, and balance tests guard the intended behaviour.

## 1. Pitch
You are an unseen guiding hand behind one historical lineage at a real moment in history.
You feed your people ideas that don't exist yet. **Knowing an idea is not being able to build
it**: every advancement needs materials, skilled people, infrastructure and social acceptance.
The game is a bootstrapping puzzle, played against rival civilisations that follow their own
history until news of your meddling reaches them. Goal: dominate your region, then your
hemisphere, then the world — by arms, trade or culture.

## 2. Design pillars
1. **Enabling chains, not tech menus.** The interesting question is always "what must exist
   first?"
2. **Capacity is the limit.** No cap on attempts; overcommitting collapses you naturally.
3. **Boring things win.** Bookkeeping, crop rotation, standard weights compound.
4. **The world keeps its own history** until it learns otherwise; ignorance is a mechanic.
5. **The engine is the referee.** The LLM interprets and narrates; code decides.

## 3. Core loop (one turn = N years, D-010)
1. **Review** — stats with trend arrows, advisor notes, intelligence reports, events.
2. **Propose ideas** — type freely (Free Thought mode) or pick from scholars' suggestions
   (Historical Advisors mode, offline). Each idea gets a ruling (§8).
3. **Commit** — start, pause or cancel projects; set priorities; manage armies and diplomacy.
4. **Resolve** — the engine runs the turn pipeline (ARCHITECTURE §4): production, upkeep,
   project progress, strain, adoption spread, suspicion, information spread, rival scripts,
   events, combat, victory check.
5. **Chronicle** — a short narrative of what happened.

## 4. Resources and stats (D-007)
| Kind | Name | Behaviour |
|---|---|---|
| Stockpile | **food** | Produced by farming provinces; consumed by population (1 per 1k people per turn-unit). Stored up to granary capacity; spoilage 10%/turn above half capacity. |
| Flow | **labour** | Workforce from population × efficiency (unrest lowers it). Cannot be stored. A surplus share (20%) is free for projects; using more pulls people off fields and workshops and cuts production. |
| Stockpile | **materials** | Timber, stone, metals abstracted into one pool; *specific* map resources (iron, coal, saltpetre…) are access flags, not pools. |
| Stockpile | **wealth** | Taxes + trade income. Pays armies, officials, imports. |
| Stockpile | **knowledge** | A little from everyone (crafts, lore), much more from literate people; spent on experimentation. |
| Stat | population | Grows toward population cap set by food and health. |
| Stat | literacy | % of population; soft requirement for some ideas. Literacy effects add to it and a share fades each decade, so they set a sustainable level. |
| Stat | unrest | 0–100. High unrest cuts labour, raises revolt risk. |
| Stat | legitimacy | 0–100. The ruling house's standing; buffers unrest. |
| Stat | suspicion | 0–100. See §7. |
| Stat | military strength | Derived from armies × equipment × organisation. |
| Stat | trade income | Derived from routes, markets, currency. |

Every stat keeps a short history so the UI shows **trends**, not just values.
**Free capacity** = production − upkeep − project commitments, shown per resource.

## 5. Projects and overextension
- An accepted idea becomes a **project** with per-turn costs (labour, materials, food,
  wealth, knowledge) and a duration in turns.
- Each turn projects are funded by priority tier (high, normal, low), **proportionally**
  within a tier. A project needs all its inputs, so its funding is its scarcest input's share.
- **Strain** moves toward a target set by how short projects fall and how much labour is
  diverted from production. Strain → unrest → labour efficiency drops → shortfalls worsen.
  Diverted labour cuts food → starvation (deaths) → more unrest. Unrest over thresholds →
  riots, then revolts (a province breaks away; the capital never does). Losing half the
  starting provinces is collapse. None of this is a special rule: it emerges.
- Underfunded projects progress slower; projects starved for 3+ turns begin to decay.
- **Low priority is steady work** (D-112): it takes only the spare hands left after other
  projects (the surplus), never farmers, so it cannot cause diversion, famine or strain;
  and while it keeps moving, however slowly, it does not decay. A small state can still
  pursue a great idea, slowly. Rival courts start what they cannot staff at full pace as
  steady work, one at a time, instead of starving themselves.
- Tested: a player who starts everything at once collapses within about 30 turns; a
  player who respects free capacity stays stable and keeps advancing.

## 6. Feasibility: what makes an idea buildable
Tech nodes carry **structured requirements**, checked by code:
- `materials`: map-resource access flags (e.g. `saltpetre: accessible`).
- `skills`: literacy thresholds, specialist pools (smiths, masons, scribes, engineers).
- `infrastructure`: other adopted nodes/buildings (roads, workshops, standard measures).
- `acceptance`: groups that resist (clergy, nobles, guilds) and how strongly.
- `prerequisites`: other nodes that must be at least `adopted`.

### Adoption stages (D-012)
`concept → experimenting → adopted → widespread`
- **Concept**: the idea is known. Free, immediate. Makes the node visible.
- **Experimenting**: costs knowledge + materials for a few turns; each turn rolls for
  progress (seeded RNG). Missing minor requirements add setbacks; missing hard requirements
  block.
- **Adopted**: effects apply in proportion to spread, which starts at 20% (the capital).
- **Widespread**: spread passes 80%; it grows each turn, faster with literacy and mobility
  (civilisation-wide in Phase 1, D-039).
Missing prerequisites become **goal stubs** (brief decision 8): visible, cost nothing, no
resources committed until the player pursues them.

## 7. Suspicion (D-022)
- Rises when an advancement arrives well ahead of the civ's baseline (gap between the node's
  historical era and the current year), faster for visible/strange ones.
- Falls slowly over time, with legitimacy, and with "explanations" (a founding myth, a
  foreign scholar, a religious framing — themselves ideas the player can pursue).
- Framing: **inspired** (legitimacy bonus), **witchcraft** (clergy hostility, unrest),
  **fraud** (nobles plot). Framing drifts according to religion, events and advisors.
- High suspicion also makes news of your inventions travel faster to rivals.
- Explanations (a royal decree, D-092): proclaim the new arts **a gift of the gods**
  (wealth; turns witchcraft or fraud talk into awe if legitimacy is high) or **credit
  foreign sages** (knowledge; quiets more, but rivals hear of your arts at once). Once
  every few turns.

## 8. The idea pipeline (online "Free Thought" mode)
1. **Interpret** player text → one or more candidate concepts, matched to existing nodes
   where possible (D-020).
2. **Clarify**: if truly ambiguous, ask one short question.
3. **Split** multi-idea input; each part ruled separately.
4. **Rule**: `feasible` / `blocked` (missing prerequisites → stubs) /
   `implausible_for_era` (in-world reason + hint).
5. **Flavour**: advisor reactions (scholar, priest, general, treasurer) that may nudge
   suspicion or unrest within engine caps.
The LLM outputs a **complexity tier** (1–5) and requirement tags; the engine computes costs,
durations and effect magnitudes by formula, then clamps to caps. Player text is data, never
instructions.

## 9. Effect menu (fixed vocabulary; caps per node per era)
Magnitudes are % unless noted. Caps: **ancient / classical / medieval / early modern**.

| Effect | Meaning | Cap per node |
|---|---|---|
| `food_output` | % food production | 10 / 12 / 15 / 20 |
| `labour_output` | % labour efficiency | 8 / 10 / 12 / 15 |
| `materials_output` | % materials | 10 / 12 / 15 / 20 |
| `wealth_output` | % taxes | 8 / 10 / 12 / 15 |
| `knowledge_gain` | % knowledge | 10 / 12 / 15 / 20 |
| `trade_income` | % trade | 10 / 12 / 15 / 20 |
| `literacy_growth` | +pp literacy per turn | 0.5 / 0.7 / 1.0 / 1.5 |
| `population_cap` | % cap | 8 / 10 / 12 / 15 |
| `health` | % reduction in plague/famine deaths | 10 / 12 / 15 / 20 |
| `military_strength` | % army strength | 10 / 12 / 15 / 25 |
| `naval_strength` | % navy strength | 10 / 12 / 15 / 25 |
| `mobility` | % army/news movement speed | 10 / 12 / 15 / 20 |
| `storage` | % granary/stockpile capacity | 15 / 15 / 20 / 25 |
| `unrest` | flat per turn (±) | ±3 / 3 / 3 / 3 |
| `legitimacy` | flat per turn (±) | ±3 / 3 / 3 / 3 |
| `suspicion` | flat on adoption (+ only from LLM) | +15 all eras |
| `information_speed` | % news propagation (own) | 10 / 12 / 15 / 20 |
| `secrecy` | % slower leakage of own tech | 10 / 12 / 15 / 20 |
| `cultural_influence` | % culture spread | 10 / 12 / 15 / 20 |
| `unlocks_building` | id of a building type | — |
| `unlocks_unit` | id of a unit type | — |
| `unlocks_resource` | reveals/enables a map resource (e.g. coal use) | — |

Stacking: multiplicative with diminishing returns per category (so ten +10% nodes ≠ +100%).

## 10. Map (D-008)
Province graph. Each province: terrain (plains, hills, mountains, forest, desert, steppe,
marsh), coastal flag, river flag, climate band, map resources with access level
(`accessible` / `limited` / `unexplored`), population, owner, culture/religion shares,
buildings. Edges: land, river, sea lane, mountain pass (with movement costs).

### Buildings (D-111)
Each province holds a few buildings: two, plus one for every 250,000 people, up to eight,
so growing cities hold more. Kinds are content (`core/buildings.yaml`): a granary, market,
temple, workshops, barracks, mines, harbour, irrigation works, school, observatory, forges,
water mill, windmills, courthouse, aqueduct, printing house, hospital, and upgrades that
take an older building's place (bank for market, academy for school, manufactory for
workshops), up to the railway station. Each needs its advancements and sometimes a coast,
a river or ore; it costs materials and wealth up front (a quarter more for each building
already standing), takes one or two decades, and costs wealth to keep. It raises its
province's food, materials, wealth or knowledge, its growth or the people it can hold;
temples and courts calm the realm and schools teach reading (weighted by the province's
share of the people); barracks train the soldiers raised there. Pillage burns the newest
building. Rival courts build one a turn in their largest cities when their stores hold
three times the cost. This is where the "boring" force multipliers of brief §5.5 pay off
province by province, and the cities on the map grow and show what stands in them.

## 10b. War: armies, battles, sieges and supply (D-099)
- **Armies** stand in provinces: men of several kinds (levies, spearmen, heavy infantry,
  archers, crossbowmen, chariots, cavalry, horse archers, armoured horsemen, war elephants,
  siege engines, cannon, musketeers - content in `core/units.yaml`), each needing its
  advancements and map resources (no horses, no cavalry; elephants only where they live).
  Raised from a province's people (costing food, materials and wealth, and labour lost to
  the fields), kept at a cost each turn, and capped by the state's mobilisation.
- **Orders**: march to a province (one to four provinces a turn, faster with roads, a sea
  crossing with sailing ends the march), hold, defend (meet invaders of your own land),
  disband.
- **Battles** when enemies meet: each kind's attack or defence, match-ups (spears stop
  horse, horse rides down archers and siege trains, archers shred infantry, elephants
  terrify), the ground (chariots founder in hills, horse archers rule the steppe), the
  defender's hills and walls, morale, the general's skill, and fortune. The beaten army
  falls back the way it came; a surrounded one surrenders. Named battles go in the
  chronicle; generals can fall.
- **Sieges**: an army alone in an enemy province besieges it; walls (terrain, capital,
  last stand) take turns to fall, faster with siege engines and cannon; then it changes
  hands.
- **Supply**: armies waste away a little at home, more abroad, more in desert, mountains
  and marsh, and fast when a province cannot feed them; unpaid armies lose heart and desert.
- **Weariness**: wars grind on until one side tires; the side losing battles and provinces
  tires faster, and carries the grievance away.
- **Battle plans** (D-108): each army fights with a plan (line, charge, shield wall,
  skirmish, envelopment, feigned retreat, ambush) that beats some and loses to others;
  great generals read the enemy's plan. Victories make veterans.
- **The sea** (D-107): fleets of warships (galleys to gun ships, content in
  `core/ships.yaml`) are built on your coasts, sail two seas a turn and fight enemy fleets
  they meet. Whoever commands a sea decides which armies may cross it; enemy fleets that
  command every sea on a province's shore blockade it (most of its trade lost, its people
  tiring of the war). Fleets cost wealth every turn. Seafaring states (Carthage, Venice, the
  Norse) start with strong fleets; others must build them.

## 11. Rival civilisations
- **Scripts** are conditional intentions with preconditions and triggers, not dated events.
- **Awareness states**: on-script (engine only, no API cost) → aware (LLM consults ruler
  persona + old script) → free agent (LLM plays from disposition).
- **Information**: news items spread along trade routes, diplomats, refugees, spies, war,
  religious networks, with delay ∝ distance and garbling. Player can seal borders, keep
  secrets, spread disinformation.
- **Script dependency graph**: when one script derails, dependents are re-checked by code.
- **Relations**: pairwise, only for plausible contact pairs; statuses (unknown, contact,
  trading, allied, tributary, hostile, at war) plus grievance/legitimacy memory entries with
  decay rates. Religion, script and trade flows are first-class.
- **Intelligence** about rivals is imperfect (D-013).
- Rivals can learn your inventions once news reaches them (D-024).

## 12. Scenarios and timeline
Scrollable timeline of named moments. Each moment is assembled from layered timeline data
(D-025): polities, borders, tech baselines for **all** civs, relations, live tensions, script
states, and the player civ's ruler, resources and threats. A disclaimer screen precedes play:
this is a good-faith simulation, not a re-enactment. Contested facts are not flagged in game;
source notes and confidence live in data files only.

## 13. Dynasties (D-011)
Polities are separate entries linked by lineage. The player's hand follows the lineage across
dynastic change; the player picks the successor to continue with when their polity falls.

## 14. Offline "Historical Advisors" mode
Each turn scholars offer 3–6 curated ideas suited to the civ's situation, drawn from the
library (same schema as online rulings). Different feel: less freedom, more curated
storytelling, zero cost, fully deterministic.

## 15. Victory (D-015)
Tiered region → hemisphere → world; military, economic or cultural paths, measured as shares
of population or trade.

## 16. Out of scope until later phases
Multiplayer, sound, final art, non-East-Asian content before Phase 6.
