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

const FolkHouses := preload("res://scripts/folk_houses.gd")
## The model-kit modules (D-280) by name: each has kinds() and build(kind).
const MODULE_NAMES := ["east", "classical", "northern", "steppe", "south", "walls", "civic"]
static var MODULES := {}

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
var _material := StandardMaterial3D.new()   ## (kept for reference; parts now use _plain)
var _models_material := ShaderMaterial.new()   ## the model kit's buildings (D-280)
var _plain := ShaderMaterial.new()   ## shared by plain parts: colour per instance, dissolves itself
var style := "east"   ## the building style of the province being built
var culture := ""     ## its owner's portrait style (samurai, joseon, punic ...), for local variants
var holder: Node3D   ## everything built, so the cities can be rebuilt as they grow


## Take every city off the map (before building them again, larger).
func remove() -> void:
	if holder != null and is_instance_valid(holder):
		holder.queue_free()


func _init(province_map: ProvinceMap) -> void:
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true   # instance colours are everyday (sRGB) colours
	_material.roughness = 0.9
	map = province_map
	earth = province_map.earth
	_plain.shader = load("res://shaders/plain.gdshader")
	_models_material.shader = load("res://shaders/models.gdshader")
	if MODULES.is_empty():
		for name in MODULE_NAMES:
			var path := "res://scripts/models/%s.gd" % name
			if ResourceLoader.exists(path):
				MODULES[name] = load(path)
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
	var paving := BoxMesh.new()   # one tile of a city's ground: lot, street or square
	paving.size = Vector3(1.0, 0.01, 1.0)
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
			["paving", paving], ["pole", pole], ["banner", banner], ["flat_roof", flat_roof],
			["low_roof", low_roof], ["yurt", yurt], ["yurt_roof", yurt_roof],
			["round_tower", round_tower], ["spire", spire], ["column", column], ["pyramid", pyramid]]:
		_parts[entry[0]] = {"mesh": entry[1], "transforms": [], "colours": []}
	var furrows := ShaderMaterial.new()
	furrows.shader = load("res://shaders/field.gdshader")
	_parts["field"]["material"] = furrows
	# city ground lit flat, like the storybook terrain around it (a lit box reads too dark)
	var ground := ShaderMaterial.new()
	ground.shader = load("res://shaders/paving.gdshader")
	_parts["paving"]["material"] = ground
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
	# houses in each civilisation's own style (D-275): roofs take the instance colour
	var folk := ShaderMaterial.new()
	folk.shader = load("res://shaders/folk.gdshader")
	for kind in FolkHouses.VARIANTS:
		for v in FolkHouses.VARIANTS[kind]:
			_parts["f_%s_%d" % [kind, v]] = {"mesh": FolkHouses.house(kind, v, CELL * 1.75), "transforms": [],
				"colours": [], "folk": true, "material": folk}
	for kind in ["pagoda", "obelisk"]:
		_parts["f_" + kind] = {"mesh": FolkHouses.house(kind, 0, CELL * 1.75), "transforms": [],
			"colours": [], "folk": true, "material": folk}
	# seen from far off, when the towns themselves are hidden, each chief city stands as one
	# larger-than-life icon in its owner's colours, as cities do on Rise of Kingdoms' map
	for entry in [["i_castle", Buildings.castle_icon(ICON * 1.5)], ["i_town", Buildings.town_icon(ICON)]]:
		_parts[entry[0]] = {"mesh": entry[1], "transforms": [], "colours": [], "kit": true, "far": true}


func build(parent: Node3D) -> void:
	# every chief city is planned first, so the towns and villages of a neighbouring
	# province never land inside one (D-279)
	for pass_no in 2:
		for index in map.sites.size():
			var site: Dictionary = map.sites[index]
			if site["sea"]:
				continue
			rng.seed = hash(site["id"]) + pass_no * 7919
			culture = str(map.civ_portraits.get(site["owner"], ""))
			style = style_of(culture)
			var population: int = site["population"]
			var cells := _good_land(index)
			if cells.is_empty():
				continue
			if pass_no == 0:
				_city(site, population, index)
				continue
			var towns := clampi(population / PEOPLE_PER_TOWN, 0, 12)
			var villages := clampi(population / PEOPLE_PER_VILLAGE, 1, MAX_VILLAGES)
			for i in towns:
				_village(cells, rng.randi_range(7, 14), true, index, 0.45)
			for i in villages:
				_village(cells, rng.randi_range(2, 5), rng.randf() < 0.6, index, 0.0)
	holder = Node3D.new()
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
		if entry.get("folk", false):
			mm.set_instance_custom_data(where[1], colour)
		else:
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


