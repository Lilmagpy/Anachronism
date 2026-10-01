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
## The map is cut into tiles, each its own batch: Godot hides a batch by the camera's distance
## to the batch's centre, so one batch for the whole map vanished on large maps.
const TILE := 120.0
const S := 4.0                      ## settlements are drawn larger than life so they read
const PEOPLE_PER_TOWN := 160000
const PEOPLE_PER_VILLAGE := 40000
const MAX_VILLAGES := 40

var map: ProvinceMap
var earth: EarthBuilder
var rng := RandomNumberGenerator.new()
var _parts := {}   ## part name -> {mesh, transforms, colours, multimesh}
var clearings: Array = []   ## [pixel, radius] of each chief city, kept free of trees
var _owned: Array = []   ## [part, instance index, site index, how much owner colour]
var _material := StandardMaterial3D.new()   ## shared by every batch: colour comes per instance
var style := "east"   ## the building style of the province being built


func _init(province_map: ProvinceMap) -> void:
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.9
	map = province_map
	earth = province_map.earth
	var house := BoxMesh.new()
	house.size = Vector3(0.16, 0.09, 0.11) * S
	var roof := PrismMesh.new()
	roof.size = Vector3(0.2, 0.07, 0.14) * S
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
	var steep_roof := PrismMesh.new()
	steep_roof.size = Vector3(0.19, 0.13, 0.13) * S
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
	for entry in [["dome", dome], ["house", house], ["roof", roof], ["wall", wall], ["tower", tower],
			["hall", hall], ["hall_roof", hall_roof], ["terrace", terrace], ["field", field],
			["pole", pole], ["banner", banner], ["flat_roof", flat_roof], ["steep_roof", steep_roof],
			["low_roof", low_roof], ["yurt", yurt], ["yurt_roof", yurt_roof],
			["round_tower", round_tower], ["spire", spire], ["column", column], ["pyramid", pyramid]]:
		_parts[entry[0]] = {"mesh": entry[1], "transforms": [], "colours": []}


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
		elif item[0] == "banner":
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
	var height: float = _parts[part]["mesh"].get_aabb().size.y * scale.y
	_parts[part]["transforms"].append(Transform3D(basis, ground + Vector3(0, lift + height / 2.0, 0)))
	_parts[part]["colours"].append(colour)
	if site >= 0 and (mix > 0.0 or part == "banner"):
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
			var white := Color(0.93, 0.91, 0.85).darkened(rng.randf() * 0.08)
			var tile := Color(0.74, 0.38, 0.24).lerp(Color(0.62, 0.30, 0.20), rng.randf())
			_add("house", pixel, 0.0, turn, Vector3.ONE * size, white)
			_add("low_roof", pixel, 0.09 * S * size, turn, Vector3.ONE * size, tile, site, tint * 0.6)
		"northern":
			var timber := Color(0.86, 0.80, 0.66).lerp(Color(0.55, 0.40, 0.26), rng.randf() * 0.6)
			var thatch := Color(0.52, 0.42, 0.26).lerp(Color(0.32, 0.30, 0.30), rng.randf() * 0.5)
			_add("house", pixel, 0.0, turn, Vector3.ONE * size, timber)
			_add("steep_roof", pixel, 0.09 * S * size, turn, Vector3.ONE * size, thatch, site, tint)
		_:
			var walls := Color(0.78, 0.72, 0.60).darkened(rng.randf() * 0.15)
			var roof := Color(0.26, 0.27, 0.30).lerp(Color(0.40, 0.30, 0.22), rng.randf() * 0.5)
			_add("house", pixel, 0.0, turn, Vector3.ONE * size, walls)
			_add("roof", pixel, 0.09 * S * size, turn, Vector3.ONE * size, roof, site, tint)


## A town or village: houses around a centre, with fields around it.
func _cluster(centre: Vector2, houses: int, radius: float, fields: bool, site: int, mix: float) -> void:
	var turn := rng.randf() * PI
	for i in houses:
		var offset := Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius) * 0.7).rotated(turn)
		_house(centre + offset * S, turn + (PI / 2.0 if rng.randf() < 0.3 else 0.0), rng.randf_range(0.8, 1.2), site, mix)
	if fields:
		var crops := [Color(0.48, 0.46, 0.28), Color(0.36, 0.42, 0.24), Color(0.44, 0.38, 0.27)]
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
		_house(p, turn + (PI / 2.0 if rng.randf() < 0.5 else 0.0), rng.randf_range(0.9, 1.3), index, 0.7)
	# the owner's banner flies over every chief city; a capital's is twice the size
	var flag := 1.6 if site["capital"] else 1.0
	var mast := centre + Vector2(half * 0.55, -half * 0.55) if site["capital"] else centre
	_add("pole", mast, 0.0, 0.0, Vector3.ONE * flag, Color(0.35, 0.25, 0.15))
	_add("banner", mast + Vector2(0.15 * S * flag, 0), 0.45 * S * flag, 0.0, Vector3.ONE * flag, Color.WHITE, index, 1.0)
	if site["capital"]:
		if style != "steppe":
			_walls(centre, half, index)
		_palace(centre, index)


