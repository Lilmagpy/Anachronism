## Towns and cities on the real map, sized by each province's population (step 2.6).
##
## Zoomed out they are hidden, the way Rise of Kingdoms reveals detail as you zoom in (D-052).
## Each province gets its chief city at its centre: walled and with a palace hall if it is a
## capital. Towns and villages are spread over its lowest, flattest land, since that is where
## people farmed. Placement is seeded by the province id, so the map always looks the same.
## Buildings follow the region of the province's first owner (its portrait family): East
## Asian rammed-earth walls and dark tiled roofs; flat-roofed mud brick and a stepped temple
## along the Nile and in the Near East; white walls, terracotta and a columned temple around
## the Mediterranean; steep roofs, stone keeps and spires in the north; felt tents and a
## great yurt on the steppe.
##
## Cities and towns wear their owner's colour: roofs, capital walls and a banner over every
## chief city. When a province changes hands, `recolour()` repaints them in place.
class_name Settlements
extends RefCounted

const SHOW_WITHIN := 320.0          ## camera distance at which settlements appear
const FAR_UNTIL := 1400.0           ## city icons stand in for them out to here
## The map is cut into tiles, each its own batch: Godot hides a batch by the camera's distance
## to the batch's centre, so one batch for the whole map vanished on large maps.
const TILE := 120.0
const S := 4.0                      ## settlements are drawn larger than life so they read
const PEOPLE_PER_TOWN := 160000
const PEOPLE_PER_VILLAGE := 40000
const MAX_VILLAGES := 40
const ICON := 9.0                   ## a far-off city icon's height in map units
const CELL := 0.11 * S              ## one kit grid cell (a house's width) in map units

var map: ProvinceMap
var earth: EarthBuilder
var rng := RandomNumberGenerator.new()
var _parts := {}   ## part name -> {mesh, transforms, colours, multimesh}
var clearings: Array = []   ## [pixel, radius] of each chief city, kept free of trees
var _chimneys: Array = []   ## where hearth smoke rises over capitals
var _owned: Array = []   ## [part, instance index, site index, how much owner colour]
var _material := StandardMaterial3D.new()   ## shared by every batch: colour comes per instance
var style := "east"   ## the building style of the province being built