func _house(pixel: Vector2, turn: float, size := 1.0, site := -1, mix := 0.0, fit := 0.0) -> void:
	if earth.is_wet(pixel):
		return  # a coastal city stops at the shore
	var tint := mix * rng.randf_range(0.8, 1.1)
	var shrink := func(part: String, big: float) -> float:   # never wider than its lot (D-279)
		return minf(big, fit / maxf(_foot(part), 0.001)) if fit > 0.0 else big
	var models := _house_list()
	if not models.is_empty():   # the model kit's houses (D-280)
		var kinds: Array = models[1]
		var part := _model(str(models[0]), str(kinds[rng.randi() % kinds.size()]), HOUSE_UNIT)
		if part != "":
			var roof: Color = ROOF_BASE.get(style, Color(0.6, 0.5, 0.4))
			roof = roof.lightened(rng.randf_range(-0.08, 0.08))
			_add(part, pixel, 0.0, turn, Vector3.ONE * shrink.call(part, size), roof, site, maxf(tint, 0.25) * 0.6)
			return
	match style:
		"steppe":
			var felt := Color(0.90, 0.86, 0.76).darkened(rng.randf() * 0.12)
			var big: float = shrink.call("yurt_roof", size * 1.35)  # tents read better a little larger
			_add("yurt", pixel, 0.0, turn, Vector3.ONE * big, felt)
			_add("yurt_roof", pixel, 0.06 * S * big, turn, Vector3.ONE * big, felt.darkened(0.12), site, tint * 0.35)
		"nile", "near_east", "south_asian":
			# mud brick, plaster or whitewash under flat roofs, parapets, domes and pavilions
			var top: Color = {"nile": Color(0.58, 0.44, 0.28), "near_east": Color(0.56, 0.44, 0.32),
				"south_asian": Color(0.62, 0.46, 0.34)}[style]
			var part := "f_%s_%d" % [style, rng.randi() % 3]
			_add(part, pixel, 0.0, turn, Vector3.ONE * shrink.call(part, size), top.darkened(rng.randf() * 0.1), site, tint * 0.35)
		"classical":
			# limewashed houses under terracotta, a few of two storeys
			var tile := Color(0.90, 0.56, 0.38).lerp(Color(0.80, 0.44, 0.32), rng.randf())
			var part := "f_classical_%d" % (rng.randi() % 3)
			_add(part, pixel, 0.0, turn, Vector3.ONE * shrink.call(part, size), tile, site, tint * 0.35)
		"northern":
			# timber-framed houses under steep thatch or slate
			var thatch := Color(0.70, 0.56, 0.34).lerp(Color(0.38, 0.38, 0.42), rng.randf() * 0.6)
			var part := "k_timber" if rng.randf() < 0.4 else "k_longhouse"
			_add(part, pixel, 0.0, turn, Vector3.ONE * shrink.call(part, size), thatch, site, tint)
		_:
			# plaster and timber under dark tiled roofs with curling eaves
			var roof := Color(0.42, 0.45, 0.50).lerp(Color(0.52, 0.40, 0.34), rng.randf() * 0.5)
			var part := "f_east_%d" % (rng.randi() % 3)
			_add(part, pixel, 0.0, turn, Vector3.ONE * shrink.call(part, size), roof, site, tint * 0.6)


# --- town planning (D-279) ----------------------------------------------------------------
#
# Every building claims its ground: a circle in `_taken` (a grid of buckets), so nothing is
# built on top of anything else, and every footprint is tested dry all round, so nothing
# stands in the water. A city is laid out on lots: its outline follows the coast, rivers and
# hills around it (each city its own shape), its streets follow its people's way of building
# (a planned grid for Rome and China, lanes running out from the centre elsewhere, a ring road
# in the north), its public buildings take the best lots around the square, the walls follow
# the outline, and the suburbs grow along the roads out of the gates. Towns and villages are
# a street or two of houses with their fields around them, kept clear of the cities.

const LOT := CELL * 1.6                ## a city lot: one house and its yard
const PALACE_R := {"steppe": 0.35, "nile": 0.45, "near_east": 0.42, "classical": 0.45,
	"south_asian": 0.7, "northern": 0.45, "east": 0.55}   ## the palace's reach, in S
const BUCKET := 2.0

var _taken := {}   ## Vector2i bucket -> Array of [centre, radius]: ground already built on
var _feet := {}    ## part -> footprint radius at scale 1