## A capital's walls with corner and gate towers, in the local stone or earth.
func _walls(centre: Vector2, half: float, index: int) -> void:
	var stone := {"east": Color(0.66, 0.56, 0.42), "nile": Color(0.74, 0.60, 0.40),
		"near_east": Color(0.66, 0.52, 0.36), "classical": Color(0.80, 0.77, 0.70),
		"south_asian": Color(0.72, 0.44, 0.30),
		"northern": Color(0.58, 0.57, 0.55)}[style] as Color
	var corner_part := "round_tower" if style in ["northern", "classical"] else "tower"
	var corners := [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	for side in 4:
		var a: Vector2 = centre + corners[side]
		var b: Vector2 = centre + corners[(side + 1) % 4]
		var length := a.distance_to(b)
		var angle := -(b - a).angle()
		var pieces := int(ceil(length / (0.9 * S)))
		for k in pieces:
			var p := a.lerp(b, (k + 0.5) / pieces)
			if earth.is_wet(p):
				continue  # the sea is the wall on that side
			_add("wall", p, 0.0, angle, Vector3(length / pieces / S + 0.02, 1, 1), stone, index, 0.2)
		if not earth.is_wet(a):
			_add(corner_part, a, 0.0, 0.0, Vector3.ONE, stone.darkened(0.1), index, 0.35)
		if not earth.is_wet(a.lerp(b, 0.5)):
			_add("tower", a.lerp(b, 0.5), 0.0, 0.0, Vector3(1.3, 1.2, 1.3), stone.darkened(0.15), index, 0.35)
		if style == "northern" and not earth.is_wet(a):
			_add("spire", a, 0.3 * S, 0.0, Vector3(0.9, 0.7, 0.9), Color(0.30, 0.30, 0.34), index, 0.5)


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
			# a temple of columns under a low pediment
			_add("terrace", centre, 0.0, 0.0, Vector3(1.0, 0.8, 0.8), Color(0.86, 0.84, 0.78))
			for k in 6:
				for row in [-1, 1]:
					var at := centre + Vector2((k - 2.5) * 0.1 * S, row * 0.16 * S)
					_add("column", at, 0.064 * S, 0.0, Vector3.ONE, Color(0.96, 0.95, 0.90))
			_add("low_roof", centre, 0.264 * S, 0.0, Vector3(3.3, 2.0, 2.6), Color(0.92, 0.90, 0.84), index, 0.35)
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
			_add("tower", centre, 0.0, 0.0, Vector3(2.4, 1.6, 2.0), Color(0.60, 0.59, 0.56))
			_add("steep_roof", centre, 0.42 * S, 0.0, Vector3(2.0, 1.4, 2.2), Color(0.26, 0.26, 0.30), index, 0.55)
			var church := centre + Vector2(0.55, 0.35) * S
			_add("hall", church, 0.0, 0.0, Vector3(0.45, 1.0, 0.4), Color(0.80, 0.78, 0.72))
			_add("round_tower", church + Vector2(0.14, 0) * S, 0.0, 0.0, Vector3(0.5, 1.6, 0.5), Color(0.80, 0.78, 0.72))
			_add("spire", church + Vector2(0.14, 0) * S, 0.48 * S, 0.0, Vector3(0.5, 1.2, 0.5), Color(0.26, 0.26, 0.30), index, 0.4)
		_:
			_add("terrace", centre, 0.0, 0.0, Vector3.ONE, Color(0.62, 0.55, 0.45))
			_add("hall", centre, 0.08 * S, 0.0, Vector3.ONE, Color(0.55, 0.20, 0.14))
			_add("hall_roof", centre, 0.26 * S, 0.0, Vector3.ONE, Color(0.18, 0.18, 0.20), index, 0.55)


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
	instance.material_override = _material
	instance.visibility_range_end = SHOW_WITHIN
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
