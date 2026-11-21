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
##
## F3: the ground belongs to its YEAR (`year`, set before the first height_at): a platform that
## names a monument (its id or `monument`) is cut only while that monument stands; the hillside
## terraces only where the city's districts are built up that year (UrbsFill's occupancy), so the
## empty hills of 509 BC keep their natural slope; every paving (a `plaza` monument standing) is
## carved level under its footprint and the ground mesh is left out beneath it (no z-fighting);
## the quays level the bank only from their year. The cache is keyed on what the year changes.
class_name UrbsTerrain

const HALF_M := 2500.0                    ## the field spans -HALF_M .. +HALF_M in x and z
const CELL_M := 5.0
const CELLS := 1000                       ## cells per side
const VERTS := CELLS + 1
const CHUNK_CELLS := 50                   ## 250 m chunks
const NEAR_M := 4000.0                    ## within this of the Forum, lod 0 uses every 5 m cell (F3: the whole field, so every street's cut is drawn)
const WARP_M := 38.0                      ## how far hill and valley outlines wander from their ideal line
const FORUM_FLOOR_M := 10.0               ## ancient Forum floor, m a.s.l.
const TERRACE_M := 4.0                    ## height of one hillside terrace
const CACHE_KEEP := 8                     ## F3: terrain caches kept in user:// (one per year shown, ~40 MB each)
const CACHE_VERSION := "f3-ground-1"       ## bump when the model code changes (F3: the ground of the year)
const STREETS_PATH := "res://data/city/streets.json"
const REGIONS_PATH := "res://data/city/regions.json"
const RURAL_CELL := 25.0                  ## resolution of the farmland weight raster
const MAP_CELL := 10.0                    ## resolution of the baked ground colour maps
const MAP_N := 501                        ## texels per side of the ground colour maps
const FRONT_RAMP := 0.2                   ## F3: slope of the ramp in front of a monument's terrace (1 in 5)
const PAVE_BLEND := 6.0                   ## F3: a paving's carved floor blends into the ground over this
const PAVE_INSET := 0.6                   ## F3: no ground drawn this far inside a paving's edge
const PAVE_DIP := 0.5                     ## F3: ground vertices under a paving are drawn this much lower
const SKY_FILL := 0.12                    ## F3: the twilight sky's fill on the ground at its strongest
const TERRACE_OCC := Vector2(0.35, 0.75)  ## F3: terraced from this built-up share (none) to this (full)

static var year := -44                    ## the year being shown (set by build); flora and site works read it
static var walls_later := false           ## F3: UrbsChunks stands the terrace walls once the houses are laid out
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
static var _urban: PackedFloat32Array = PackedFloat32Array()      ## 0..1 inside the Servian circuit (soft edge), MAP_N x MAP_N
static var _circuit: PackedVector2Array = PackedVector2Array()
static var _warp: FastNoiseLite = null
static var _warp2: FastNoiseLite = null
static var _material: ShaderMaterial = null
static var _sky_fill := 0.0                                      ## the twilight fill (set_sky_fill)
static var _street_w: PackedFloat32Array = PackedFloat32Array()  ## street cuts' weight (while computing)
static var _cover: PackedByteArray = PackedByteArray()          ## 1 under a paving, 2 well inside it (no ground drawn)
static var _occ: PackedFloat32Array = PackedFloat32Array()      ## built-up share of the year, RURAL_CELL grid
static var _built_year := 999999                                 ## the year the field was computed for
static var _sig := ""                                            ## what that year changed (see _signature)
static var _mons: UrbsMonuments = null
static var _plat_year := 999999
static var _plat: Array = []
static var _pave_year := 999999
static var _pave: Array = []


## Computes the heightfield if that has not been done yet (several seconds the first time).
## height_at and build_chunk call this themselves; call it early to choose when the cost falls.
static func prepare() -> void:
	if not _h.is_empty() and _built_year == year:
		return
	var sig := _signature()
	_built_year = year
	if not _h.is_empty() and sig == _sig:
		return   # this year's ground is the same as the one already computed
	_sig = sig
	_material = null
	# (the builders' own code is part of the key too, so an edit to them never reads a stale cache)
	var code := FileAccess.get_file_as_string("res://scripts/urbs/terrain.gd") + FileAccess.get_file_as_string("res://scripts/urbs/tiber.gd")
	var key := "%x" % hash(JSON.stringify(UrbsTiber.topography()) + FileAccess.get_file_as_string(STREETS_PATH) + FileAccess.get_file_as_string(UrbsTiber.MONUMENTS_PATH).md5_text() + CACHE_VERSION + sig + code.md5_text())
	if _load_cache(key):
		return
	_compute()
	_save_cache(key)