## Which model-kit houses each style builds (D-280), listed by how common each kind is; a
## culture may have its own mix. Missing kinds (a module not yet made) fall back to the old ones.
const HOUSE_MODELS := {
	"east": ["east", ["house_1", "house_1", "house_2", "house_3", "house_6", "house_2"]],
	"east:samurai": ["east", ["house_4", "house_4", "house_4", "house_2", "house_6", "house_1"]],
	"east:joseon": ["east", ["house_5", "house_5", "house_5", "house_6", "house_1", "house_3"]],
	"east:hills": ["east", ["house_6", "house_6", "house_5", "house_1"]],
	"classical": ["classical", ["house_1", "house_2", "house_3", "house_4", "house_5", "house_6", "house_2", "house_1"]],
	"classical:punic": ["classical", ["house_5", "house_5", "house_5", "house_2", "house_6", "house_3"]],
	"northern": ["northern", ["house_1", "house_2", "house_3", "house_4", "house_5", "house_6"]],
	"northern:viking": ["northern", ["house_4", "house_4", "house_2", "house_6"]],
	"northern:rus": ["northern", ["house_5", "house_5", "house_2", "house_1"]],
	"steppe": ["steppe", ["yurt_1", "yurt_2", "yurt_3", "yurt_1"]],
	"nile": ["south", ["nile_house_1", "nile_house_2", "nile_house_3", "nile_house_4"]],
	"near_east": ["south", ["near_east_house_1", "near_east_house_2", "near_east_house_3", "near_east_house_4"]],
	"south_asian": ["south", ["south_asian_house_1", "south_asian_house_2", "south_asian_house_3", "south_asian_house_4"]],
}
## The seat of power at a capital's heart, by style (and culture).
const PALACE_MODELS := {
	"east": ["east", "palace"], "east:samurai": ["east", "castle_keep"],
	"classical": ["classical", "palace"], "northern": ["northern", "palace"],
	"steppe": ["steppe", "great_tent"], "nile": ["south", "nile_palace"],
	"near_east": ["south", "near_east_palace"], "near_east:assyrian": ["south", "ziggurat"],
	"near_east:hittite": ["south", "near_east_palace"], "south_asian": ["south", "south_asian_palace"],
}
## The roof colour each style's houses start from (the owner's colour is mixed in).
const ROOF_BASE := {"east": Color(0.40, 0.43, 0.48), "classical": Color(0.84, 0.47, 0.32),
	"northern": Color(0.46, 0.42, 0.40), "steppe": Color(0.86, 0.82, 0.74), "nile": Color(0.70, 0.56, 0.38),
	"near_east": Color(0.70, 0.60, 0.46), "south_asian": Color(0.74, 0.52, 0.36)}
const HOUSE_UNIT := LOT * 0.95   ## map units per model-kit unit for houses
const GRAND_UNIT := LOT * 1.15   ## ... and for palaces and great buildings


## The model-kit house list for the province being built, or [] for the old houses.
func _house_list() -> Array:
	var entry: Array = HOUSE_MODELS.get(style + ":" + culture, HOUSE_MODELS.get(style, []))
	if entry.is_empty() or not MODULES.has(entry[0]):
		return []
	return entry


## The palace part for the province being built ("" for the old palace).
func _palace_part() -> String:
	var entry: Array = PALACE_MODELS.get(style + ":" + culture, PALACE_MODELS.get(style, []))
	if entry.is_empty():
		return ""
	return _model(str(entry[0]), str(entry[1]), GRAND_UNIT)


## A model from a model-kit module (D-280) as a part "m_<module>_<kind>", made once; it shares
## the kit's material and takes its owner colour as instance custom data (like folk houses).
## `unit` is how many map units one model unit is. Returns "" if the module lacks the kind.
func _model(module: String, kind: String, unit: float) -> String:
	var part := "m_%s_%s" % [module, kind]
	if _parts.has(part):
		return part
	var script: GDScript = MODULES.get(module)
	if script == null or not (script.call("kinds") as Array).has(kind):
		return ""
	var mesh: ArrayMesh = _scaled_model(script, kind, unit)
	_parts[part] = {"mesh": mesh, "transforms": [], "colours": [], "folk": true, "material": _models_material}
	return part


static var _model_cache := {}


static func _scaled_model(script: GDScript, kind: String, unit: float) -> ArrayMesh:
	var key := "%s|%s|%s" % [script.resource_path, kind, unit]
	if _model_cache.has(key):
		return _model_cache[key]
	var raw: ArrayMesh = script.call("build", kind)
	var out := ArrayMesh.new()
	var st := SurfaceTool.new()
	for i in raw.get_surface_count():
		st.append_from(raw, i, Transform3D(Basis().scaled(Vector3.ONE * unit), Vector3.ZERO))
	st.commit(out)
	_model_cache[key] = out
	return out


## The radius of ground a part covers at scale 1 (from its mesh).
func _foot(part: String) -> float:
	if not _feet.has(part):
		var box: AABB = (_parts[part]["mesh"] as Mesh).get_aabb()
		_feet[part] = maxf(box.size.x, box.size.z) * 0.5
	return _feet[part]


## True when no building yet stands within `r` of `p`.
func _free(p: Vector2, r: float) -> bool:
	var lo := Vector2i(floori((p.x - r - 3.0) / BUCKET), floori((p.y - r - 3.0) / BUCKET))
	var hi := Vector2i(floori((p.x + r + 3.0) / BUCKET), floori((p.y + r + 3.0) / BUCKET))
	for bx in range(lo.x, hi.x + 1):
		for by in range(lo.y, hi.y + 1):
			for item in _taken.get(Vector2i(bx, by), []):
				if (item[0] as Vector2).distance_to(p) < float(item[1]) + r:
					return false
	return true


func _claim(p: Vector2, r: float) -> void:
	var key := Vector2i(floori(p.x / BUCKET), floori(p.y / BUCKET))
	if not _taken.has(key):
		_taken[key] = []
	_taken[key].append([p, r])


