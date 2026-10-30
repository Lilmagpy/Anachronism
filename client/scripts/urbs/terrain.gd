## Urbs: the ground of ancient Rome (U2, reworked in U8 "site"). A heightfield of the city, 5 km
## x 5 km round the Forum at 5 m cells, built from topography.json and turned into chunked
## meshes with collision. The model (data/rome/city/topography.yaml `terrain_model`, each entry
## with its sources):
##   1. an underlying slope, low by the river and rising to the eastern plateau;
##   2. the Campus Martius plain;
##   3. the soft hills as RIDGES (Quirinal, Viminal, Esquiline, Cispius, Caelian, Pincian,
##      Janiculum, Velia) and the three cliff hills as PLATEAUS (Capitoline, Palatine, Aventine):
##      flat-topped polygons whose top is interpolated from the outline and summit heights and
##      falls over a `flank` to the ground round it;
##   4. natural undulation on the high ground (damped on the plateau tops);
##   5. the valleys flattened to their ANCIENT floors (Forum 10 m, Velabrum, Vallis Murcia,
##      Subura), then the built PLATFORMS carved dead flat (the Forum piazza with every basilica
##      on it, Caesar's forum, the Area Capitolina, the arena of the Circus);
##   6. TERRACES on the built-up hillsides inside the Servian circuit (4 m steps, retaining walls
##      from UrbsSite): a modelling choice, the hillsides of Rome were terraced and built over;
##   7. every street cut into the ground with a smoothed profile, so a hill road is a ramp
##      notched into the slope and nothing bumps;
##   8. the Tiber channel, banks, quays and island (tiber.gd).
##
## Usage, from anywhere:
##   var y := UrbsTerrain.height_at(x, z)        # ground height a.s.l. at local (x, z) metres
##   UrbsTerrain.build(urbs)                      # whole-scene parts (river water, site works)
##   UrbsTerrain.build_chunk(rect, lod)           # the ground of one 250 m chunk (collision at lod 0)
##   UrbsTerrain.build_all(parent)                # everything at once (standalone preview)
## (all static: calling them on an `UrbsTerrain.new()` instance works too, as urbs.gd does)
## The frame is UrbsGeo's (x east, z south, y a.s.l.); the Forum floor is y = 10.
## Vegetation is UrbsSiteFlora's (site_flora.gd); terraces, walls, steps and quays UrbsSite's.
## Everything is deterministic: no random numbers.
class_name UrbsTerrain

const HALF_M := 2500.0                    ## the field spans -HALF_M .. +HALF_M in x and z
const CELL_M := 5.0
const CELLS := 1000                       ## cells per side
const VERTS := CELLS + 1
const CHUNK_CELLS := 50                   ## 250 m chunks
const NEAR_M := 2000.0                    ## within this of the Forum, lod 0 uses every 5 m cell
const WARP_M := 38.0                      ## how far hill and valley outlines wander from their ideal line
const FORUM_FLOOR_M := 10.0               ## ancient Forum floor, m a.s.l.
const TERRACE_M := 4.0                    ## height of one hillside terrace
const CACHE_VERSION := "u8-site-10"        ## bump when the model code changes
const STREETS_PATH := "res://data/city/streets.json"
const REGIONS_PATH := "res://data/city/regions.json"
const RURAL_CELL := 25.0                  ## resolution of the farmland weight raster
const MAP_CELL := 10.0                    ## resolution of the baked ground colour maps
const MAP_N := 501                        ## texels per side of the ground colour maps

static var year := -44                    ## the year being shown (set by build); flora and site works read it
static var _h: PackedFloat32Array = PackedFloat32Array()
static var _river_dist: PackedFloat32Array = PackedFloat32Array()
static var _river_level: PackedFloat32Array = PackedFloat32Array()
static var _river_hw: PackedFloat32Array = PackedFloat32Array()
static var _river_inner: PackedFloat32Array = PackedFloat32Array()
static var _valley_w: PackedFloat32Array = PackedFloat32Array()
static var _plateau_w: PackedFloat32Array = PackedFloat32Array()   ## 1 on a plateau top, fading down its flank
static var _built_w: PackedFloat32Array = PackedFloat32Array()     ## 1 on a platform or a street cut (trodden ground)
static var _terrace_w: PackedFloat32Array = PackedFloat32Array()   ## how much the ground is terraced
static var _rural: PackedFloat32Array = PackedFloat32Array()       ## farmland weight, RURAL_CELL grid
static var _map_col: PackedByteArray = PackedByteArray()          ## ground colour (rgb, sRGB) and farmland (a), MAP_N x MAP_N
static var _map_w: PackedByteArray = PackedByteArray()            ## ground weights: grass, mud, dust, gravel
static var _circuit: PackedVector2Array = PackedVector2Array()
static var _warp: FastNoiseLite = null
static var _warp2: FastNoiseLite = null
static var _material: ShaderMaterial = null


## Computes the heightfield if that has not been done yet (several seconds the first time).
## height_at and build_chunk call this themselves; call it early to choose when the cost falls.
static func prepare() -> void:
	if not _h.is_empty():
		return
	var key := "%x" % hash(JSON.stringify(UrbsTiber.topography()) + FileAccess.get_file_as_string(STREETS_PATH) + FileAccess.get_file_as_string(UrbsTiber.MONUMENTS_PATH).md5_text() + CACHE_VERSION)
	if _load_cache(key):
		return
	_compute()
	_save_cache(key)


## The heightfield and its companion rasters are kept in user:// after the first run (keyed on a
## hash of the data files and CACHE_VERSION), so later starts take a tenth of a second.
static func _cache_path(key: String) -> String:
	return "user://urbs_terrain_%s.bin" % key


