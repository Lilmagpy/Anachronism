## Urbs: the ground of ancient Rome (task U2). A heightfield of the city, 5 km x 5 km round the
## Forum at 10 m cells, built from topography.json (hills as ridges with the summit heights and
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
const CELL_M := 10.0
const CELLS := 500                        ## cells per side
const VERTS := CELLS + 1
const CHUNK_CELLS := 50                   ## 500 m chunks, 10 x 10 of them
const WARP_M := 38.0                      ## how far hill and valley outlines wander from their ideal line
const FORUM_FLOOR_M := 10.0               ## ancient Forum floor, m a.s.l.

static var _h: PackedFloat32Array = PackedFloat32Array()
static var _river_dist: PackedFloat32Array = PackedFloat32Array()
static var _river_level: PackedFloat32Array = PackedFloat32Array()
static var _warp: FastNoiseLite = null


## Computes the heightfield if that has not been done yet (a second or two the first time).
## height_at and build call this themselves; call it early to choose when the cost falls.
static func prepare() -> void:
	if not _h.is_empty():
		return
	_warp = FastNoiseLite.new()
	_warp.seed = 27
	_warp.frequency = 1.0 / 170.0
	var model: Dictionary = UrbsTiber.topography().get("terrain_model", {})
	var n := VERTS
	var h := PackedFloat32Array()
	h.resize(n * n)
	# 1. the underlying slope: low by the river, rising to the eastern and northern plateaus
	for j in n:
		var z := -HALF_M + j * CELL_M
		for i in n:
			var x := -HALF_M + i * CELL_M
			var east := smoothstep(-300.0, 2400.0, x)
			var north := smoothstep(900.0, 2400.0, -z)
			var west := smoothstep(1300.0, 2400.0, -x)
			h[j * n + i] = 11.5 + 22.0 * east + 12.0 * north + 9.0 * west
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
		_stamp_ridge(_pts(ridge), float(ridge["core"]) * (1.0 - 0.5 * soft), float(ridge["outer"]) * (1.0 + 0.3 * soft), h, base)
	_smooth(h)
	# 4. gentle natural undulation on the high ground only (kept off the valley floors)
	var noise := FastNoiseLite.new()
	noise.seed = 509
	noise.frequency = 1.0 / 90.0
	noise.fractal_octaves = 3
	for j in n:
		for i in n:
			var k := j * n + i
			var amp := smoothstep(16.0, 34.0, h[k]) * 1.4
			if amp > 0.0:
				h[k] += noise.get_noise_2d(-HALF_M + i * CELL_M, -HALF_M + j * CELL_M) * amp
	# 5. the valleys, flattened to their ancient floors
	wgrid.fill(0.0)
	fgrid.fill(0.0)
	for v: Dictionary in model.get("valleys", []):
		_stamp(_pts(v), float(v["core"]), float(v["outer"]), wgrid, fgrid)
	for k in n * n:
		if wgrid[k] > 0.0:
			h[k] = lerpf(h[k], fgrid[k], wgrid[k])
	# 6. the Tiber
	var riv := UrbsTiber.carve(h, n, -HALF_M, CELL_M)
	_river_dist = riv["dist"]
	_river_level = riv["level"]
	_h = h


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


static func _stamp_ridge(pts: PackedVector3Array, core: float, outer: float, h: PackedFloat32Array, base: PackedFloat32Array) -> void:
	for s in range(pts.size() - 1):
		var a := pts[s]
		var b := pts[s + 1]
		_walk_segment(a, b, outer, func(idx: int, t: float, d: float) -> void:
			var top := lerpf(a.y, b.y, t)
			var f := 1.0 - smoothstep(core, outer, d)
			var v := base[idx] + maxf(top - base[idx], 0.0) * f
			if v > h[idx]:
				h[idx] = v)