## True when the ground is dry all round `p` out to `r` (no footprint over the water).
func _dry(p: Vector2, r: float) -> bool:
	if earth.is_wet(p):
		return false
	for k in 8:
		var a := k * TAU / 8.0
		if earth.is_wet(p + Vector2(cos(a), sin(a)) * r):
			return false
	return true


## The way to the nearest water within `reach` (a unit vector), or zero inland.
func _sea_direction(centre: Vector2, reach: float) -> Vector2:
	for step in 6:
		var r := reach * (step + 1) / 6.0
		var sum := Vector2.ZERO
		for k in 24:
			var d := Vector2(cos(k * TAU / 24.0), sin(k * TAU / 24.0))
			if earth.is_wet(centre + d * r):
				sum += d
		if sum.length() > 0.01:
			return sum.normalized()
	return Vector2.ZERO


## Place a house of the local style in a lot of radius `fit`, scaled down to fit it.
func _fit_house(pixel: Vector2, turn: float, size: float, fit: float, site: int, mix: float) -> bool:
	if not _dry(pixel, fit) or not _free(pixel, fit):
		return false
	_house(pixel, turn, size, site, mix, fit)
	_claim(pixel, fit)
	return true


## The province's chief city, planned on its ground (D-279).
func _city(site: Dictionary, population: int, index: int) -> void:
	var centre: Vector2 = site["pixel"]
	var tier := int(site.get("tier", 0))   # village, town, city, great city, metropolis (D-127)
	var half := clampf(0.5 + sqrt(population / 100000.0) * 0.28, 0.6, 1.8) * S * (1.0 + 0.12 * tier)
	var houses := clampi(population / 30000, 8, 60) + tier * 8
	# a city on the water is laid out to face it; inland, on the lie of its own ground
	var sea := _sea_direction(centre, half * 1.3)
	var theta := sea.angle() if sea != Vector2.ZERO else rng.randf_range(-0.5, 0.5)
	if earth.is_wet(centre):   # the province's point is offshore: build on the nearest shore
		for r in range(1, 12):
			var found := false
			for k in 16:
				var p := centre + Vector2(cos(k * TAU / 16.0), sin(k * TAU / 16.0)) * r * LOT
				if _dry(p, LOT):
					centre = p
					found = true
					break
			if found:
				break
	clearings.append([centre, half * 1.35])
	if style == "steppe":
		_camp(site, centre, half, houses * 2, index)
		return
	var planned := style in ["classical", "east"]
	var shape := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var reach := func(phi: float) -> float:   # the city's own outline
		if planned:   # a planned city is near square, corners a little worn
			var c := maxf(absf(cos(phi)), absf(sin(phi)))
			return half * (0.92 + 0.06 * sin(3.0 * phi + shape[0])) / c * 0.82
		return half * (0.86 + 0.12 * sin(2.0 * phi + shape[0]) + 0.07 * sin(3.0 * phi + shape[1])
			+ 0.04 * sin(5.0 * phi + shape[2]))
	# the roads out of the city: on the grid's axes when planned, else fanning out
	var roads: Array = []
	if planned:
		roads = [0.0, PI / 2.0, PI, 3.0 * PI / 2.0]
	else:
		var count := rng.randi_range(3, 5)
		var start := rng.randf() * TAU
		for k in count:
			roads.append(start + TAU * k / count + rng.randf_range(-0.3, 0.3))
		if sea != Vector2.ZERO:
			roads[0] = 0.0   # one road runs down to the harbour
	var base := earth.metres_at(centre)
	var n := int(ceil(half * 1.7 / LOT))
	var lots := {}   # Vector2i -> [pixel, local, kind]
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var local := Vector2(i, j) * LOT
			var phi := local.angle()
			var edge: float = reach.call(phi)
			var inside: bool = local.length() <= edge
			var on_road := false
			for a in roads:
				var d := Vector2(cos(a), sin(a))
				if local.dot(d) > 0.0 and absf(local.cross(d)) < LOT * 0.55:
					on_road = true
			var suburb: bool = not inside and tier >= 2 and local.length() < edge * 1.55 and on_road
			if not inside and not suburb:
				continue
			var p := centre + local.rotated(theta)
			if not _dry(p, LOT * 0.55):
				continue
			if absf(earth.metres_at(p) - base) > 220.0:
				continue   # the city does not climb the mountain
			lots[Vector2i(i, j)] = [p, local, "suburb" if not inside else "lot", on_road]
	# keep only lots that can be walked to from the centre (not across a bay)
	var start_lot := Vector2i.ZERO
	if not lots.has(start_lot):
		var best := INF
		for key in lots:
			if (lots[key][1] as Vector2).length() < best:
				best = (lots[key][1] as Vector2).length()
				start_lot = key
	var reached := {start_lot: true}
	var queue: Array = [start_lot]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = at + step
			if lots.has(nxt) and not reached.has(nxt):
				reached[nxt] = true
				queue.append(nxt)
	for key in lots.keys():
		if not reached.has(key):
			lots.erase(key)
	if lots.is_empty():
		return
	var palace_part := _palace_part() if site["capital"] else ""
	var palace_reach: float = _foot(palace_part) if palace_part != "" else float(PALACE_R.get(style, 0.6)) * S
	if site["capital"]:   # the palace needs dry ground all round: the nearest lot that has it
		var palace_r := palace_reach
		var order := lots.keys()
		order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (lots[a][1] as Vector2).length() < (lots[b][1] as Vector2).length())
		for key in order:
			if _dry(lots[key][0], palace_r):
				start_lot = key
				break
	var heart: Vector2 = lots[start_lot][0]
	# the square at the heart, large enough for the palace and the public buildings
	var plaza := LOT * (0.8 if site.get("buildings", []).size() == 0 and not site["capital"] else 1.3)
	if site["capital"]:
		plaza = maxf(plaza, palace_reach * 0.95)
	var heart_local: Vector2 = lots[start_lot][1]
	var streets := {}
	for key in lots:
		var local: Vector2 = lots[key][1]
		var kind := "lot"
		if (local - heart_local).length() <= plaza:
			kind = "plaza"
		elif lots[key][3]:
			kind = "street"
		elif planned and (posmod(key.x, 6) == 3 or posmod(key.y, 5) == 2):
			kind = "street"
		elif style == "northern" and absf(local.length() - float(reach.call(local.angle())) * 0.6) < LOT * 0.5:
			kind = "street"   # the ring road where the old walls stood
		elif lots[key][2] == "suburb":
			kind = "yard"
		streets[key] = kind
	var ground: Color = {"near_east": Color(0.82, 0.70, 0.50), "nile": Color(0.85, 0.74, 0.54),
		"south_asian": Color(0.76, 0.60, 0.44), "northern": Color(0.56, 0.52, 0.42)}.get(style, Color(0.74, 0.66, 0.50))
	var street: Color = ground.lerp(Color(0.80, 0.74, 0.64), 0.45)
	var paved: Color = ground.lerp(Color(0.84, 0.80, 0.70), 0.6)
	for key in lots:
		var kind: String = streets[key]
		if kind == "yard" or (lots[key][2] == "suburb" and tier < 4):
			continue   # suburbs stand on their own fields, not paving
		# paving grows with the city (owner's wish): a young town's houses stand on the grass
		# round a small square; a city paves its streets; a great city paves everything
		if tier <= 1 and kind != "plaza":
			continue
		if tier == 2 and kind == "lot":
			continue
		var colour: Color = paved if kind == "plaza" else (street if kind == "street" else ground.darkened(rng.randf() * 0.08))
		colour.a = 1.0 if kind == "plaza" else (0.66 if kind == "street" else 0.33)   # the paving's pattern (D-280)
		_add("paving", lots[key][0], -0.55, -theta, Vector3(LOT * 1.03, 90.0, LOT * 1.03), colour)
	# the palace at the heart, the public buildings around the square
	if site["capital"]:
		if palace_part != "":   # the model kit's palace (D-280), its front to the main road
			_add(palace_part, heart, 0.0, -theta - PI / 2.0, Vector3.ONE, ROOF_BASE.get(style, Color.WHITE), index, 0.85)
			if style == "nile":
				_pyramid(heart, half, index)
		else:
			_palace(heart, index, -theta)
		_claim(heart, maxf(plaza - LOT * 0.5, LOT * 0.5))   # the square is the palace's ground
	else:
		_claim(heart, LOT * 0.5)
	var mast := heart + Vector2(plaza * 0.75, 0).rotated(theta + PI / 4.0)
	_add("k_flag", mast, 0.0, 0.0, Vector3.ONE * (1.6 if site["capital"] else 1.0), Color.WHITE, index, 1.0)
	_claim(mast, LOT * 0.25)
	var size := clampf(0.8 + population / 2000000.0, 0.8, 1.4)
	_add("i_castle" if site["capital"] else "i_town", centre, 0.0, PI / 5.0, Vector3.ONE * size, Color.WHITE, index, 1.0)
	# walls first, so nothing is built across them: along the outline, the outline, broken where the water guards the city and opened by gates
	if site["capital"] or tier >= 2:
		_city_walls(centre, theta, lots, streets, roads, index)
	var spots: Array = []   # building plots: the lots next to the square and the main streets
	for key in lots:
		if streets[key] != "lot":
			continue
		var next_to := false
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if streets.get(key + step, "") in ["plaza", "street"]:
				next_to = true
		if next_to:
			spots.append(key)
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (lots[a][1] as Vector2).distance_to(heart_local) < (lots[b][1] as Vector2).distance_to(heart_local))
	var looks: Array = (site.get("buildings", []) as Array).duplicate()
	if str(site.get("works", "")) != "":
		looks.append("|works|" + str(site["works"]))
	for extra in _landmarks(site, tier):
		looks.append(extra)
	for look in looks:
		_public_building(str(look), spots, lots, heart, theta, index)
	# the houses fill the rest, close at the heart and thinning out to the edge
	var houses_lots: Array = []
	for key in lots:
		if streets[key] in ["lot", "yard"]:
			houses_lots.append(key)
	var want := clampf(houses * 3.5 / maxf(houses_lots.size(), 1.0), 0.75, 1.0)
	var organic := not planned
	for key in houses_lots:
		var p: Vector2 = lots[key][0]
		var local: Vector2 = lots[key][1]
		var edge_here: float = reach.call(local.angle())
		var out := clampf(local.length() / maxf(edge_here, 0.1), 0.0, 1.6)
		if rng.randf() > want * lerpf(1.25, 0.7, minf(out, 1.0)):
			if rng.randf() < 0.12 and _dry(p, LOT * 0.4) and _free(p, LOT * 0.4):   # a garden
				_add("field", p, 0.0, -theta, Vector3(0.55, 1.0, 0.55), Color(0.46, 0.60, 0.30))
				_claim(p, LOT * 0.4)
			continue
		# a house faces its street
		var face := -theta
		for step in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			if streets.get(key + step, "") in ["street", "plaza"]:
				face = -theta - Vector2(step).angle() + PI / 2.0
				break
		var jitter := Vector2.ZERO
		if organic:   # lanes wander; houses sit a little askew
			jitter = Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05)) * LOT
			face += rng.randf_range(-0.25, 0.25)
		var big := lerpf(1.25, 0.85, minf(out, 1.0)) * rng.randf_range(0.92, 1.08)
		_fit_house(p + jitter.rotated(theta), face, big, LOT * 0.44, index, 0.4)
	# by a river or the sea: wooden piers out over the water
	if sea != Vector2.ZERO:
		_piers(lots, theta, sea)
	if style == "nile" and site["capital"]:
		_pyramid(heart, half, index)
	if site["capital"]:
		for k in 3:
			_chimneys.append(heart + Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half)) * 0.5)