static func _rural_n() -> int:
	return int(2.0 * HALF_M / RURAL_CELL) + 1


static func _save_cache(key: String) -> void:
	var f := FileAccess.open(_cache_path(key), FileAccess.WRITE)
	if f == null:
		return
	for arr: PackedFloat32Array in [_h, _river_dist, _river_level, _river_hw, _river_inner, _valley_w, _plateau_w, _built_w, _terrace_w]:
		f.store_buffer(arr.to_byte_array())
	f.store_buffer(_rural.to_byte_array())
	f.store_buffer(_map_col)
	f.store_buffer(_map_w)


static func _load_cache(key: String) -> bool:
	var f := FileAccess.open(_cache_path(key), FileAccess.READ)
	if f == null:
		return false
	var bytes := VERTS * VERTS * 4
	var rn := _rural_n()
	if f.get_length() != bytes * 9 + rn * rn * 4 + MAP_N * MAP_N * 8:
		return false
	_h = f.get_buffer(bytes).to_float32_array()
	_river_dist = f.get_buffer(bytes).to_float32_array()
	_river_level = f.get_buffer(bytes).to_float32_array()
	_river_hw = f.get_buffer(bytes).to_float32_array()
	_river_inner = f.get_buffer(bytes).to_float32_array()
	_valley_w = f.get_buffer(bytes).to_float32_array()
	_plateau_w = f.get_buffer(bytes).to_float32_array()
	_built_w = f.get_buffer(bytes).to_float32_array()
	_terrace_w = f.get_buffer(bytes).to_float32_array()
	_rural = f.get_buffer(rn * rn * 4).to_float32_array()
	_map_col = f.get_buffer(MAP_N * MAP_N * 4)
	_map_w = f.get_buffer(MAP_N * MAP_N * 4)
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
	# 3. the soft hills, each a ridge whose flank falls between `core` and `outer` metres
	var base := h.duplicate()
	for ridge: Dictionary in model.get("ridges", []):
		var soft: float = 1.0 if bool(ridge.get("soft", false)) else 0.0
		var power := 1.6 if bool(ridge.get("cliff", false)) else 1.0
		_stamp_ridge(_pts(ridge), float(ridge["core"]) * (1.0 - 0.5 * soft), float(ridge["outer"]) * (1.0 + 0.3 * soft), power, h, base)
	# 3b. the cliff hills as plateaus
	_plateau_w = PackedFloat32Array()
	_plateau_w.resize(n * n)
	for plateau: Dictionary in model.get("plateaus", []):
		_stamp_plateau(plateau, h)
	_smooth(h)
	# 4. natural undulation on the high ground only (kept off the valley floors, damped on the plateaus)
	var noise := FastNoiseLite.new()
	noise.seed = 509
	noise.frequency = 1.0 / 90.0
	noise.fractal_octaves = 3
	var fine := FastNoiseLite.new()
	fine.seed = 12
	fine.frequency = 1.0 / 23.0
	var swell := FastNoiseLite.new()
	swell.seed = 99
	swell.frequency = 1.0 / 260.0
	var crags := FastNoiseLite.new()
	crags.seed = 5
	crags.frequency = 1.0 / 14.0
	for j in n:
		for i in n:
			var k := j * n + i
			var amp := smoothstep(16.0, 34.0, h[k])
			if amp > 0.0:
				var x := -HALF_M + i * CELL_M
				var z := -HALF_M + j * CELL_M
				var slope := (absf(h[mini(k + 1, n * n - 1)] - h[maxi(k - 1, 0)]) + absf(h[mini(k + n, n * n - 1)] - h[maxi(k - n, 0)])) / (2.0 * CELL_M)
				var rocky := smoothstep(0.45, 1.1, slope)
				var damp := 1.0 - 0.8 * smoothstep(0.6, 1.0, _plateau_w[k])
				h[k] += (noise.get_noise_2d(x, z) * 2.2 + swell.get_noise_2d(x, z) * 3.6 + fine.get_noise_2d(x, z) * 0.5) * amp * damp
				if rocky > 0.0:   # ledges on the steep faces (gentle: an even slope reads better than a blotchy one)
					h[k] += crags.get_noise_2d(x, z) * rocky * 1.6
	# 5. the valleys, flattened to their ancient floors (the weights are kept for the ground colour)
	wgrid.fill(0.0)
	fgrid.fill(0.0)
	for v: Dictionary in model.get("valleys", []):
		_stamp(_pts(v), float(v["core"]), float(v["outer"]), wgrid, fgrid)
	for k in n * n:
		if wgrid[k] > 0.0:
			h[k] = lerpf(h[k], fgrid[k], wgrid[k])
	_valley_w = wgrid
	# 5b. the built platforms, dead flat
	_built_w = PackedFloat32Array()
	_built_w.resize(n * n)
	for pf: Dictionary in model.get("platforms", []):
		_stamp_platform(pf, h)
	# 6. terraces on the built-up hillsides
	_terrace(h)
	# 7. the streets cut into the ground
	_cut_streets(model.get("street_cuts", {}), h)
	# 8. the Tiber
	var riv := UrbsTiber.carve(h, n, -HALF_M, CELL_M)
	_river_dist = riv["dist"]
	_river_level = riv["level"]
	_river_hw = riv["hw"]
	_river_inner = riv["inner"]
	_h = h
	_compute_rural()
	_bake_maps()