## Calls `fn(cell_index, t_along_segment, distance_to_segment)` for each cell within `reach`
## metres of the segment a-b (x, z are the vectors' x and z).
static func _walk_segment(a: Vector3, b: Vector3, reach: float, fn: Callable) -> void:
	var a2 := Vector2(a.x, a.z)
	var ab := Vector2(b.x, b.z) - a2
	var l2 := maxf(ab.length_squared(), 0.001)
	var i0 := maxi(int(floor((minf(a.x, b.x) - reach + HALF_M) / CELL_M)), 0)
	var i1 := mini(int(ceil((maxf(a.x, b.x) + reach + HALF_M) / CELL_M)), CELLS)
	var j0 := maxi(int(floor((minf(a.z, b.z) - reach + HALF_M) / CELL_M)), 0)
	var j1 := mini(int(ceil((maxf(a.z, b.z) + reach + HALF_M) / CELL_M)), CELLS)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := Vector2(-HALF_M + i * CELL_M, -HALF_M + j * CELL_M)
			p += Vector2(_warp.get_noise_2d(p.x, p.y), _warp.get_noise_2d(p.y + 777.0, p.x - 333.0)) * WARP_M
			var t := clampf((p - a2).dot(ab) / l2, 0.0, 1.0)
			var d := p.distance_to(a2 + ab * t)
			if d < reach:
				fn.call(j * VERTS + i, t, d)


## One light 1-2-1 blur pass, to round off the creases where ridge flanks meet.
static func _smooth(h: PackedFloat32Array) -> void:
	var n := VERTS
	var tmp := h.duplicate()
	for j in n:
		for i in range(1, n - 1):
			tmp[j * n + i] = 0.25 * h[j * n + i - 1] + 0.5 * h[j * n + i] + 0.25 * h[j * n + i + 1]
	for j in range(1, n - 1):
		for i in n:
			h[j * n + i] = 0.25 * tmp[(j - 1) * n + i] + 0.5 * tmp[j * n + i] + 0.25 * tmp[(j + 1) * n + i]


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


## Distance in metres from (x, z) to the Tiber's centre line (large when far away).
static func river_distance(x: float, z: float) -> float:
	prepare()
	var i := clampi(roundi((x + HALF_M) / CELL_M), 0, CELLS)
	var j := clampi(roundi((z + HALF_M) / CELL_M), 0, CELLS)
	return _river_dist[j * VERTS + i]


## True if (x, z) lies in the water of the Tiber (ground below the normal water level).
static func in_river(x: float, z: float) -> bool:
	prepare()
	var i := clampi(roundi((x + HALF_M) / CELL_M), 0, CELLS)
	var j := clampi(roundi((z + HALF_M) / CELL_M), 0, CELLS)
	return _h[j * VERTS + i] < _river_level[j * VERTS + i] - 0.2 and _river_dist[j * VERTS + i] < 120.0


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
## field, but any rect inside it works). lod 0 is the finest (10 m cells) and carries collision
## (a heightmap body); lod 1 and 2 use 50 m cells with no collision. Every chunk has a skirt
## dropped 4 m round its edge so neighbours of different detail show no cracks.
static func build_chunk(rect: Rect2, lod: int) -> Node3D:
	prepare()
	var step := 1 if lod <= 0 else 5
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
		var shape := HeightMapShape3D.new()
		shape.map_width = ci + 1
		shape.map_depth = cj + 1
		var data := PackedFloat32Array()
		data.resize((ci + 1) * (cj + 1))
		for dj in cj + 1:
			for di in ci + 1:
				data[dj * (ci + 1) + di] = _h[_gi(j0 + dj) * VERTS + _gi(i0 + di)]
		shape.map_data = data
		var body := StaticBody3D.new()
		body.name = "GroundBody"
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		body.scale = Vector3(CELL_M, 1.0, CELL_M)
		body.position = Vector3(rect.position.x + ci * CELL_M * 0.5, 0.0, rect.position.y + cj * CELL_M * 0.5)
		node.add_child(body)
	return node


## Builds the whole field at once (100 chunks of 500 m, with collision) plus the river, under a
## new Node3D "UrbsTerrain" added to `parent`. Used by the standalone preview.
static func build_all(parent: Node3D) -> Node3D:
	prepare()
	var root := Node3D.new()
	root.name = "UrbsTerrain"
	parent.add_child(root)
	var size := CHUNK_CELLS * CELL_M
	for cj in CELLS / CHUNK_CELLS:
		for ci in CELLS / CHUNK_CELLS:
			root.add_child(build_chunk(Rect2(-HALF_M + ci * size, -HALF_M + cj * size, size, size), 0))
	build(root)
	return root


static func _gi(i: int) -> int:
	return clampi(i, 0, CELLS)