## The great buildings a city of this style and rank raises beside its houses (D-280), as
## "|m:module:kind" entries for `_public_building`.
func _landmarks(site: Dictionary, tier: int) -> Array:
	var out: Array = []
	var capital: bool = site["capital"]
	match style:
		"east":
			if capital or tier >= 2:
				out.append("|m:east:pagoda")
			if tier >= 1:
				out.append("|m:east:gate")
		"classical":
			if tier >= 2 or capital:
				out.append("|m:classical:forum_hall")
			if tier >= 3:
				out.append("|m:classical:triumphal_arch")
			if tier >= 3 or (capital and tier >= 2):
				out.append("|m:classical:villa_great")
		"northern":
			if tier >= 1 or capital:
				out.append("|m:northern:church")
			if tier >= 2:
				out.append("|m:northern:market_hall")
		"nile":
			if capital or tier >= 2:
				out.append("|m:south:obelisk")
			if capital and tier >= 2:
				out.append("|m:south:sphinx")
		"near_east":
			if tier >= 2 and not capital:
				out.append("|m:south:ziggurat")
		"south_asian":
			if capital or tier >= 2:
				out.append("|m:south:stupa")
			if tier >= 1:
				out.append("|m:south:temple_shikhara")
	return out


## A public building (D-111) on the best free plot by the square or a main street, facing it.
## "|works|look" is one going up (in scaffolding); "|pagoda" the pagoda of an eastern city.
func _public_building(look: String, spots: Array, lots: Dictionary, heart: Vector2, theta: float, index: int) -> void:
	var building := look
	var part := ""
	if look.begins_with("|m:"):
		var bits := look.split(":")
		part = _model(bits[1], bits[2], GRAND_UNIT)
		if part == "":
			return
	elif look == "|pagoda":
		part = "f_pagoda"
	else:
		if look.begins_with("|works|"):
			building = look.substr(7)
		part = "b_" + building
		if not _parts.has(part):
			var entry: Array = Buildings.CITY_LOOKS.get(building, Buildings.CITY_LOOKS["hall"])
			_parts[part] = {"mesh": Buildings.city_building(building, float(entry[1]) * S), "transforms": [],
				"colours": [], "kit": true}
	var scale := 1.3 if part == "f_pagoda" else 1.0
	var r := _foot(part) * scale
	for key in spots:
		var p: Vector2 = lots[key][0]
		if not _dry(p, r) or not _free(p, r):
			continue
		var face := -(heart - p).angle() + PI / 2.0 if p.distance_to(heart) > 0.1 else -theta
		if look.begins_with("|works|"):
			_scaffold_at(part, p, face, r, index)
		elif look.begins_with("|m:"):
			_add(part, p, 0.0, face, Vector3.ONE, ROOF_BASE.get(style, Color.WHITE), index, 0.6)
		elif part == "f_pagoda":
			_add(part, p, 0.0, -theta, Vector3.ONE * scale, Color(0.36, 0.38, 0.42), index, 0.3)
		else:
			_add(part, p, 0.0, face, Vector3.ONE, Color(0.88, 0.55, 0.38), index, 0.4)
		_claim(p, r)
		return