func _init(province_map: ProvinceMap) -> void:
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true   # instance colours are everyday (sRGB) colours
	_material.roughness = 0.9
	map = province_map
	earth = province_map.earth
	var house := BoxMesh.new()
	house.size = Vector3(0.16, 0.09, 0.11) * S
	var wall := BoxMesh.new()
	wall.size = Vector3(1.0, 0.16, 0.07) * S
	var tower := BoxMesh.new()
	tower.size = Vector3(0.16, 0.26, 0.16) * S
	var hall := BoxMesh.new()
	hall.size = Vector3(0.5, 0.18, 0.32) * S
	var hall_roof := PrismMesh.new()
	hall_roof.size = Vector3(0.62, 0.16, 0.42) * S
	var terrace := BoxMesh.new()
	terrace.size = Vector3(0.7, 0.08, 0.5) * S
	var field := BoxMesh.new()
	field.size = Vector3(0.34, 0.012, 0.24) * S
	var pole := CylinderMesh.new()
	pole.top_radius = 0.012 * S
	pole.bottom_radius = 0.016 * S
	pole.height = 0.7 * S
	pole.radial_segments = 6
	var banner := BoxMesh.new()
	banner.size = Vector3(0.3, 0.2, 0.012) * S
	var flat_roof := BoxMesh.new()
	flat_roof.size = Vector3(0.18, 0.02, 0.13) * S
	var low_roof := PrismMesh.new()
	low_roof.size = Vector3(0.2, 0.045, 0.14) * S
	var yurt := CylinderMesh.new()
	yurt.top_radius = 0.08 * S
	yurt.bottom_radius = 0.08 * S
	yurt.height = 0.06 * S
	yurt.radial_segments = 10
	var yurt_roof := CylinderMesh.new()
	yurt_roof.top_radius = 0.01 * S
	yurt_roof.bottom_radius = 0.09 * S
	yurt_roof.height = 0.05 * S
	yurt_roof.radial_segments = 10
	var round_tower := CylinderMesh.new()
	round_tower.top_radius = 0.09 * S
	round_tower.bottom_radius = 0.1 * S
	round_tower.height = 0.3 * S
	round_tower.radial_segments = 10
	var spire := CylinderMesh.new()
	spire.top_radius = 0.0
	spire.bottom_radius = 0.11 * S
	spire.height = 0.22 * S
	spire.radial_segments = 8
	var column := CylinderMesh.new()
	column.top_radius = 0.02 * S
	column.bottom_radius = 0.022 * S
	column.height = 0.2 * S
	column.radial_segments = 6
	var pyramid := CylinderMesh.new()
	pyramid.top_radius = 0.0
	pyramid.bottom_radius = 0.45 * S
	pyramid.height = 0.45 * S
	pyramid.radial_segments = 4
	var dome := SphereMesh.new()  # a stupa's dome: a half sphere on its drum
	dome.radius = 0.32 * S
	dome.height = 0.32 * S
	dome.is_hemisphere = true
	dome.radial_segments = 16
	dome.rings = 6
	for entry in [["dome", dome], ["house", house], ["wall", wall], ["tower", tower],
			["hall", hall], ["hall_roof", hall_roof], ["terrace", terrace], ["field", field],
			["pole", pole], ["banner", banner], ["flat_roof", flat_roof],
			["low_roof", low_roof], ["yurt", yurt], ["yurt_roof", yurt_roof],
			["round_tower", round_tower], ["spire", spire], ["column", column], ["pyramid", pyramid]]:
		_parts[entry[0]] = {"mesh": entry[1], "transforms": [], "colours": []}
	var furrows := ShaderMaterial.new()
	furrows.shader = load("res://shaders/field.gdshader")
	_parts["field"]["material"] = furrows
	var walls := ShaderMaterial.new()
	walls.shader = load("res://shaders/house.gdshader")
	_parts["house"]["material"] = walls
	# castles from the Kenney castle kit (CC0, G1): their blue roofs and flags take the
	# owner's colour; they keep their own stone (`kit` parts are drawn with their own materials)
	for entry in [
			["k_wall", KenneyKit.mesh("castle/wall", 0.24 * S)],
			["k_tower", KenneyKit.stack(["castle/tower-square-base", "castle/tower-square-mid",
				"castle/tower-square-top-roof-high"], 0.62 * S)],
			["k_round", KenneyKit.stack(["castle/tower-hexagon-base", "castle/tower-hexagon-mid",
				"castle/tower-hexagon-roof"], 0.66 * S)],
			["k_keep", KenneyKit.stack(["castle/tower-square-base", "castle/tower-square-mid-windows",
				"castle/tower-square-mid", "castle/tower-square-top-roof-high"], 1.05 * S)],
			["k_gate", KenneyKit.mesh("castle/gate", 0.36 * S)],
			["k_flag", KenneyKit.mesh("castle/flag-banner-long", 0.75 * S)],
			# houses of plaster or timber from the fantasy-town kit: their roofs take the
			# instance colour (terracotta, slate, thatch or the owner's)
			["k_cottage", Buildings.house(1, 1, 1, false, "point", 1.5 * CELL)],
			["k_house", Buildings.house(2, 1, 1, false, "gable", 1.57 * CELL)],
			["k_hall", Buildings.house(2, 1, 2, false, "gable", 2.57 * CELL)],
			["k_timber", Buildings.house(1, 1, 2, true, "high", 3.15 * CELL)],
			["k_longhouse", Buildings.house(2, 1, 1, true, "high", 2.15 * CELL)]]:
		_parts[entry[0]] = {"mesh": entry[1], "transforms": [], "colours": [], "kit": true}
	# seen from far off, when the towns themselves are hidden, each chief city stands as one
	# larger-than-life icon in its owner's colours, as cities do on Rise of Kingdoms' map
	for entry in [["i_castle", Buildings.castle_icon(ICON * 1.5)], ["i_town", Buildings.town_icon(ICON)]]:
		_parts[entry[0]] = {"mesh": entry[1], "transforms": [], "colours": [], "kit": true, "far": true}