## Control points (x, z, height) of a terrain_model entry, in local metres.
static func _pts(entry: Dictionary, key := "pts") -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Array in entry.get(key, []):
		var l := UrbsGeo.to_local(float(p[0]), float(p[1]))
		out.append(Vector3(l.x, float(p[2]) if p.size() > 2 else 0.0, l.y))
	return out


static func _poly2(pts: PackedVector3Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x, p.z))
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


## Inverse-distance interpolation of the heights of `pts` (x, z, h) at p.
static func _idw(pts: PackedVector3Array, p: Vector2) -> float:
	var num := 0.0
	var den := 0.0
	for q in pts:
		var d2 := Vector2(q.x, q.z).distance_squared_to(p)
		var w := 1.0 / (d2 + 400.0)
		num += w * q.y
		den += w
	return num / maxf(den, 1e-9)


## Nearest point on the closed polygon's boundary and its distance: [Vector2, float].
static func _poly_edge(poly: PackedVector2Array, p: Vector2) -> Array:
	var best := Vector2.ZERO
	var bd := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		var d := q.distance_squared_to(p)
		if d < bd:
			bd = d
			best = q
	return [best, sqrt(bd)]


static func _bbox(poly: PackedVector2Array, grow: float) -> Array:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in poly:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	return [maxi(int(floor((lo.x - grow + HALF_M) / CELL_M)), 0), mini(int(ceil((hi.x + grow + HALF_M) / CELL_M)), CELLS),
		maxi(int(floor((lo.y - grow + HALF_M) / CELL_M)), 0), mini(int(ceil((hi.y + grow + HALF_M) / CELL_M)), CELLS), lo, hi]


## A cliff hill: inside the outline the top (interpolated from outline and peak heights); outside,
## the top edge's height falling over `flank` metres to the ground round it.
static func _stamp_plateau(plateau: Dictionary, h: PackedFloat32Array) -> void:
	var outline := _pts(plateau, "outline")
	var poly := _poly2(outline)
	var ctrl := outline.duplicate()
	ctrl.append_array(_pts(plateau, "peaks"))
	var flank := float(plateau.get("flank", 70.0))
	var cliff := str(plateau.get("shape", "cliff")) == "cliff"
	var bb := _bbox(poly, flank + 30.0)
	for j in range(bb[2], bb[3] + 1):
		for i in range(bb[0], bb[1] + 1):
			var p := Vector2(-HALF_M + i * CELL_M, -HALF_M + j * CELL_M)
			p += Vector2(_warp.get_noise_2d(p.x, p.y), _warp.get_noise_2d(p.y + 777.0, p.x - 333.0)) * (WARP_M * 0.45)
			p += Vector2(_warp2.get_noise_2d(p.x, p.y), _warp2.get_noise_2d(p.y - 51.0, p.x + 913.0)) * 9.0
			var idx := j * VERTS + i
			if Geometry2D.is_point_in_polygon(p, poly):
				h[idx] = maxf(h[idx], _idw(ctrl, p))
				_plateau_w[idx] = 1.0
				continue
			var e := _poly_edge(poly, p)
			var d: float = e[1]
			if d >= flank:
				continue
			var t := d / flank
			var f := pow(1.0 - t, 2.2) if cliff else 1.0 - (0.5 * t + 0.5 * smoothstep(0.0, 1.0, t))
			var edge_top := _idw(ctrl, e[0])
			var v := h[idx] + maxf(edge_top - h[idx], 0.0) * f
			if v > h[idx]:
				h[idx] = v
			_plateau_w[idx] = maxf(_plateau_w[idx], f)


## A built floor: the polygon carved to `level` (a gradient between two values along x), blended
## into the ground over `blend` metres beyond its edge.
static func _stamp_platform(pf: Dictionary, h: PackedFloat32Array) -> void:
	var poly := _poly2(_pts(pf, "polygon"))
	var lv: Array = pf.get("level", [10.0, 10.0])
	var l0 := float(lv[0])
	var l1 := float(lv[lv.size() - 1])
	var blend := float(pf.get("blend", 25.0))
	var bb := _bbox(poly, blend)
	var lo: Vector2 = bb[4]
	var hi: Vector2 = bb[5]
	for j in range(bb[2], bb[3] + 1):
		for i in range(bb[0], bb[1] + 1):
			var p := Vector2(-HALF_M + i * CELL_M, -HALF_M + j * CELL_M)
			var idx := j * VERTS + i
			var level := lerpf(l0, l1, clampf((p.x - lo.x) / maxf(hi.x - lo.x, 1.0), 0.0, 1.0))
			var w := 1.0
			if not Geometry2D.is_point_in_polygon(p, poly):
				var d: float = _poly_edge(poly, p)[1]
				if d >= blend:
					continue
				w = 1.0 - smoothstep(0.0, blend, d)
			h[idx] = lerpf(h[idx], level, w)
			_built_w[idx] = maxf(_built_w[idx], w)


## The Servian circuit (regions.json `servian_circuit`), local metres.
static func circuit() -> PackedVector2Array:
	if _circuit.is_empty():
		var reg: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGIONS_PATH))
		if reg is Dictionary and reg.has("servian_circuit"):
			for ll in reg["servian_circuit"].get("polygon", []):
				_circuit.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
	return _circuit