static func _chunk_mesh(i0: int, j0: int, ci: int, cj: int, step: int) -> ArrayMesh:
	var nx := maxi(ci / step, 1)
	var nz := maxi(cj / step, 1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var stride := nx + 1
	# top surface then, after it, a skirt ring (same x, z; y lowered, same normal and colour)
	for dj in nz + 1:
		for di in nx + 1:
			_add_vertex(i0 + di * step, j0 + dj * step, 0.0, verts, norms, cols, uvs)
	var idx := PackedInt32Array()
	for dj in nz:
		for di in nx:
			var a := dj * stride + di
			idx.append_array([a, a + 1, a + stride, a + 1, a + stride + 1, a + stride])
	var ring: Array[Vector2i] = []
	for di in nx:
		ring.append(Vector2i(di, 0))
	for dj in nz:
		ring.append(Vector2i(nx, dj))
	for di in range(nx, 0, -1):
		ring.append(Vector2i(di, nz))
	for dj in range(nz, 0, -1):
		ring.append(Vector2i(0, dj))
	var base := verts.size()
	for r in ring:
		_add_vertex(i0 + r.x * step, j0 + r.y * step, 4.0, verts, norms, cols, uvs)
	for k in ring.size():
		var r0: Vector2i = ring[k]
		var r1: Vector2i = ring[(k + 1) % ring.size()]
		var t0 := r0.y * stride + r0.x
		var t1 := r1.y * stride + r1.x
		var s0 := base + k
		var s1 := base + (k + 1) % ring.size()
		idx.append_array([t0, t1, s0, t1, s1, s0])
		idx.append_array([t0, s0, t1, t1, s0, s1])   # double sided: the skirt is seen from outside
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


static func _add_vertex(i: int, j: int, drop: float, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array) -> void:
	i = _gi(i)
	j = _gi(j)
	var x := -HALF_M + i * CELL_M
	var z := -HALF_M + j * CELL_M
	var y := _h[j * VERTS + i]
	var hl := _h[j * VERTS + _gi(i - 1)]
	var hr := _h[j * VERTS + _gi(i + 1)]
	var hu := _h[_gi(j - 1) * VERTS + i]
	var hd := _h[_gi(j + 1) * VERTS + i]
	var nrm := Vector3(hl - hr, 2.0 * CELL_M, hu - hd).normalized()
	verts.append(Vector3(x, y - drop, z))
	norms.append(nrm)
	cols.append(_ground_colour(x, z, y, nrm.y, _river_dist[j * VERTS + i], _river_level[j * VERTS + i]))
	uvs.append(Vector2(x, z) * 0.1)


## Ground colour: grass on the gentle hill tops, tufa earth on the steep sides, a lighter
## trodden earth near the Forum, damp meadow on the flood plain, mud at the river's edge.
static func _ground_colour(x: float, z: float, y: float, ny: float, rd: float, wl: float) -> Color:
	var grass := Color(0.34, 0.40, 0.17)
	var meadow := Color(0.31, 0.38, 0.16)
	var tufa := Color(0.55, 0.41, 0.25)
	var trodden := Color(0.62, 0.52, 0.37)
	var mud := Color(0.38, 0.32, 0.22)
	var c := meadow.lerp(grass, smoothstep(16.0, 34.0, y))
	c = c.lerp(tufa, (1.0 - smoothstep(0.82, 0.97, ny)))
	var forum := 1.0 - smoothstep(150.0, 480.0, Vector2(x, z).length())
	c = c.lerp(trodden, forum * smoothstep(0.7, 0.95, ny) * 0.8)
	var bank := (1.0 - smoothstep(0.0, 22.0, rd - UrbsTiber.half_width())) * (1.0 - smoothstep(1.5, 5.0, y - wl))
	c = c.lerp(mud, clampf(bank, 0.0, 1.0))
	return c


static var _material: ShaderMaterial = null


static func _ground_material() -> ShaderMaterial:
	if _material != null:
		return _material
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vnoise(wpos.xz * 0.02) * 0.5 + vnoise(wpos.xz * 0.11) * 0.3 + vnoise(wpos.xz * 0.9) * 0.2;
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * (0.78 + 0.44 * n);
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
"""
	_material = ShaderMaterial.new()
	_material.shader = sh
	return _material