## What the year changes in the ground: the platforms and pavings standing, the quays, and the
## built-up share of each district (rounded), as one string.
static func _signature() -> String:
	var parts: Array = []
	for pf: Dictionary in platforms():
		parts.append(str(pf["id"]) + str(pf["poly"]))
	for pv: Dictionary in pavings():
		parts.append(str(pv["id"]) + str(pv["poly"]))
	for q: Dictionary in topography_quays():
		parts.append(str(q.get("id", "")))
	var f := _fill_probe()
	for d: Dictionary in f._districts + [f._default_inside, f._default]:
		parts.append("%s%.2f" % [d["id"], snappedf(f._occupancy(d), 0.02)])
	parts.append(str(year >= -378))
	return JSON.stringify(parts).md5_text()


## The quays of topography.yaml standing in the year.
static func topography_quays() -> Array:
	var out := []
	for q: Dictionary in UrbsTiber.topography().get("terrain_model", {}).get("quays", []):
		var from_y: Variant = q.get("from")
		if from_y == null or int(from_y) <= year:
			out.append(q)
	return out


## An UrbsFill set to the year, to ask its districts how built up they are (fill.gd `_occupancy`).
static func _fill_probe() -> UrbsFill:
	var f := UrbsFill.new()
	f.year = year
	f._load()
	return f


static func _monuments() -> UrbsMonuments:
	if _mons == null:
		_mons = UrbsMonuments.new()
	return _mons


## Monument `id` as monuments.gd places it in the year: {centre, yaw, ax, az, half (x across,
## y along), model}, or {} when it does not stand. (The frame of monuments.gd `_make`.)
static func monument_plan(id: String) -> Dictionary:
	var st := _monuments().state_at(id, year)
	if st.is_empty():
		return {}
	var m: Dictionary = _monuments().entry(id)
	if not m.has("lat") or m.get("lat") == null:
		return {}
	var c := UrbsGeo.to_local(float(m["lat"]), float(m["lon"]))
	var off: Variant = m.get("offset_m")
	if off is Array:
		c += Vector2(float(off[0]), -float(off[1]))
	var br: Variant = m.get("bearing_deg")
	var yaw := UrbsGeo.yaw_from_bearing(float(br)) if br != null else 0.0
	return {"centre": c, "yaw": yaw, "ax": Vector2(cos(yaw), -sin(yaw)), "az": Vector2(sin(yaw), cos(yaw)),
		"half": Vector2(float(st.width), float(st.length)) * 0.5, "model": str(st.model)}


## The plan's rectangle grown by `grow` metres, as a polygon.
static func plan_rect(pl: Dictionary, grow := 0.0) -> PackedVector2Array:
	var c: Vector2 = pl["centre"]
	var hx := float(pl["half"].x) + grow
	var hz := float(pl["half"].y) + grow
	var ax: Vector2 = pl["ax"]
	var az: Vector2 = pl["az"]
	return PackedVector2Array([c + ax * hx + az * hz, c + ax * hx - az * hz, c - ax * hx - az * hz, c - ax * hx + az * hz])


## The platforms of the year (topography.yaml terrain_model.platforms), each the yaml entry plus
## "poly" (local metres). A platform that names a monument (its own id, or `monument`) is cut only
## while that monument stands; with `outline: monument` its polygon is that monument's footprint.
static func platforms() -> Array:
	if _plat_year == year:
		return _plat
	_plat_year = year
	_plat = []
	var model: Dictionary = UrbsTiber.topography().get("terrain_model", {})
	for pf: Dictionary in model.get("platforms", []):
		var mid := str(pf.get("monument", pf.get("id", "")))
		var known := _monuments().entry(mid).size() > 0
		var pl := monument_plan(mid) if known else {}
		if known and pl.is_empty():
			continue
		var e := pf.duplicate()
		var poly := PackedVector2Array()
		if str(pf.get("outline", "")) == "monument" and not pl.is_empty():
			poly = plan_rect(pl, 0.5)
		else:
			for ll: Array in pf.get("polygon", []):
				poly.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
		e["poly"] = poly
		if not pl.is_empty():
			e["front"] = Vector2(pl["az"])
		_plat.append(e)
	return _plat


## The pavings of the year: every `plaza` monument standing, {id, poly (its footprint), centre}.
static func pavings() -> Array:
	if _pave_year == year:
		return _pave
	_pave_year = year
	_pave = []
	var ids: Array = _monuments()._recs.keys()
	ids.sort()
	for id: String in ids:
		var pl := monument_plan(id)
		if pl.is_empty() or str(pl["model"]) != "plaza" or float(pl["half"].x) <= 0.0 or float(pl["half"].y) <= 0.0:
			continue
		_pave.append({"id": id, "poly": plan_rect(pl), "centre": pl["centre"]})
	return _pave


## The heightfield and its companion rasters are kept in user:// after the first run (keyed on a
## hash of the data files and CACHE_VERSION), so later starts take a tenth of a second.
static func _cache_path(key: String) -> String:
	return "user://urbs_terrain_%s.bin" % key


static func _rural_n() -> int:
	return int(2.0 * HALF_M / RURAL_CELL) + 1


