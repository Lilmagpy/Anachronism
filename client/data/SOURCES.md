# Map data sources and licences

| File | What | Source | Licence |
|---|---|---|---|
| `east_asia_height.i16/.json` | Elevation in whole metres (16-bit) (Web Mercator, zoom 6, halved) | Terrarium tiles, Mapzen / AWS Open Data Terrain Tiles (SRTM, GMTED2010, ETOPO1, others) | Open; attribution required (see below) |
| `east_asia_colour.png` | Satellite colour | NASA Blue Marble (via the three-globe example image) | Public domain (NASA) |
| `east_asia_rivers.json` | Rivers | Natural Earth 10 m rivers and lake centrelines | Public domain |
| `europe_*` | The same three sources for Europe, the Mediterranean and the Near East (11°W–62°E, 17°N–67°N) | as above | as above |

Attribution to show in the game's credits:
"Elevation: Mapzen Terrain Tiles (SRTM, GMTED2010, ETOPO1 and others), via AWS Open Data.
Imagery: NASA Blue Marble. Rivers: Natural Earth."

Rebuild (see D-053): `client/tools/build_heightmap.gd`, `client/tools/build_colour.gd`,
`scripts/build_rivers.py`.