## Hillsides inside the circuit stepped into terraces of TERRACE_M: flat treads, a short riser
## (where UrbsSite stands a retaining wall). Only on moderate slopes, never on a platform.
static func _terrace(h: PackedFloat32Array) -> void:
	_terrace_w = PackedFloat32Array()
	_terrace_w.resize(VERTS * VERTS)
	var poly := circuit()
	if poly.size() < 3:
		return
	var src := h.duplicate()
	var bb := _bbox(poly, 0.0)
	for j in range(maxi(bb[2], 1), mini(bb[3], CELLS - 1) + 1):
		for i in range(maxi(bb[0], 1), mini(bb[1], CELLS - 1) + 1):
			var k := j * VERTS + i
			if _built_w[k] > 0.6 or _plateau_w[k] > 0.02:   # never on the cliff hills' flanks
				continue
			var gx := (src[k + 1] - src[k - 1]) / (2.0 * CELL_M)
			var gz := (src[k + VERTS] - src[k - VERTS]) / (2.0 * CELL_M)
			var g := sqrt(gx * gx + gz * gz)
			var w := smoothstep(0.08, 0.14, g) * (1.0 - smoothstep(0.4, 0.6, g)) * (1.0 - smoothstep(0.1, 0.6, _built_w[k]))
			if w <= 0.0:
				continue
			if not Geometry2D.is_point_in_polygon(Vector2(-HALF_M + i * CELL_M, -HALF_M + j * CELL_M), poly):
				continue
			var q := src[k] / TERRACE_M
			var kq := floorf(q)
			var ht := TERRACE_M * (kq + smoothstep(0.78, 1.0, q - kq))
			h[k] = lerpf(src[k], ht, w)
			_terrace_w[k] = w


## Streets cut into the ground: the profile along each street is sampled from the field, smoothed
## (and held to `max_gradient` on a hill road), then stamped back over the street's width plus a
## shoulder, blending out over `blend_m` (a clivus is cut sharply, its sides walled by UrbsSite).
## A `stairs` street keeps its slope (the steps follow it).
static func _cut_streets(cfg: Dictionary, h: PackedFloat32Array) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STREETS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var smooth_m := float(cfg.get("smooth_m", 36.0))
	var max_grad := float(cfg.get("max_gradient", 0.16))
	var step := 4.0
	var wgrid := PackedFloat32Array()
	wgrid.resize(VERTS * VERTS)
	var pgrid := PackedFloat32Array()
	pgrid.resize(VERTS * VERTS)
	for entry in parsed.get("streets", []):
		var raw := PackedVector2Array()
		for ll in entry["points"]:
			raw.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
		var pts := UrbsStreets._smooth(raw, 2)
		var hw := float(entry.get("width_m", 4.0)) * 0.5
		var kind := str(entry.get("kind", "street"))
		var shoulder := float(cfg.get("shoulder_m", 2.0))
		var blend := float(cfg.get("blend_m", 9.0))
		if kind == "clivus":
			shoulder = 1.6
			blend = 4.0
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		var length := cum[cum.size() - 1]
		if length < step * 2.0:
			continue
		var prof := street_profile(h, pts, cum, kind == "stairs", smooth_m, max_grad, step)
		var ns := prof.size()
		var sp := PackedVector2Array()
		for i in ns:
			sp.append(_polyline_at(pts, cum, length * float(i) / float(ns - 1)))
		var reach := hw + shoulder + blend
		for i in range(ns - 1):
			var a := sp[i]
			var b := sp[i + 1]
			var ab := b - a
			var l2 := maxf(ab.length_squared(), 0.001)
			var i0 := maxi(int(floor((minf(a.x, b.x) - reach + HALF_M) / CELL_M)), 0)
			var i1 := mini(int(ceil((maxf(a.x, b.x) + reach + HALF_M) / CELL_M)), CELLS)
			var j0 := maxi(int(floor((minf(a.y, b.y) - reach + HALF_M) / CELL_M)), 0)
			var j1 := mini(int(ceil((maxf(a.y, b.y) + reach + HALF_M) / CELL_M)), CELLS)
			for j in range(j0, j1 + 1):
				for ii in range(i0, i1 + 1):
					var p := Vector2(-HALF_M + ii * CELL_M, -HALF_M + j * CELL_M)
					var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
					var d := p.distance_to(a + ab * t)
					if d >= reach:
						continue
					var w := 1.0 - smoothstep(hw + shoulder, reach, d)
					var idx := j * VERTS + ii
					if w > wgrid[idx]:
						wgrid[idx] = w
						pgrid[idx] = lerpf(prof[i], prof[i + 1], t)
	for k in VERTS * VERTS:
		if wgrid[k] > 0.0:
			h[k] = lerpf(h[k], pgrid[k], wgrid[k])
			_built_w[k] = maxf(_built_w[k], wgrid[k])


## The height profile of a street (one value every `step` metres along it): sampled from `h`,
## then (unless `keep`) smoothed and held to `max_grad` by lowering whichever side climbs too fast.
static func street_profile(h: PackedFloat32Array, pts: PackedVector2Array, cum: PackedFloat32Array, keep: bool, smooth_m: float, max_grad: float, step: float) -> PackedFloat32Array:
	var length := cum[cum.size() - 1]
	var ns := int(ceil(length / step)) + 1
	var prof := PackedFloat32Array()
	for i in ns:
		var q := _polyline_at(pts, cum, length * float(i) / float(ns - 1))
		prof.append(_sample(h, q.x, q.y))
	if keep:
		return prof
	var half := maxi(int(smooth_m / step / 2.0), 1)
	for _r in 3:
		var tmp := prof.duplicate()
		for i in ns:
			var acc := 0.0
			var cnt := 0
			for k in range(maxi(i - half, 0), mini(i + half, ns - 1) + 1):
				acc += tmp[k]
				cnt += 1
			prof[i] = acc / cnt
	var st := length / float(ns - 1)
	for i in range(1, ns):
		prof[i] = minf(prof[i], prof[i - 1] + max_grad * st)
	for i in range(ns - 2, -1, -1):
		prof[i] = minf(prof[i], prof[i + 1] + max_grad * st)
	return prof