func build(parent: Node3D) -> void:
	for index in map.sites.size():
		var site: Dictionary = map.sites[index]
		if site["sea"]:
			continue
		rng.seed = hash(site["id"])
		style = style_of(map.civ_portraits.get(site["owner"], ""))
		var population: int = site["population"]
		var cells := _good_land(index)
		if cells.is_empty():
			continue
		_city(site, population, index)
		var towns := clampi(population / PEOPLE_PER_TOWN, 0, 12)
		var villages := clampi(population / PEOPLE_PER_VILLAGE, 1, MAX_VILLAGES)
		for i in towns:
			_cluster(_pick(cells), rng.randi_range(7, 14), 0.55, true, index, 0.45)
		for i in villages:
			_cluster(_pick(cells), rng.randi_range(2, 5), 0.3, rng.randf() < 0.6, index, 0.0)
	var holder := Node3D.new()
	holder.name = "Settlements"
	parent.add_child(holder)
	for spot in _chimneys:
		holder.add_child(_smoke(spot))
	for part in _parts:
		var entry: Dictionary = _parts[part]
		var groups := {}   # tile -> indices of this part's instances there
		for i in entry["transforms"].size():
			var origin: Vector3 = entry["transforms"][i].origin
			var key := Vector2i(floori(origin.x / TILE), floori(origin.z / TILE))
			if not groups.has(key):
				groups[key] = []
			groups[key].append(i)
		entry["where"] = []
		entry["where"].resize(entry["transforms"].size())
		for key in groups:
			holder.add_child(_multimesh(entry, groups[key]))
	recolour()


## Repaint roofs, walls and banners in their province's current owner's colour.
func recolour() -> void:
	for item in _owned:
		var entry: Dictionary = _parts[item[0]]
		var where: Array = entry["where"][item[1]]
		var mm: MultiMesh = where[0]
		var base: Color = entry["colours"][item[1]]
		var owner: Variant = map.sites[item[2]]["owner"]
		var colour := base
		if owner != null and map.civ_colours.has(owner):
			colour = base.lerp(map.civ_colours[owner], item[3])
		elif item[0] in ["banner", "k_flag", "i_castle", "i_town"]:
			colour = Color(0.85, 0.82, 0.75)  # a masterless city flies a plain flag
		mm.set_instance_color(where[1], colour)

## A portrait style's building style: east, nile, near_east, classical, northern, steppe or
## south_asian.
static func style_of(portrait: String) -> String:
	if portrait in ["steppe", "rus"]:
		return "steppe" if portrait == "steppe" else "northern"
	if portrait in ["pharaoh", "kushite"]:
		return "nile"
	match Portrait.FAMILY.get(portrait, ""):
		"near_east":
			return "near_east"
		"classical":
			return "classical"
		"northern":
			return "northern"
		"south_asian":
			return "south_asian"
	return "east"

# --- where people live -------------------------------------------------------------------

## The province's cells, flattest and lowest first weighted in: a list to draw from.
func _good_land(index: int) -> Array:
	var cells: Array = []
	for c in map.cells_in(index):
		var metres: float = map.metres[c]
		var slope := _slope(c)
		# Plains and valley floors hold the farms; steep or high land very few.
		var weight := 1.0 / (1.0 + slope / 60.0) / (1.0 + maxf(metres, 0.0) / 900.0)
		if weight > 0.25:
			cells.append(c)
	return cells


func _slope(c: int) -> float:
	var q := c % map.cols
	var r := c / map.cols
	var worst := 0.0
	for n in [c - 1 if q > 0 else c, c + 1 if q < map.cols - 1 else c,
			c - map.cols if r > 0 else c, c + map.cols if r < map.rows - 1 else c]:
		worst = maxf(worst, absf(map.metres[n] - map.metres[c]))
	return worst


