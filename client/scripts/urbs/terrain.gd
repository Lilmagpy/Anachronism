## Urbs: the ground of ancient Rome (task U2). A heightfield of the city, 5 km x 5 km round the
## Forum at 5 m cells (10 m beyond 2 km of the Forum in the chunk meshes), built from topography.json (hills as ridges with the summit heights and
## cliffs the sources describe, valleys flattened to their ANCIENT floors, the Campus Martius
## plain, the Tiber channel and island) and turned into chunked meshes with collision.
##
## Usage, from anywhere:
##   var y := UrbsTerrain.height_at(x, z)        # ground height a.s.l. at local (x, z) metres
##   UrbsTerrain.build(urbs)                      # whole-scene parts (the river water)
##   UrbsTerrain.build_chunk(rect, lod)           # the ground of one 250 m chunk (collision at lod 0)
##   UrbsTerrain.build_all(parent)                # everything at once (standalone preview)
## (all static: calling them on an `UrbsTerrain.new()` instance works too, as urbs.gd does)
## The frame is UrbsGeo's (x east, z south, y a.s.l.); the Forum floor is about y = 10.
##
## Model (the heights and the 460 x 180 m Capitol, 600 x 150 m Circus valley, 10-15 m Campus
## Martius come from Platner-Ashby; see topography.yaml `terrain_model` for each source and for
## what is the modeller's own reading). Everything is deterministic: no random numbers.
class_name UrbsTerrain

const HALF_M := 2500.0                    ## the field spans -HALF_M .. +HALF_M in x and z
const CELL_M := 5.0
const CELLS := 1000                       ## cells per side
const VERTS := CELLS + 1
const CHUNK_CELLS := 50                   ## 250 m chunks
const NEAR_M := 2000.0                    ## within this of the Forum, lod 0 uses every 5 m cell
const WARP_M := 38.0                      ## how far hill and valley outlines wander from their ideal line
const FORUM_FLOOR_M := 10.0               ## ancient Forum floor, m a.s.l.
const CACHE_VERSION := "u2-6"            ## bump when the model code changes
const CENTRE_NO_TREES_M := 1000.0         ## no trees or scrub closer to the Forum than this

static var _h: PackedFloat32Array = PackedFloat32Array()
static var _river_dist: PackedFloat32Array = PackedFloat32Array()
static var _river_level: PackedFloat32Array = PackedFloat32Array()
static var _river_hw: PackedFloat32Array = PackedFloat32Array()
static var _river_inner: PackedFloat32Array = PackedFloat32Array()
static var _valley_w: PackedFloat32Array = PackedFloat32Array()
static var _warp: FastNoiseLite = null
static var _warp2: FastNoiseLite = null
static var _woods: Array = []
static var _material: ShaderMaterial = null
static var _veg: Dictionary = {}
static var _veg_noise: FastNoiseLite = null


## Computes the heightfield if that has not been done yet (about a second the first time).
## height_at and build_chunk call this themselves; call it early to choose when the cost falls.
static func prepare() -> void:
	if not _h.is_empty():
		return
	var model0: Dictionary = UrbsTiber.topography().get("terrain_model", {})
	var key := "%x" % hash(JSON.stringify(UrbsTiber.topography()) + CACHE_VERSION)
	if _load_cache(key):
		_load_woods(model0)
		return
	_compute()
	_save_cache(key)


## The heightfield and its companion rasters are kept in user:// after the first run (keyed on a
## hash of topography.json and CACHE_VERSION), so later starts take a tenth of a second.
static func _cache_path(key: String) -> String:
	return "user://urbs_terrain_%s.bin" % key


static func _save_cache(key: String) -> void:
	var f := FileAccess.open(_cache_path(key), FileAccess.WRITE)
	if f == null:
		return
	for arr: PackedFloat32Array in [_h, _river_dist, _river_level, _river_hw, _river_inner, _valley_w]:
		f.store_buffer(arr.to_byte_array())


static func _load_cache(key: String) -> bool:
	var f := FileAccess.open(_cache_path(key), FileAccess.READ)
	if f == null:
		return false
	var bytes := VERTS * VERTS * 4
	if f.get_length() != bytes * 6:
		return false
	_h = f.get_buffer(bytes).to_float32_array()
	_river_dist = f.get_buffer(bytes).to_float32_array()
	_river_level = f.get_buffer(bytes).to_float32_array()
	_river_hw = f.get_buffer(bytes).to_float32_array()
	_river_inner = f.get_buffer(bytes).to_float32_array()
	_valley_w = f.get_buffer(bytes).to_float32_array()
	return true