## Building work in a city (D-127): the new building half-risen in its place, wrapped in
## timber scaffolding, with a crane over it.
func _scaffold_at(part: String, spot: Vector2, face: float, r: float, index: int) -> void:
	_add(part, spot, 0.0, face, Vector3(1.0, 0.55, 1.0), Color(0.88, 0.55, 0.38), index, 0.4)
	var timber := Color(0.62, 0.44, 0.26)
	var e := r * 0.8
	for corner in [Vector2(-e, -e), Vector2(e, -e), Vector2(e, e), Vector2(-e, e)]:
		_add("pole", spot + corner, 0.0, 0.0, Vector3(1.6, 0.9, 1.6), timber)
	for height in [0.18, 0.4]:   # walkways of planks
		_add("terrace", spot, height * S, face, Vector3(e * 2.0 / (0.7 * S), 0.2, e * 2.0 / (0.5 * S)), timber.lightened(0.1))
	var mast := spot + Vector2(e, 0)
	_add("pole", mast, 0.0, 0.0, Vector3(2.0, 1.8, 2.0), timber.darkened(0.1))
	_add("terrace", mast + Vector2(-e * 0.7, 0), 1.2 * S, 0.0, Vector3(1.1, 0.8, 0.1), timber.darkened(0.1))


## Walls along the city's own outline (Kenney castle kit): towers at the turns, a gatehouse
## where each road leaves, nothing where the water guards it. Roofs fly the owner's colours.
func _city_walls(centre: Vector2, theta: float, lots: Dictionary, streets: Dictionary, roads: Array, index: int) -> void:
	var sectors := 28
	var radius: Array = []
	radius.resize(sectors)
	radius.fill(0.0)
	for key in lots:
		if lots[key][2] != "lot":
			continue
		var local: Vector2 = lots[key][1]
		var k := posmod(int(round(local.angle() / TAU * sectors)), sectors)
		radius[k] = maxf(radius[k], local.length() + LOT * 0.75)
	var smooth: Array = []
	for k in sectors:   # an even line, not a saw
		var a: float = radius[(k + sectors - 1) % sectors]
		var b: float = radius[k]
		var c: float = radius[(k + 1) % sectors]
		smooth.append(maxf(b, (a + b + c) / 3.0) if b > 0.0 else 0.0)
	var corner_part := "k_round" if style in ["northern", "classical"] else "k_tower"
	var piece_width := 0.24 * S / 1.31   # the wall model's width for its height
	var gates := {}
	for a in roads:
		gates[posmod(int(round(float(a) / TAU * sectors)), sectors)] = true
	for k in sectors:
		var r0: float = smooth[k]
		var r1: float = smooth[(k + 1) % sectors]
		if r0 <= 0.0 or r1 <= 0.0:
			continue   # no city that way: the water is the wall
		var a := centre + Vector2(cos(k * TAU / sectors), sin(k * TAU / sectors)).rotated(theta) * r0
		var b := centre + Vector2(cos((k + 1) * TAU / sectors), sin((k + 1) * TAU / sectors)).rotated(theta) * r1
		var length := a.distance_to(b)
		var angle := -(b - a).angle()
		var pieces := maxi(1, int(ceil(length / piece_width)))
		for m in pieces:
			var p := a.lerp(b, (m + 0.5) / pieces)
			if earth.is_wet(p) or not _free(p, piece_width * 0.3):
				continue
			if gates.has(k) and m == pieces / 2:
				_add("k_gate", p, 0.0, angle, Vector3.ONE, Color.WHITE, index, 1.0)
				_claim(p, piece_width * 0.8)
				continue
			_add("k_wall", p, 0.0, angle, Vector3(length / pieces / piece_width * 1.02, 1, 1), Color.WHITE, index, 1.0)
		if k % 3 == 0 and _dry(a, piece_width * 0.4) and _free(a, piece_width * 0.4):
			_add(corner_part, a, 0.0, 0.0, Vector3.ONE, Color.WHITE, index, 1.0)
			_claim(a, piece_width * 0.5)


