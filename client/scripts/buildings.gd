## Buildings put together from Kenney kit pieces (CC0, G1): houses of plaster or timber
## under gabled or pointed roofs, and the landmarks your ideas raise around a capital - a
## windmill, a water mill, a clock tower, a school hall, an observatory, a forge, a market.
##
## Each is one mesh for a MultiMesh or a MeshInstance3D. Roofs and awnings take the instance
## colour (`KenneyKit` "roofs"), so a town's roofs can be terracotta, slate or its owner's
## colour; castle pieces keep their stone and repaint their blue roofs.
class_name Buildings
extends RefCounted

const TOWN := "fantasy-town/"
const CASTLE := "castle/"


## A house `w` cells wide and `d` deep with `floors` storeys: plaster or timber walls with a
## door at the front, shuttered windows, and a gabled roof along its length ("gable"),
## a steep one ("high") or a pyramid ("point", for one-cell houses).
static func house(w: int, d: int, floors: int, timber: bool, roof: String, height: float) -> ArrayMesh:
	var key := "house|%d|%d|%d|%s|%s|%s" % [w, d, floors, timber, roof, height]
	return KenneyKit.compose(key, _house_pieces(w, d, floors, timber, roof), height)


## A landmark by kind (see `Landmarks.KINDS`), or null if it has no kit building.
static func landmark(kind: String, height: float) -> ArrayMesh:
	var key := "landmark|%s|%s" % [kind, height]
	var pieces: Array = []
	match kind:
		"windmill":
			# a round stone tower with its sails turned to the wind
			for piece in [["tower-hexagon-base", 0.0], ["tower-hexagon-mid", 1.31], ["tower-hexagon-roof", 1.77]]:
				pieces.append([CASTLE + piece[0], Transform3D(Basis(), Vector3(0, piece[1], 0)), "accents"])
			pieces.append([TOWN + "windmill", Transform3D(Basis().scaled(Vector3.ONE * 0.75), Vector3(0.0, 1.75, 0.6)).rotated_local(Vector3.UP, PI / 2.0), "roofs"])
		"water_wheel":
			pieces = _house_pieces(2, 1, 1, true)
			pieces.append([TOWN + "watermill", Transform3D(Basis().scaled(Vector3.ONE * 0.8), Vector3(0.5, 0.65, 0.95)).rotated_local(Vector3.UP, PI / 2.0), "roofs"])
		"clock_tower":
			for piece in [["tower-square-base", 0.0], ["tower-square-mid-windows", 1.01], ["tower-square-mid-windows", 2.02], ["tower-square-top-roof-high-windows", 3.03]]:
				pieces.append([CASTLE + piece[0], Transform3D(Basis(), Vector3(0, piece[1], 0)), "accents"])
		"watchtower", "powder_tower":
			for piece in [["tower-square-base", 0.0], ["tower-square-mid", 1.01], ["tower-square-top-roof-high", 2.02]]:
				pieces.append([CASTLE + piece[0], Transform3D(Basis(), Vector3(0, piece[1], 0)), "accents"])
		"observatory":
			for piece in [["tower-hexagon-base", 0.0], ["tower-hexagon-mid", 1.31], ["tower-hexagon-mid", 1.77], ["tower-hexagon-top", 2.23]]:
				pieces.append([CASTLE + piece[0], Transform3D(Basis(), Vector3(0, piece[1], 0)), "accents"])
		"school":
			pieces = _house_pieces(3, 1, 2, false)
			pieces.append([TOWN + "banner-green", _at(1, 1, 0, 3), "roofs"])
		"workshop", "press", "kiln":
			pieces = _house_pieces(2, 1, 1, true)
			pieces.append([TOWN + "chimney", _at(1, 0, 0, 0), "roofs"])
		"forge", "furnace":
			pieces = _house_pieces(2, 2, 1, false)
			pieces.append([TOWN + "chimney", _at(1, 0, 0, 0), "roofs"])
			pieces.append([TOWN + "chimney", _at(1, 0, 1, 0), "roofs"])
		"mint":
			pieces = _house_pieces(2, 1, 2, false)
			pieces.append([TOWN + "stall-red", Transform3D(Basis(), Vector3(0.0, 0, 1.2)), "roofs"])
			pieces.append([TOWN + "stall-green", Transform3D(Basis(), Vector3(1.0, 0, 1.2)), "roofs"])
		"harbour":
			pieces.append(["watercraft/boat-sail-a", Transform3D(), "accents"])
		_:
			return null
	return KenneyKit.compose(key, pieces, height)