static func _save_cache(key: String) -> void:
	_prune_cache(CACHE_KEEP - 1)
	var f := FileAccess.open(_cache_path(key), FileAccess.WRITE)
	if f == null:
		return
	for arr: PackedFloat32Array in [_h, _river_dist, _river_level, _river_hw, _river_inner, _valley_w, _plateau_w, _built_w, _terrace_w]:
		f.store_buffer(arr.to_byte_array())
	f.store_buffer(_rural.to_byte_array())
	f.store_buffer(_map_col)
	f.store_buffer(_map_w)
	f.store_buffer(_cover)


## F3: the ground now differs by year, so caches pile up (about 40 MB each): keep the `keep` most
## recently written and delete the rest.
static func _prune_cache(keep: int) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var found: Array = []
	for name in dir.get_files():
		if name.begins_with("urbs_terrain_") and name.ends_with(".bin"):
			found.append([FileAccess.get_modified_time("user://" + name), name])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for k in range(keep, found.size()):
		dir.remove(found[k][1])


static func _load_cache(key: String) -> bool:
	var f := FileAccess.open(_cache_path(key), FileAccess.READ)
	if f == null:
		return false
	var bytes := VERTS * VERTS * 4
	var rn := _rural_n()
	if f.get_length() != bytes * 9 + rn * rn * 4 + MAP_N * MAP_N * 8 + VERTS * VERTS:
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
	_cover = f.get_buffer(VERTS * VERTS)
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
	# 5b. the built platforms of the year, dead flat
	_built_w = PackedFloat32Array()
	_built_w.resize(n * n)
	for pf: Dictionary in platforms():
		_stamp_platform(pf, h)
	# 6. terraces on the hillsides built up in the year
	_compute_occupancy()
	_terrace(h)
	# 7. the streets cut into the ground
	_cut_streets(model.get("street_cuts", {}), h)
	# 8. the Tiber
	var riv := UrbsTiber.carve(h, n, -HALF_M, CELL_M)
	_river_dist = riv["dist"]
	_river_level = riv["level"]
	_river_hw = riv["hw"]
	_river_inner = riv["inner"]
	# 9. F3: every paving of the year carved level under its footprint (at the level monuments.gd
	# lays it: its platform's floor, else the ground at its centre), the ground mesh left out under it
	_cover = PackedByteArray()
	_cover.resize(n * n)
	for pv: Dictionary in pavings():
		_stamp_paving(pv, h)
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
## into the ground over `blend` metres beyond its edge. F3: a platform carrying a monument
## (`front`, the monument's facing) falls in front of it as a ramp of FRONT_RAMP (1 in 5) to the
## ground, so its front never stands over the street or the ground it faces (UrbsSite leaves the
## wall off that side).
static func _stamp_platform(pf: Dictionary, h: PackedFloat32Array) -> void:
	var poly: PackedVector2Array = pf["poly"] if pf.has("poly") else _poly2(_pts(pf, "polygon"))
	if poly.size() < 3:
		return
	var lv: Array = pf.get("level", [10.0, 10.0])
	var l0 := float(lv[0])
	var l1 := float(lv[lv.size() - 1])
	var blend := float(pf.get("blend", 25.0))
	var front: Vector2 = pf.get("front", Vector2.ZERO)
	var ramp := 0.0
	if front != Vector2.ZERO and str(pf.get("id", "")).begins_with("f2_terrace_"):
		# how far the ground in front lies below the floor, read before the cut
		var c := Vector2.ZERO
		for q in poly:
			c += q / poly.size()
		var far := 0.0
		while far < 200.0 and Geometry2D.is_point_in_polygon(c + front * far, poly):
			far += 1.0
		var q := c + front * (far + 6.0)
		ramp = clampf((l0 - _sample(h, q.x, q.y)) / FRONT_RAMP, blend, 80.0)
	var reach := maxf(blend, ramp)
	var bb := _bbox(poly, reach)
	var lo: Vector2 = bb[4]
	var hi: Vector2 = bb[5]
	for j in range(bb[2], bb[3] + 1):
		for i in range(bb[0], bb[1] + 1):
			var p := Vector2(-HALF_M + i * CELL_M, -HALF_M + j * CELL_M)
			var idx := j * VERTS + i
			var level := lerpf(l0, l1, clampf((p.x - lo.x) / maxf(hi.x - lo.x, 1.0), 0.0, 1.0))
			var w := 1.0
			if not Geometry2D.is_point_in_polygon(p, poly):
				var e := _poly_edge(poly, p)
				var d: float = e[1]
				var b := blend
				if ramp > 0.0:
					var side := ((p - (e[0] as Vector2)).normalized()).dot(front)
					b = lerpf(blend, ramp, smoothstep(0.35, 0.75, side))
				if d >= b:
					continue
				w = 1.0 - (d / b if ramp > 0.0 and b > blend + 0.5 else smoothstep(0.0, b, d))
			h[idx] = lerpf(h[idx], level, w)
			_built_w[idx] = maxf(_built_w[idx], w)