## Wooden piers from the waterfront out over the water, where the harbour road meets it.
func _piers(lots: Dictionary, theta: float, sea: Vector2) -> void:
	var timber := Color(0.50, 0.36, 0.22)
	var made := 0
	var keys := lots.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return absf((lots[a][1] as Vector2).cross(Vector2.RIGHT)) < absf((lots[b][1] as Vector2).cross(Vector2.RIGHT)))
	for key in keys:
		if made >= 2:
			return
		var p: Vector2 = lots[key][0]
		var out := p + sea * LOT * 0.9
		if not earth.is_wet(out) or not earth.is_wet(out + sea * LOT):
			continue
		var shore := earth.ground_at_pixel(p).y
		for m in 3:
			var q := p + sea * LOT * (0.7 + m * 0.8)
			var lift := shore - earth.ground_at_pixel(q).y + 0.05
			_add("terrace", q, lift, -sea.angle(), Vector3(0.35, 0.25, 0.12) * 4.0 / S, timber)
		made += 1


## A pyramid on the desert edge beyond a Nile capital: dry ground, away from the river.
func _pyramid(heart: Vector2, half: float, index: int) -> void:
	var r := 0.45 * S
	for step in 16:
		var a := step * TAU / 16.0
		for dist in [half * 1.6, half * 2.0, half * 2.5]:
			var p := heart + Vector2(cos(a), sin(a)) * float(dist)
			if _dry(p, r * 1.4) and _free(p, r * 1.2):
				_add("pyramid", p, 0.0, PI / 4.0, Vector3.ONE, Color(0.84, 0.70, 0.46))
				_claim(p, r * 1.2)
				clearings.append([p, r * 1.5])
				return