func _pick(cells: Array) -> Vector2:
	var c: int = cells[rng.randi() % cells.size()]
	var cell := Vector2(c % map.cols, c / map.cols)
	return (cell + Vector2(rng.randf(), rng.randf())) * ProvinceMap.CELL


# --- building ----------------------------------------------------------------------------

## Place one part; with `site` >= 0 and `mix` > 0 it takes on that province's owner colour.
func _add(part: String, pixel: Vector2, lift: float, turn: float, scale: Vector3, colour: Color,
		site := -1, mix := 0.0) -> void:
	var ground := earth.ground_at_pixel(pixel)
	var basis := Basis(Vector3.UP, turn).scaled(scale)
	var foot: float = -_parts[part]["mesh"].get_aabb().position.y * scale.y   # stand it on the ground
	_parts[part]["transforms"].append(Transform3D(basis, ground + Vector3(0, lift + foot, 0)))
	_parts[part]["colours"].append(colour)
	if site >= 0 and (mix > 0.0 or part in ["banner", "k_flag"]):
		_owned.append([part, _parts[part]["colours"].size() - 1, site, mix])


func _house(pixel: Vector2, turn: float, size := 1.0, site := -1, mix := 0.0) -> void:
	if earth.is_wet(pixel):
		return  # a coastal city stops at the shore
	var tint := mix * rng.randf_range(0.8, 1.1)
	match style:
		"steppe":
			var felt := Color(0.90, 0.86, 0.76).darkened(rng.randf() * 0.12)
			var big := size * 1.35  # tents read better a little larger than houses
			_add("yurt", pixel, 0.0, turn, Vector3.ONE * big, felt)
			_add("yurt_roof", pixel, 0.06 * S * big, turn, Vector3.ONE * big, felt.darkened(0.12), site, tint * 0.35)
		"nile", "near_east":
			# flat-roofed mud brick, a little taller; the roof terrace takes the owner's colour
			var brick := Color(0.70, 0.55, 0.38) if style == "near_east" else Color(0.78, 0.63, 0.42)
			brick = brick.darkened(rng.randf() * 0.12)
			_add("house", pixel, 0.0, turn, Vector3(1.0, 1.25, 1.0) * size, brick)
			_add("flat_roof", pixel, 0.11 * S * size, turn, Vector3.ONE * size, brick.lerp(Color(0.55, 0.40, 0.26), 0.4), site, tint * 0.3)
		"south_asian":
			# whitewash or fired brick under flat roofs, the roof terrace in the owner's colour
			var walls := Color(0.94, 0.90, 0.80) if rng.randf() < 0.5 else Color(0.76, 0.46, 0.32)
			walls = walls.darkened(rng.randf() * 0.1)
			_add("house", pixel, 0.0, turn, Vector3(1.0, 1.15, 1.0) * size, walls)
			_add("flat_roof", pixel, 0.105 * S * size, turn, Vector3.ONE * size, walls.darkened(0.2), site, tint * 0.5)
		"classical":
			# limewashed houses under terracotta, a few of two storeys
			var tile := Color(0.90, 0.56, 0.38).lerp(Color(0.80, 0.44, 0.32), rng.randf())
			var part := "k_cottage" if rng.randf() < 0.35 else ("k_hall" if rng.randf() < 0.25 else "k_house")
			_add(part, pixel, 0.0, turn, Vector3.ONE * size, tile, site, tint * 0.35)
		"northern":
			# timber-framed houses under steep thatch or slate
			var thatch := Color(0.70, 0.56, 0.34).lerp(Color(0.38, 0.38, 0.42), rng.randf() * 0.6)
			var part := "k_timber" if rng.randf() < 0.4 else "k_longhouse"
			_add(part, pixel, 0.0, turn, Vector3.ONE * size, thatch, site, tint)
		_:
			# plastered houses under dark tiled roofs
			var roof := Color(0.50, 0.53, 0.58).lerp(Color(0.56, 0.44, 0.36), rng.randf() * 0.5)
			var part := "k_house" if rng.randf() < 0.6 else ("k_hall" if rng.randf() < 0.3 else "k_cottage")
			_add(part, pixel, 0.0, turn, Vector3.ONE * size, roof, site, tint)