## F3: a paving's footprint carved level (cut and filled, blended over PAVE_BLEND m) and marked in
## `_cover` where the paving hides the ground (its footprint less PAVE_INSET), so the ground mesh
## leaves those triangles out.
static func _stamp_paving(pv: Dictionary, h: PackedFloat32Array) -> void:
	var poly: PackedVector2Array = pv["poly"]
	var c: Vector2 = pv["centre"]
	var level := _sample(h, c.x, c.y)
	var on_platform := false
	for pf: Dictionary in platforms():
		if Geometry2D.is_point_in_polygon(c, pf["poly"]):
			var lv: Array = pf.get("level", [10.0])
			level = float(lv[0])
			on_platform = true
	# off a platform monuments.gd lays the paving on the lowest ground under its corners and the
	# middles of its sides: those spots stay level whatever passes there
	var spots := PackedVector2Array()
	if not on_platform:
		for k in poly.size():
			spots.append(poly[k])
			spots.append((poly[k] + poly[(k + 1) % poly.size()]) * 0.5)
	# level to a cell and a half beyond the edge, so the ground under the paving's corners and edges
	# (where monuments.gd reads its lowest point) is the floor itself; then the blend
	var flat := CELL_M * 1.5
	var bb := _bbox(poly, flat + PAVE_BLEND)
	for j in range(bb[2], bb[3] + 1):
		for i in range(bb[0], bb[1] + 1):
			var p := Vector2(-HALF_M + i * CELL_M, -HALF_M + j * CELL_M)
			var idx := j * VERTS + i
			var w := 1.0
			if Geometry2D.is_point_in_polygon(p, poly):
				_cover[idx] = 2 if _poly_edge(poly, p)[1] > PAVE_INSET else maxi(_cover[idx], 1)
			else:
				var d: float = _poly_edge(poly, p)[1]
				if d >= flat + PAVE_BLEND:
					continue
				# beyond its first cell a paving's floor gives way to a street's own cut, but at its
				# spots (the first cell stays level, so no slope of ground rises through the paving's
				# edge; a walled platform's wall hides the step beyond it)
				w = 1.0 - smoothstep(flat, flat + PAVE_BLEND, d)
				var spot := d <= CELL_M + 0.5
				for q in spots:
					spot = spot or q.distance_to(p) < flat
				if not spot:
					w *= 1.0 - _street_w[idx]
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
			w *= smoothstep(TERRACE_OCC.x, TERRACE_OCC.y, _occ_at(-HALF_M + i * CELL_M, -HALF_M + j * CELL_M))
			if w <= 0.0:
				continue
			if not Geometry2D.is_point_in_polygon(Vector2(-HALF_M + i * CELL_M, -HALF_M + j * CELL_M), poly):
				continue
			var q := src[k] / TERRACE_M
			var kq := floorf(q)
			var ht := TERRACE_M * (kq + smoothstep(0.78, 1.0, q - kq))
			h[k] = lerpf(src[k], ht, w)
			_terrace_w[k] = w


## F3: how built up the city is in the year (UrbsFill's district occupancy) on the RURAL_CELL grid.
static func _compute_occupancy() -> void:
	var f := _fill_probe()
	var rn := _rural_n()
	_occ = PackedFloat32Array()
	_occ.resize(rn * rn)
	for j in rn:
		for i in rn:
			var p := Vector2(-HALF_M + i * RURAL_CELL, -HALF_M + j * RURAL_CELL)
			if p.length() > 2600.0:
				continue
			_occ[j * rn + i] = f._occupancy_at(f._district_at(p), p)


static func _occ_at(x: float, z: float) -> float:
	if _occ.is_empty():
		return 1.0
	var rn := _rural_n()
	var fx := clampf((x + HALF_M) / RURAL_CELL, 0.0, rn - 1.001)
	var fz := clampf((z + HALF_M) / RURAL_CELL, 0.0, rn - 1.001)
	var i := int(fx)
	var j := int(fz)
	var k := j * rn + i
	return lerpf(lerpf(_occ[k], _occ[k + 1], fx - i), lerpf(_occ[k + rn], _occ[k + rn + 1], fx - i), fz - j)


