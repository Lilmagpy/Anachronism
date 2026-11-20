# data/rome/sources: reference extracts for the city audit (F2)

Read by `uv run anachronism-city-audit` (`src/anachronism/tools/city_audit.py`); rebuilt from the
network with `uv run anachronism-city-audit --refresh [--cache DIR]`. Only trimmed extracts are
kept in git, not the raw dumps.

| file | what | licence |
|---|---|---|
| `pleiades_rome.json` | Pleiades places whose representative point lies within 3.5 km of the Forum (41.8925 N 12.4853 E) and whose earliest period starts before AD 120: names, feature types, periods, and per location its accuracy and the hull (areas) or simplified line (streets, walls, aqueducts) of the mapped geometry | **CC BY 3.0**. Attribution: Pleiades, *A Gazetteer of Past Places*, https://pleiades.stoa.org, and the contributors named on each place's page (retrieved from the dump `pleiades-places-latest.csv.gz` and the places' JSON). Most outlines in Pleiades come from OpenStreetMap (ODbL), as each location's title says. |
| `platner_ashby.json` | Entries of S. B. Platner and T. Ashby, *A Topographical Dictionary of Ancient Rome* (Oxford 1929), as transcribed by Bill Thayer on LacusCurtius (https://penelope.uchicago.edu/Thayer/E/Gazetteer/Places/Europe/Italy/Lazio/Roma/Rome/_Texts/PLATOP*/home.html), of the kinds the city needs (buildings, temples, shrines, altars, groves, gates, bridges, aqueducts, streets, statues, tombs) whose text names a year or reign before AD 120 or an author writing before then; text cut at 900 characters | public domain |
| `references.yaml` | the curated part: verdicts where the automatic matching is wrong or an entry is left out (with the reason), published measurements (bearing, length, width, each with its source), and explanations of the flags that remain | this project |
