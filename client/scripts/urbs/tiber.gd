## Urbs: the Tiber through Rome (U2; U8 "site": real width at the island, quays). Reads the
## `tiber` entry of topography.json (course from the north through the bend round the Campus
## Martius, past the Tiber Island, to the south), smooths it into a river centre line in local
## metres, cuts the channel, banks, quays and the island into a heightfield, and builds the water
## surface. Everything is static; the course is cached.
##
## The island reach (U8): the island and its two channels are fitted to the two bridges of the
## dataset (topography.yaml `island.fit_bridges`): the Pons Fabricius (62 m, P-A s.v. Pons
## Fabricius) spans the eastern channel and the Pons Cestius (48 m, P-A s.v. Pons Cestius) the
## western one, each resting a few metres on land at both ends; the island is 270 x 67 m
## (topography.yaml; Wikipedia s.v. Tiber Island) and drawn as a ship, prow downstream.
##
## Sources: topography.yaml `tiber` (Livy 1.4, 7.3.2, 35.9.2; Platner-Ashby s.v. Tiberis, Campus
## Martius: the river stood about 3-8 m below the plain, i.e. about 5-7 m a.s.l.).
class_name UrbsTiber

const TOPOGRAPHY_PATH := "res://data/city/topography.json"
const MONUMENTS_PATH := "res://data/city/monuments.json"
const STEP_M := 20.0            ## spacing of the smoothed centre line
const ISLAND_RAISE := 3.4       ## island top above the water, m (about 9 m a.s.l.)
const ISLAND_HALF_LONG := 135.0 ## 270 m long (topography.yaml)
const ISLAND_HALF_WIDE := 33.5  ## 67 m wide (topography.yaml)
const ISLAND_ZONE := Vector2(150.0, 300.0)   ## along the island's axis: fitted channel inside x, course beyond y
const BANK_BAND := 10.0         ## F3: metres either side of the water line where a bank is a plane
const BANK_SLOPE := Vector2(0.07, 0.2)   ## F3: its slope on the inside of a bend (x) and elsewhere (y)
const ISLAND_SHORE := 0.97      ## F3: the island's water line in island_r units (its facing stands at 0.95)

static var _topo: Dictionary = {}
static var _course: PackedVector2Array = PackedVector2Array()
static var _cum: PackedFloat32Array = PackedFloat32Array()
static var _island_c: Vector2 = Vector2.ZERO
static var _island_dir: Vector2 = Vector2.RIGHT     ## long axis, pointing downstream
static var _island_n: Vector2 = Vector2.UP          ## across, pointing to the first bridge's bank
static var _half_wide := ISLAND_HALF_WIDE            ## F2: as wide as the bridges' island ends need (>= 67 m)
static var _band := Vector2(0.0, 80.0)              ## the water across the island reach: (centre, half-width) along _island_n
static var _quays: Array = []
static var _turn: PackedFloat32Array = PackedFloat32Array()   ## how sharply the river turns at each point (+ left / - right), -1..1
static var _noise: FastNoiseLite = null


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
	_noise = FastNoiseLite.new()
	_noise.seed = 41
	_noise.frequency = 1.0
	_turn.resize(_course.size())
	for i in _course.size():
		var a: Vector2 = _course[maxi(i - 4, 0)]
		var b: Vector2 = _course[i]
		var c: Vector2 = _course[mini(i + 4, _course.size() - 1)]
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		_turn[i] = clampf(d1.cross(d2) * 3.0, -1.0, 1.0)
	_fit_island()
	_load_quays()