## Streets cut into the ground: the profile along each street is sampled from the field, smoothed
## (and held to `max_gradient` on a hill road), then stamped back over the street's width plus a
## shoulder, blending out over `blend_m` (a clivus is cut sharply, its sides walled by UrbsSite).
## A `stairs` street keeps its slope (the steps follow it). F3: only the streets of the year; one
## street after another, the narrower first, each sampling the ground the earlier ones left and
## blended into it, so where two streets meet or cross they share one surface (before, every
## profile was read from the uncut ground and the strongest won, leaving steps of up to 2 m where
## two met); `end_level`/`start_level` (a platform id or metres) pin a street's end to the floor
## it leads to (the Clivus Capitolinus to the Area Capitolina).
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
	_street_w = PackedFloat32Array()
	_street_w.resize(VERTS * VERTS)
	var entries: Array = []
	for entry: Dictionary in parsed.get("streets", []):
		var from_y: Variant = entry.get("exists_from")
		if from_y == null or int(from_y) <= year:
			entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var wa := float(a.get("width_m", 4.0))
		var wb := float(b.get("width_m", 4.0))
		return wa < wb if wa != wb else str(a["id"]) < str(b["id"]))
	for entry: Dictionary in entries:
		var raw := PackedVector2Array()
		for ll in entry["points"]:
			raw.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
		var pts := UrbsStreets._smooth(raw, 2)
		var hw := float(entry.get("width_m", 4.0)) * 0.5
		var kind := str(entry.get("kind", "street"))
		var shoulder := float(cfg.get("shoulder_m", 2.0))
		var blend := float(cfg.get("blend_m", 9.0))
		if kind == "clivus":
			shoulder = float(cfg.get("clivus_shoulder_m", 1.6))
			blend = 4.0
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		var length := cum[cum.size() - 1]
		if length < step * 2.0:
			continue
		var prof := street_profile(h, pts, cum, kind == "stairs", smooth_m, max_grad, step)
		var ns := prof.size()
		var pin0: Variant = _pin_level(entry.get("start_level"))
		var pin1: Variant = _pin_level(entry.get("end_level"))
		if pin0 != null or pin1 != null:
			var d0 := 0.0 if pin0 == null else float(pin0) - prof[0]
			var d1 := 0.0 if pin1 == null else float(pin1) - prof[ns - 1]
			for i in ns:
				prof[i] += lerpf(d0, d1, float(i) / float(ns - 1))
		var sp := PackedVector2Array()
		for i in ns:
			sp.append(_polyline_at(pts, cum, length * float(i) / float(ns - 1)))
		var reach := hw + shoulder + blend
		var touched := PackedInt32Array()
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
					if wgrid[idx] == 0.0:
						touched.append(idx)
					if w > wgrid[idx]:
						wgrid[idx] = w
						pgrid[idx] = lerpf(prof[i], prof[i + 1], t)
		for idx in touched:
			h[idx] = lerpf(h[idx], pgrid[idx], wgrid[idx])
			_built_w[idx] = maxf(_built_w[idx], wgrid[idx])
			_street_w[idx] = maxf(_street_w[idx], wgrid[idx])
			wgrid[idx] = 0.0


## A pinned street end: a platform id (its floor) or a height in metres; null when not pinned.
static func _pin_level(v: Variant) -> Variant:
	if v == null:
		return null
	if v is float or v is int:
		return float(v)
	for pf: Dictionary in platforms():
		if str(pf["id"]) == str(v):
			var lv: Array = pf.get("level", [10.0])
			return float(lv[0])
	return null


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
	_bake_urban()
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


## The inside of the Servian circuit as a soft 0..1 mask on the map grid (a binary mask blurred
## by shrinking and re-growing it, about 60 m of soft edge).
static func _bake_urban() -> void:
	var img := Image.create(MAP_N, MAP_N, false, Image.FORMAT_L8)
	var poly := circuit()
	for j in MAP_N:
		for i in MAP_N:
			var p := Vector2(-HALF_M + i * MAP_CELL, -HALF_M + j * MAP_CELL)
			img.set_pixel(i, j, Color(1, 1, 1) if poly.size() > 2 and Geometry2D.is_point_in_polygon(p, poly) else Color(0, 0, 0))
	img.resize(MAP_N / 6, MAP_N / 6, Image.INTERPOLATE_BILINEAR)
	img.resize(MAP_N, MAP_N, Image.INTERPOLATE_CUBIC)
	_urban = PackedFloat32Array()
	_urban.resize(MAP_N * MAP_N)
	for j in MAP_N:
		for i in MAP_N:
			_urban[j * MAP_N + i] = clampf(img.get_pixel(i, j).r, 0.0, 1.0)


static func _urban_at(x: float, z: float) -> float:
	if _urban.is_empty():
		return 0.0
	var i := clampi(roundi((x + HALF_M) / MAP_CELL), 0, MAP_N - 1)
	var j := clampi(roundi((z + HALF_M) / MAP_CELL), 0, MAP_N - 1)
	return _urban[j * MAP_N + i]


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


## The ground as a chunk mesh draws it with `step` cells per quad (1: lod 0 within NEAR_M of the
## Forum, 2 beyond it, 5 lod 1, 10 lod 2): each quad split into two triangles along its
## (i+1, j)-(i, j+1) diagonal, as _chunk_mesh does. (F3: the audit compares surfaces with this.)
static func mesh_height_at(x: float, z: float, step := 1) -> float:
	prepare()
	var c := CELL_M * step
	var nq := CELLS / step
	var fx := clampf((x + HALF_M) / c, 0.0, nq - 0.0001)
	var fz := clampf((z + HALF_M) / c, 0.0, nq - 0.0001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var h10 := _mesh_y(_gi(j * step) * VERTS + _gi((i + 1) * step))
	var h01 := _mesh_y(_gi((j + 1) * step) * VERTS + _gi(i * step))
	if u + v <= 1.0:
		var h00 := _mesh_y(_gi(j * step) * VERTS + _gi(i * step))
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	var h11 := _mesh_y(_gi((j + 1) * step) * VERTS + _gi((i + 1) * step))
	return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)