static func _polyline_at(pts: PackedVector2Array, cum: PackedFloat32Array, d: float) -> Vector2:
	var k := 0
	while k < cum.size() - 2 and cum[k + 1] < d:
		k += 1
	var seg := maxf(cum[k + 1] - cum[k], 0.0001)
	return pts[k].lerp(pts[k + 1], clampf((d - cum[k]) / seg, 0.0, 1.0))


## Bilinear sample of a field on this grid.
static func _sample(h: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x + HALF_M) / CELL_M, 0.0, CELLS - 0.001)
	var fz := clampf((z + HALF_M) / CELL_M, 0.0, CELLS - 0.001)
	var i := int(fx)
	var j := int(fz)
	var k := j * VERTS + i
	var a := lerpf(h[k], h[k + 1], fx - i)
	var b := lerpf(h[k + VERTS], h[k + VERTS + 1], fx - i)
	return lerpf(a, b, fz - j)


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


## The farmland weight raster: open country outside the Servian circuit and away from the
## centre, off the steep ground, the river and the woods; little on the Campus Martius (meadow).
static func _compute_rural() -> void:
	var rn := _rural_n()
	_rural = PackedFloat32Array()
	_rural.resize(rn * rn)
	var poly := circuit()
	for j in rn:
		for i in rn:
			var x := -HALF_M + i * RURAL_CELL
			var z := -HALF_M + j * RURAL_CELL
			var p := Vector2(x, z)
			if p.length() < 1000.0:
				continue
			var d := 2000.0
			if poly.size() > 2:
				if Geometry2D.is_point_in_polygon(p, poly):
					continue
				d = _poly_edge(poly, p)[1]
			var w := smoothstep(120.0, 420.0, d) * smoothstep(1100.0, 1500.0, p.length())
			if w <= 0.0:
				continue
			var e := CELL_M
			var gx := _sample(_h, x + e, z) - _sample(_h, x - e, z)
			var gz := _sample(_h, x, z + e) - _sample(_h, x, z - e)
			var ny := Vector3(-gx, 2.0 * e, -gz).normalized().y
			w *= smoothstep(0.86, 0.95, ny)
			var k := _cell(x, z)
			if _h[k] < _river_level[k] + 2.0 or _river_dist[k] < _river_hw[k] + 40.0:
				w = 0.0
			w *= 1.0 - smoothstep(0.25, 0.6, UrbsSiteFlora.wood_density(x, z))
			if x < -250.0 and z < -250.0 and x > -1700.0 and z > -2300.0:   # the Campus Martius: meadow and pasture
				w *= 0.3
			_rural[j * rn + i] = w


## The ground's colour and material weights baked into two world-space maps (MAP_CELL apart),
## which the ground shader samples by position. (In the game's compatibility renderer per-vertex
## attributes of the chunk meshes did not reach the shader intact; a map does not depend on them,
## and it shades every lod alike.)
static func _bake_maps() -> void:
	_map_col = PackedByteArray()
	_map_col.resize(MAP_N * MAP_N * 4)
	_map_w = PackedByteArray()
	_map_w.resize(MAP_N * MAP_N * 4)
	var st := int(MAP_CELL / CELL_M)
	for j in MAP_N:
		for i in MAP_N:
			var gi := _gi(i * st)
			var gj := _gi(j * st)
			var k := gj * VERTS + gi
			var x := -HALF_M + gi * CELL_M
			var z := -HALF_M + gj * CELL_M
			var e := 2
			var nrm := Vector3(_h[gj * VERTS + _gi(gi - e)] - _h[gj * VERTS + _gi(gi + e)], 2.0 * e * CELL_M, _h[_gi(gj - e) * VERTS + gi] - _h[_gi(gj + e) * VERTS + gi]).normalized()
			var w := _ground_weights(x, z, _h[k], nrm.y, k)
			var c: Color = w[0]
			var a: Vector2 = w[1]
			var b: Vector2 = w[2]
			var o := (j * MAP_N + i) * 4
			_map_col[o] = clampi(roundi(c.r * 255.0), 0, 255)
			_map_col[o + 1] = clampi(roundi(c.g * 255.0), 0, 255)
			_map_col[o + 2] = clampi(roundi(c.b * 255.0), 0, 255)
			_map_col[o + 3] = clampi(roundi(c.a * 255.0), 0, 255)
			_map_w[o] = clampi(roundi(a.x * 255.0), 0, 255)
			_map_w[o + 1] = clampi(roundi(a.y * 255.0), 0, 255)
			_map_w[o + 2] = clampi(roundi(b.x * 255.0), 0, 255)
			_map_w[o + 3] = clampi(roundi(b.y * 255.0), 0, 255)


## Farmland weight 0..1 at local (x, z).
static func rural_at(x: float, z: float) -> float:
	prepare()
	var rn := _rural_n()
	var fx := clampf((x + HALF_M) / RURAL_CELL, 0.0, rn - 1.001)
	var fz := clampf((z + HALF_M) / RURAL_CELL, 0.0, rn - 1.001)
	var i := int(fx)
	var j := int(fz)
	var k := j * rn + i
	var a := lerpf(_rural[k], _rural[k + 1], fx - i)
	var b := lerpf(_rural[k + rn], _rural[k + rn + 1], fx - i)
	return lerpf(a, b, fz - j)


## Ground height in metres a.s.l. at local (x, z); bilinear, clamped to the field's edge.
static func height_at(x: float, z: float) -> float:
	prepare()
	return _sample(_h, x, z)


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