## A town or village: houses around a centre, with fields around it.
func _cluster(centre: Vector2, houses: int, radius: float, fields: bool, site: int, mix: float) -> void:
	var turn := rng.randf() * PI
	for i in houses:
		var offset := Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius) * 0.7).rotated(turn)
		_house(centre + offset * S, turn + (PI / 2.0 if rng.randf() < 0.3 else 0.0), rng.randf_range(0.8, 1.2), site, mix)
	if fields:
		var crops := [Color(0.86, 0.72, 0.30), Color(0.55, 0.70, 0.28), Color(0.74, 0.64, 0.30), Color(0.45, 0.62, 0.26)]
		for i in houses + 2:
			var angle := rng.randf() * TAU
			var at := centre + Vector2(cos(angle), sin(angle)) * (radius + rng.randf_range(0.3, 0.9)) * S
			if earth.is_wet(at):
				continue
			_add("field", at, 0.0, turn, Vector3.ONE, crops[rng.randi() % crops.size()])


## The province's chief city; a capital gets walls, gate towers and a palace hall.
func _city(site: Dictionary, population: int, index: int) -> void:
	var centre: Vector2 = site["pixel"]
	var half := clampf(0.5 + sqrt(population / 100000.0) * 0.28, 0.6, 1.8) * S
	var turn := 0.0  # cities were laid out on the cardinal directions
	clearings.append([centre, half * 1.25])
	var houses := clampi(population / 30000, 8, 60)
	if style == "steppe":
		houses *= 2  # a khan's camp sprawls: many tents for few people
	for i in houses:
		var p := centre + Vector2(rng.randf_range(-half, half) * 0.85, rng.randf_range(-half, half) * 0.85)
		_house(p, turn + (PI / 2.0 if rng.randf() < 0.5 else 0.0), rng.randf_range(0.9, 1.3), index, 0.4)
	# the owner's banner flies over every chief city; a capital's is twice the size
	var flag := 1.6 if site["capital"] else 1.0
	var mast := centre + Vector2(half * 0.55, -half * 0.55) if site["capital"] else centre
	_add("k_flag", mast, 0.0, 0.0, Vector3.ONE * flag, Color.WHITE, index, 1.0)
	var size := clampf(0.8 + population / 2000000.0, 0.8, 1.4)
	_add("i_castle" if site["capital"] else "i_town", centre, 0.0, PI / 5.0, Vector3.ONE * size, Color.WHITE, index, 1.0)
	if site["capital"]:
		if style != "steppe":
			_walls(centre, half, index)
		_palace(centre, index)
		for k in 3:
			_chimneys.append(centre + Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half)) * 0.6)