static func _house_pieces(w: int, d: int, floors: int, timber: bool, roof := "") -> Array:
	var pieces: Array = []
	var plain := TOWN + ("wall-wood" if timber else "wall")
	var window := TOWN + ("wall-wood-window-shutters" if timber else "wall-window-shutters")
	var door := TOWN + ("wall-wood-door" if timber else "wall-door")
	for f in floors:
		for x in w:
			for z in d:
				for side in 4:
					var out: Vector2i = Vector2i(x, z) + [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1)][side]
					if out.x >= 0 and out.x < w and out.y >= 0 and out.y < d:
						continue
					var piece := window if (x + z + f + side) % 2 == 0 else plain
					if f == 0 and side == 3 and x == w / 2:
						piece = door
					pieces.append([piece, _at(x, f, z, side), "roofs"])
	if roof == "":
		roof = "high" if w * d > 1 else "point"
	var name: String = {"gable": "roof-gable", "high": "roof-high-gable", "point": "roof-point"}[roof]
	if roof == "point" and w * d > 1:
		name = "roof-high-gable"
	for x in w:
		for z in d:
			pieces.append([TOWN + name, _at(x, floors, z, 0 if w >= d else 1), "roofs"])
	return pieces


## Grid cell (x, floor, z), turned `side` quarter turns: kit walls stand on a cell's +x edge,
## so side 0 faces +x, 1 faces -z, 2 faces -x, 3 faces +z.
static func _at(x: int, floor: int, z: int, side: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, side * PI / 2.0), Vector3(x, floor, z))


## A capital as seen from far off (G1): a walled castle with corner towers and a tall keep,
## its roofs in the owner's colour.
static func castle_icon(height: float) -> ArrayMesh:
	var pieces: Array = []
	var tower := [["tower-square-base", 0.0], ["tower-square-mid", 1.01], ["tower-square-top-roof-high", 2.02]]
	for corner in [Vector2(0, 0), Vector2(3, 0), Vector2(3, 3), Vector2(0, 3)]:
		for piece in tower:
			pieces.append([CASTLE + piece[0], Transform3D(Basis(), Vector3(corner.x, piece[1], corner.y)), "accents"])
	for k in [1, 2]:
		pieces.append([CASTLE + "wall", Transform3D(Basis(), Vector3(k, 0, 0)), "accents"])
		pieces.append([CASTLE + "wall", Transform3D(Basis(), Vector3(k, 0, 3)), "accents"])
		pieces.append([CASTLE + "wall", Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, 0, k)), "accents"])
		pieces.append([CASTLE + "wall", Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(3, 0, k)), "accents"])
	var keep := [["tower-square-base", 0.0], ["tower-square-mid-windows", 1.01], ["tower-square-mid", 2.02], ["tower-square-top-roof-high", 3.03]]
	for piece in keep:
		pieces.append([CASTLE + piece[0], Transform3D(Basis().scaled(Vector3(1.4, 1.0, 1.4)), Vector3(1.5, piece[1], 1.5)), "accents"])
	pieces.append([CASTLE + "flag-banner-long", Transform3D(Basis(), Vector3(1.5, 4.3, 1.5)), "accents"])
	return KenneyKit.compose("castle_icon|%s" % height, pieces, height)