## The raw height grid (VERTS x VERTS, CELL_M apart from -HALF_M): for UrbsSite's contour walk.
static func field() -> PackedFloat32Array:
	prepare()
	return _h


## Distance in metres from (x, z) to the Tiber's centre line (large when far away).
static func river_distance(x: float, z: float) -> float:
	prepare()
	return _river_dist[_cell(x, z)]


## Normal water level of the Tiber nearest (x, z), m a.s.l.
static func river_level(x: float, z: float) -> float:
	prepare()
	return _river_level[_cell(x, z)]


## Half-width of the channel nearest (x, z).
static func river_half_width(x: float, z: float) -> float:
	prepare()
	return _river_hw[_cell(x, z)]


## True if (x, z) lies in the water of the Tiber (ground below the normal water level).
static func in_river(x: float, z: float) -> bool:
	prepare()
	var k := _cell(x, z)
	return _h[k] < _river_level[k] - 0.2 and _river_dist[k] < 150.0


## How much (x, z) is on a plateau top (1) or its flank (fading to 0).
static func plateau_at(x: float, z: float) -> float:
	prepare()
	return _plateau_w[_cell(x, z)]


## How much (x, z) is built ground: a platform or a street cut (1) or open ground (0).
static func built_at(x: float, z: float) -> float:
	prepare()
	return _built_w[_cell(x, z)]


## How much (x, z) is terraced hillside (0..1).
static func terrace_at(x: float, z: float) -> float:
	prepare()
	return _terrace_w[_cell(x, z)]


## The field's extent as a Rect2 in local (x, z) metres.
static func bounds() -> Rect2:
	return Rect2(-HALF_M, -HALF_M, 2.0 * HALF_M, 2.0 * HALF_M)


## Whole-scene parts for the Urbs root (urbs.gd interface): the site works of the year (platform walls, clivus walls, steps, quays, the island's facing). The
## ground itself comes chunk by chunk from build_chunk. Returns the node holding the parts.
static func build(urbs: Node3D) -> Node3D:
	prepare()
	var y: Variant = urbs.get("year")
	if y != null:
		year = int(y)
	var root := Node3D.new()
	root.name = "UrbsRiver"
	urbs.add_child(root)
	UrbsSite.build(root, year, Callable(UrbsTerrain, "height_at"))
	return root


## The ground of one chunk covering `rect` (local x, z metres; 250 m squares aligned to the
## field, but any rect inside it works). lod 0 is the finest (5 m cells within 2 km of the Forum,
## 10 m beyond) and carries collision (a heightmap body), the terrace walls and the full flora;
## lod 1 (25 m cells) the walls and the flora; lod 2 (50 m cells) the bare ground with far trees.
## Every chunk has a skirt dropped 4 m round its edge so neighbours of different detail show no cracks.
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
	var water := _water_mesh(i0, j0, ci, cj, step)
	if water != null:
		var wmi := MeshInstance3D.new()
		wmi.name = "Water"
		wmi.mesh = water
		wmi.material_override = UrbsMaterials.get_material("tiber_water")
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(wmi)
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
		var walls := UrbsSite.build_chunk_walls(rect, lod, year)
		if walls != null:
			node.add_child(walls)
	UrbsSiteFlora.build_chunk(node, rect, lod, year)
	return node


## Builds the whole field at once (400 chunks of 250 m, with collision) plus the river, under a
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
	var stride := nx + 1
	for dj in nz + 1:
		for di in nx + 1:
			_add_vertex(i0 + di * step, j0 + dj * step, 0.0, step, pp, pn)
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
		_add_vertex(i0 + r.x * step, j0 + r.y * step, 4.0, step, pp, pn)
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
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## The Tiber's surface over this chunk: a quad at the water level (per vertex, it falls gently
## downstream) over every cell where the ground dips below it. Follows the banks, the island and
## the quays exactly, whatever the river's shape.
static func _water_mesh(i0: int, j0: int, ci: int, cj: int, step: int) -> ArrayMesh:
	var nx := maxi(ci / step, 1)
	var nz := maxi(cj / step, 1)
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var map := {}
	for dj in nz:
		for di in nx:
			var wet := false
			var ks: Array[int] = []
			for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var k := _gi(j0 + (dj + c.y) * step) * VERTS + _gi(i0 + (di + c.x) * step)
				ks.append(k)
				if _river_dist[k] < 400.0 and _h[k] < _river_level[k] + 0.05:
					wet = true
			if not wet:
				continue
			var q: Array[int] = []
			for c in 4:
				var k: int = ks[c]
				if not map.has(k):
					map[k] = verts.size()
					var i := k % VERTS
					var j := k / VERTS
					verts.append(Vector3(-HALF_M + i * CELL_M, _river_level[k], -HALF_M + j * CELL_M))
				q.append(map[k])
			idx.append_array([q[0], q[1], q[3], q[1], q[2], q[3]])
	if idx.is_empty():
		return null
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var uvs := PackedVector2Array()
	for v in verts:
		uvs.append(Vector2(v.x, v.z) / 40.0)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


static func _add_vertex(i: int, j: int, drop: float, step: int, pp: PackedVector3Array, pn: PackedVector3Array) -> void:
	i = _gi(i)
	j = _gi(j)
	var k := j * VERTS + i
	# the normal over the mesh's own spacing (at least two cells): an even shading on the slopes
	var e := maxi(step, 2)
	var hl := _h[j * VERTS + _gi(i - e)]
	var hr := _h[j * VERTS + _gi(i + e)]
	var hu := _h[_gi(j - e) * VERTS + i]
	var hd := _h[_gi(j + e) * VERTS + i]
	pp.append(Vector3(-HALF_M + i * CELL_M, _h[k] - drop, -HALF_M + j * CELL_M))
	pn.append(Vector3(hl - hr, 2.0 * e * CELL_M, hu - hd).normalized())