## Places and turns the island and its two channels so that the dataset's bridges span them.
static func _fit_island() -> void:
	var isl: Dictionary = _tiber().get("island", {})
	_island_c = UrbsGeo.to_local(float(isl.get("lat", 41.8908)), float(isl.get("lon", 12.4772)))
	var k := _nearest_index(_island_c)
	var tangent := (_course[mini(k + 3, _course.size() - 1)] - _course[maxi(k - 3, 0)]).normalized()
	_island_dir = tangent
	_island_n = Vector2(-tangent.y, tangent.x)
	_band = Vector2(_island_n.dot(_island_c), half_width() + 38.0)
	var ids: Array = isl.get("fit_bridges", [])
	if ids.size() != 2:
		return
	var abut := float(isl.get("abutment_m", 3.0))
	var ends: Array = []   # [island end, bank end] for each bridge
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MONUMENTS_PATH))
	if not parsed is Dictionary:
		return
	for want: String in ids:
		for m: Dictionary in parsed.get("monuments", []):
			if str(m.get("id", "")) != want:
				continue
			var c := UrbsGeo.to_local(float(m["lat"]), float(m["lon"]))
			var b := deg_to_rad(float(m.get("bearing_deg", 0.0)))
			var half := float((m.get("footprint_m", {}) as Dictionary).get("length", 60.0)) * 0.5
			var u := Vector2(sin(b), -cos(b))
			var e1 := c + u * half
			var e2 := c - u * half
			if e1.distance_to(_island_c) < e2.distance_to(_island_c):
				ends.append([e1, e2])
			else:
				ends.append([e2, e1])
	if ends.size() != 2:
		return
	var p1: Vector2 = ends[0][0]
	var p2: Vector2 = ends[1][0]
	# F2: the island lies across the bridges as they stand on their remains: its short axis is the
	# bridges' mean direction (each from its island end to its bank), its long axis square to that
	# (the remains give about 126 degrees, as the island itself), and it is as wide as the two island
	# ends need (at least the 67 m of topography.yaml). The U8 fit turned the island until a 67 m
	# width fitted between the ends, which put its axis 25 degrees off when the bridges were moved
	# onto their remains.
	var d1 := ((ends[0][1] as Vector2) - p1).normalized()
	var d2 := ((ends[1][1] as Vector2) - p2).normalized()
	var best := (d1 - d2).normalized()
	_half_wide = maxf(ISLAND_HALF_WIDE, absf(best.dot(p1 - p2)) * 0.5 + 1.0)
	_island_n = best
	_island_dir = Vector2(-best.y, best.x)
	if _island_dir.dot(tangent) < 0.0:
		_island_dir = -_island_dir
	var cn := (_island_n.dot(p1) + _island_n.dot(p2)) * 0.5
	var ca := (_island_dir.dot(p1) + _island_dir.dot(p2)) * 0.5
	_island_c = _island_n * cn + _island_dir * ca
	var far1 := _island_n.dot(ends[0][1]) - abut
	var far2 := _island_n.dot(ends[1][1]) + abut
	_band = Vector2((far1 + far2) * 0.5, absf(far1 - far2) * 0.5)


## Reads the quays (topography.yaml terrain_model.quays): each becomes {s0, s1, side, rise, from, id}.
static func _load_quays() -> void:
	_quays = []
	for q: Dictionary in topography().get("terrain_model", {}).get("quays", []):
		var p := UrbsGeo.to_local(float(q["lat"]), float(q["lon"]))
		var k := _nearest_index(p)
		var a := _course[maxi(k - 1, 0)]
		var b := _course[mini(k + 1, _course.size() - 1)]
		var side := signf((b - a).cross(p - _course[k]))
		var half := float(q.get("length_m", 300.0)) * 0.5
		var from_y: Variant = q.get("from")
		_quays.append({"id": str(q.get("id", "")), "s0": _cum[k] - half, "s1": _cum[k] + half, "side": side,
			"rise": float(q.get("rise_m", 4.0)), "from": -9999 if from_y == null else int(from_y)})


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


## Point and unit tangent (downstream) at distance `s` along the course: [Vector2, Vector2].
static func at_s(s: float) -> Array:
	_ensure()
	var k := 0
	while k < _cum.size() - 2 and _cum[k + 1] < s:
		k += 1
	var seg := maxf(_cum[k + 1] - _cum[k], 0.0001)
	var p := _course[k].lerp(_course[k + 1], clampf((s - _cum[k]) / seg, 0.0, 1.0))
	return [p, (_course[k + 1] - _course[k]).normalized()]


## The bank line: the point `offset` metres beyond the water's edge at distance `s` on `side`
## (+1 left of the flow, -1 right), using the same width as the channel (no edge noise).
static func bank_point(s: float, side: float, offset := 0.0) -> Vector2:
	var a := at_s(s)
	var t: Vector2 = a[1]
	return (a[0] as Vector2) + Vector2(-t.y, t.x) * side * (half_width_at_s(s) + offset)


## Normal water level (m a.s.l.) at distance `s` metres along the course; it falls gently
## from the north end to the south end (topography.yaml `surface_m`).
static func water_level_at_s(s: float) -> float:
	_ensure()
	var sm: Array = _tiber().get("surface_m", [6.2, 5.3])
	return lerpf(float(sm[0]), float(sm[1]), clampf(s / length(), 0.0, 1.0))


