## Urbs: the Tiber through Rome (task U2). Reads the `tiber` entry of topography.json (course
## from the north through the bend round the Campus Martius, past the Tiber Island, to the
## south), smooths it into a river centre line in local metres, cuts the channel and banks into
## a heightfield, and builds the water surface. Everything is static; the course is cached.
##
## Sources: topography.yaml `tiber` (Livy 1.4, 7.3.2, 35.9.2; Platner-Ashby s.v. Tiberis, Campus
## Martius: the river stood about 3-8 m below the plain, i.e. about 5-7 m a.s.l.).
class_name UrbsTiber

const TOPOGRAPHY_PATH := "res://data/city/topography.json"
const STEP_M := 20.0            ## spacing of the smoothed centre line
const ISLAND_RAISE := 3.4       ## island top above the water, m (about 9 m a.s.l.)
const ISLAND_HALF_LONG := 135.0 ## 270 m long (topography.yaml)
const ISLAND_HALF_WIDE := 33.5  ## 67 m wide (topography.yaml)

static var _topo: Dictionary = {}
static var _course: PackedVector2Array = PackedVector2Array()
static var _cum: PackedFloat32Array = PackedFloat32Array()
static var _island_c: Vector2 = Vector2.ZERO
static var _island_dir: Vector2 = Vector2.RIGHT


## The parsed topography.json (cached). Shared with UrbsTerrain.
static func topography() -> Dictionary:
	if _topo.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TOPOGRAPHY_PATH))
		_topo = parsed if parsed is Dictionary else {}
	return _topo


static func _tiber() -> Dictionary:
	return topography().get("tiber", {})


## Normal channel half-width in metres (topography.yaml `banks.half_width_m`, default 35).
static func half_width() -> float:
	return float(_tiber().get("banks", {}).get("half_width_m", 35.0))


static func _bank_cut() -> float:
	return float(_tiber().get("banks", {}).get("bank_cut_m", 16.0))


static func _depth() -> float:
	return float(_tiber().get("banks", {}).get("depth_m", 3.2))


static func _ensure() -> void:
	if not _course.is_empty():
		return
	var pts := PackedVector2Array()
	for p: Array in _tiber().get("course", []):
		pts.append(UrbsGeo.to_local(float(p[0]), float(p[1])))
	_course = _resample(pts)
	_cum.resize(_course.size())
	var acc := 0.0
	for i in _course.size():
		if i > 0:
			acc += _course[i].distance_to(_course[i - 1])
		_cum[i] = acc
	var isl: Dictionary = _tiber().get("island", {})
	_island_c = UrbsGeo.to_local(float(isl.get("lat", 41.8905)), float(isl.get("lon", 12.4772)))
	var k := _nearest_index(_island_c)
	_island_c = _course[k]
	var a: Vector2 = _course[maxi(k - 3, 0)]
	var b: Vector2 = _course[mini(k + 3, _course.size() - 1)]
	_island_dir = (b - a).normalized()


static func _nearest_index(p: Vector2) -> int:
	var best := 0
	var bd := INF
	for i in _course.size():
		var d := _course[i].distance_squared_to(p)
		if d < bd:
			bd = d
			best = i
	return best


## Catmull-Rom through the control points, resampled every STEP_M metres.
static func _resample(pts: PackedVector2Array) -> PackedVector2Array:
	var dense := PackedVector2Array()
	var n := pts.size()
	for i in n - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		var steps := maxi(int(p1.distance_to(p2) / 4.0), 2)
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	dense.append(pts[n - 1])
	var out := PackedVector2Array()
	out.append(dense[0])
	var carry := 0.0
	for i in range(1, dense.size()):
		var seg := dense[i].distance_to(dense[i - 1])
		carry += seg
		if carry >= STEP_M:
			out.append(dense[i])
			carry = 0.0
	out.append(dense[dense.size() - 1])
	return out


## The smoothed river centre line in local metres (x, z), north to south.
static func course() -> PackedVector2Array:
	_ensure()
	return _course


## Total length of the centre line in metres.
static func length() -> float:
	_ensure()
	return _cum[_cum.size() - 1]


## Normal water level (m a.s.l.) at distance `s` metres along the course; it falls gently
## from the north end to the south end (topography.yaml `surface_m`).
static func water_level_at_s(s: float) -> float:
	_ensure()
	var sm: Array = _tiber().get("surface_m", [6.2, 5.3])
	return lerpf(float(sm[0]), float(sm[1]), clampf(s / length(), 0.0, 1.0))


## Elliptical distance from the Tiber Island's centre: below 1 is on the island.
static func island_r(x: float, z: float) -> float:
	_ensure()
	var d := Vector2(x, z) - _island_c
	var u := d.dot(_island_dir) / ISLAND_HALF_LONG
	var v := (d.x * -_island_dir.y + d.y * _island_dir.x) / ISLAND_HALF_WIDE
	return sqrt(u * u + v * v)