## Ground colour and material weights at a vertex. Returns [colour (alpha = farmland), (grass,
## mud), (dust, gravel)]. Dry Mediterranean grass on the gentle high ground, trodden earth round
## the Forum, in the low valleys, on the terraces and on every platform and street cut, tufa on the
## steep slopes, damp mud at the river's edge, gravel on the inside of the bends, stone on the island.
static func _ground_weights(x: float, z: float, y: float, ny: float, k: int) -> Array:
	var rd := _river_dist[k]
	var wl := _river_level[k]
	var hw := _river_hw[k]
	var flat := smoothstep(0.80, 0.95, ny)
	var steep := 1.0 - smoothstep(0.66, 0.86, ny)
	var forum := (1.0 - smoothstep(150.0, 520.0, Vector2(x, z).length())) * flat
	# the hill flanks get one even colour: no dust there (the flank's wavy edge made stripes)
	var flank := smoothstep(0.0, 0.12, _plateau_w[k]) * (1.0 - smoothstep(0.97, 1.0, _plateau_w[k]))
	var valley := smoothstep(0.8, 0.98, _valley_w[k]) * (1.0 - flank)
	var built := smoothstep(0.2, 0.9, _built_w[k])
	var dust := clampf(maxf(maxf(forum * 0.9 * (1.0 - flank), valley * 0.7), built * 0.85), 0.0, 1.0)
	var bank := (1.0 - smoothstep(0.0, 24.0, rd - hw)) * (1.0 - smoothstep(1.2, 4.5, y - wl))
	var mud := clampf(bank * (1.0 - _river_inner[k] * 0.8), 0.0, 1.0)
	var gravel := clampf(_river_inner[k] * (1.0 - smoothstep(0.3, 1.2, y - wl)) * smoothstep(hw * 0.8, hw, rd) * 1.2, 0.0, 1.0)
	var ir := UrbsTiber.island_r(x, z)
	var stone := 0.0
	if ir < 1.12 and y > wl - 0.8:
		stone = smoothstep(0.86, 0.96, ir) * (1.0 - smoothstep(1.0, 1.12, ir))
		mud *= smoothstep(0.9, 1.0, ir)
		dust = maxf(dust, 0.5 * (1.0 - smoothstep(0.8, 0.95, ir)))
	var grass_c := Color(0.47, 0.47, 0.25).lerp(Color(0.53, 0.50, 0.28), smoothstep(30.0, 60.0, y))
	var meadow_c := Color(0.39, 0.44, 0.22)
	var grass := meadow_c.lerp(grass_c, smoothstep(16.0, 34.0, y))
	var dust_c := Color(0.57, 0.48, 0.35).lerp(Color(0.66, 0.57, 0.42), maxf(forum, built))
	var tufa := Color(0.60, 0.50, 0.36)
	var c := grass.lerp(tufa, steep)
	c = c.lerp(dust_c, dust * (1.0 - steep))
	c = c.lerp(Color(0.33, 0.28, 0.19), mud)
	c = c.lerp(Color(0.48, 0.44, 0.36).lerp(Color(0.44, 0.42, 0.37), stone), maxf(gravel, stone))
	var wg := clampf(1.0 - maxf(maxf(dust, mud), maxf(maxf(gravel, stone), steep)), 0.0, 1.0)
	c.a = _rural_raw(x, z) * flat * (1.0 - dust)
	return [c, Vector2(wg, mud), Vector2(dust, maxf(gravel, stone))]


static func _rural_raw(x: float, z: float) -> float:
	var rn := _rural_n()
	var fx := clampf((x + HALF_M) / RURAL_CELL, 0.0, rn - 1.001)
	var fz := clampf((z + HALF_M) / RURAL_CELL, 0.0, rn - 1.001)
	var i := int(fx)
	var j := int(fz)
	var k := j * rn + i
	return lerpf(lerpf(_rural[k], _rural[k + 1], fx - i), lerpf(_rural[k + rn], _rural[k + rn + 1], fx - i), fz - j)