static func _compute() -> void:
	_warp = FastNoiseLite.new()
	_warp.seed = 27
	_warp.frequency = 1.0 / 170.0
	_warp2 = FastNoiseLite.new()
	_warp2.seed = 31
	_warp2.frequency = 1.0 / 48.0
	var model: Dictionary = UrbsTiber.topography().get("terrain_model", {})
	var n := VERTS
	var h := PackedFloat32Array()
	h.resize(n * n)
	# 1. the underlying slope: low by the river, rising to the eastern and northern plateaus
	for j in n:
		var z := -HALF_M + j * CELL_M
		var north := smoothstep(900.0, 2400.0, -z) * 12.0
		for i in n:
			var x := -HALF_M + i * CELL_M
			h[j * n + i] = 11.5 + 22.0 * smoothstep(-300.0, 2400.0, x) + north + 9.0 * smoothstep(1300.0, 2400.0, -x)
	# 2. the Campus Martius plain: base level pulled down to its floor (10-15 m a.s.l.)
	var wgrid := PackedFloat32Array()
	wgrid.resize(n * n)
	var fgrid := PackedFloat32Array()
	fgrid.resize(n * n)
	for plain: Dictionary in model.get("plains", []):
		_stamp(_pts(plain), float(plain["core"]), float(plain["outer"]), wgrid, fgrid)
	for k in n * n:
		h[k] = lerpf(h[k], fgrid[k], wgrid[k])
	# 3. the hills, each a ridge whose flank falls between `core` and `outer` metres
	var base := h.duplicate()
	for ridge: Dictionary in model.get("ridges", []):
		var soft: float = 1.0 if bool(ridge.get("soft", false)) else 0.0
		var power := 1.6 if bool(ridge.get("cliff", false)) else 1.0   # cliffs: steep above, a talus foot below
		_stamp_ridge(_pts(ridge), float(ridge["core"]) * (1.0 - 0.5 * soft), float(ridge["outer"]) * (1.0 + 0.3 * soft), power, h, base)
	_smooth(h)
	# 4. natural undulation on the high ground only (kept off the valley floors)
	var noise := FastNoiseLite.new()
	noise.seed = 509
	noise.frequency = 1.0 / 90.0
	noise.fractal_octaves = 3
	var fine := FastNoiseLite.new()
	fine.seed = 12
	fine.frequency = 1.0 / 23.0
	var crags := FastNoiseLite.new()
	crags.seed = 5
	crags.frequency = 1.0 / 14.0
	var gullies := FastNoiseLite.new()
	gullies.seed = 8
	gullies.frequency = 1.0 / 40.0
	var swell := FastNoiseLite.new()
	swell.seed = 99
	swell.frequency = 1.0 / 260.0
	for j in n:
		for i in n:
			var k := j * n + i
			var amp := smoothstep(16.0, 34.0, h[k])
			if amp > 0.0:
				var x := -HALF_M + i * CELL_M
				var z := -HALF_M + j * CELL_M
				var slope := (absf(h[mini(k + 1, n * n - 1)] - h[maxi(k - 1, 0)]) + absf(h[mini(k + n, n * n - 1)] - h[maxi(k - n, 0)])) / (2.0 * CELL_M)
				var rocky := smoothstep(0.35, 1.0, slope)
				h[k] += (noise.get_noise_2d(x, z) * 2.4 + swell.get_noise_2d(x, z) * 4.0 + fine.get_noise_2d(x, z) * 0.6) * amp
				if rocky > 0.0:   # crags and gullies on the steep faces
					h[k] += crags.get_noise_2d(x, z) * rocky * 3.2 - pow(1.0 - absf(gullies.get_noise_2d(x, z)), 5.0) * rocky * 5.0
	# 5. the valleys, flattened to their ancient floors (the weights are kept for the ground colour)
	wgrid.fill(0.0)
	fgrid.fill(0.0)
	for v: Dictionary in model.get("valleys", []):
		_stamp(_pts(v), float(v["core"]), float(v["outer"]), wgrid, fgrid)
	for k in n * n:
		if wgrid[k] > 0.0:
			h[k] = lerpf(h[k], fgrid[k], wgrid[k])
	_valley_w = wgrid
	# 6. the Tiber
	var riv := UrbsTiber.carve(h, n, -HALF_M, CELL_M)
	_river_dist = riv["dist"]
	_river_level = riv["level"]
	_river_hw = riv["hw"]
	_river_inner = riv["inner"]
	_h = h
	_load_woods(model)


