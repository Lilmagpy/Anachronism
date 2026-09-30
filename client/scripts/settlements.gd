## Towns and cities on the real map, sized by each province's population (step 2.6).
##
## Zoomed out they are hidden, the way Rise of Kingdoms reveals detail as you zoom in (D-052).
## Each province gets its chief city at its centre: walled and with a palace hall if it is a
## capital. Towns and villages are spread over its lowest, flattest land, since that is where
## people farmed. Placement is seeded by the province id, so the map always looks the same.
## The style follows the period in East Asia: rectangular rammed-earth walls, gate towers,
## pale walls and dark tiled roofs.
class_name Settlements
extends RefCounted

const SHOW_WITHIN := 320.0          ## camera distance at which settlements appear
const S := 4.0                      ## settlements are drawn larger than life so they read
const PEOPLE_PER_TOWN := 160000
const PEOPLE_PER_VILLAGE := 40000
const MAX_VILLAGES := 40

var map: ProvinceMap
var earth: EarthBuilder
var rng := RandomNumberGenerator.new()
var _parts := {}   ## part name -> {mesh, transforms, colours}


func _init(province_map: ProvinceMap) -> void:
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
	for entry in [["house", house], ["roof", roof], ["wall", wall], ["tower", tower],
			["hall", hall], ["hall_roof", hall_roof], ["terrace", terrace], ["field", field]]:
		_parts[entry[0]] = {"mesh": entry[1], "transforms": [], "colours": []}


func build(parent: Node3D) -> void:
	for index in map.sites.size():
		var site: Dictionary = map.sites[index]
		if site["sea"]:
			continue
		rng.seed = hash(site["id"])
		var population: int = site["population"]
		var cells := _good_land(index)
		if cells.is_empty():
			continue
		_city(site, population)
		var towns := clampi(population / PEOPLE_PER_TOWN, 0, 12)
		var villages := clampi(population / PEOPLE_PER_VILLAGE, 1, MAX_VILLAGES)
		for i in towns:
			_cluster(_pick(cells), rng.randi_range(7, 14), 0.55, true)
		for i in villages:
			_cluster(_pick(cells), rng.randi_range(2, 5), 0.3, rng.randf() < 0.6)
	var holder := Node3D.new()
	holder.name = "Settlements"
	parent.add_child(holder)
	for part in _parts:
		var entry: Dictionary = _parts[part]
		if not entry["transforms"].is_empty():
			holder.add_child(_multimesh(entry))


# --- where people live -------------------------------------------------------------------

## The province's cells, flattest and lowest first weighted in: a list to draw from.
func _good_land(index: int) -> Array:
	var cells: Array = []
	for c in map.cols * map.rows:
		if map.region[c] != index:
			continue
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

func _add(part: String, pixel: Vector2, lift: float, turn: float, scale: Vector3, colour: Color) -> void:
	var ground := earth.ground_at_pixel(pixel)
	var basis := Basis(Vector3.UP, turn).scaled(scale)
	var height: float = _parts[part]["mesh"].get_aabb().size.y * scale.y
	_parts[part]["transforms"].append(Transform3D(basis, ground + Vector3(0, lift + height / 2.0, 0)))
	_parts[part]["colours"].append(colour)


func _house(pixel: Vector2, turn: float, size := 1.0) -> void:
	var walls := Color(0.78, 0.72, 0.60).darkened(rng.randf() * 0.15)
	var roof := Color(0.26, 0.27, 0.30).lerp(Color(0.40, 0.30, 0.22), rng.randf() * 0.5)
	_add("house", pixel, 0.0, turn, Vector3.ONE * size, walls)
	_add("roof", pixel, 0.09 * S * size, turn, Vector3.ONE * size, roof)


## A town or village: houses around a centre, with fields around it.
func _cluster(centre: Vector2, houses: int, radius: float, fields: bool) -> void:
	var turn := rng.randf() * PI
	for i in houses:
		var offset := Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius) * 0.7).rotated(turn)
		_house(centre + offset * S, turn + (PI / 2.0 if rng.randf() < 0.3 else 0.0), rng.randf_range(0.8, 1.2))
	if fields:
		var crops := [Color(0.48, 0.46, 0.28), Color(0.36, 0.42, 0.24), Color(0.44, 0.38, 0.27)]
		for i in houses + 2:
			var angle := rng.randf() * TAU
			var at := centre + Vector2(cos(angle), sin(angle)) * (radius + rng.randf_range(0.3, 0.9)) * S
			_add("field", at, 0.0, turn, Vector3.ONE, crops[rng.randi() % crops.size()])


## The province's chief city; a capital gets walls, gate towers and a palace hall.
func _city(site: Dictionary, population: int) -> void:
	var centre: Vector2 = site["pixel"]
	var half := clampf(0.5 + sqrt(population / 100000.0) * 0.28, 0.6, 1.8) * S
	var turn := 0.0  # cities were laid out on the cardinal directions
	var houses := clampi(population / 30000, 8, 60)
	for i in houses:
		var p := centre + Vector2(rng.randf_range(-half, half) * 0.85, rng.randf_range(-half, half) * 0.85)
		_house(p, turn + (PI / 2.0 if rng.randf() < 0.5 else 0.0), rng.randf_range(0.9, 1.3))
	var earth_wall := Color(0.66, 0.56, 0.42)
	if site["capital"]:
		var corners := [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
		for side in 4:
			var a: Vector2 = centre + corners[side]
			var b: Vector2 = centre + corners[(side + 1) % 4]
			var length := a.distance_to(b)
			var angle := -(b - a).angle()
			var pieces := int(ceil(length / (0.9 * S)))
			for k in pieces:
				var p := a.lerp(b, (k + 0.5) / pieces)
				_add("wall", p, 0.0, angle, Vector3(length / pieces / S + 0.02, 1, 1), earth_wall)
			_add("tower", a, 0.0, 0.0, Vector3.ONE, earth_wall.darkened(0.1))
			_add("tower", a.lerp(b, 0.5), 0.0, 0.0, Vector3(1.3, 1.2, 1.3), earth_wall.darkened(0.15))
		_add("terrace", centre, 0.0, turn, Vector3.ONE, Color(0.62, 0.55, 0.45))
		_add("hall", centre, 0.08 * S, turn, Vector3.ONE, Color(0.55, 0.20, 0.14))
		_add("hall_roof", centre, 0.26 * S, turn, Vector3.ONE, Color(0.18, 0.18, 0.20))


func _multimesh(entry: Dictionary) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = entry["mesh"]
	mm.instance_count = entry["transforms"].size()
	for i in mm.instance_count:
		mm.set_instance_transform(i, entry["transforms"][i])
		mm.set_instance_color(i, entry["colours"][i])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	instance.visibility_range_end = SHOW_WITHIN
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