## The ground's shader. The farmland parcels use the same integer hash and frame as
## UrbsSite.parcel_at (site.gd), so the olive groves UrbsSiteFlora plants stand on the right fields.
static func _ground_material() -> ShaderMaterial:
	if _material != null:
		return _material
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 wpos;
varying vec3 wnorm;
uniform sampler2D ground_col : filter_linear, repeat_disable;
uniform sampler2D ground_w : filter_linear, repeat_disable;
uniform float map_half = 2500.0;
uniform float map_cell = 10.0;
uniform float map_n = 501.0;
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }
uint pcg(uint v) { uint s = v * 747796405u + 2891336453u; uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u; return (w >> 22u) ^ w; }
float ih(int a, int b, int s) { return float(pcg(uint(a) ^ pcg(uint(b) ^ pcg(uint(s))))) / 4294967295.0; }
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
// kind: 0 ploughed, 1 green crop, 2 ripe/stubble, 3 pasture, 4 olive grove, 5 vineyard; hedge in .a
vec4 farm(vec2 p) {
	float RS = 420.0;
	ivec2 rc = ivec2(floor(p / RS));
	float ang = ih(rc.x, rc.y, 1) * 3.14159265;
	float cs = cos(ang); float sn = sin(ang);
	vec2 d = p - vec2(ih(rc.x, rc.y, 2), ih(rc.x, rc.y, 3)) * 300.0;
	vec2 q = vec2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y);
	vec2 cell = vec2(54.0, 92.0);
	ivec2 id = ivec2(floor(q / cell));
	vec2 f = fract(q / cell);
	int ia = id.x + rc.x * 131; int ib = id.y + rc.y * 71;
	float k = ih(ia, ib, 4);
	int kind = k < 0.28 ? 0 : (k < 0.52 ? 1 : (k < 0.68 ? 2 : (k < 0.80 ? 3 : (k < 0.92 ? 4 : 5))));
	float edge = min(min(f.x, 1.0 - f.x) * cell.x, min(f.y, 1.0 - f.y) * cell.y);
	vec2 rf = fract(p / RS);
	float redge = min(min(rf.x, 1.0 - rf.x), min(rf.y, 1.0 - rf.y)) * RS;
	float hedge = (1.0 - smoothstep(0.8, 2.0, min(edge, redge))) * (ih(ia, ib, 5) < 0.7 ? 0.8 : 0.25);
	float furrow = 0.5 + 0.5 * sin(q.x * 6.2832 / 1.1);
	float along = 0.5 + 0.5 * sin(q.x * 6.2832 / 2.6);
	vec3 col;
	if (kind == 0) col = mix(vec3(0.48, 0.41, 0.31), vec3(0.51, 0.44, 0.33), furrow);
	else if (kind == 1) col = mix(vec3(0.44, 0.47, 0.29), vec3(0.46, 0.49, 0.30), furrow);
	else if (kind == 2) col = mix(vec3(0.58, 0.54, 0.39), vec3(0.61, 0.57, 0.41), furrow);
	else if (kind == 3) col = vec3(0.46, 0.48, 0.30);
	else if (kind == 4) col = vec3(0.52, 0.49, 0.37);
	else col = mix(vec3(0.49, 0.43, 0.32), vec3(0.43, 0.46, 0.28), smoothstep(0.4, 0.6, along));
	col *= 0.94 + 0.12 * ih(ia, ib, 6);
	return vec4(col, hedge);
}
void fragment() {
	vec3 N = normalize(wnorm);
	float big = vnoise(wpos * 0.012);
	float mid = vnoise(wpos * 0.09);
	float fine = vnoise(wpos * 0.7);
	float micro = vnoise(wpos * 3.1);
	vec2 muv = ((wpos.xz + vec2(map_half)) / map_cell + 0.5) / map_n;
	vec4 gc = texture(ground_col, muv);
	vec4 wts = texture(ground_w, muv);
	float rural = gc.a;
	float wg = wts.x; float wm = wts.y; float wd = wts.z; float wgr = wts.w;
	vec3 col = lin(gc.rgb) * (0.84 + 0.28 * (0.4 * big + 0.3 * mid + 0.3 * fine));
	// grass: a gentle drift between green and straw, and a fine speckle of tufts
	float dry = smoothstep(0.3, 0.75, vnoise(wpos * 0.02 + 7.0) + 0.3 * (fine - 0.5));
	col = mix(col, col * vec3(1.2, 1.12, 0.85), dry * 0.35 * wg);
	col *= 1.0 + (micro - 0.5) * 0.3 * wg;
	// trodden earth and dust: lighter on the high spots, scuffed
	col *= 1.0 + ((fine - 0.5) * 0.35 + (mid - 0.5) * 0.2) * wd;
	// mud: darker and wet
	col = mix(col, col * 0.6, wm);
	// gravel and stone: pebbles
	float peb = vnoise(wpos * 2.3);
	col = mix(col, mix(col * 0.82, col * 1.15, step(0.55, peb)), wgr * 0.85);
	// farmland: parcels with furrows and hedgerows, on the flat open ground only
	float steep = 1.0 - smoothstep(0.62, 0.84, N.y);
	if (rural > 0.01) {
		vec4 fm = farm(wpos.xz);
		vec3 fc = lin(fm.rgb) * (0.9 + 0.2 * (0.5 * mid + 0.5 * fine));
		fc = mix(fc, lin(vec3(0.30, 0.33, 0.20)) * (0.85 + 0.3 * fine), fm.a);
		col = mix(col, fc, rural * (1.0 - steep) * 0.85);
	}
	// cliffs and steep slopes: tufa, an even warm grey-brown with faint horizontal bedding
	float bf = fract(wpos.y * 1.1 + big * 3.0);
	vec3 st = lin(vec3(0.60, 0.51, 0.38));
	st *= 0.92 + 0.16 * vnoise(wpos * vec3(0.5, 1.6, 0.5));
	st *= 0.95 + 0.05 * smoothstep(0.0, 0.15, bf) * smoothstep(1.0, 0.85, bf);
	col = mix(col, st, steep * 0.85);
	ALBEDO = col;
	ROUGHNESS = mix(1.0, 0.55, wm);
	SPECULAR = mix(0.05, 0.3, wm);
}
"""
	_material = ShaderMaterial.new()
	_material.shader = sh
	_material.set_shader_parameter("ground_col", ImageTexture.create_from_image(Image.create_from_data(MAP_N, MAP_N, false, Image.FORMAT_RGBA8, _map_col)))
	_material.set_shader_parameter("ground_w", ImageTexture.create_from_image(Image.create_from_data(MAP_N, MAP_N, false, Image.FORMAT_RGBA8, _map_w)))
	_material.set_shader_parameter("map_half", HALF_M)
	_material.set_shader_parameter("map_cell", MAP_CELL)
	_material.set_shader_parameter("map_n", float(MAP_N))
	return _material
