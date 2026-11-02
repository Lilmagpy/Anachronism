# data/rome: the Roman state's datasets (F1, phase R2)

Read in place by the `rome` content pack (`pack.yaml`, `external:`), so the game and the
tools share one copy. The city of Rome's dataset is in `city/` (its own README).

## `fasti.yaml`: who held which office, every year 509-27 BC

Top-level key `fasti`, one entry per year, 483 entries (475 years with magistrates and the
8 gap years), ordered from 509 BC. Years are astronomical (`-509` = 509 BC).

| field | meaning |
|---|---|
| `id` | `fasti_<year>bc` |
| `year` | the Varronian year |
| `confidence` | `high` certain, `medium` probable, `low` traditional or doubtful (the view shows "disputed") |
| `gap` | `anarchy` (375-371: Livy 6.35.10) or `dictator_year` (333, 324, 309, 301): no consuls; the engine seats only the colleges listed and the plebeian offices |
| `colleges` | one per office held that year: `office` (a `magistracies` id) and `holders` |
| `holders[].person` | the id of a modelled person (`people.yaml`); or |
| `holders[].name`, `gens` | the man's full name and his family (`gentes.yaml`), for a man not modelled |
| `holders[].plebeian` | only when the man's order differs from his family's (a patrician Sempronius Atratinus, a plebeian Claudius Marcellus) |
| `holders[].suffect` | a replacement elected during the year |
| `holders[].note` | `(continuing)`, `(resigned)` |
| `notes` | what the sources say of the year; where Wikipedia's list differs, it says so |
| `sources` | ancient passages first; `# unverified` after a source means it was not read against a text |

Offices covered: consuls (every year), consular tribunes (444-367), dictators and masters of
the horse (80 and 73), censors (38 colleges: the list is not complete, the censors of other
lustra are elected by the engine's five-year rhythm only in years the Fasti do not cover),
decemvirs (451-450), the triumvirs of 43, tribunes of the plebs in 39 years (the famous
colleges only), one praetor and one aedile college (366). A modelled person's lower offices
(quaestor, aedile, tribune, praetor) are in `people.yaml` and honoured by the engine too.

**Method.** The draft of every year was compiled on branch `claude/r1-fasti` from the Fasti
Capitolini and the narrative sources (Livy, Polybius, Plutarch, Appian, Cassius Dio), with a
confidence per year. For this round the gens ids were corrected, names cleaned, holders linked
to the modelled persons, the gap years folded in, and **every consul and consular-tribune
college was compared with Wikipedia's "List of Roman consuls"** (which follows Broughton's
*Magistrates of the Roman Republic*): 456 years agree wholly, 8 in part (a suffect missing
from one side), 9 differ in a name (a cognomen variant such as Foslius/Folius, Venox/Venno,
Curtius/Curiatius, or an iteration): those years say so in `notes` and keep `# unverified`
on the Fasti line. The check is of names, not of the ancient passages: `# unverified` on a
Livy or Polybius line means that passage was not re-read, and the owner's R6 pass should.

Known limits: the early list (509-c.300) is the tradition's and `low`; iteration numbers
(II, III) are not stored; dates of death inside a year are not stored (a man who died in
office dies after the year's seating).

## `../src/anachronism/content/packs/rome/gentes.yaml` (generated from the Fasti)

One entry per family the Fasti name (160), plus the families of modelled persons.
`order`, `praenomina` and `branches` (each cognomen with the years it is attested, widened a
generation each way) come from the Fasti; `extinct_after` is set when a family's last
attestation is more than seventy years before 27 BC. `standing` snapshots by era
(509, 448, 366, 286, 200, 133, 79) are **derived**: a score of the family's offices in the
Fasti around that year (consulships weigh 1, consular tribunates 0.6, dictatorships and
censorships 0.8, the praetorship 0.3; recent ones double, older ones fade) gives
`dignitas_bp` and `auctoritas_bp`; `wealth` and `clients` follow the score with a hand
multiplier for the famously rich (Cornelii, Caecilii, Licinii, Pompeii...). `stances` on all
eight Senate issues and `popular_lean_bp` are **hand-authored** for 141 families from what
the sources say of their politics (`notes` names the source: Livy, Plutarch, Cicero, Appian,
Sallust) and **inferred from the order** for the rest ("inferred from its record"). The
numbers are game balance; the names, orders and dates are history.

## `../src/anachronism/content/packs/rome/people.yaml`

148 modelled persons with birth, death and its cause (`died_of`), gens, offices by year,
traits and sources. The senior offices are the Fasti's (the build linked the names); the
lower offices and the undated facts were entered by hand. `legendary: true` marks the first
century, whose men are the tradition's. `alive_until` gives the last year a man is known
alive when his death is unknown; the engine spares him until then in a chronicle.

## Regenerating

The generator (not in the repository) read the draft, the Wikipedia table and the hand files
and wrote these three files; they are now the data the game reads and are edited directly.