## The height a mesh vertex is drawn at: the field, dipped PAVE_DIP under a paving's edge (F3:
## where a paving covers only part of a quad, the ground slopes down beneath the slab instead of
## meeting it within a few centimetres).
static func _mesh_y(k: int) -> float:
	if not _cover.is_empty() and _cover[k] > 0:
		return _h[k] - (PAVE_DIP if _cover[k] == 2 else PAVE_DIP * 0.2)
	return _h[k]


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
	mi.mesh = chunk_mesh(rect, lod)
	if not bounds().encloses(rect):
		mi.material_override = _ground_material()
		node.add_child(mi)
		var ow := _outer_water(rect)
		if ow != null:
			var wmi := MeshInstance3D.new()
			wmi.name = "Water"
			wmi.mesh = ow
			wmi.material_override = UrbsMaterials.get_material("tiber_water")
			wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(wmi)
		return node   # F3: beyond the heightfield, the ground carried on (no flora, no walls)
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
	if lod <= 1 and not walls_later:
		var walls := UrbsSite.build_chunk_walls(rect, lod, year)
		if walls != null:
			node.add_child(walls)
	UrbsSiteFlora.build_chunk(node, rect, lod, year)
	return node


## The ground mesh alone of the chunk covering `rect` at `lod` (as build_chunk draws it).
static func chunk_mesh(rect: Rect2, lod: int) -> ArrayMesh:
	prepare()
	if not bounds().encloses(rect):
		return _outer_mesh(rect)
	var near := rect.get_center().length() < NEAR_M
	var step := (1 if near else 2) if lod <= 0 else (5 if lod == 1 else 10)
	var i0 := roundi((rect.position.x + HALF_M) / CELL_M)
	var j0 := roundi((rect.position.y + HALF_M) / CELL_M)
	var ci := maxi(roundi(rect.size.x / CELL_M), 1)
	var cj := maxi(roundi(rect.size.y / CELL_M), 1)
	return _chunk_mesh(i0, j0, ci, cj, step)


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