## Island centre and long-axis direction, local metres.
static func island() -> Dictionary:
	_ensure()
	return {"center": _island_c, "dir": _island_dir, "half_long": ISLAND_HALF_LONG, "half_wide": ISLAND_HALF_WIDE}


## Channel half-width at a point: normal width, wider round the island so water passes both sides.
static func half_width_at(x: float, z: float) -> float:
	var hw := half_width()
	return hw + 38.0 * (1.0 - smoothstep(0.9, 2.0, island_r(x, z)))


## Cuts the river into `h` (a square grid of n x n vertices, `cell` metres apart, whose first
## vertex is at (origin, origin)). Writes the channel bed, the cut banks and the island, and
## returns {"dist": distance to the centre line, "level": water level at the nearest point}.
static func carve(h: PackedFloat32Array, n: int, origin: float, cell: float) -> Dictionary:
	_ensure()
	var dist := PackedFloat32Array()
	dist.resize(n * n)
	dist.fill(99999.0)
	var level := PackedFloat32Array()
	level.resize(n * n)
	level.fill(5.5)
	var reach := half_width() + 38.0 + _bank_cut() + cell
	for k in range(_course.size() - 1):
		var a := _course[k]
		var b := _course[k + 1]
		var ab := b - a
		var l2 := maxf(ab.length_squared(), 0.001)
		var i0 := maxi(int(floor((minf(a.x, b.x) - reach - origin) / cell)), 0)
		var i1 := mini(int(ceil((maxf(a.x, b.x) + reach - origin) / cell)), n - 1)
		var j0 := maxi(int(floor((minf(a.y, b.y) - reach - origin) / cell)), 0)
		var j1 := mini(int(ceil((maxf(a.y, b.y) + reach - origin) / cell)), n - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := Vector2(origin + i * cell, origin + j * cell)
				var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
				var d := p.distance_to(a + ab * t)
				var idx := j * n + i
				if d < dist[idx]:
					dist[idx] = d
					level[idx] = water_level_at_s(lerpf(_cum[k], _cum[k + 1], t))
	var depth := _depth()
	var cut := _bank_cut()
	for j in n:
		for i in n:
			var idx := j * n + i
			var d := dist[idx]
			if d > reach:
				continue
			var x := origin + i * cell
			var z := origin + j * cell
			var hw := half_width_at(x, z)
			if d > hw + cut:
				continue
			var wl := level[idx]
			var terr := h[idx]
			var bed := wl - depth + (depth - 0.6) * pow(minf(d / hw, 1.0), 2.0)
			var out: float
			if d <= hw:
				out = minf(terr, bed)
			else:
				var bank := lerpf(wl - 0.6, terr, smoothstep(hw, hw + cut, d))
				out = minf(terr, bank)
			var r := island_r(x, z)
			if r < 1.1:
				var w := 1.0 - smoothstep(0.7, 1.1, r)
				var top := wl + ISLAND_RAISE * (1.0 - 0.25 * r * r)
				out = lerpf(out, maxf(top, out), w)
			h[idx] = out
	return {"dist": dist, "level": level}


## Builds the water surface along the whole course and adds it to `parent`. Returns the node.
static func build_water(parent: Node3D) -> MeshInstance3D:
	_ensure()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idxs := PackedInt32Array()
	for i in _course.size():
		var p := _course[i]
		var a := _course[maxi(i - 1, 0)]
		var b := _course[mini(i + 1, _course.size() - 1)]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var hw := half_width_at(p.x, p.y) + 6.0
		var y := water_level_at_s(_cum[i])
		verts.append(Vector3(p.x - side.x * hw, y, p.y - side.y * hw))
		verts.append(Vector3(p.x + side.x * hw, y, p.y + side.y * hw))
		uvs.append(Vector2(0.0, _cum[i] / 40.0))
		uvs.append(Vector2(1.0, _cum[i] / 40.0))
		if i > 0:
			var k := (i - 1) * 2
			idxs.append_array([k, k + 2, k + 1, k + 1, k + 2, k + 3])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idxs
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "TiberWater"
	mi.mesh = mesh
	mi.material_override = _water_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _water_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.17, 0.25, 0.20);
uniform vec3 shallow_color : source_color = vec3(0.33, 0.38, 0.27);
void fragment() {
	vec2 w = UV * vec2(18.0, 1.0);
	float t = TIME * 0.35;
	float r = sin(w.y * 6.0 - t * 3.0 + sin(w.x * 3.0) * 1.7) * 0.5 + sin(w.y * 11.0 - t * 5.0 + w.x * 5.0) * 0.5;
	float edge = abs(UV.x - 0.5) * 2.0;
	vec3 c = mix(deep_color, shallow_color, smoothstep(0.55, 1.0, edge));
	ALBEDO = c + vec3(0.02) * r;
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.8;
	ALPHA = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
