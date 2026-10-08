## Builds the 3D world from the engine's view: terrain, sea, territory colours, borders, labels.
##
## Provinces and sea zones are "sites". Every point of the map belongs to its nearest site
## (a Voronoi map), measured after a gentle noise warp so coasts and borders wander naturally.
## Land takes its province's terrain type for height and colour; sea sites become water.
## Owners tint their land and draw bright bands where two owners meet.
class_name WorldBuilder
extends RefCounted

const CELL := 2.0           ## grid spacing in map units (about km)
const MARGIN := 230.0       ## terrain beyond the outermost sites (ends under the ocean)
const WARP := 22.0          ## how far coasts and borders wander
const BORDER_WIDTH := 4.5   ## half-width of the border band
const FAR := 130.0          ## beyond this from any site, land fades and sinks into the ocean

## Height and relief of each terrain type, and its base colour.
const TERRAIN := {
	"river_plains": {"base": 1.5, "relief": 1.0, "colour": Color(0.24, 0.42, 0.13)},
	"plains": {"base": 2.5, "relief": 2.5, "colour": Color(0.40, 0.48, 0.18)},
	"coast": {"base": 2.0, "relief": 2.0, "colour": Color(0.33, 0.46, 0.20)},
	"hills": {"base": 7.0, "relief": 9.0, "colour": Color(0.34, 0.38, 0.18)},
	"forest": {"base": 4.0, "relief": 5.0, "colour": Color(0.13, 0.30, 0.12)},
	"steppe": {"base": 3.0, "relief": 2.5, "colour": Color(0.52, 0.50, 0.26)},
	"mountains": {"base": 16.0, "relief": 26.0, "colour": Color(0.40, 0.38, 0.34)},
	"marsh": {"base": 0.8, "relief": 0.5, "colour": Color(0.27, 0.37, 0.22)},
	"desert": {"base": 3.0, "relief": 4.0, "colour": Color(0.70, 0.55, 0.32)},
}
const SAND := Color(0.80, 0.72, 0.50)
const SNOW := Color(0.93, 0.94, 0.96)
const ROCK := Color(0.38, 0.35, 0.32)
const SEABED := Color(0.20, 0.30, 0.32)
const UNKNOWN := Color(0.35, 0.36, 0.30)

var sites: Array = []   ## {pos: Vector2, sea: bool, province: Dictionary}
var centre := Vector2.ZERO
var owner_colours := {}
var relief := FastNoiseLite.new()
var warp := FastNoiseLite.new()
var grain := FastNoiseLite.new()


func _init(view: Dictionary) -> void:
	for civ in view["civs"]:
		owner_colours[civ["id"]] = Color(civ["colour"])
	var total := Vector2.ZERO
	for p in view["provinces"]:
		var pos := Vector2(p["position"][0], p["position"][1])
		sites.append({"pos": pos, "sea": false, "province": p})
		total += pos
	centre = total / view["provinces"].size()
	for s in view.get("seas", []):
		sites.append({"pos": Vector2(s["position"][0], s["position"][1]), "sea": true, "province": {}})
	var seed_value := int(view.get("seed", 1))
	relief.seed = seed_value
	relief.frequency = 0.011
	relief.fractal_octaves = 5
	relief.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	warp.seed = seed_value + 7
	warp.frequency = 0.009
	warp.fractal_octaves = 3
	grain.seed = seed_value + 13
	grain.frequency = 0.07


## Map position (x east, y south) to world position on the ground plane.
func to_world(map_pos: Vector2) -> Vector3:
	return Vector3(map_pos.x - centre.x, 0.0, map_pos.y - centre.y)


## Ground height at a map position (sea floor below zero).
func height_at(map_pos: Vector2) -> float:
	return _sample(map_pos)["height"]


func build(parent: Node3D) -> void:
	parent.add_child(_terrain_mesh())
	parent.add_child(_water())
	for site in sites:
		if not site["sea"]:
			parent.add_child(_label(site["province"], site["pos"]))


## Nearest and second-nearest site to a (warped) point.
func _nearest(map_pos: Vector2) -> Array:
	var warped := map_pos + Vector2(warp.get_noise_2dv(map_pos), warp.get_noise_2dv(map_pos + Vector2(500, 500))) * WARP
	var best := -1
	var second := -1
	var best_d := INF
	var second_d := INF
	for i in sites.size():
		var d: float = warped.distance_to(sites[i]["pos"])
		if d < best_d:
			second = best
			second_d = best_d
			best = i
			best_d = d
		elif d < second_d:
			second = i
			second_d = d
	return [best, best_d, second, second_d]


func _land_height(terrain: String, map_pos: Vector2) -> float:
	var t: Dictionary = TERRAIN.get(terrain, TERRAIN["plains"])
	var n := (relief.get_noise_2dv(map_pos) + 1.0) * 0.5
	return t["base"] + n * n * t["relief"] + grain.get_noise_2dv(map_pos) * 0.4