static func _load_woods(model: Dictionary) -> void:
	_woods.clear()
	_veg_noise = FastNoiseLite.new()
	_veg_noise.seed = 77
	_veg_noise.frequency = 1.0 / 140.0
	for w: Dictionary in model.get("woods", []):
		var kinds: Array = []
		for kind: String in w.get("mix", {}):
			for c in int(w["mix"][kind]):
				kinds.append(kind)
		_woods.append({"c": UrbsGeo.to_local(float(w["lat"]), float(w["lon"])), "r": float(w["radius"]), "d": float(w["density"]), "kinds": kinds})


## Control points (x, z, height) of a terrain_model entry, in local metres.
static func _pts(entry: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Array in entry.get("pts", []):
		var l := UrbsGeo.to_local(float(p[0]), float(p[1]))
		out.append(Vector3(l.x, float(p[2]), l.y))
	return out


## For each cell near the polyline: weight 1 inside `core`, fading to 0 at `outer`; keeps the
## strongest weight and the polyline height there.
static func _stamp(pts: PackedVector3Array, core: float, outer: float, wgrid: PackedFloat32Array, fgrid: PackedFloat32Array) -> void:
	for s in range(pts.size() - 1):
		var a := pts[s]
		var b := pts[s + 1]
		_walk_segment(a, b, outer, func(idx: int, t: float, d: float) -> void:
			var w := 1.0 - smoothstep(core, outer, d)
			if w > wgrid[idx]:
				wgrid[idx] = w
				fgrid[idx] = lerpf(a.y, b.y, t))


static func _stamp_ridge(pts: PackedVector3Array, core: float, outer: float, power: float, h: PackedFloat32Array, base: PackedFloat32Array) -> void:
	for s in range(pts.size() - 1):
		var a := pts[s]
		var b := pts[s + 1]
		_walk_segment(a, b, outer, func(idx: int, t: float, d: float) -> void:
			var top := lerpf(a.y, b.y, t)
			var f := pow(1.0 - smoothstep(core, outer, d), power)
			var v := base[idx] + maxf(top - base[idx], 0.0) * f
			if v > h[idx]:
				h[idx] = v)


## Calls `fn(cell_index, t_along_segment, distance_to_segment)` for each cell within `reach`
## metres of the segment a-b (x, z are the vectors' x and z).
static func _walk_segment(a: Vector3, b: Vector3, reach: float, fn: Callable) -> void:
	var a2 := Vector2(a.x, a.z)
	var ab := Vector2(b.x, b.z) - a2
	var l2 := maxf(ab.length_squared(), 0.001)
	var m := reach + WARP_M * 1.5
	var i0 := maxi(int(floor((minf(a.x, b.x) - m + HALF_M) / CELL_M)), 0)
	var i1 := mini(int(ceil((maxf(a.x, b.x) + m + HALF_M) / CELL_M)), CELLS)
	var j0 := maxi(int(floor((minf(a.z, b.z) - m + HALF_M) / CELL_M)), 0)
	var j1 := mini(int(ceil((maxf(a.z, b.z) + m + HALF_M) / CELL_M)), CELLS)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := Vector2(-HALF_M + i * CELL_M, -HALF_M + j * CELL_M)
			p += Vector2(_warp.get_noise_2d(p.x, p.y), _warp.get_noise_2d(p.y + 777.0, p.x - 333.0)) * WARP_M
			p += Vector2(_warp2.get_noise_2d(p.x, p.y), _warp2.get_noise_2d(p.y - 51.0, p.x + 913.0)) * 13.0
			var t := clampf((p - a2).dot(ab) / l2, 0.0, 1.0)
			var d := p.distance_to(a2 + ab * t)
			if d < reach:
				fn.call(j * VERTS + i, t, d)


## A light 1-2-1 blur (60% blended in), to round off the creases where ridge flanks meet.
static func _smooth(h: PackedFloat32Array) -> void:
	var n := VERTS
	var tmp := h.duplicate()
	for j in n:
		for i in range(1, n - 1):
			tmp[j * n + i] = 0.25 * h[j * n + i - 1] + 0.5 * h[j * n + i] + 0.25 * h[j * n + i + 1]
	for j in range(1, n - 1):
		for i in n:
			var b := 0.25 * tmp[(j - 1) * n + i] + 0.5 * tmp[j * n + i] + 0.25 * tmp[(j + 1) * n + i]
			h[j * n + i] = lerpf(h[j * n + i], b, 0.6)


## Ground height in metres a.s.l. at local (x, z); bilinear, clamped to the field's edge.
static func height_at(x: float, z: float) -> float:
	prepare()
	var fx := clampf((x + HALF_M) / CELL_M, 0.0, CELLS - 0.001)
	var fz := clampf((z + HALF_M) / CELL_M, 0.0, CELLS - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var k := j * VERTS + i
	var a := lerpf(_h[k], _h[k + 1], tx)
	var b := lerpf(_h[k + VERTS], _h[k + VERTS + 1], tx)
	return lerpf(a, b, tz)


## Unit surface normal at local (x, z).
static func normal_at(x: float, z: float) -> Vector3:
	var e := CELL_M
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


static func _cell(x: float, z: float) -> int:
	var i := clampi(roundi((x + HALF_M) / CELL_M), 0, CELLS)
	var j := clampi(roundi((z + HALF_M) / CELL_M), 0, CELLS)
	return j * VERTS + i


## Distance in metres from (x, z) to the Tiber's centre line (large when far away).
static func river_distance(x: float, z: float) -> float:
	prepare()
	return _river_dist[_cell(x, z)]


## True if (x, z) lies in the water of the Tiber (ground below the normal water level).
static func in_river(x: float, z: float) -> bool:
	prepare()
	var k := _cell(x, z)
	return _h[k] < _river_level[k] - 0.2 and _river_dist[k] < 150.0


## The field's extent as a Rect2 in local (x, z) metres.
static func bounds() -> Rect2:
	return Rect2(-HALF_M, -HALF_M, 2.0 * HALF_M, 2.0 * HALF_M)


## Whole-scene parts for the Urbs root (urbs.gd interface): the Tiber's water surface. The
## ground itself comes chunk by chunk from build_chunk. Returns the node holding the parts.
static func build(urbs: Node3D) -> Node3D:
	prepare()
	var root := Node3D.new()
	root.name = "UrbsRiver"
	urbs.add_child(root)
	UrbsTiber.build_water(root)
	return root


## The ground of one chunk covering `rect` (local x, z metres; 250 m squares aligned to the
## field, but any rect inside it works). lod 0 is the finest (5 m cells within 2 km of the Forum,
## 10 m beyond) and carries collision (a heightmap body), trees, scrub and reeds; lod 1 (25 m
## cells) has trees and scrub too, thinned; lod 2 (50 m cells) is the bare ground. Only lod 0
## has collision. Every chunk has a skirt dropped 4 m round its edge so neighbours of different
## detail show no cracks.
static func build_chunk(rect: Rect2, lod: int) -> Node3D:
	prepare()
	var near := rect.get_center().length() < NEAR_M
	var step := (1 if near else 2) if lod <= 0 else (5 if lod == 1 else 10)
	var i0 := roundi((rect.position.x + HALF_M) / CELL_M)
	var j0 := roundi((rect.position.y + HALF_M) / CELL_M)
	var ci := maxi(roundi(rect.size.x / CELL_M), 1)
	var cj := maxi(roundi(rect.size.y / CELL_M), 1)
	var node := Node3D.new()
	node.name = "Ground_%d_%d_L%d" % [i0, j0, lod]
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _chunk_mesh(i0, j0, ci, cj, step)
	mi.material_override = _ground_material()
	node.add_child(mi)
	if lod <= 0:
		var nx := maxi(ci / step, 1)
		var nz := maxi(cj / step, 1)
		var shape := HeightMapShape3D.new()
		shape.map_width = nx + 1
		shape.map_depth = nz + 1
		var data := PackedFloat32Array()
		data.resize((nx + 1) * (nz + 1))
		for dj in nz + 1:
			for di in nx + 1:
				data[dj * (nx + 1) + di] = _h[_gi(j0 + dj * step) * VERTS + _gi(i0 + di * step)]
		shape.map_data = data
		var body := StaticBody3D.new()
		body.name = "GroundBody"
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		body.scale = Vector3(CELL_M * step, 1.0, CELL_M * step)
		body.position = Vector3(rect.position.x + nx * step * CELL_M * 0.5, 0.0, rect.position.y + nz * step * CELL_M * 0.5)
		node.add_child(body)
	if lod <= 1:
		_add_vegetation(node, rect, lod)
	return node


## Builds the whole field at once (100 chunks of 500 m, with collision) plus the river, under a
## new Node3D "UrbsTerrain" added to `parent`. Used by the standalone preview.
static func build_all(parent: Node3D, lod: int = 0) -> Node3D:
	prepare()
	var root := Node3D.new()
	root.name = "UrbsTerrain"
	parent.add_child(root)
	var size := 250.0
	for cj in 20:
		for ci in 20:
			root.add_child(build_chunk(Rect2(-HALF_M + ci * size, -HALF_M + cj * size, size, size), lod))
	build(root)
	return root


static func _gi(i: int) -> int:
	return clampi(i, 0, CELLS)


static func _chunk_mesh(i0: int, j0: int, ci: int, cj: int, step: int) -> ArrayMesh:
	var nx := maxi(ci / step, 1)
	var nz := maxi(cj / step, 1)
	var pp := PackedVector3Array()
	var pn := PackedVector3Array()
	var pc := PackedColorArray()
	var pu := PackedVector2Array()
	var pu2 := PackedVector2Array()
	var stride := nx + 1
	for dj in nz + 1:
		for di in nx + 1:
			_add_vertex(i0 + di * step, j0 + dj * step, 0.0, pp, pn, pc, pu, pu2)
	var idx := PackedInt32Array()
	for dj in nz:
		for di in nx:
			var a := dj * stride + di
			idx.append_array([a, a + 1, a + stride, a + 1, a + stride + 1, a + stride])
	# the skirt ring: the same x, z, lowered 4 m, drawn double sided
	var ring: Array[Vector2i] = []
	for di in nx:
		ring.append(Vector2i(di, 0))
	for dj in nz:
		ring.append(Vector2i(nx, dj))
	for di in range(nx, 0, -1):
		ring.append(Vector2i(di, nz))
	for dj in range(nz, 0, -1):
		ring.append(Vector2i(0, dj))
	var base := pp.size()
	for r in ring:
		_add_vertex(i0 + r.x * step, j0 + r.y * step, 4.0, pp, pn, pc, pu, pu2)
	for k in ring.size():
		var r0: Vector2i = ring[k]
		var r1: Vector2i = ring[(k + 1) % ring.size()]
		var t0 := r0.y * stride + r0.x
		var t1 := r1.y * stride + r1.x
		var s0 := base + k
		var s1 := base + (k + 1) % ring.size()
		idx.append_array([t0, t1, s0, t1, s1, s0, t0, s0, t1, t1, s0, s1])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pp
	arr[Mesh.ARRAY_NORMAL] = pn
	arr[Mesh.ARRAY_COLOR] = pc
	arr[Mesh.ARRAY_TEX_UV] = pu
	arr[Mesh.ARRAY_TEX_UV2] = pu2
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


static func _add_vertex(i: int, j: int, drop: float, pp: PackedVector3Array, pn: PackedVector3Array, pc: PackedColorArray, pu: PackedVector2Array, pu2: PackedVector2Array) -> void:
	i = _gi(i)
	j = _gi(j)
	var k := j * VERTS + i
	var x := -HALF_M + i * CELL_M
	var z := -HALF_M + j * CELL_M
	var y := _h[k]
	var hl := _h[j * VERTS + _gi(i - 1)]
	var hr := _h[j * VERTS + _gi(i + 1)]
	var hu := _h[_gi(j - 1) * VERTS + i]
	var hd := _h[_gi(j + 1) * VERTS + i]
	var nrm := Vector3(hl - hr, 2.0 * CELL_M, hu - hd).normalized()
	pp.append(Vector3(x, y - drop, z))
	pn.append(nrm)
	var w := _ground_weights(x, z, y, nrm.y, k)
	pc.append(w[0])
	pu.append(w[1])
	pu2.append(w[2])


## Ground colour and material weights at a vertex. Returns [colour, (grass, mud), (dust, gravel)].
## Grass on the gentle high ground, trodden dust round the Forum and in the low valleys (the
## Forum, Velabrum, Circus and Subura floors), tufa earth on the steep slopes, damp mud at the
## river edge, gravel on the inside of the bends, stone on the island's rock shelves.
static func _ground_weights(x: float, z: float, y: float, ny: float, k: int) -> Array:
	var rd := _river_dist[k]
	var wl := _river_level[k]
	var hw := _river_hw[k]
	var flat := smoothstep(0.78, 0.95, ny)
	var steep := 1.0 - smoothstep(0.82, 0.97, ny)
	var forum := (1.0 - smoothstep(150.0, 520.0, Vector2(x, z).length())) * flat
	var valley := smoothstep(0.35, 0.9, _valley_w[k]) * flat
	var dust := clampf(maxf(forum * 0.9, valley * 0.7), 0.0, 1.0)
	var bank := (1.0 - smoothstep(0.0, 24.0, rd - hw)) * (1.0 - smoothstep(1.2, 4.5, y - wl))
	var mud := clampf(bank * (1.0 - _river_inner[k] * 0.8), 0.0, 1.0)
	var gravel := clampf(_river_inner[k] * (1.0 - smoothstep(0.3, 1.2, y - wl)) * smoothstep(hw * 0.8, hw, rd) * 1.2, 0.0, 1.0)
	var ir := UrbsTiber.island_r(x, z)
	var stone := 0.0
	if ir < 1.12 and y > wl - 0.8:
		stone = smoothstep(0.55, 0.9, ir) * (1.0 - smoothstep(1.0, 1.12, ir))
	var grass_c := Color(0.42, 0.41, 0.21).lerp(Color(0.50, 0.45, 0.24), smoothstep(30.0, 60.0, y))
	var meadow_c := Color(0.35, 0.39, 0.19)
	var grass := meadow_c.lerp(grass_c, smoothstep(16.0, 34.0, y))
	var dust_c := Color(0.50, 0.40, 0.28).lerp(Color(0.64, 0.54, 0.39), forum)
	var tufa := Color(0.55, 0.41, 0.25)
	var c := grass.lerp(tufa, steep)
	c = c.lerp(dust_c, dust * (1.0 - steep))
	c = c.lerp(Color(0.30, 0.25, 0.16), mud)
	c = c.lerp(Color(0.46, 0.42, 0.34).lerp(Color(0.40, 0.38, 0.33), stone), maxf(gravel, stone))
	var wg := clampf(1.0 - maxf(maxf(dust, mud), maxf(maxf(gravel, stone), steep)), 0.0, 1.0)
	return [c, Vector2(wg, mud), Vector2(dust, maxf(gravel, stone))]


static func _ground_material() -> ShaderMaterial:
	if _material != null:
		return _material
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 wpos;
varying vec3 wnorm;
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
	vec3 N = normalize(wnorm);
	float big = vnoise(wpos * 0.012);
	float mid = vnoise(wpos * 0.09);
	float fine = vnoise(wpos * 0.7);
	float micro = vnoise(wpos * 3.1);
	float wg = UV.x; float wm = UV.y; float wd = UV2.x; float wgr = UV2.y;
	vec3 col = lin(COLOR.rgb) * (0.72 + 0.5 * (0.4 * big + 0.3 * mid + 0.3 * fine));
	// grass: dry yellow patches and a speckle of tufts
	float dry = smoothstep(0.35, 0.7, vnoise(wpos * 0.03 + 7.0) + 0.5 * (fine - 0.5) + 0.2 * (mid - 0.5));
	col = mix(col, col * vec3(1.5, 1.3, 0.7), dry * 0.55 * wg);
	col *= 1.0 + (micro - 0.5) * 0.55 * wg;
	// trodden earth and dust: lighter on the high spots, scuffed
	col *= 1.0 + ((fine - 0.5) * 0.5 + (mid - 0.5) * 0.3) * wd;
	// mud: darker and wet
	col = mix(col, col * 0.6, wm);
	// gravel and stone: pebbles
	float peb = vnoise(wpos * 2.3);
	col = mix(col, mix(col * 0.8, col * 1.2, step(0.55, peb)), wgr * 0.85);
	// cliffs: tufa strata, bands of orange-brown and grey-buff with dark joints
	float steep = 1.0 - smoothstep(0.55, 0.8, N.y);
	float band = wpos.y * 2.6 + big * 9.0 + vnoise(wpos * vec3(0.22, 0.5, 0.22)) * 3.0;
	float bi = floor(band); float bf = fract(band);
	float pick = hash(vec3(bi, 3.0, 9.0));
	vec3 s1 = lin(vec3(0.55, 0.43, 0.29)); vec3 s2 = lin(vec3(0.51, 0.44, 0.34)); vec3 s3 = lin(vec3(0.46, 0.37, 0.27));
	vec3 st = pick < 0.4 ? s1 : (pick < 0.75 ? s2 : s3);
	st *= 0.8 + 0.35 * vnoise(wpos * vec3(0.8, 2.5, 0.8)) + 0.25 * (vnoise(wpos * vec3(1.6, 0.15, 1.6)) - 0.5);
	st *= 0.9 + 0.1 * smoothstep(0.0, 0.1, bf) * smoothstep(1.0, 0.9, bf);
	col = mix(col, st, steep);
	ALBEDO = col;
	ROUGHNESS = mix(1.0, 0.55, wm);
	SPECULAR = mix(0.05, 0.3, wm);
}
"""
	_material = ShaderMaterial.new()
	_material.shader = sh
	return _material


# ---- trees, scrub and reeds ------------------------------------------------------------------

static func _hash(ix: int, iz: int, seed_: int) -> float:
	var n := ix * 374761393 + iz * 668265263 + seed_ * 144665
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / 16777216.0


static func _wood_at(x: float, z: float) -> Dictionary:
	var best := 0.0
	var pick: Dictionary = {}
	for w: Dictionary in _woods:
		var d := (w["c"] as Vector2).distance_to(Vector2(x, z))
		var f: float = float(w["d"]) * (1.0 - smoothstep(0.55 * float(w["r"]), float(w["r"]), d))
		if f > best:
			best = f
			pick = w
	return {"d": best, "w": pick}


## Adds the MultiMesh trees, scrub and reeds of one chunk to `node`.
static func _add_vegetation(node: Node3D, rect: Rect2, lod: int) -> void:
	_ensure_veg_meshes()
	var spacing := 12.0 if lod <= 0 else 24.0
	var lists := {"oak": [], "pine": [], "cypress": [], "scrub": [], "reed": []}
	var gx0 := int(floor(rect.position.x / spacing))
	var gx1 := int(ceil(rect.end.x / spacing))
	var gz0 := int(floor(rect.position.y / spacing))
	var gz1 := int(ceil(rect.end.y / spacing))
	for gz in range(gz0, gz1):
		for gx in range(gx0, gx1):
			var x := (gx + _hash(gx, gz, 1)) * spacing
			var z := (gz + _hash(gx, gz, 2)) * spacing
			if not rect.has_point(Vector2(x, z)):
				continue
			var wood := _wood_at(x, z)
			var dens: float = wood["d"]
			if dens <= 0.0:
				continue
			var centre := smoothstep(CENTRE_NO_TREES_M, CENTRE_NO_TREES_M + 300.0, Vector2(x, z).length())
			var clump := smoothstep(-0.3, 0.3, _veg_noise.get_noise_2d(x, z))
			var p := dens * (spacing * spacing / 100.0) * centre * clump * (0.5 if lod > 0 else 1.0) * (4.0 if lod > 0 else 1.0)
			if _hash(gx, gz, 3) > p:
				continue
			var k := _cell(x, z)
			var y := _h[k]
			var ny := normal_at(x, z).y
			if ny < 0.72 or y < _river_level[k] + 3.0 or y < 13.0 or _river_dist[k] < _river_hw[k] + 14.0:
				continue
			var kinds: Array = (wood["w"] as Dictionary)["kinds"]
			var kind: String = kinds[int(_hash(gx, gz, 4) * kinds.size()) % kinds.size()]
			if ny < 0.84 and kind != "scrub":
				kind = "scrub"
			var sc := 0.75 + 0.6 * _hash(gx, gz, 5)
			var basis := Basis(Vector3.UP, _hash(gx, gz, 6) * TAU).scaled(Vector3(sc, sc * (0.9 + 0.25 * _hash(gx, gz, 7)), sc))
			var tone := 0.8 + 0.4 * _hash(gx, gz, 8)
			(lists[kind] as Array).append([Transform3D(basis, Vector3(x, y - 0.15, z)), Color(tone, tone, tone * (0.9 + 0.2 * _hash(gx, gz, 9)))])
	if lod <= 0:
		# reeds in clumps along the water's edge
		var i0 := roundi((rect.position.x + HALF_M) / CELL_M)
		var j0 := roundi((rect.position.y + HALF_M) / CELL_M)
		for dj in range(0, 50, 2):
			for di in range(0, 50, 2):
				var k := _gi(j0 + dj) * VERTS + _gi(i0 + di)
				var rd := _river_dist[k]
				if rd > 300.0:
					continue
				var hw := _river_hw[k]
				var y := _h[k]
				var wl := _river_level[k]
				if rd < hw - 6.0 or rd > hw + 12.0 or y < wl - 0.9 or y > wl + 1.6:
					continue
				if _hash(i0 + di, j0 + dj, 11) > 0.55:
					continue
				var x := rect.position.x + di * CELL_M + _hash(i0 + di, j0 + dj, 12) * CELL_M * 2.0
				var z := rect.position.y + dj * CELL_M + _hash(i0 + di, j0 + dj, 13) * CELL_M * 2.0
				var sc := 0.8 + 0.7 * _hash(i0 + di, j0 + dj, 14)
				var basis := Basis(Vector3.UP, _hash(i0 + di, j0 + dj, 15) * TAU).scaled(Vector3(sc, sc, sc))
				(lists["reed"] as Array).append([Transform3D(basis, Vector3(x, maxf(height_at(x, z), wl - 0.3), z)), Color(1, 1, 1)])
	for kind: String in lists:
		var items: Array = lists[kind]
		if items.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _veg[kind]
		mm.instance_count = items.size()
		for q in items.size():
			mm.set_instance_transform(q, items[q][0])
			mm.set_instance_color(q, items[q][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = kind.capitalize()
		mmi.multimesh = mm
		mmi.material_override = _veg["mat_reed"] if kind == "reed" else _veg["mat"]
		mmi.visibility_range_end = 1500.0 if lod <= 0 else 3500.0
		node.add_child(mmi)


static func _ensure_veg_meshes() -> void:
	if not _veg.is_empty():
		return
	var trunk := CylinderMesh.new()
	trunk.radial_segments = 6
	trunk.rings = 1
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.34
	trunk.height = 1.0
	var ball := SphereMesh.new()
	ball.radial_segments = 8
	ball.rings = 4
	ball.radius = 1.0
	ball.height = 2.0
	var cone := CylinderMesh.new()
	cone.radial_segments = 7
	cone.rings = 1
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	var brown := Color(0.30, 0.22, 0.14)
	var tr := func(pos: Vector3, scl: Vector3) -> Transform3D:
		return Transform3D(Basis.from_scale(scl), pos)
	_veg["oak"] = _merge([
		[trunk, tr.call(Vector3(0, 1.6, 0), Vector3(1, 3.2, 1)), brown],
		[ball, tr.call(Vector3(0, 5.2, 0), Vector3(3.2, 2.7, 3.2)), Color(0.30, 0.40, 0.13)],
		[ball, tr.call(Vector3(1.6, 4.4, 0.7), Vector3(2.0, 1.7, 2.0)), Color(0.35, 0.44, 0.15)],
		[ball, tr.call(Vector3(-1.4, 4.7, -0.9), Vector3(2.1, 1.8, 2.1)), Color(0.25, 0.35, 0.11)]])
	_veg["pine"] = _merge([
		[trunk, tr.call(Vector3(0, 3.5, 0), Vector3(1.2, 7.0, 1.2)), brown],
		[ball, tr.call(Vector3(0, 8.0, 0), Vector3(4.6, 2.4, 4.6)), Color(0.32, 0.41, 0.14)],
		[ball, tr.call(Vector3(1.8, 7.0, 0.8), Vector3(2.6, 1.6, 2.6)), Color(0.36, 0.44, 0.16)]])
	_veg["cypress"] = _merge([
		[trunk, tr.call(Vector3(0, 0.6, 0), Vector3(0.8, 1.2, 0.8)), brown],
		[cone, tr.call(Vector3(0, 5.5, 0), Vector3(1.5, 10.0, 1.5)), Color(0.17, 0.29, 0.11)]])
	_veg["scrub"] = _merge([
		[ball, tr.call(Vector3(0, 0.7, 0), Vector3(1.5, 1.0, 1.5)), Color(0.33, 0.36, 0.15)],
		[ball, tr.call(Vector3(1.0, 0.5, 0.6), Vector3(1.0, 0.7, 1.0)), Color(0.38, 0.37, 0.17)]])
	# a reed clump: crossed, tapering blades
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for b in 9:
		var ang := b * 0.9
		var d := Vector3(cos(ang), 0, sin(ang))
		var off := d * (0.15 + 0.12 * (b % 3))
		var hgt := 2.4 + 0.7 * float(b % 4)
		var tip := off + Vector3(0.25 * sin(b * 2.1), hgt, 0.25 * cos(b * 1.7))
		var side := Vector3(-d.z, 0, d.x) * 0.12
		var k0 := verts.size()
		verts.append_array([off - side, off + side, tip])
		norms.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
		cols.append_array([Color(0.30, 0.34, 0.14), Color(0.30, 0.34, 0.14), Color(0.55, 0.52, 0.25)])
		idx.append_array([k0, k0 + 1, k0 + 2])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var reed := ArrayMesh.new()
	reed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_veg["reed"] = reed
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	_veg["mat"] = mat
	var rm := mat.duplicate() as StandardMaterial3D
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_veg["mat_reed"] = rm


## Merges primitive meshes [mesh, transform, colour] into one vertex-coloured ArrayMesh.
static func _merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for part: Array in parts:
		var arr: Array = (part[0] as PrimitiveMesh).get_mesh_arrays()
		var xf: Transform3D = part[1]
		var inv := xf.basis.inverse().transposed()
		var base := verts.size()
		var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for k in pv.size():
			verts.append(xf * pv[k])
			norms.append((inv * pn[k]).normalized())
			cols.append(part[2])
		for i: int in arr[Mesh.ARRAY_INDEX]:
			idx.append(base + i)
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = norms
	out[Mesh.ARRAY_COLOR] = cols
	out[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh
