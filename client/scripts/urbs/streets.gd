## Urbs (D-289, step U3): the streets of Rome as strips laid on the terrain.
##
## Data: `res://data/city/streets.json` (from data/rome/city/streets.yaml, see its header for the
## sources). A street exists from `exists_from`; it is paved with polygonal basalt (silex) from
## `paved_from` (Livy 41.27.5: the censors of 174 BC paved the city streets with silex and
## gravelled the roads outside it; the Via Appia 293 and 189 BC, Livy 10.47.4 and 38.28.3), and
## is beaten earth (inside the walls) or gravel (roads) before. Stone kerbs edge a paved street.
##
## API (the spectacles and the camera use these):
##   build(parent, year, height)       make the meshes under `parent`; `height` is (x, z) -> y
##   nearest_street(p: Vector2)        {id, distance, point, t, tangent, normal, half_width,
##                                      kind, paved} or {} when nothing lies within 400 m
##   along(street_id, t) -> Vector3    point at fraction t (0..1) of the street's length, on
##                                      the ground; t=0 is the first point of the YAML list
##   street_length(street_id) -> float
##   street_ids() -> Array             ids of the streets that exist in the year
##   load_data(year)                   index only (no meshes): what fill.gd uses
class_name UrbsStreets
extends RefCounted

const DATA_PATH := "res://data/city/streets.json"
const CELL := 64.0           ## spatial index cell, metres
const STEP := 4.0            ## spacing of strip samples, metres
const KERB_W := 0.28
const KERB_H := 0.2
const SURFACE_LIFT := 0.14   ## strips float this far above the terrain to avoid z-fighting
const SEARCH_RINGS := 7

static var _tex_cache := {}

var year := -300
var height: Callable = func(_x: float, _z: float) -> float: return 10.0
var streets: Array = []      ## per street: {id, kind, hw, pts: PackedVector2Array, cum: PackedFloat32Array, len, paved, ...}
var _by_id := {}
var _grid := {}              ## Vector2i -> Array of [street index, segment index]
var _root: Node3D


## Read the data and index the streets that exist in `new_year`. Cheap; no meshes.
func load_data(new_year: int) -> void:
	year = new_year
	streets = []
	_by_id = {}
	_grid = {}
	var text := FileAccess.get_file_as_string(DATA_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("UrbsStreets: cannot read %s" % DATA_PATH)
		return
	for entry in parsed.get("streets", []):
		var from_year: Variant = entry.get("exists_from")
		if from_year != null and int(from_year) > year:
			continue
		var raw := PackedVector2Array()
		for ll in entry["points"]:
			raw.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
		var pts := _smooth(raw, 2)
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		var paved_from: Variant = entry.get("paved_from")
		var s := {
			"id": str(entry["id"]),
			"kind": str(entry.get("kind", "street")),
			"hw": float(entry.get("width_m", 4.0)) * 0.5,
			"pts": pts,
			"cum": cum,
			"len": cum[cum.size() - 1],
			"paved": paved_from != null and int(paved_from) <= year,
			"road": str(entry.get("kind", "street")) == "road",
		}
		_by_id[s["id"]] = streets.size()
		streets.append(s)
	for si in streets.size():
		var pts: PackedVector2Array = streets[si]["pts"]
		for k in range(pts.size() - 1):
			var a := pts[k]
			var b := pts[k + 1]
			var lo := Vector2i(floori(minf(a.x, b.x) / CELL), floori(minf(a.y, b.y) / CELL))
			var hi := Vector2i(floori(maxf(a.x, b.x) / CELL), floori(maxf(a.y, b.y) / CELL))
			for cx in range(lo.x, hi.x + 1):
				for cz in range(lo.y, hi.y + 1):
					var key := Vector2i(cx, cz)
					if not _grid.has(key):
						_grid[key] = []
					_grid[key].append([si, k])


## Chaikin corner-cutting that keeps both end points.
static func _smooth(pts: PackedVector2Array, rounds: int) -> PackedVector2Array:
	var cur := pts
	for _r in rounds:
		if cur.size() < 3:
			break
		var out := PackedVector2Array([cur[0]])
		for i in range(cur.size() - 1):
			var a := cur[i]
			var b := cur[i + 1]
			if i > 0:
				out.append(a.lerp(b, 0.25))
			if i < cur.size() - 2:
				out.append(a.lerp(b, 0.75))
		out.append(cur[cur.size() - 1])
		cur = out
	return cur


func street_ids() -> Array:
	var ids := []
	for s in streets:
		ids.append(s["id"])
	return ids


func street_length(street_id: String) -> float:
	return float(streets[_by_id[street_id]]["len"]) if _by_id.has(street_id) else 0.0


## Nearest street to the local point `p` (x, z): see the file header. {} if none within ~450 m.
func nearest_street(p: Vector2) -> Dictionary:
	var best := {}
	var best_d := 1.0e9
	var centre := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for ring in range(SEARCH_RINGS + 1):
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var key := centre + Vector2i(dx, dz)
				if not _grid.has(key):
					continue
				for ref in _grid[key]:
					var s: Dictionary = streets[ref[0]]
					var pts: PackedVector2Array = s["pts"]
					var a := pts[ref[1]]
					var b := pts[ref[1] + 1]
					var ab := b - a
					var l2 := ab.length_squared()
					var u := 0.0 if l2 < 1e-6 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
					var q := a + ab * u
					var d := p.distance_to(q)
					if d < best_d:
						best_d = d
						var tangent := ab.normalized() if l2 > 1e-6 else Vector2.RIGHT
						var along_m: float = s["cum"][ref[1]] + u * sqrt(l2)
						var side := tangent.x * (p.y - q.y) - tangent.y * (p.x - q.x)
						var normal := Vector2(-tangent.y, tangent.x)
						if side < 0.0:
							normal = -normal
						best = {
							"id": s["id"], "distance": d, "point": q, "tangent": tangent,
							"normal": normal, "half_width": s["hw"], "kind": s["kind"],
							"paved": s["paved"], "t": along_m / maxf(s["len"], 0.001),
						}
		if best_d <= float(ring) * CELL:
			break
	return best


## Ground point at fraction `t` of the street's length (0 = first YAML point, 1 = last).
func along(street_id: String, t: float) -> Vector3:
	if not _by_id.has(street_id):
		return Vector3.ZERO
	var s: Dictionary = streets[_by_id[street_id]]
	var d := clampf(t, 0.0, 1.0) * float(s["len"])
	var cum: PackedFloat32Array = s["cum"]
	var pts: PackedVector2Array = s["pts"]
	var k := 0
	while k < cum.size() - 2 and cum[k + 1] < d:
		k += 1
	var seg := maxf(cum[k + 1] - cum[k], 0.0001)
	var p := pts[k].lerp(pts[k + 1], clampf((d - cum[k]) / seg, 0.0, 1.0))
	return Vector3(p.x, float(height.call(p.x, p.y)) + SURFACE_LIFT, p.y)


## Make the streets of `new_year` under `parent`.
func build(parent: Node3D, new_year: int, new_height: Callable) -> void:
	height = new_height
	load_data(new_year)
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Streets"
	parent.add_child(_root)
	var paved_mat := _material(true)
	var earth_mat := _material(false)
	var gravel_mat := _material(false, true)
	var kerb_mat := StandardMaterial3D.new()
	kerb_mat.albedo_color = Color(0.52, 0.5, 0.46)
	kerb_mat.roughness = 1.0
	for si in streets.size():
		var s: Dictionary = streets[si]
		var surface: StandardMaterial3D = paved_mat if s["paved"] else (gravel_mat if s["road"] else earth_mat)
		var mesh := _street_mesh(s, float(si) * 0.004, surface, kerb_mat)
		if mesh == null:
			continue
		var node := MeshInstance3D.new()
		node.name = String(s["id"])
		node.mesh = mesh
		node.set_meta("street_id", s["id"])
		_root.add_child(node)


func _street_mesh(s: Dictionary, lift: float, surface: Material, kerb_mat: Material) -> ArrayMesh:
	var pts: PackedVector2Array = s["pts"]
	var length: float = s["len"]
	if pts.size() < 2 or length < 1.0:
		return null
	var hw: float = s["hw"]
	var n := maxi(2, int(ceil(length / STEP)) + 1)
	var samples := PackedVector2Array()
	var tangents := PackedVector2Array()
	for i in n:
		var d := length * float(i) / float(n - 1)
		var q := _point_at(s, d)
		samples.append(q)
		var q2 := _point_at(s, minf(d + 1.5, length))
		var q1 := _point_at(s, maxf(d - 1.5, 0.0))
		tangents.append((q2 - q1).normalized())
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var kv := PackedVector3Array()
	var kn := PackedVector3Array()
	var ki := PackedInt32Array()
	var run := 0.0
	for i in n:
		if i > 0:
			run += samples[i].distance_to(samples[i - 1])
		var t := tangents[i]
		var nrm := Vector2(-t.y, t.x)
		var l := samples[i] + nrm * hw
		var r := samples[i] - nrm * hw
		var yl := float(height.call(l.x, l.y)) + SURFACE_LIFT + lift
		var yr := float(height.call(r.x, r.y)) + SURFACE_LIFT + lift
		var yc := float(height.call(samples[i].x, samples[i].y)) + SURFACE_LIFT + lift + 0.04   # slight camber
		verts.append(Vector3(l.x, yl, l.y)); normals.append(Vector3.UP); uvs.append(Vector2(run / 3.0, hw / 1.5))
		verts.append(Vector3(samples[i].x, yc, samples[i].y)); normals.append(Vector3.UP); uvs.append(Vector2(run / 3.0, 0.0))
		verts.append(Vector3(r.x, yr, r.y)); normals.append(Vector3.UP); uvs.append(Vector2(run / 3.0, -hw / 1.5))
		if i > 0:
			var b := (i - 1) * 3
			for row in 2:
				var a0 := b + row
				idx.append_array([a0, a0 + 3, a0 + 1, a0 + 1, a0 + 3, a0 + 4])
		if bool(s["paved"]):
			for side: float in [1.0, -1.0]:
				var inner := samples[i] + nrm * (hw * side)
				var outer := samples[i] + nrm * ((hw + KERB_W) * side)
				var y_in := float(height.call(inner.x, inner.y)) + SURFACE_LIFT + lift
				var y_out := float(height.call(outer.x, outer.y)) + SURFACE_LIFT + lift
				# top of the kerb stone, then its inner face dropping to the road
				kv.append(Vector3(inner.x, y_in + KERB_H, inner.y)); kn.append(Vector3.UP)
				kv.append(Vector3(outer.x, y_out + KERB_H, outer.y)); kn.append(Vector3.UP)
				kv.append(Vector3(inner.x, y_in, inner.y)); kn.append(Vector3(-nrm.x * side, 0.0, -nrm.y * side))
	if bool(s["paved"]):
		# kerb triangles: per sample 6 verts (2 sides x 3)
		for i in range(1, n):
			for side_i in 2:
				var b0 := (i - 1) * 6 + side_i * 3
				var b1 := i * 6 + side_i * 3
				var flip := side_i == 1
				_quad(ki, b0, b0 + 1, b1, b1 + 1, flip)           # top
				_quad(ki, b0 + 2, b0, b1 + 2, b1, flip)           # inner face
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, surface)
	if bool(s["paved"]) and kv.size() > 0:
		var ka := []
		ka.resize(Mesh.ARRAY_MAX)
		ka[Mesh.ARRAY_VERTEX] = kv
		ka[Mesh.ARRAY_NORMAL] = kn
		ka[Mesh.ARRAY_INDEX] = ki
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ka)
		mesh.surface_set_material(1, kerb_mat)
	return mesh