## F3: a chunk's border is always drawn at every cell (5 m), whatever its level of detail, with
## the normals of the finest mesh, so two neighbours of different detail share the very same edge
## (no step and no seam in the light where they meet); a coarser chunk's inner grid is zipped to
## that border. The skirt stays as a guard.
static func _chunk_mesh(i0: int, j0: int, ci: int, cj: int, step: int) -> ArrayMesh:
	var nx := maxi(ci / step, 1)
	var nz := maxi(cj / step, 1)
	var pp := PackedVector3Array()
	var pn := PackedVector3Array()
	var idx := PackedInt32Array()
	var outer: Array[Vector2i] = []   # the border ring, in cells from (i0, j0), corner (0, 0) first
	if step == 1 or nx < 3 or nz < 3:
		var stride := nx + 1
		for dj in nz + 1:
			for di in nx + 1:
				_add_vertex(i0 + di * step, j0 + dj * step, 0.0, step if (di > 0 and dj > 0 and di < nx and dj < nz) else 1, pp, pn)
		for dj in nz:
			for di in nx:
				var a := dj * stride + di
				if not _cover.is_empty() and _covered(i0 + di * step, j0 + dj * step, step):
					continue   # F3: under a paving, which hides the ground
				idx.append_array([a, a + 1, a + stride, a + 1, a + stride + 1, a + stride])
		var ring_idx := []
		for di in nx:
			ring_idx.append(di)
		for dj in nz:
			ring_idx.append(dj * stride + nx)
		for di in range(nx, 0, -1):
			ring_idx.append(nz * stride + di)
		for dj in range(nz, 0, -1):
			ring_idx.append(dj * stride)
		_skirt(ring_idx, pp, pn, idx)
	else:
		# the inner grid, (1..nx-1) x (1..nz-1) coarse vertices
		var stride := nx - 1
		var gi := func(a: int, b: int) -> int: return (b - 1) * stride + (a - 1)
		for b in range(1, nz):
			for a in range(1, nx):
				_add_vertex(i0 + a * step, j0 + b * step, 0.0, step, pp, pn)
		for b in range(1, nz - 1):
			for a in range(1, nx - 1):
				if not _cover.is_empty() and _covered(i0 + a * step, j0 + b * step, step):
					continue
				var k: int = gi.call(a, b)
				idx.append_array([k, k + 1, k + stride, k + 1, k + stride + 1, k + stride])
		# the inner ring and the fine border, each walked the same way round with a parameter
		# 0..4 (one per side), zipped together
		var inner := []
		for a in range(1, nx):
			inner.append([gi.call(a, 1), float(a - 1) / float(nx - 2)])
		for b in range(2, nz):
			inner.append([gi.call(nx - 1, b), 1.0 + float(b - 1) / float(nz - 2)])
		for a in range(nx - 2, 0, -1):
			inner.append([gi.call(a, nz - 1), 2.0 + float(nx - 1 - a) / float(nx - 2)])
		for b in range(nz - 2, 1, -1):
			inner.append([gi.call(1, b), 3.0 + float(nz - 1 - b) / float(nz - 2)])
		var border := []
		var base := pp.size()
		var cells := []
		for i in ci:
			cells.append([Vector2i(i, 0), float(i) / ci])
		for j in cj:
			cells.append([Vector2i(ci, j), 1.0 + float(j) / cj])
		for i in range(ci, 0, -1):
			cells.append([Vector2i(i, cj), 2.0 + float(ci - i) / ci])
		for j in range(cj, 0, -1):
			cells.append([Vector2i(0, j), 3.0 + float(cj - j) / cj])
		for c: Array in cells:
			var v: Vector2i = c[0]
			_add_vertex(i0 + v.x, j0 + v.y, 0.0, 1, pp, pn)
			border.append([base + border.size(), float(c[1])])
		var ii := 0
		var oi := 0
		var ni := inner.size()
		var no := border.size()
		while ii < ni or oi < no:
			var a_in: Array = inner[ii % ni]
			var a_out: Array = border[oi % no]
			var t_in := float(inner[(ii + 1) % ni][1]) + (4.0 if ii + 1 >= ni else 0.0)
			var t_out := float(border[(oi + 1) % no][1]) + (4.0 if oi + 1 >= no else 0.0)
			var c_idx: int
			if oi < no and (ii >= ni or t_out <= t_in):
				c_idx = border[(oi + 1) % no][0]
				oi += 1
			else:
				c_idx = inner[(ii + 1) % ni][0]
				ii += 1
			_tri(int(a_in[0]), int(a_out[0]), c_idx, pp, idx)
		var ring_idx := []
		for o: Array in border:
			ring_idx.append(o[0])
		_skirt(ring_idx, pp, pn, idx)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pp
	arr[Mesh.ARRAY_NORMAL] = pn
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## F3: the ground beyond the heightfield (the loader asks for chunks up to UrbsGeo.RADIUS_M from
## the Forum, the field ends at HALF_M): the field's edge carried on outwards at 25 m cells
## (height_at clamps to the edge), so the far hills and fields never end in a void.
static func _outer_mesh(rect: Rect2) -> ArrayMesh:
	var n := 10
	var c := rect.size.x / n
	var pp := PackedVector3Array()
	var pn := PackedVector3Array()
	for j in n + 1:
		for i in n + 1:
			var x := rect.position.x + i * c
			var z := rect.position.y + j * c
			pp.append(Vector3(x, height_at(x, z), z))
			var dx := height_at(x + c, z) - height_at(x - c, z)
			var dz := height_at(x, z + c) - height_at(x, z - c)
			pn.append(Vector3(-dx, 2.0 * c, -dz).normalized())
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			idx.append_array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pp
	arr[Mesh.ARRAY_NORMAL] = pn
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## F3: the Tiber carried on beyond the heightfield, over the cells of _outer_mesh below its level.
static func _outer_water(rect: Rect2) -> ArrayMesh:
	var n := 10
	var c := rect.size.x / n
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			var q: Array[Vector2] = []
			var wet := false
			for v: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var p := rect.position + (Vector2(i, j) + v) * c
				q.append(p)
				if river_distance(p.x, p.y) < 400.0 and height_at(p.x, p.y) < river_level(p.x, p.y) + 0.05:
					wet = true
			if not wet:
				continue
			var b := verts.size()
			for p: Vector2 in q:
				verts.append(Vector3(p.x, river_level(p.x, p.y), p.y))
			idx.append_array([b, b + 1, b + 3, b + 1, b + 2, b + 3])
	if idx.is_empty():
		return null
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## A ground triangle, wound to face up (as the grid's own: (b - a) x (c - a) points down).
static func _tri(a: int, b: int, c: int, pp: PackedVector3Array, idx: PackedInt32Array) -> void:
	if (pp[b] - pp[a]).cross(pp[c] - pp[a]).y > 0.0:
		idx.append_array([a, c, b])
	else:
		idx.append_array([a, b, c])


## The skirt round a chunk: its border vertices (`ring`, in order) again 4 m lower, double sided.
static func _skirt(ring: Array, pp: PackedVector3Array, pn: PackedVector3Array, idx: PackedInt32Array) -> void:
	var base := pp.size()
	for k: int in ring:
		pp.append(pp[k] - Vector3(0.0, 4.0, 0.0))
		pn.append(pn[k])
	for k in ring.size():
		var t0: int = ring[k]
		var t1: int = ring[(k + 1) % ring.size()]
		var s0 := base + k
		var s1 := base + (k + 1) % ring.size()
		idx.append_array([t0, t1, s0, t1, s1, s0, t0, s0, t1, t1, s0, s1])