## A capital's walls with corner towers and a gatehouse on each side (Kenney castle kit);
## roofs and banners fly the owner's colours.
func _walls(centre: Vector2, half: float, index: int) -> void:
	var stone := Color.WHITE
	var corner_part := "k_round" if style in ["northern", "classical"] else "k_tower"
	var corners := [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	var piece_width := 0.24 * S / 1.31  # the wall model's width for its height
	for side in 4:
		var a: Vector2 = centre + corners[side]
		var b: Vector2 = centre + corners[(side + 1) % 4]
		var length := a.distance_to(b)
		var angle := -(b - a).angle()
		var pieces := int(ceil(length / piece_width))
		for k in pieces:
			var p := a.lerp(b, (k + 0.5) / pieces)
			if earth.is_wet(p) or (k == pieces / 2):
				continue  # the sea is the wall on that side; the gate stands mid-way
			_add("k_wall", p, 0.0, angle, Vector3(length / pieces / piece_width * 1.02, 1, 1), stone, index, 1.0)
		if not earth.is_wet(a):
			_add(corner_part, a, 0.0, 0.0, Vector3.ONE, stone, index, 1.0)
		var mid := a.lerp(b, (pieces / 2 + 0.5) / pieces)
		if not earth.is_wet(mid):
			_add("k_gate", mid, 0.0, angle, Vector3.ONE, stone, index, 1.0)


## The seat of power at a capital's heart, in the local manner.
func _palace(centre: Vector2, index: int) -> void:
	match style:
		"steppe":
			# the khan's great tent among the camp
			_add("yurt", centre, 0.0, 0.0, Vector3(2.6, 2.2, 2.6), Color(0.95, 0.92, 0.84))
			_add("yurt_roof", centre, 0.06 * S * 2.2, 0.0, Vector3(2.8, 2.6, 2.8), Color(0.70, 0.62, 0.50), index, 0.6)
		"nile":
			# a temple on its platform, and a pyramid on the desert edge
			_add("terrace", centre, 0.0, 0.0, Vector3.ONE, Color(0.74, 0.62, 0.44))
			_add("hall", centre, 0.08 * S, 0.0, Vector3(1.0, 1.1, 1.0), Color(0.86, 0.74, 0.52))
			_add("flat_roof", centre, 0.28 * S, 0.0, Vector3(3.0, 1.5, 2.6), Color(0.62, 0.48, 0.32), index, 0.35)
			for k in 4:  # painted columns along the temple front
				_add("column", centre + Vector2((k - 1.5) * 0.12 * S, 0.2 * S), 0.08 * S, 0.0, Vector3.ONE, Color(0.30, 0.45, 0.62))
			_add("pyramid", centre + Vector2(-2.2, 1.6) * S, 0.0, PI / 4.0, Vector3.ONE, Color(0.84, 0.70, 0.46))
		"near_east":
			# a stepped temple tower over the palace
			for k in 3:
				var step := 1.0 - k * 0.28
				_add("terrace", centre, k * 0.08 * S, 0.0, Vector3(step, 1.0, step * 1.3), Color(0.72, 0.58, 0.40).darkened(k * 0.05))
			_add("hall", centre, 0.24 * S, 0.0, Vector3(0.4, 0.8, 0.5), Color(0.30, 0.42, 0.62), index, 0.4)
		"classical":
			# a temple on a stepped platform, columns all round, under a tiled pediment roof
			var marble := Color(0.95, 0.93, 0.87)
			for k in 3:
				_add("terrace", centre, k * 0.03 * S, 0.0, Vector3(1.05 - k * 0.06, 0.38, 0.86 - k * 0.06), marble.darkened(0.12 - k * 0.04))
			_add("hall", centre, 0.09 * S, 0.0, Vector3(0.82, 0.95, 0.75), Color(0.80, 0.70, 0.58))   # the cella
			for k in 8:
				for row in [-1, 1]:
					_add("column", centre + Vector2((k - 3.5) * 0.085 * S, row * 0.17 * S), 0.09 * S, 0.0, Vector3.ONE, marble)
			for k in [-1, 1]:
				for row in [-0.085, 0.0, 0.085]:
					_add("column", centre + Vector2(k * 3.5 * 0.085 * S, row * S), 0.09 * S, 0.0, Vector3.ONE, marble)
			_add("terrace", centre, 0.29 * S, 0.0, Vector3(1.0, 0.45, 0.8), marble)   # the entablature
			_add("low_roof", centre, 0.33 * S, 0.0, Vector3(3.6, 1.1, 2.9), Color(0.86, 0.52, 0.36), index, 0.2)
		"south_asian":
			# a pillared hall with a curved roof, and a white stupa beside it
			_add("terrace", centre, 0.0, 0.0, Vector3.ONE, Color(0.72, 0.50, 0.36))
			_add("hall", centre, 0.08 * S, 0.0, Vector3(1.0, 1.1, 1.0), Color(0.92, 0.86, 0.72))
			_add("hall_roof", centre, 0.28 * S, 0.0, Vector3(1.0, 0.8, 1.0), Color(0.62, 0.36, 0.22), index, 0.5)
			var stupa := centre + Vector2(0.75, 0.45) * S
			_add("yurt", stupa, 0.0, 0.0, Vector3(4.2, 1.2, 4.2), Color(0.86, 0.82, 0.74))
			_add("dome", stupa, 0.07 * S, 0.0, Vector3.ONE, Color(0.97, 0.95, 0.90))
			_add("pole", stupa, 0.3 * S, 0.0, Vector3(1.0, 0.4, 1.0), UiStyle.GOLD, index, 0.0)
		"northern":
			# a stone keep with a steep roof, and a church spire beside it
			_add("k_keep", centre, 0.0, 0.0, Vector3(1.4, 1.0, 1.4), Color.WHITE, index, 1.0)
			var church := centre + Vector2(0.55, 0.35) * S
			_add("hall", church, 0.0, 0.0, Vector3(0.45, 1.0, 0.4), Color(0.80, 0.78, 0.72))
			_add("round_tower", church + Vector2(0.14, 0) * S, 0.0, 0.0, Vector3(0.5, 1.6, 0.5), Color(0.80, 0.78, 0.72))
			_add("spire", church + Vector2(0.14, 0) * S, 0.48 * S, 0.0, Vector3(0.5, 1.2, 0.5), Color(0.26, 0.26, 0.30), index, 0.4)
		_:
			# a palace hall of red pillars on a stone terrace, under a double roof of grey tile
			_add("terrace", centre, 0.0, 0.0, Vector3(1.2, 1.0, 1.2), Color(0.74, 0.70, 0.62))
			_add("terrace", centre, 0.08 * S, 0.0, Vector3(1.0, 0.6, 1.0), Color(0.80, 0.76, 0.68))
			_add("hall", centre, 0.13 * S, 0.0, Vector3(0.9, 0.9, 0.85), Color(0.66, 0.22, 0.16))
			for k in 6:
				_add("column", centre + Vector2((k - 2.5) * 0.085 * S, 0.15 * S), 0.13 * S, 0.0, Vector3(1.0, 0.85, 1.0), Color(0.72, 0.18, 0.12))
			_add("hall_roof", centre, 0.29 * S, 0.0, Vector3(1.15, 0.7, 1.15), Color(0.42, 0.44, 0.48), index, 0.35)
			_add("hall", centre, 0.38 * S, 0.0, Vector3(0.6, 0.45, 0.55), Color(0.66, 0.22, 0.16))
			_add("hall_roof", centre, 0.45 * S, 0.0, Vector3(0.8, 0.6, 0.8), Color(0.42, 0.44, 0.48), index, 0.35)


func _multimesh(entry: Dictionary, indices: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = entry["mesh"]
	mm.instance_count = indices.size()
	for local in indices.size():
		var i: int = indices[local]
		mm.set_instance_transform(local, entry["transforms"][i])
		mm.set_instance_color(local, entry["colours"][i])
		entry["where"][i] = [mm, local]
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	if entry.has("material"):
		instance.material_override = entry["material"]
	elif not entry.get("kit", false):
		instance.material_override = _material
	if entry.get("far", false):
		instance.visibility_range_begin = SHOW_WITHIN
		instance.visibility_range_end = FAR_UNTIL
	else:
		instance.visibility_range_end = SHOW_WITHIN
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON   # soft shadows under buildings (G1)
	return instance


## Hearth smoke drifting up from a city (G1): soft grey puffs that rise, swell and fade.
func _smoke(pixel: Vector2) -> CPUParticles3D:
	return smoke_at(earth.ground_at_pixel(pixel) + Vector3(0, 0.35 * S, 0), Color(0.9, 0.9, 0.92, 0.32))


## Smoke rising from `at` (hearths, forges); `colour`'s alpha is how thick it is.
static func smoke_at(at: Vector3, colour: Color) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.06 * S
	puff.height = 0.12 * S
	puff.radial_segments = 8
	puff.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	puff.material = material
	smoke.mesh = puff
	smoke.amount = 18
	smoke.lifetime = 5.0
	smoke.preprocess = 5.0
	smoke.direction = Vector3(0.3, 1, 0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.35 * S
	smoke.initial_velocity_max = 0.5 * S
	smoke.gravity = Vector3(0.08 * S, 0, 0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.6))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.45))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	smoke.color_ramp = fade
	smoke.position = at
	smoke.visibility_range_end = SHOW_WITHIN
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return smoke