## Distance from the island's centre in island units: below 1 is on the island. The outline is a
## ship: an ellipse whose ends taper, the downstream end (the prow) more sharply.
static func island_r(x: float, z: float) -> float:
	_ensure()
	var d := Vector2(x, z) - _island_c
	var u := d.dot(_island_dir) / ISLAND_HALF_LONG
	var v := d.dot(_island_n) / _half_wide
	var taper := 1.0 - (0.55 if u > 0.0 else 0.32) * smoothstep(0.25, 1.0, absf(u))
	return sqrt(u * u + (v / taper) * (v / taper))


## Island frame, local metres: centre, long axis (downstream), across axis, half sizes, and the
## water across the island reach (`band`: centre and half-width along `across`).
static func island() -> Dictionary:
	_ensure()
	return {"center": _island_c, "dir": _island_dir, "across": _island_n, "half_long": ISLAND_HALF_LONG,
		"half_wide": _half_wide, "band": _band}


## The quays: [{id, s0, s1, side, rise, from}].
static func quays() -> Array:
	_ensure()
	return _quays


## Half-width of the channel at distance `s` metres along the course: the normal width, varying
## by about 15% along the river.
static func half_width_at_s(s: float) -> float:
	_ensure()
	return half_width() * (1.0 + 0.15 * _noise.get_noise_1d(s / 180.0))


## In the island reach the channel is the fitted band: [weight 0..1, distance from the band's
## middle, band half-width].
static func _island_band(x: float, z: float) -> Array:
	var p := Vector2(x, z)
	var a := absf((p - _island_c).dot(_island_dir))
	var w := 1.0 - smoothstep(ISLAND_ZONE.x, ISLAND_ZONE.y, a)
	if w <= 0.0:
		return [0.0, 0.0, 0.0]
	var n := p.dot(_island_n)
	# F3: and only near the island across its axis too (the reach's band is a strip square to the
	# axis; unbounded, it straightened the river 800 m downstream at the Emporium, where the course
	# runs across that axis, and left part of its bed as dry ground 6 m above the water)
	w *= 1.0 - smoothstep(_band.y + 80.0, _band.y + 200.0, absf(n - _band.x))
	return [w, absf(n - _band.x), _band.y]