## The Tiber's surface over this chunk: a quad at the water level (per vertex, it falls gently
## downstream) over every cell where the ground dips below it. Follows the banks, the island and
## the quays exactly, whatever the river's shape.
## True when the quad at grid (i, j) of `step` cells lies wholly under a paving.
static func _covered(i: int, j: int, step: int) -> bool:
	for c: Vector2i in [Vector2i(0, 0), Vector2i(step, 0), Vector2i(0, step), Vector2i(step, step)]:
		if _cover[_gi(j + c.y) * VERTS + _gi(i + c.x)] < 2:
			return false
	return true


## True where a paving lies on the ground (the ground mesh is not drawn there).
static func covered_at(x: float, z: float) -> bool:
	prepare()
	return not _cover.is_empty() and _cover[_cell(x, z)] == 2


## True where the chunk mesh of `step` draws the ground at (x, z) (it leaves out what pavings cover).
static func ground_drawn_at(x: float, z: float, step := 1) -> bool:
	prepare()
	if _cover.is_empty():
		return true
	var c := CELL_M * step
	var i := clampi(int(floor((x + HALF_M) / c)), 0, CELLS / step - 1) * step
	var j := clampi(int(floor((z + HALF_M) / c)), 0, CELLS / step - 1) * step
	return not _covered(i, j, step)


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
	pp.append(Vector3(-HALF_M + i * CELL_M, _mesh_y(k) - drop, -HALF_M + j * CELL_M))
	pn.append(vertex_normal(i, j, step))


## The normal a chunk mesh of `step` gives its vertex at grid (i, j).
static func vertex_normal(i: int, j: int, step: int) -> Vector3:
	# the normal over the mesh's own spacing (at least two cells): an even shading on the slopes
	var e := maxi(step, 2)
	var hl := _h[_gi(j) * VERTS + _gi(i - e)]
	var hr := _h[_gi(j) * VERTS + _gi(i + e)]
	var hu := _h[_gi(j - e) * VERTS + _gi(i)]
	var hd := _h[_gi(j + e) * VERTS + _gi(i)]
	return Vector3(hl - hr, 2.0 * e * CELL_M, hu - hd).normalized()


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
	# Inside the walls a crowded city: beaten earth and gravel on the gentle ground, worn grass and
	# scrub on the slopes, real green only in the gardens and groves (UrbsSiteFlora) and on the
	# steep untouched faces.
	var urban := _urban_at(x, z)
	var green := UrbsSiteFlora.grove_weight(x, z)
	var worn := urban * (1.0 - green)
	dust = maxf(dust, worn * smoothstep(0.80, 0.94, ny) * 0.7 * (1.0 - mud))
	var grass_c := Color(0.47, 0.47, 0.25).lerp(Color(0.53, 0.50, 0.28), smoothstep(30.0, 60.0, y))
	var meadow_c := Color(0.39, 0.44, 0.22)
	var grass := meadow_c.lerp(grass_c, smoothstep(16.0, 34.0, y))
	grass = grass.lerp(Color(0.50, 0.48, 0.36), worn * 0.85)
	# trodden earth, light and dusty; compacted gravel on the carved platforms, close to travertine
	var dust_c := Color(0.63, 0.59, 0.50).lerp(Color(0.74, 0.71, 0.62), maxf(forum * 0.5, built))
	var tufa := Color(0.60, 0.50, 0.36).lerp(Color(0.42, 0.44, 0.26), 0.35 * urban)
	var c := grass.lerp(tufa, steep)
	c = c.lerp(dust_c, dust * (1.0 - steep))
	c = c.lerp(Color(0.40, 0.34, 0.25), mud)
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


## F3: between sunset and night the ground (dark grass and earth, albedo about 0.1-0.2) fell
## under the tone mapper's toe and drew black while the stone round it stayed grey. The light of
## the twilight sky, which the sky's radiance gives the ground too faintly, is added back as a
## glow in proportion to the ground's own colour: `fill` 0 by day and at full night (UrbsChunks
## sets it from the sun's height).
static func set_sky_fill(fill: float) -> void:
	_sky_fill = fill
	_ground_material().set_shader_parameter("sky_fill", fill)


## The share of sky fill for the sun at `elevation` degrees (see set_sky_fill).
static func sky_fill_for(elevation: float) -> float:
	return SKY_FILL * (1.0 - smoothstep(-1.0, 10.0, elevation)) * smoothstep(-15.0, -6.0, elevation)


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
uniform float sky_fill = 0.0;   // F3: the twilight sky's light on the ground (set_sky_fill)
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
	// mud: darker and wet (F3: not near-black: wet silt is still a mid brown)
	col = mix(col, col * 0.82, wm);
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
	EMISSION = col * sky_fill;
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
	_material.set_shader_parameter("sky_fill", _sky_fill)
	return _material