## Two triangles for the strip quad a-b (this sample) / c-d (next sample).
static func _quad(idx: PackedInt32Array, a: int, b: int, c: int, d: int, flip: bool) -> void:
	if flip:
		idx.append_array([a, b, c, b, d, c])
	else:
		idx.append_array([a, c, b, b, c, d])


func _point_at(s: Dictionary, d: float) -> Vector2:
	var cum: PackedFloat32Array = s["cum"]
	var pts: PackedVector2Array = s["pts"]
	var k := 0
	while k < cum.size() - 2 and cum[k + 1] < d:
		k += 1
	var seg := maxf(cum[k + 1] - cum[k], 0.0001)
	return pts[k].lerp(pts[k + 1], clampf((d - cum[k]) / seg, 0.0, 1.0))


# ---------------------------------------------------------------- materials

static func _material(paved: bool, gravel := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture("basalt" if paved else ("gravel" if gravel else "earth"))
	m.roughness = 0.92
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Procedural, tiling 3 m textures: basalt = polygonal silex slabs, earth = beaten earth.
static func _texture(kind: String) -> ImageTexture:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var size := 128
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919
	if kind == "basalt":
		var grid := 6
		var pts: Array = []
		var tone: Array = []
		for gz in grid:
			for gx in grid:
				pts.append(Vector2((gx + rng.randf_range(0.15, 0.85)) / grid, (gz + rng.randf_range(0.15, 0.85)) / grid))
				tone.append(rng.randf_range(0.20, 0.36))
		for y in size:
			for x in size:
				var p := Vector2(float(x) / size, float(y) / size)
				var d1 := 9.0
				var d2 := 9.0
				var which := 0
				var gx0 := int(p.x * grid)
				var gz0 := int(p.y * grid)
				for oz in range(-1, 2):
					for ox in range(-1, 2):
						var rx := gx0 + ox
						var rz := gz0 + oz
						var gx := posmod(rx, grid)
						var gz := posmod(rz, grid)
						var q: Vector2 = pts[gz * grid + gx]
						q += Vector2(floori(float(rx) / grid), floori(float(rz) / grid))
						var d := p.distance_to(q)
						if d < d1:
							d2 = d1
							d1 = d
							which = gz * grid + gx
						elif d < d2:
							d2 = d
				var v: float = tone[which]
				var noise := rng.randf_range(-0.025, 0.025)
				if d2 - d1 < 0.018:
					v = 0.09          # the joint between slabs
				img.set_pixel(x, y, Color(v * 1.0 + noise, v * 0.99 + noise, v * 0.96 + noise))
	elif kind == "gravel":
		for y in size:
			for x in size:
				var v := rng.randf_range(0.50, 0.68)
				img.set_pixel(x, y, Color(v, v * 0.93, v * 0.78))
	else:
		var noise := FastNoiseLite.new()
		noise.seed = 31
		noise.frequency = 0.06
		for y in size:
			for x in size:
				var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
				var v := 0.34 + n * 0.14 + rng.randf_range(-0.03, 0.03)
				img.set_pixel(x, y, Color(v * 1.02, v * 0.88, v * 0.66))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[kind] = tex
	return tex