## A khan's camp: tents in loose rings around the great tent, none touching.
func _camp(site: Dictionary, centre: Vector2, half: float, tents: int, index: int) -> void:
	if site["capital"]:
		_palace(centre, index, 0.0)
	_claim(centre, float(PALACE_R["steppe"]) * S)
	_add("k_flag", centre + Vector2(LOT, -LOT), 0.0, 0.0, Vector3.ONE, Color.WHITE, index, 1.0)
	var placed := 0
	for attempt in tents * 4:
		if placed >= tents:
			break
		var ring := sqrt(rng.randf()) * half
		var a := rng.randf() * TAU
		var p := centre + Vector2(cos(a), sin(a)) * ring
		if _fit_house(p, rng.randf() * TAU, rng.randf_range(0.9, 1.3), LOT * 0.45, index, 0.4):
			placed += 1


## A town or village: a street or two of houses along a lane, its fields beyond, on the
## province's best farmland and clear of the cities and of each other.
func _village(cells: Array, houses: int, fields: bool, site: int, mix: float) -> void:
	var spacing := LOT * 0.95
	var reach := spacing * (houses / 2.0 + 1.0)
	var centre := Vector2.ZERO
	for attempt in 8:
		var p := _pick(cells)
		if _dry(p, spacing) and _free(p, reach * 0.6):
			centre = p
			break
	if centre == Vector2.ZERO:
		return
	var lane := rng.randf() * PI
	var along := Vector2(cos(lane), sin(lane))
	var across := Vector2(-along.y, along.x)
	var bend := rng.randf_range(-0.04, 0.04)   # the lane curves gently
	var placed := 0
	for k in houses * 2:
		if placed >= houses:
			break
		var t := (k / 2 - houses / 4.0) * spacing
		var side := 1.0 if k % 2 == 0 else -1.0
		var p := centre + along * t + across * (side * spacing * 0.62 + bend * t * t)
		p += Vector2(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1)) * spacing
		var face := -lane + (PI / 2.0 if side > 0.0 else -PI / 2.0) + rng.randf_range(-0.2, 0.2)
		if _fit_house(p, face, rng.randf_range(0.85, 1.1), spacing * 0.45, site, mix):
			placed += 1
	if placed == 0:
		return
	clearings.append([centre, reach * 0.7])
	if not fields:
		return
	var crops := [Color(0.86, 0.72, 0.30), Color(0.55, 0.70, 0.28), Color(0.74, 0.64, 0.30), Color(0.45, 0.62, 0.26)]
	var field_r := _foot("field") * 1.05
	for k in houses + 2:
		var a := rng.randf() * TAU
		var p := centre + Vector2(cos(a), sin(a)) * (reach * 0.6 + rng.randf_range(0.3, 1.2) * S)
		if _dry(p, field_r) and _free(p, field_r):
			_add("field", p, 0.0, -lane, Vector3.ONE, crops[rng.randi() % crops.size()])
			_claim(p, field_r)



## The seat of power at a capital's heart, in the local manner.
func _palace(centre: Vector2, index: int, _turn := 0.0) -> void:
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
			for side in [-1.0, 1.0]:   # obelisks flank the temple gate (D-275)
				_add("f_obelisk", centre + Vector2(side * 0.32, 0.42) * S, 0.0, 0.0, Vector3.ONE * 0.8, Color(0.9, 0.75, 0.35))
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
	var folk: bool = entry.get("folk", false)
	mm.use_colors = not folk   # folk houses keep their wall colours: the roof colour goes as custom data
	mm.use_custom_data = folk
	mm.mesh = entry["mesh"]
	mm.instance_count = indices.size()
	for local in indices.size():
		var i: int = indices[local]
		mm.set_instance_transform(local, entry["transforms"][i])
		if folk:
			mm.set_instance_custom_data(local, entry["colours"][i])
		else:
			mm.set_instance_color(local, entry["colours"][i])
		entry["where"][i] = [mm, local]
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	if entry.has("material"):
		instance.material_override = entry["material"]
	elif not entry.get("kit", false):
		instance.material_override = _plain
	if entry.get("far", false):
		Lod.between(instance, SHOW_WITHIN, FAR_UNTIL)  # crossfades with the town itself
	else:
		Lod.near(instance, SHOW_WITHIN)
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
	Lod.near(smoke, SHOW_WITHIN)
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return smoke