## A town as seen from far off: a few houses around a watchtower, roofs in the owner's colour.
static func town_icon(height: float) -> ArrayMesh:
	var pieces: Array = []
	for item in [[Vector3(0, 0, 0), 0.0, [2, 1, 1, false, "gable"]], [Vector3(2.3, 0, 0.9), PI / 2.0, [1, 1, 2, true, "high"]],
			[Vector3(-0.6, 0, 1.6), 0.0, [1, 1, 1, false, "point"]], [Vector3(0.9, 0, 2.2), 0.0, [2, 1, 1, true, "high"]]]:
		var place := Transform3D(Basis(Vector3.UP, item[1]), item[0])
		var spec: Array = item[2]
		for piece in _house_pieces(spec[0], spec[1], spec[2], spec[3], spec[4]):
			pieces.append([piece[0], place * piece[1], piece[2]])
	for piece in [["tower-square-base", 0.0], ["tower-square-mid", 1.01], ["tower-square-top-roof-high", 2.02]]:
		pieces.append([CASTLE + piece[0], Transform3D(Basis().scaled(Vector3(0.8, 0.8, 0.8)), Vector3(2.4, piece[1] * 0.8, -0.6)), "accents"])
	return KenneyKit.compose("town_icon|%s" % height, pieces, height)


## What each province building (engine content `buildings.yaml`, its `look`) is drawn as in
## the city (D-111): [mesh kind, height in settlement units]. Unknown looks get a hall.
const CITY_LOOKS := {
	"market": ["mint", 0.55], "bank": ["bank", 0.7], "temple": ["temple", 0.75],
	"granary": ["granary", 0.45], "workshop": ["workshop", 0.42], "factory": ["factory", 0.6],
	"barracks": ["watchtower", 0.75], "mine": ["mine", 0.45], "school": ["school", 0.55],
	"academy": ["academy", 0.75], "observatory": ["observatory", 0.75], "forge": ["forge", 0.45],
	"watermill": ["water_wheel", 0.5], "windmill": ["windmill", 0.85], "courthouse": ["clock_tower", 0.9],
	"aqueduct": ["aqueduct", 0.45], "press": ["workshop", 0.5], "hospital": ["hospital", 0.55],
	"station": ["station", 0.55], "hall": ["hall", 0.5],
}


## A province building as drawn in its city, by its content `look`.
static func city_building(look: String, height: float) -> ArrayMesh:
	var entry: Array = CITY_LOOKS.get(look, CITY_LOOKS["hall"])
	var kind: String = entry[0]
	var built := landmark(kind, height)
	if built != null:
		return built
	var key := "city|%s|%s" % [kind, height]
	var pieces: Array = []
	match kind:
		"temple":
			# a round shrine under a tall roof, on a stepped base
			for piece in [["tower-hexagon-base", 0.0], ["tower-hexagon-roof", 1.31]]:
				pieces.append([CASTLE + piece[0], Transform3D(Basis().scaled(Vector3(1.6, 1.0, 1.6)), Vector3(0, piece[1], 0)), "accents"])
		"granary":
			pieces = _house_pieces(2, 1, 1, true, "high")
		"bank":
			pieces = _house_pieces(2, 1, 2, false, "gable")
			pieces.append([TOWN + "stall-red", Transform3D(Basis(), Vector3(0.5, 0, 1.2)), "roofs"])
		"factory":
			pieces = _house_pieces(3, 2, 1, false, "gable")
			for x in 3:
				pieces.append([TOWN + "chimney", _at(x, 0, 0, 0), "roofs"])
		"mine":
			pieces = _house_pieces(1, 1, 1, true, "point")
			pieces.append(["nature/rock_largeC", Transform3D(Basis().scaled(Vector3.ONE * 1.2), Vector3(1.3, 0, 0)), "none"])
			pieces.append([TOWN + "cart", Transform3D(Basis(), Vector3(0.6, 0, 1.1)), "roofs"])
		"academy":
			pieces = _house_pieces(3, 2, 2, false, "high")
			pieces.append([TOWN + "banner-green", _at(1, 1, 1, 3), "roofs"])
		"hospital", "station", "hall":
			pieces = _house_pieces(3, 1, 1, false, "gable")
		"aqueduct":
			# a run of stone arches
			for k in 4:
				pieces.append([TOWN + "wall-arch-top", Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(k, 0, 0)), "roofs"])
				pieces.append([TOWN + "pillar-stone", Transform3D(Basis(), Vector3(k - 0.5, 0, 0.45)), "roofs"])
		_:
			pieces = _house_pieces(2, 1, 1, false, "gable")
	return KenneyKit.compose(key, pieces, height)