## Height, colour inputs and ownership for one point.
func _sample(map_pos: Vector2) -> Dictionary:
	var near := _nearest(map_pos)
	var a: Dictionary = sites[near[0]]
	var b: Dictionary = sites[near[2]]
	var edge: float = near[3] - near[1]   ## 0 on the boundary between the two sites
	var height: float
	if a["sea"]:
		height = -4.0 - smoothstep(0.0, 60.0, edge) * 14.0
		if not b["sea"]:
			height = lerpf(0.6, height, smoothstep(0.0, 14.0, edge))
	else:
		var own := _land_height(a["province"]["terrain"], map_pos)
		if b["sea"]:
			own = lerpf(0.4, own, smoothstep(0.0, 18.0, edge))
		else:
			var other := _land_height(b["province"]["terrain"], map_pos)
			own = lerpf(other, own, smoothstep(0.0, 36.0, edge) * 0.5 + 0.5)
		height = own
	var remoteness := smoothstep(FAR - 40.0, FAR + 40.0, near[1])
	if remoteness > 0.0 and not a["sea"]:
		height = lerpf(height, 3.0 + relief.get_noise_2dv(map_pos) * 3.0, remoteness)
	var shore := smoothstep(FAR + 20.0, FAR + 90.0, near[1] + warp.get_noise_2dv(map_pos * 0.5) * 30.0)
	height = lerpf(height, -18.0, shore)
	return {"height": height, "near": near, "edge": edge, "remote": remoteness}


func _colour(sample: Dictionary, map_pos: Vector2, slope: float) -> Color:
	var near: Array = sample["near"]
	var a: Dictionary = sites[near[0]]
	var b: Dictionary = sites[near[2]]
	var h: float = sample["height"]
	if a["sea"] or h < 0.0:
		return SEABED.lerp(SAND, smoothstep(-3.0, 0.5, h))
	var terrain: String = a["province"]["terrain"]
	var c: Color = TERRAIN.get(terrain, TERRAIN["plains"])["colour"]
	if not b["sea"]:
		var other: Color = TERRAIN.get(b["province"]["terrain"], TERRAIN["plains"])["colour"]
		c = c.lerp(other, (1.0 - smoothstep(0.0, 26.0, sample["edge"])) * 0.5)
	c = c.darkened(grain.get_noise_2dv(map_pos * 2.0) * 0.10)
	c = c.lerp(SAND, smoothstep(1.4, 0.3, h))
	c = c.lerp(ROCK, smoothstep(0.35, 0.7, slope))
	c = c.lerp(SNOW, smoothstep(26.0, 34.0, h) * (1.0 - smoothstep(0.6, 0.85, slope)))
	c = c.lerp(UNKNOWN, sample["remote"] * 0.7)
	var owner = a["province"].get("owner")
	if owner != null:
		var owner_colour: Color = owner_colours[owner]
		c = c.lerp(owner_colour, 0.18 * (1.0 - sample["remote"]))
		var other_owner = null if b["sea"] else b["province"].get("owner")
		if other_owner != owner and sample["edge"] < BORDER_WIDTH * 2.0:
			var band := 1.0 - smoothstep(BORDER_WIDTH * 0.6, BORDER_WIDTH * 2.0, sample["edge"])
			c = c.lerp(owner_colour.lightened(0.1), band * 0.9)
	return c


func _terrain_mesh() -> MeshInstance3D:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for site in sites:
		lo = lo.min(site["pos"])
		hi = hi.max(site["pos"])
	lo -= Vector2(MARGIN, MARGIN)
	hi += Vector2(MARGIN, MARGIN)
	var cols := int((hi.x - lo.x) / CELL) + 1
	var rows := int((hi.y - lo.y) / CELL) + 1
	var samples := []
	samples.resize(cols * rows)
	var heights := PackedFloat32Array()
	heights.resize(cols * rows)
	for r in rows:
		for q in cols:
			var s := _sample(lo + Vector2(q * CELL, r * CELL))
			samples[r * cols + q] = s
			heights[r * cols + q] = s["height"]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	verts.resize(cols * rows)
	normals.resize(cols * rows)
	colours.resize(cols * rows)
	for r in rows:
		for q in cols:
			var i := r * cols + q
			var map_pos := lo + Vector2(q * CELL, r * CELL)
			var hl := heights[r * cols + maxi(q - 1, 0)]
			var hr := heights[r * cols + mini(q + 1, cols - 1)]
			var hu := heights[maxi(r - 1, 0) * cols + q]
			var hd := heights[mini(r + 1, rows - 1) * cols + q]
			var normal := Vector3(hl - hr, 2.0 * CELL, hu - hd).normalized()
			verts[i] = to_world(map_pos) + Vector3(0, heights[i], 0)
			normals[i] = normal
			colours[i] = _colour(samples[i], map_pos, 1.0 - normal.y)
	var indices := PackedInt32Array()
	indices.resize((rows - 1) * (cols - 1) * 6)
	var k := 0
	for r in rows - 1:
		for q in cols - 1:
			var i := r * cols + q
			indices[k] = i
			indices[k + 1] = i + 1
			indices[k + 2] = i + cols
			indices[k + 3] = i + 1
			indices[k + 4] = i + cols + 1
			indices[k + 5] = i + cols
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	var instance := MeshInstance3D.new()
	instance.name = "Terrain"
	instance.mesh = mesh
	instance.material_override = material
	return instance


func _water() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.10, 0.28, 0.40, 0.78)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.35
	material.roughness = 0.06
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = material
	return water


func _label(p: Dictionary, map_pos: Vector2) -> Label3D:
	var label := Label3D.new()
	label.name = "Label_" + str(p["id"])
	label.text = ("♛ " if p["capital"] else "") + str(p["name"])
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40 if p["capital"] else 30
	label.fixed_size = true  # same size on screen at every zoom level
	label.pixel_size = 0.0007
	label.outline_size = 14
	label.modulate = Color(1.0, 0.97, 0.90)
	label.outline_modulate = Color(0.06, 0.05, 0.05, 0.9)
	label.no_depth_test = true
	label.position = to_world(map_pos) + Vector3(0, maxf(height_at(map_pos), 0.0) + 14.0, 0)
	return label