## Cuts the river into `h` (a square grid of n x n vertices, `cell` metres apart, whose first
## vertex is at (origin, origin)): the channel bed, banks (steep and short on the outside of a
## bend, long and gentle with a gravel bar on the inside), the quays and the Tiber Island.
## Returns rasters, one value per grid vertex: "dist" distance to the centre line, "level" water
## level, "hw" channel half-width, "inner" 0..1 how much the point lies on the inside of a bend.
static func carve(h: PackedFloat32Array, n: int, origin: float, cell: float) -> Dictionary:
	_ensure()
	var dist := PackedFloat32Array()
	dist.resize(n * n)
	dist.fill(99999.0)
	var arc := PackedFloat32Array()
	arc.resize(n * n)
	var side := PackedFloat32Array()
	side.resize(n * n)
	var turn := PackedFloat32Array()
	turn.resize(n * n)
	var reach := maxf(half_width() * 1.15, _band.y + 40.0) + 82.0 + cell
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
				var q := a + ab * t
				var d := p.distance_to(q)
				var idx := j * n + i
				if d < dist[idx]:
					dist[idx] = d
					arc[idx] = lerpf(_cum[k], _cum[k + 1], t)
					side[idx] = signf(ab.cross(p - q))
					turn[idx] = lerpf(_turn[k], _turn[k + 1], t)
	var level := PackedFloat32Array()
	level.resize(n * n)
	var hwr := PackedFloat32Array()
	hwr.resize(n * n)
	var inner := PackedFloat32Array()
	inner.resize(n * n)
	level.fill(5.5)
	hwr.fill(half_width())
	var depth := _depth()
	for j in n:
		for i in n:
			var idx := j * n + i
			var d := dist[idx]
			if d > reach:
				continue
			var x := origin + i * cell
			var z := origin + j * cell
			var s := arc[idx]
			var wl := water_level_at_s(s)
			level[idx] = wl
			var hw := half_width_at_s(s)
			var inn := clampf(side[idx] * turn[idx] * 1.5, 0.0, 1.0)
			var outr := clampf(-side[idx] * turn[idx] * 1.5, 0.0, 1.0)
			# the bank wanders a few metres off the line (F3: over about 80 m, not 22 m, so the bank is
			# a plane across each 5 m cell and the water's edge drawn on it stays smooth)
			var dd := d + 4.0 * _noise.get_noise_2d(x / 80.0, z / 80.0)
			var e_course := dd - hw   # F3: the course's own channel, kept wherever the island reach fades
			var ib := _island_band(x, z)
			var iw: float = ib[0]
			if iw > 0.0:   # the island reach: the fitted channel, straight banks
				dd = lerpf(dd, float(ib[1]), iw)
				hw = lerpf(hw, float(ib[2]), iw)
				inn *= 1.0 - iw
				outr *= 1.0 - iw
			# the quays: a straight stone edge, the ground behind levelled
			var qw := 0.0
			var qrise := 0.0
			for qy: Dictionary in _quays:
				if UrbsTerrain.year < int(qy["from"]):
					continue   # F3: before its quay was built the bank is the river's own
				if side[idx] == float(qy["side"]):
					var w := smoothstep(float(qy["s0"]) - 30.0, float(qy["s0"]), s) * (1.0 - smoothstep(float(qy["s1"]), float(qy["s1"]) + 30.0, s))
					if w > qw:
						qw = w
						qrise = float(qy["rise"])
			if qw > 0.0:
				dd = lerpf(dd, d, qw)
				inn *= 1.0 - qw
			hwr[idx] = hw
			inner[idx] = inn
			var cut := _bank_cut() + 26.0 * inn - 8.0 * outr
			cut = lerpf(cut, 5.0, maxf(iw, qw))   # the island reach and the quays: steep, built banks
			# F3: across the water line the bank is a plane (height linear in the distance from the
			# channel's edge, BANK_BAND m either side), so the 5 m ground mesh draws a straight shore
			# instead of a saw-tooth; it shelves gently on the inside of a bend (a gravel beach) and
			# more steeply on the outside, then rises to the ground over `cut` metres.
			var k := lerpf(lerpf(BANK_SLOPE.y, BANK_SLOPE.x, inn), BANK_SLOPE.y * 1.6, maxf(iw, qw))
			var e := dd - hw
			if iw > 0.0:
				e = minf(e, e_course)   # the fitted reach may widen the river, never pinch it
			var terr := h[idx]
			var out := terr
			if e <= BANK_BAND + cut:
				var bank := wl + k * clampf(e, -BANK_BAND, BANK_BAND)
				if e < -BANK_BAND:
					var inner_w := maxf(hw - BANK_BAND, 1.0)
					bank = wl - depth + (depth - k * BANK_BAND) * pow(clampf(dd / inner_w, 0.0, 1.0), 2.0)
				elif e > BANK_BAND:
					var tt := smoothstep(0.0, 1.0, (e - BANK_BAND) / cut)
					var yb := wl + k * BANK_BAND
					bank = yb + maxf(terr - yb, 0.0) * pow(tt, 1.0 + 0.7 * inn - 0.45 * outr)
				out = minf(terr, bank)
			if qw > 0.0 and dd > hw - 1.0:
				var top := wl + qrise
				var keep := 1.0 - smoothstep(hw + 60.0, hw + 110.0, dd)
				out = lerpf(out, top, qw * keep)
			var r := island_r(x, z)
			if r < 1.35:
				# the island's shore the same way: a plane across its water line, then up to its top
				var top := wl + ISLAND_RAISE * (1.0 - 0.15 * minf(r * r, 1.0))
				var gr := Vector2(island_r(x + 1.0, z) - island_r(x - 1.0, z), island_r(x, z + 1.0) - island_r(x, z - 1.0)).length() * 0.5
				var ei := (ISLAND_SHORE - r) / maxf(gr, 1e-4)   # metres inside the shore
				var ki := BANK_SLOPE.y * 1.1
				var ih := wl + ki * clampf(ei, -BANK_BAND, BANK_BAND)
				if ei > BANK_BAND:
					var yb := wl + ki * BANK_BAND
					ih = yb + maxf(top - yb, 0.0) * smoothstep(BANK_BAND, BANK_BAND + 12.0, ei)
				out = lerpf(out, maxf(out, ih), 1.0 - smoothstep(1.2, 1.35, r))
			h[idx] = out
	return {"dist": dist, "level": level, "hw": hwr, "inner": inner}


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
		var ib := _island_band(p.x, p.y)
		var hw := half_width_at_s(_cum[i]) + 14.0 + float(ib[0]) * (float(ib[2]) + float(ib[1]) + 10.0)
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
	mi.material_override = UrbsMaterials.get_material("tiber_water")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
