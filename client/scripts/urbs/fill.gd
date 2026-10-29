## Urbs (D-289, step U3): the ordinary buildings of Rome between the monuments.
##
## Layout, for a year. Three layers, all deterministic (fixed hashes of lot positions, no random
## state, so a chunk looks the same whenever and in whatever order it is built):
##  1. Street furniture and street-front lots along every known street (streets.yaml): wells or
##     fountains, compitum shrines at crossroads, then a row of tabernae (shop-fronts) where the
##     street is a shopping street, and a continuous row of houses behind or instead of them.
##  2. A lattice of blocks over the whole city: blocks of 3 x 3 plots of 17 m (insulae, casae,
##     workshops; a domus on 2 x 2 plots in the houses of the rich; a garden estate (horti) on a whole
##     block on the outer hills) separated by 6.5 m lanes. The lattice is rotated by an angle that
##     drifts slowly over the city, so the blocks follow no single grid. THE LANES ARE INFERRED
##     minor streets, not data: the known street network leaves gaps of 100-300 m everywhere and
##     real Rome was a dense web of vici and alleys there (Livy 5.55.2-5: crooked, hasty streets).
##     Plots that collide with a street-front lot or a monument are dropped; the gap is then packed
##     with small houses (infill). Where two lattice regions meet and overlap, the region with the
##     lower hash wins.
##  3. The ground between the houses (packed earth, not meadow) as one mesh per chunk.
## Everything that is not a monument, a street, the river or the Servian wall is built over where
## the district says so.
##
## Character (data/rome/city/regions.yaml `districts`, with their sources): domus of the rich on the
## Palatine, Carinae and Quirinal (P-A s.v. Carinae); dense insulae and workshops in the Subura
## (P-A s.v. Subura, Martial, Juvenal), the Velabrum (P-A s.v. Velabrum), the Forum Boarium (Livy
## 21.62.3: an ox on the third storey, 218 BC), the Aventine (Livy 3.31.1) and Transtiberim; horti
## on the Pincian and Esquiline in the late Republic (P-A s.v. Horti); the Campus Martius open
## until 220 BC then built over from the south (P-A s.v. Campus Martius). Storeys: Vitruvius 2.8.17
## (read) on building up; Strabo 5.3.7 (read) on Augustus' 70-foot limit (nothing here exceeds
## five storeys, 16 m). Density = district max_density x (city population / saturates_at) ** 0.7,
## the population from population.json (central estimate, log-interpolated; Pliny NH 3.66 on the
## size of the city, # unverified).
##
## Interface (urbs.gd): build(urbs, year, height) per year; build_chunk(rect, lod, height) ->
## Node3D returns a UrbsFillChunk that fills itself over the next frames (a few ms per frame);
## push_out(p, radius, h) keeps the walking camera out of walls (finished chunks only).
## Tools/tests: `prepare()`, `build_chunk_into(parent, chunk, year, height, footprints, lod)`
## (synchronous), `chunks_in(radius, centre)`, `footprints_from_json(year)`, `count_stats`.
class_name UrbsFill
extends RefCounted

const CHUNK := 250.0
const PITCH := 14.0
const LANE := 5.0
const BP := PITCH * 3.0 + LANE
const REG := 138.0
const REGIONS_PATH := "res://data/city/regions.json"
const POP_PATH := "res://data/city/population.json"
const TOPO_PATH := "res://data/city/topography.json"
const MONUMENTS_PATH := "res://data/city/monuments.json"
const SHOP_DEPTH := 5.0
const FOOTPATH := 1.0
const KERB := 0.3
const TIBER_BAND := 48.0
const MAX_SLOPE := 0.6
const MASK_RES := 3.0
const MASK_HALF := 3300.0
const MASK_N := 2200
const M_STREET := 1
const M_FOOT := 2
const M_WATER := 4
const PALETTE: Array[Color] = [
	Color(0.80, 0.62, 0.40), Color(0.78, 0.50, 0.36), Color(0.84, 0.76, 0.58), Color(0.70, 0.40, 0.30),
	Color(0.62, 0.56, 0.48), Color(0.88, 0.84, 0.74), Color(0.82, 0.68, 0.36), Color(0.66, 0.36, 0.28),
	Color(0.74, 0.58, 0.44), Color(0.58, 0.48, 0.40), Color(0.86, 0.80, 0.66), Color(0.76, 0.56, 0.38),
]

var year := -300
var height: Callable = func(_x: float, _z: float) -> float: return 10.0
var footprints: Array = []           ## Rect2 in local metres: monuments and anything else to avoid
var sync_chunks := false             ## true: build_chunk finishes the chunk before returning
var count_stats := {}
var reject_stats := {}               ## why lattice lots were refused (diagnostics)                ## lot counts of the street layer, for reports

var _streets := UrbsStreets.new()
var _districts: Array = []
var _default: Dictionary = {}
var _default_inside: Dictionary = {}
var _pop_pts: Array = []
var _tiber := PackedVector2Array()
var _wall := PackedVector2Array()
var _circuit := PackedVector2Array()   ## the Servian circuit (regions.yaml servian_circuit): what is 'inside the walls'
var _rural := {}                       ## regions.yaml rural: kind weights
var _loaded := false
var _mask := PackedByteArray()
var _street_lots: Array = []
var _street_hash := {}
var _street_by_chunk := {}
var _lot_grid := {}                  ## 30 m cell -> lattice lots (finished regions), for overlap tests
var _region_cache := {}              ## Vector2i -> candidate array
var _region_state := {}              ## Vector2i -> {cands, idx, lots, done}
var _region_by_chunk := {}           ## Vector2i(chunk) -> Array of lots
var _chunk_cache := {}               ## finished chunks: Vector2i -> Array of lots
var _warm := false


# ---------------------------------------------------------------- set-up

## Per-year set-up (called by urbs.gd after the terrain, streets and monuments).
func build(urbs: Node3D, new_year: int, new_height: Callable) -> void:
	year = new_year
	height = new_height
	footprints = []
	# with --screenshot every chunk is finished before it is returned, so the picture is complete
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--screenshot"):
			sync_chunks = true
	var mon: Variant = urbs.get("monuments") if urbs != null else null
	if mon != null and mon.has_method("ids"):
		for id in mon.ids():
			var b: AABB = mon.bounds(id)
			if minf(b.size.x, b.size.z) < 600.0:     # skip the Servian wall's whole-circuit box
				footprints.append(Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
	prepare()


## Load the data and lay out the street layer for the current `year`, `height`, `footprints`.
func prepare() -> void:
	if not _loaded:
		_load()
	_streets.height = height
	_streets.load_data(year)
	_region_cache = {}
	_region_state = {}
	_region_by_chunk = {}
	_chunk_cache = {}
	_lot_grid = {}
	_stamp_mask()
	_gen_street_lots()
	if not _warm:
		_warm = true
		_warm_meshes()


func _load() -> void:
	_loaded = true
	var reg: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGIONS_PATH))
	if reg is Dictionary:
		for d in reg.get("districts", []):
			_districts.append({
				"id": str(d["id"]), "c": UrbsGeo.to_local(float(d["lat"]), float(d["lon"])),
				"r": float(d["radius_m"]), "max": float(d["max_density"]), "sat": float(d["saturates_at"]),
				"onset": int(d["onset"]), "eras": d["eras"],
			})
		var circ: Variant = reg.get("servian_circuit")
		if circ is Dictionary:
			for ll in circ["polygon"]:
				_circuit.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
		_rural = reg.get("rural", {})
		var di: Dictionary = reg.get("default_inside", {})
		_default_inside = {"id": "default_inside", "c": Vector2.ZERO, "r": 1.0e9, "max": float(di.get("max_density", 0.9)),
			"sat": float(di.get("saturates_at", 150000)), "onset": int(di.get("onset", -378)), "eras": di.get("eras", [])}
		var df: Dictionary = reg.get("default", {})
		_default = {"id": "default", "c": Vector2.ZERO, "r": 1.0e9, "max": float(df.get("max_density", 0.1)),
			"sat": float(df.get("saturates_at", 800000)), "onset": int(df.get("onset", -200)), "eras": df.get("eras", [])}
	var pop: Variant = JSON.parse_string(FileAccess.get_file_as_string(POP_PATH))
	if pop is Dictionary:
		for e in pop.get("city_population", []):
			_pop_pts.append([int(e["year"]), float(e["central"])])
		_pop_pts.sort_custom(func(a, b): return a[0] < b[0])
	var topo: Variant = JSON.parse_string(FileAccess.get_file_as_string(TOPO_PATH))
	if topo is Dictionary:
		for ll in topo["tiber"]["course"]:
			_tiber.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
	var mons: Variant = JSON.parse_string(FileAccess.get_file_as_string(MONUMENTS_PATH))
	if mons is Dictionary:
		for m in mons["monuments"]:
			if str(m["id"]) == "murus_servianus" and m.has("route"):
				for ll in m["route"]:
					_wall.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))


func _warm_meshes() -> void:
	for shape in ["gable", "hip", "stepped"]:
		for st in range(2, 6):
			for feat in 3:
				for pitch in 2:
					for lod in 3:
						UrbsFillMeshes.get_mesh("insula:%s:%d:%d:%d" % [shape, st, feat, pitch], lod)
						if shape != "stepped" and st >= 3:
							UrbsFillMeshes.get_mesh("insula:%s:%d:%d:%d:n" % [shape, st, feat, pitch], lod)
	for lod in 3:
		for k in ["domus", "horti", "casa:tile", "casa:thatch", "casa:shingle", "workshop:0", "workshop:1",
				"tree:cypress", "tree:pine", "tree:round", "prop:cart", "prop:amph", "prop:sacks", "prop:crates",
				"furn:fountain", "furn:well", "furn:shrine"]:
			UrbsFillMeshes.get_mesh(k, lod)
		for v in 6:
			UrbsFillMeshes.get_mesh("taberna:%d" % v, lod)


## Footprints (Rect2) of the monuments standing in `for_year`, read straight from monuments.json
## with rough sizes by type. For tools and previews; the game passes `urbs.monuments` bounds.
static func footprints_from_json(for_year: int) -> Array:
	var out: Array = []
	var radius := {"temple": 22.0, "basilica": 34.0, "forum": 60.0, "portico": 28.0, "theatre": 80.0,
		"circus": 140.0, "curia": 16.0, "comitium": 22.0, "rostra": 12.0, "horrea": 40.0, "market": 40.0,
		"arch": 7.0, "tomb": 10.0, "house": 18.0, "gate": 9.0, "shrine": 8.0, "altar": 6.0, "prison": 12.0,
		"archive": 18.0, "public_building": 25.0, "citadel": 50.0, "platform": 15.0, "monument": 8.0,
		"fountain": 6.0, "amphitheatre": 85.0, "baths": 70.0}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MONUMENTS_PATH))
	if not (parsed is Dictionary):
		return out
	for m in parsed["monuments"]:
		var t := str(m.get("type", ""))
		if not radius.has(t) or not m.has("lat"):
			continue
		var built: Variant = m.get("built")
		if built is Dictionary and built.get("year") != null and int(built["year"]) > for_year:
			continue
		var ended: Variant = m.get("ended")
		if ended is Dictionary and ended.get("year") != null and int(ended["year"]) <= for_year:
			continue
		var p := UrbsGeo.to_local(float(m["lat"]), float(m["lon"]))
		var r: float = radius[t]
		out.append(Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0))
	return out


# ---------------------------------------------------------------- hashing and lookups

static func _hash(a: int, b: int, c: int) -> int:
	var h: int = a * 374761393 + b * 668265263 + c * 2246822519 + 1013904223
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	h = (h ^ (h >> 11)) * 2654435761
	return (h ^ (h >> 15)) & 0x7fffffff


## Deterministic value in [0, 1) from three integers.
static func _r(a: int, b: int, c: int) -> float:
	return float(_hash(a, b, c)) / 2147483648.0


static func _smooth_noise(p: Vector2) -> float:
	var ix := floori(p.x)
	var iz := floori(p.y)
	var fx := p.x - ix
	var fz := p.y - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := lerpf(_r(ix, iz, 61), _r(ix + 1, iz, 61), fx)
	var b := lerpf(_r(ix, iz + 1, 61), _r(ix + 1, iz + 1, 61), fx)
	return lerpf(a, b, fz)


## Inside the walls? From 378 BC the Servian circuit; before that the early town (about 450 m).
func _urban(p: Vector2) -> bool:
	if year >= -378 and not _circuit.is_empty():
		return Geometry2D.is_point_in_polygon(p, _circuit)
	return p.length() < 450.0


## Distance from `p` to the Servian circuit (0 if inside).
func _circuit_dist(p: Vector2) -> float:
	if _circuit.is_empty() or Geometry2D.is_point_in_polygon(p, _circuit):
		return 0.0
	var best := 1.0e9
	for i in _circuit.size():
		var q := Geometry2D.get_closest_point_to_segment(p, _circuit[i], _circuit[(i + 1) % _circuit.size()])
		best = minf(best, p.distance_to(q))
	return best


func _population() -> float:
	if _pop_pts.is_empty():
		return 100000.0
	if year <= _pop_pts[0][0]:
		return _pop_pts[0][1]
	for i in range(1, _pop_pts.size()):
		if year <= _pop_pts[i][0]:
			var a: Array = _pop_pts[i - 1]
			var b: Array = _pop_pts[i]
			var f := float(year - a[0]) / float(b[0] - a[0])
			return exp(lerpf(log(a[1]), log(b[1]), f))
	return _pop_pts[_pop_pts.size() - 1][1]


func _district_at(p: Vector2) -> Dictionary:
	var best := _default
	var best_r := 1.0e18
	for d in _districts:
		if d["r"] < best_r and p.distance_squared_to(d["c"]) < d["r"] * d["r"]:
			best = d
			best_r = d["r"]
	if best == _default and year >= -378 and not _circuit.is_empty() and Geometry2D.is_point_in_polygon(p, _circuit):
		return _default_inside
	return best


func _era(d: Dictionary) -> Dictionary:
	var eras: Array = d["eras"]
	if eras.is_empty():
		return {"w": {}, "shops": 0.0}
	var pick: Dictionary = eras[0]
	for e in eras:
		if int(e["from"]) <= year:
			pick = e
	return {"w": pick["weights"], "shops": float(pick.get("shops", 0.0))}


## Occupancy at a point: the district's own, fading out over its outer 40% so a district's edge dissolves
## into the suburbs instead of ending in a circle.
func _occupancy_at(d: Dictionary, p: Vector2) -> float:
	var occ := _occupancy(d)
	var r: float = d["r"]
	if r > 5000.0 or _urban(p):
		return occ
	var edge := 1.0 - p.distance_to(d["c"]) / r
	return occ * smoothstep(0.0, 0.4, edge) * 0.8 + occ * 0.2 * smoothstep(0.0, 0.1, edge)


func _occupancy(d: Dictionary) -> float:
	if year < int(d["onset"]):
		return 0.0
	var f := pow(clampf(_population() / float(d["sat"]), 0.0, 1.0), 0.7)
	# inside the Servian wall the city is built continuously once it has grown
	return minf(float(d["max"]) * f * 1.12, 0.985)


# ---------------------------------------------------------------- hazard mask

func _mask_idx(p: Vector2) -> int:
	var ix := int((p.x + MASK_HALF) / MASK_RES)
	var iz := int((p.y + MASK_HALF) / MASK_RES)
	if ix < 0 or iz < 0 or ix >= MASK_N or iz >= MASK_N:
		return -1
	return iz * MASK_N + ix


func _mask_disc(c: Vector2, r: float, bit: int) -> void:
	var r2 := r * r
	var x0 := int((c.x - r + MASK_HALF) / MASK_RES)
	var x1 := int((c.x + r + MASK_HALF) / MASK_RES)
	var z0 := int((c.y - r + MASK_HALF) / MASK_RES)
	var z1 := int((c.y + r + MASK_HALF) / MASK_RES)
	for iz in range(maxi(z0, 0), mini(z1, MASK_N - 1) + 1):
		var pz := (float(iz) + 0.5) * MASK_RES - MASK_HALF
		for ix in range(maxi(x0, 0), mini(x1, MASK_N - 1) + 1):
			var px := (float(ix) + 0.5) * MASK_RES - MASK_HALF
			if (px - c.x) * (px - c.x) + (pz - c.y) * (pz - c.y) <= r2:
				_mask[iz * MASK_N + ix] |= bit


func _mask_rect(r: Rect2, bit: int) -> void:
	var x0 := int((r.position.x + MASK_HALF) / MASK_RES)
	var x1 := int((r.end.x + MASK_HALF) / MASK_RES)
	var z0 := int((r.position.y + MASK_HALF) / MASK_RES)
	var z1 := int((r.end.y + MASK_HALF) / MASK_RES)
	for iz in range(maxi(z0, 0), mini(z1, MASK_N - 1) + 1):
		for ix in range(maxi(x0, 0), mini(x1, MASK_N - 1) + 1):
			_mask[iz * MASK_N + ix] |= bit


func _mask_line(pts: PackedVector2Array, step: float, r: float, bit: int) -> void:
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / step))
		for k in range(n + 1):
			_mask_disc(a.lerp(b, float(k) / float(n)), r, bit)


func _stamp_mask() -> void:
	_mask = PackedByteArray()
	_mask.resize(MASK_N * MASK_N)
	_mask_line(_tiber, 12.0, TIBER_BAND, M_WATER)
	for f in footprints:
		_mask_rect((f as Rect2).grow(2.0), M_FOOT)
	if year >= -378:    # the Servian wall (Livy 6.32.1: begun 378 BC)
		_mask_line(_wall, 6.0, 8.0, M_FOOT)
	for st in _streets.streets:
		var pts: PackedVector2Array = st["pts"]
		_mask_line(pts, 2.2, float(st["hw"]) + 0.2, M_STREET)


func _hazard(p: Vector2) -> int:
	var i := _mask_idx(p)
	return 0 if i < 0 else _mask[i]


# ---------------------------------------------------------------- lots

## A lot: {mesh, c, th, sx, sz, hx, hz, y, tint, top, kind}. `th` is the yaw of a local frame whose
## +z points to the front; (hx, hz) are half sizes along local x and z. tint.a is a per-lot random.
func _make_lot(mesh: String, nominal: Vector2, c: Vector2, front: Vector2, w: float, d: float, tint: Color, top: float, kind: String) -> Dictionary:
	return {"mesh": mesh, "c": c, "th": atan2(front.x, front.y), "sx": w / nominal.x, "sz": d / nominal.y,
		"hx": w * 0.5, "hz": d * 0.5, "y": 0.0, "tint": tint, "top": top, "kind": kind}


static func _axes(lot: Dictionary) -> Array:
	var th: float = lot["th"]
	return [Vector2(cos(th), -sin(th)), Vector2(sin(th), cos(th))]


static func _overlap(a: Dictionary, b: Dictionary, margin: float) -> bool:
	var aa := _axes(a)
	var bb := _axes(b)
	var dc: Vector2 = b["c"] - a["c"]
	for ax in [aa[0], aa[1], bb[0], bb[1]]:
		var ra: float = absf(ax.dot(aa[0])) * a["hx"] + absf(ax.dot(aa[1])) * a["hz"]
		var rb: float = absf(ax.dot(bb[0])) * b["hx"] + absf(ax.dot(bb[1])) * b["hz"]
		if absf(dc.dot(ax)) > ra + rb + margin:
			return false
	return true


func _corners(lot: Dictionary) -> Array:
	var ax := _axes(lot)
	var c: Vector2 = lot["c"]
	var x: Vector2 = ax[0] * lot["hx"]
	var z: Vector2 = ax[1] * lot["hz"]
	return [c, c + x + z, c + x - z, c - x + z, c - x - z, c + z, c - z, c + x, c - x]


## Slope test and ground height of a lot; sets lot.y. False if too steep.
func _ground_ok(lot: Dictionary, pts: Array) -> bool:
	var lo := 1.0e9
	var hi := -1.0e9
	var sum := 0.0
	for p in pts:
		var hh: float = height.call(p.x, p.y)
		lo = minf(lo, hh)
		hi = maxf(hi, hh)
		sum += hh
	var span := maxf(lot["hx"], lot["hz"]) * 2.0
	if (hi - lo) / span > MAX_SLOPE:
		return false
	lot["y"] = sum / float(pts.size()) - 0.15
	return true


func _pick_type(era: Dictionary, roll: float) -> String:
	var w: Dictionary = era["w"]
	var total := 0.0
	for k in w:
		total += float(w[k])
	if total <= 0.0:
		return ""
	var acc := 0.0
	var keys := w.keys()
	keys.sort()
	for k in keys:
		acc += float(w[k]) / total
		if roll < acc:
			return str(k)
	return ""


func _storeys(r: float) -> int:
	# insulae are rare and low in the early Republic (Livy 21.62.3: a third storey by 218 BC)
	if year < -250:
		return 2 + int(r * 2.0)
	if year < -150:
		return 3 + int(r * 2.0)
	return 3 + int(r * 2.99) if r < 0.97 else 5


func _roof_kind(r: float) -> String:
	if year < -280:
		return "thatch" if r < 0.55 else "shingle"
	return "tile" if r < 0.8 else "shingle"


## The lot of `type` at `c`, facing `front`, from hash values (a, b, salt). `cell` limits sizes to a
## 17 m lattice plot. Returns {} for types that make no building.
func _lot_of(type: String, c: Vector2, front: Vector2, a: int, b: int, salt: int, cell := false) -> Dictionary:
	var tint := Color(PALETTE[_hash(a, b, salt + 90) % PALETTE.size()], _r(a, b, salt + 91))
	var cap := 13.2 if cell else 99.0
	match type:
		"insula":
			var s := _storeys(_r(a, b, salt + 1))
			var w := minf(10.0 + _r(a, b, salt + 2) * 4.0, cap)
			var d := minf(11.0 + _r(a, b, salt + 3) * 3.8, cap)
			var shape := "gable" if _r(a, b, salt + 4) < 0.5 else ("hip" if _r(a, b, salt + 4) < 0.75 else "stepped")
			var fr := _r(a, b, salt + 6)
			var feat := 0 if fr < 0.55 else (1 if fr < 0.8 else 2)
			var pitch := 1 if _r(a, b, salt + 7) < 0.4 else 0
			var top := 3.7 + 3.1 * float(s - 1) + (3.3 if pitch == 1 else 1.9)
			if _r(a, b, salt + 8) < 0.88 and shape != "stepped" and s >= 3:
				# a narrow-fronted house, 6-7 m wide: the commonest kind of dwelling in the streets
				var wn := 5.6 + _r(a, b, salt + 9) * 1.2
				var lot_n := _make_lot("insula:%s:%d:%d:%d:n" % [shape, s, feat, pitch], Vector2(7, 18), c, front, wn, d, tint, top, "insula")
				lot_n["narrow"] = true
				return lot_n
			return _make_lot("insula:%s:%d:%d:%d" % [shape, s, feat, pitch], Vector2(18, 18), c, front, w, d, tint, top, "insula")
		"casa":
			var w2 := 5.2 + _r(a, b, salt + 2) * 1.4 if cell else 6.5 + _r(a, b, salt + 2) * 3.0
			var d2 := 6.0 + _r(a, b, salt + 3) * 1.5 if cell else 7.5 + _r(a, b, salt + 3) * 3.0
			return _make_lot("casa:" + _roof_kind(_r(a, b, salt + 5)), Vector2(8, 9), c, front, w2, d2, tint, 5.0, "casa")
		"workshop":
			var w3 := minf(11.5 + _r(a, b, salt + 2) * 3.0, cap)
			var d3 := minf(10.5 + _r(a, b, salt + 3) * 2.5, cap)
			return _make_lot("workshop:%d" % int(_r(a, b, salt + 4) * 2.0), Vector2(16, 14), c, front, w3, d3, tint, 8.2, "workshop")
		"domus":
			var w4 := 17.0 + _r(a, b, salt + 2) * 7.0
			var d4 := 28.0 + _r(a, b, salt + 3) * 7.0
			if cell:
				w4 = 18.0 + _r(a, b, salt + 2) * 4.5
				d4 = 21.0 + _r(a, b, salt + 3) * 4.5
			return _make_lot("domus", Vector2(20, 34), c, front, w4, d4, tint, 6.4, "domus")
	return {}


# ---------------------------------------------------------------- street layer

func _gen_street_lots() -> void:
	_street_lots = []
	_street_hash = {}
	_street_by_chunk = {}
	var furniture_n := 0
	# 1. crossroads shrines
	for sh_pos in _crossroads():
		var p: Vector2 = sh_pos[0]
		var front: Vector2 = sh_pos[1]
		if _occupancy(_district_at(p)) < 0.25:
			continue
		var lot := _make_lot("furn:shrine", Vector2(2.2, 2.0), p, front, 2.2, 2.0, Color(1, 1, 1, _r(roundi(p.x), roundi(p.y), 5)), 2.7, "furn")
		_add_street_lot(lot, "", 0.2, true)
		furniture_n += 1
	# 2. wells and fountains along the streets
	for si in _streets.streets.size():
		var st: Dictionary = _streets.streets[si]
		if str(st["kind"]) == "road":
			continue
		var sid := str(st["id"])
		var sh := hash(sid) & 0xfffff
		var s := 25.0 + _r(sh, 1, 3) * 60.0
		var n := 0
		while s < float(st["len"]) - 10.0:
			var sp := _streets.sample_at(si, s)
			var p: Vector2 = sp[0]
			var t: Vector2 = sp[1]
			var d := _district_at(p)
			if _occupancy(d) > 0.3 and p.length() < 3000.0:
				var side := 1.0 if _r(sh, n, 11) < 0.5 else -1.0
				var nn := Vector2(-t.y, t.x) * side
				var fountain := year >= -312 and _r(sh, n, 12) < (0.5 if year < -144 else 0.8)
				var kind := "fountain" if fountain else "well"
				var nominal := Vector2(1.8, 0.8) if fountain else Vector2(1.4, 1.4)
				var depth := nominal.y
				var cp := p + nn * (float(st["hw"]) + KERB + 0.35 + depth * 0.5)
				var lot := _make_lot("furn:" + kind, nominal, cp, -nn, nominal.x, nominal.y, Color(1, 1, 1, _r(sh, n, 13)), 2.1, "furn")
				_add_street_lot(lot, sid, 0.3, true)
				furniture_n += 1
			s += 80.0 + _r(sh, n, 14) * 60.0
			n += 1
	# 2b. tombs along the roads out of the gates (before the houses, so the houses give way)
	furniture_n += _gen_tombs()
	# 3. tabernae and houses along every street
	for si in _streets.streets.size():
		_street_rows(si)
	_bucket_street_lots()
	count_stats = {"furniture": furniture_n}
	for lot in _street_lots:
		var k := str(lot["mesh"]).split(":")[0]
		count_stats[k] = int(count_stats.get(k, 0)) + 1


## Tombs lining the roads outside the walls: altar tombs, columbaria, round mausolea, tumuli, stelae.
## Burial outside the city by law (Twelve Tables 10.1; Cic. Leg. 2.58, read); P-A s.v. Via Appia and Via
## Latina (read): roads flanked with tombs and columbaria. Sparser near the gates, where houses and
## inns line the road instead.
func _gen_tombs() -> int:
	var n := 0
	var sizes := {"altar": Vector3(3, 3, 2.3), "columbarium": Vector3(5, 5, 4.6), "round": Vector3(8, 8, 7.2), "tumulus": Vector3(9, 9, 3.2), "stele": Vector3(1, 0.5, 2.0)}
	for si in _streets.streets.size():
		var st: Dictionary = _streets.streets[si]
		if str(st["kind"]) != "road":
			continue
		var sid := str(st["id"])
		var sh := hash(sid) & 0xfffff
		var s := 0.0
		var item := 0
		while s < float(st["len"]):
			var sp := _streets.sample_at(si, s)
			var p: Vector2 = sp[0]
			var t: Vector2 = sp[1]
			if p.length() > 3200.0 or _urban(p):
				s += 10.0
				continue
			var dist := _circuit_dist(p)
			for side in [1, -1]:
				var prob := 0.3 if dist < 450.0 else 0.72
				if _r(sh, item, side + 71) >= prob:
					continue
				var rk := _r(sh, item, side + 72)
				var kind := "altar" if rk < 0.3 else ("columbarium" if rk < 0.5 else ("round" if rk < 0.62 else ("tumulus" if rk < 0.75 else "stele")))
				var sz: Vector3 = sizes[kind]
				var sc := 0.85 + _r(sh, item, side + 73) * 0.4
				var nn := Vector2(-t.y, t.x) * float(side)
				var cp := p + nn * (float(st["hw"]) + KERB + 2.2 + _r(sh, item, side + 74) * 2.0 + sz.y * sc * 0.5)
				var lot := _make_lot("tomb:" + kind, Vector2(sz.x, sz.y), cp, -nn, sz.x * sc, sz.y * sc, Color(1, 1, 1, _r(sh, item, side + 75)), sz.z, "tomb")
				if _add_street_lot(lot, sid, 0.6):
					n += 1
			s += 15.0 + _r(sh, item, 76) * 22.0
			item += 1
	return n


## Points where two known streets cross: [[position of the shrine, facing], ...].
func _crossroads() -> Array:
	var out: Array = []
	var seen := {}
	var grid: Dictionary = _streets._grid
	var keys := grid.keys()
	keys.sort()
	for key in keys:
		var refs: Array = grid[key]
		for i in refs.size():
			for j in range(i + 1, refs.size()):
				var ra: Array = refs[i]
				var rb: Array = refs[j]
				if ra[0] == rb[0]:
					continue
				var sa: Dictionary = _streets.streets[ra[0]]
				var sb: Dictionary = _streets.streets[rb[0]]
				var a0: Vector2 = sa["pts"][ra[1]]
				var a1: Vector2 = sa["pts"][ra[1] + 1]
				var b0: Vector2 = sb["pts"][rb[1]]
				var b1: Vector2 = sb["pts"][rb[1] + 1]
				var hit: Variant = Geometry2D.segment_intersects_segment(a0, a1, b0, b1)
				if hit == null:
					continue
				var p: Vector2 = hit
				var cell := Vector2i(roundi(p.x / 30.0), roundi(p.y / 30.0))
				if seen.has(cell):
					continue
				seen[cell] = true
				var ta := (a1 - a0).normalized()
				var tb := (b1 - b0).normalized()
				var na := Vector2(-ta.y, ta.x)
				var nb := Vector2(-tb.y, tb.x)
				var corner := p + na * (float(sa["hw"]) + 2.6) + nb * (float(sb["hw"]) + 2.6)
				var face := (p - corner).normalized()
				out.append([corner, face])
	return out


func _shops_at(stretches: Array, s: float) -> bool:
	for e in stretches:
		if s < e[0]:
			return e[1]
	return false


static func _stretch_end(stretches: Array, s: float) -> float:
	for e in stretches:
		if s < e[0]:
			return e[0] + 0.01
	return 1.0e9


## Era mix and occupancy at a point of a street: ribbon development along the roads just outside
## the walls (casae, workshops and inns, thinning with distance), the district's own mix elsewhere.
func _street_context(p: Vector2, road: bool) -> Dictionary:
	if road and not _urban(p):
		var dd := _circuit_dist(p)
		if dd < 800.0:
			var f := pow(clampf(_population() / 150000.0, 0.0, 1.0), 0.5)
			return {"era": {"w": {"casa": 0.55, "workshop": 0.25, "insula": 0.2}, "shops": 0.25}, "occ": 0.65 * (1.0 - dd / 800.0) * f}
		return {"era": {"w": {}, "shops": 0.0}, "occ": 0.0}
	var d := _district_at(p)
	return {"era": _era(d), "occ": _occupancy_at(d, p)}


func _street_rows(si: int) -> void:
	var st: Dictionary = _streets.streets[si]
	var sid := str(st["id"])
	var sh := hash(sid) & 0xfffff
	var length: float = st["len"]
	var hw: float = st["hw"]
	var road := str(st["kind"]) == "road"
	for side in [1, -1]:
		var stretches: Array = []
		var s := 0.0
		var n := 0
		while s < length:
			var p0: Vector2 = _streets.sample_at(si, s)[0]
			var era0: Dictionary = _street_context(p0, road)["era"]
			var e := s + 22.0 + _r(sh, n, side + 5) * 40.0
			stretches.append([e, _r(sh, n, side + 7) < float(era0["shops"])])
			s = e
			n += 1
		# tabernae along the shop stretches
		s = 0.0
		var item := 0
		while s < length:
			if not _shops_at(stretches, s):
				s = _stretch_end(stretches, s)
				continue
			var tw := 3.6 + _r(sh, item, side + 11) * 1.8
			var mid := _streets.sample_at(si, s + tw * 0.5)
			var mp: Vector2 = mid[0]
			var mt: Vector2 = mid[1]
			if mp.length() < 3500.0:
				var mn := Vector2(-mt.y, mt.x) * float(side)
				var occ: float = _street_context(mp, road)["occ"]
				if _r(sh, item, side + 13) < 0.95 and _r(sh, item, side + 15) < clampf(occ * 1.3, 0.0, 1.0):
					var dd := SHOP_DEPTH + _r(sh, item, side + 17) * 0.4
					var pos := mp + mn * (hw + KERB + FOOTPATH + dd * 0.5)
					var variant := int(_r(sh, item, side + 19) * 6.0)
					var tab := _make_lot("taberna:%d" % variant, Vector2(4.6, 5.2), pos, -mn, tw, dd, Color(PALETTE[_hash(sh, item, side + 21) % PALETTE.size()], _r(sh, item, side + 20)), 5.0 if variant != 4 else 7.5, "taberna")
					if _add_street_lot(tab, sid, 0.2):
						_street_prop(mp, mn, hw, sh, item, side)
			s += tw + (2.2 if _r(sh, item, side + 22) < 0.06 else 0.0)
			item += 1
		# houses along the whole street
		s = 0.0
		item = 0
		while s < length:
			var sp := _streets.sample_at(si, s)
			var p: Vector2 = sp[0]
			if p.length() > 3500.0:
				s += 30.0
				continue
			var ctx := _street_context(p, road)
			var era: Dictionary = ctx["era"]
			var type := _pick_type(era, _r(sh, item, side + 25))
			if type == "horti" or type == "field":
				type = ""
			if type == "":
				s += 10.0
				item += 1
				continue
			var probe := _lot_of(type, Vector2.ZERO, Vector2.UP, sh, item, side * 31 + 3)
			if probe.is_empty() or _r(sh, item, side + 27) >= float(ctx["occ"]):
				s += 8.0 + _r(sh, item, side + 28) * 6.0
				item += 1
				continue
			var wide: float = probe["hx"] * 2.0
			var depth: float = probe["hz"] * 2.0
			var mid2 := _streets.sample_at(si, s + wide * 0.5)
			var np: Vector2 = mid2[0]
			var nt: Vector2 = mid2[1]
			var nn := Vector2(-nt.y, nt.x) * float(side)
			var rowdist := hw + KERB + FOOTPATH + (SHOP_DEPTH + 0.5 if _shops_at(stretches, s + wide * 0.5) else 0.0)
			var lot := _lot_of(type, np + nn * (rowdist + depth * 0.5), -nn, sh, item, side * 31 + 3)
			var ok := _add_street_lot(lot, sid, 0.25)
			s += wide + (_r(sh, item, side + 29) * 1.8 + 0.4 if ok else 5.0)
			item += 1


## Heaps, carts and sacks on the footpath in front of a shop.
func _street_prop(mp: Vector2, mn: Vector2, hw: float, sh: int, item: int, side: int) -> void:
	var r := _r(sh, item, side + 41)
	if r > 0.38:
		return
	var kind := "amph" if r < 0.14 else ("sacks" if r < 0.22 else ("cart" if r < 0.27 else "crates"))
	var along := (_r(sh, item, side + 43) - 0.5) * 1.6
	var tan := Vector2(-mn.y, mn.x)
	var pos := mp + mn * (hw + KERB + 0.55) + tan * along
	var th := Vector2(-mn.x, -mn.y)
	var lot := _make_lot("prop:" + kind, Vector2(1, 1), pos, th, 1.0, 1.0, Color(1, 1, 1, _r(sh, item, side + 44)), 1.5, "prop")
	lot["hx"] = 0.4
	lot["hz"] = 0.4
	lot["c"] = pos
	lot["y"] = float(height.call(pos.x, pos.y))
	_street_lots.append(lot)


func _add_street_lot(lot: Dictionary, own: String, margin: float, force_ok := false) -> bool:
	if lot.is_empty():
		return false
	var c: Vector2 = lot["c"]
	if c.length() > 3500.0:
		return false
	var key := Vector2i(floori(c.x / 30.0), floori(c.y / 30.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k2 := key + Vector2i(dx, dz)
			if _street_hash.has(k2):
				for idx in _street_hash[k2]:
					var other: Dictionary = _street_lots[idx]
					if c.distance_to(other["c"]) < 60.0 and _overlap(lot, other, margin):
						return false
	var pts := _corners(lot)
	for p in pts:
		if _hazard(p) & (M_FOOT | M_WATER):
			return false
	if not force_ok or str(lot["kind"]) != "furn":
		var near := _streets.nearest_street(c)
		if not near.is_empty() and near["distance"] < maxf(lot["hx"], lot["hz"]) * 1.42 + 14.0:
			for p in pts:
				var ns := _streets.nearest_street(p)
				if ns.is_empty():
					continue
				var lim := float(ns["half_width"]) + (0.15 if str(ns["id"]) == own else 0.7)
				if ns["distance"] < lim:
					return false
	if not _ground_ok(lot, pts):
		return false
	_street_hash[key] = _street_hash.get(key, [])
	_street_hash[key].append(_street_lots.size())
	_street_lots.append(lot)
	return true


func _bucket_street_lots() -> void:
	for lot in _street_lots:
		var key := Vector2i(floori(lot["c"].x / CHUNK), floori(lot["c"].y / CHUNK))
		if not _street_by_chunk.has(key):
			_street_by_chunk[key] = []
		_street_by_chunk[key].append(lot)


func _overlaps_street_lots(lot: Dictionary, margin: float) -> bool:
	var c: Vector2 = lot["c"]
	var key := Vector2i(floori(c.x / 30.0), floori(c.y / 30.0))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var k2 := key + Vector2i(dx, dz)
			if _street_hash.has(k2):
				for idx in _street_hash[k2]:
					var other: Dictionary = _street_lots[idx]
					if c.distance_to(other["c"]) < 70.0 and _overlap(lot, other, margin):
						return true
	return false


# ---------------------------------------------------------------- the lattice

func _region_angle(gi: int, gj: int) -> float:
	var c := Vector2((float(gi) + 0.5) * REG, (float(gj) + 0.5) * REG)
	var f := _smooth_noise(c / 650.0)
	return deg_to_rad(roundf((f * 2.0 - 1.0) * 36.0 / 6.0) * 6.0)


## Candidate lots of region (gi, gj): the lattice plots, before any acceptance test. The lattice is
## the same global one (rotated about the origin by the region's angle) for every region, so
## neighbours with the same angle fit exactly and never collide.
func _region_cands(gi: int, gj: int) -> Array:
	var rk := Vector2i(gi, gj)
	if _region_cache.has(rk):
		return _region_cache[rk]
	var out: Array = []
	var th := _region_angle(gi, gj)
	var rc := Vector2((float(gi) + 0.5) * REG, (float(gj) + 0.5) * REG)
	var ax := Vector2(cos(th), sin(th))
	var az := Vector2(-sin(th), cos(th))
	var sq := Rect2(float(gi) * REG, float(gj) * REG, REG, REG)
	var half := REG * 0.71 + PITCH
	var ru := rc.dot(ax)
	var rv := rc.dot(az)
	var ba0 := floori((ru - half) / BP) - 1
	var ba1 := floori((ru + half) / BP) + 1
	var bb0 := floori((rv - half) / BP) - 1
	var bb1 := floori((rv + half) / BP) + 1
	for bb in range(bb0, bb1 + 1):
		for l in 3:
			var v := float(bb) * BP + float(l) * PITCH + PITCH * 0.5
			for ba in range(ba0, ba1 + 1):
				for k in 3:
					var u := float(ba) * BP + float(k) * PITCH + PITCH * 0.5
					var c := ax * u + az * v
					if not sq.has_point(c):
						continue
					out.append({"c": c, "a": ba * 3 + k, "b": bb * 3 + l, "ba": ba, "bb": bb, "k": k, "l": l, "ax": ax, "az": az, "gi": gi, "gj": gj,
						"bc": ax * (float(ba) * BP + PITCH * 1.5) + az * (float(bb) * BP + PITCH * 1.5)})
	_region_cache[rk] = out
	return out


## Plan of one block: "horti", "domus" or "" (plots decided one by one).
func _block_plan(gi: int, gj: int, ba: int, bb: int, bc: Vector2) -> String:
	var d := _district_at(bc)
	var era := _era(d)
	var w: Dictionary = era["w"]
	var total := 0.0
	for key in w:
		total += float(w[key])
	if total <= 0.0:
		return ""
	var occ := _occupancy_at(d, bc)
	var r := _r(gi * 97 + ba, gj * 89 + bb, 11)
	if w.has("horti") and r < float(w["horti"]) / total and _r(gi * 97 + ba, gj * 89 + bb, 12) < occ * 1.3:
		return "horti"
	var r2 := _r(gi * 97 + ba, gj * 89 + bb, 13)
	if w.has("domus") and r2 < float(w["domus"]) / total and _r(gi * 97 + ba, gj * 89 + bb, 14) < occ:
		return "domus"
	return ""


func _cell_lots(cd: Dictionary, sub_only := false) -> Array:
	var gi: int = cd["gi"]
	var gj: int = cd["gj"]
	var a: int = cd["a"]
	var b: int = cd["b"]
	var k: int = cd["k"]
	var l: int = cd["l"]
	var ba: int = cd["ba"]
	var bb: int = cd["bb"]
	var c: Vector2 = cd["c"]
	var ax: Vector2 = cd["ax"]
	var az: Vector2 = cd["az"]
	var seed_a := gi * 131 + a
	var seed_b := gj * 137 + b
	var plan := _block_plan(gi, gj, ba, bb, cd["bc"])
	var d := _district_at(c)
	var era := _era(d)
	var occ := _occupancy_at(d, c)
	var out: Array = []
	if str(d["id"]) == "default":
		return out        # open country: farmland parcels and farm steadings only (rural_step)
	var jit := deg_to_rad((_r(seed_a, seed_b, 3) - 0.5) * 6.0)
	if plan == "horti":
		if k != 1 or l != 1:
			return out
		var s := 43.0
		var front := ax * cos(jit) + az * sin(jit)
		front = (-az if _r(seed_a, seed_b, 4) < 0.5 else az)
		out.append(_make_lot("horti", Vector2(70, 70), cd["bc"], front, s, s, Color(1, 1, 1, _r(seed_a, seed_b, 5)), 8.0, "horti"))
		return out
	if plan == "domus" and k < 2 and l < 2:
		if k != 0 or l != 0:
			return out
		var cc: Vector2 = c + ax * PITCH * 0.5 + az * PITCH * 0.5
		var fr := -az if _r(seed_a, seed_b, 4) < 0.5 else -ax
		var lot := _lot_of("domus", cc, fr, seed_a, seed_b, 300, true)
		out.append(lot)
		return out
	# front: toward the nearest lane of the block
	var opts: Array = []
	if k == 0: opts.append(-ax)
	if k == 2: opts.append(ax)
	if l == 0: opts.append(-az)
	if l == 2: opts.append(az)
	if opts.is_empty():
		opts = [ax, -ax, az, -az]
	var fdir: Vector2 = opts[int(_r(seed_a, seed_b, 6) * float(opts.size()))]
	var front2 := fdir.rotated(jit)
	var w_all: Dictionary = era["w"]
	var total := 0.0
	for key in w_all:
		total += float(w_all[key])
	if total <= 0.0:
		return out
	var type := _pick_type(era, _r(seed_a, seed_b, 7))
	if type == "domus":
		type = "insula"
	if type == "horti" or type == "field" or type == "":
		return out
	if _r(seed_a, seed_b, 8) >= occ and not sub_only:
		return out
	if type == "casa":
		# four small houses to a plot, each its own lot
		for q in 4:
			var qo := Vector2(float(q % 2) - 0.5, float(q / 2) - 0.5) * (PITCH * 0.5)
			var qc := c + ax * qo.x + az * qo.y
			qc += Vector2(_r(seed_a, seed_b, 20 + q) - 0.5, _r(seed_a, seed_b, 30 + q) - 0.5) * 2.4
			if _r(seed_a, seed_b, 40 + q) > 0.42:
				continue
			var fq := (fdir if q % 2 == 0 else -fdir).rotated(deg_to_rad((_r(seed_a, seed_b, 50 + q) - 0.5) * 28.0))
			var lot := _lot_of("casa", qc, fq, seed_a * 5 + q, seed_b, 400, true)
			out.append(lot)
		return out
	var cj := c + Vector2(_r(seed_a, seed_b, 9) - 0.5, _r(seed_a, seed_b, 10) - 0.5) * 1.4
	var main := _lot_of(type, cj, front2, seed_a, seed_b, 500, true)
	if main.get("narrow", false):
		# two narrow houses side by side on one plot
		var along := Vector2(front2.y, -front2.x)
		var wn: float = main["hx"] * 2.0
		var second := main.duplicate()
		main["c"] = cj + along * (wn * 0.5 + 0.2)
		second["c"] = cj - along * (wn * 0.5 + 0.2)
		var salt2 := _lot_of(type, cj, front2, seed_a + 1, seed_b, 500, true)
		second["tint"] = salt2["tint"]
		out.append(second)
	out.append(main)
	return out


## Priority of a region when two lattices overlap (lower wins).
func _rprio(gi: int, gj: int) -> int:
	return _hash(gi, gj, 77)


## Work on region `rk` until `deadline` (usec ticks). True when done.
func advance_region(rk: Vector2i, deadline: int) -> bool:
	if not _region_state.has(rk):
		_region_state[rk] = {"cands": _region_cands(rk.x, rk.y), "idx": 0, "lots": [], "done": false}
	var st: Dictionary = _region_state[rk]
	if st["done"]:
		return true
	var cands: Array = st["cands"]
	var neigh: Array = []
	while st["idx"] < cands.size():
		var cd: Dictionary = cands[st["idx"]]
		st["idx"] += 1
		for lot in _cell_lots(cd):
			if lot.is_empty():
				continue
			var verdict := _lattice_verdict(lot, rk, neigh)
			if verdict == 0:
				st["lots"].append(lot)
			elif verdict == 2 and str(lot["kind"]) != "casa" and str(lot["kind"]) != "horti" and str(lot["kind"]) != "domus":
				# plot blocked by a street-front lot: pack the gap with small houses instead
				var ax: Vector2 = cd["ax"]
				var az: Vector2 = cd["az"]
				for q in 4:
					var qo := Vector2(float(q % 2) - 0.5, float(q / 2) - 0.5) * (PITCH * 0.5)
					var qc: Vector2 = cd["c"] + ax * qo.x + az * qo.y
					var sa: int = cd["gi"] * 131 + cd["a"]
					var sb: int = cd["gj"] * 137 + cd["b"]
					var small := _lot_of("casa", qc, (ax if q % 2 == 0 else -az), sa * 5 + q, sb, 600, true)
					small["sx"] *= 0.8
					small["sz"] *= 0.8
					small["hx"] *= 0.8
					small["hz"] *= 0.8
					if _lattice_verdict(small, rk, neigh) == 0:
						st["lots"].append(small)
		if Time.get_ticks_usec() > deadline:
			return false
	st["done"] = true
	for lot in st["lots"]:
		var gk := Vector2i(floori(lot["c"].x / 30.0), floori(lot["c"].y / 30.0))
		_lot_grid[gk] = _lot_grid.get(gk, [])
		_lot_grid[gk].append(lot)
		var key := Vector2i(floori(lot["c"].x / CHUNK), floori(lot["c"].y / CHUNK))
		if not _region_by_chunk.has(key):
			_region_by_chunk[key] = []
		_region_by_chunk[key].append(lot)
	return true


## 0 accepted, 1 hazard (water, monument, street, steep), 2 blocked by another lot.
func _lattice_verdict(lot: Dictionary, rk: Vector2i, neigh: Array) -> int:
	var pts := _corners(lot)
	for p in pts:
		var hz := _hazard(p)
		if hz != 0:
			var rk2 := "hazard_%d" % hz
			reject_stats[rk2] = int(reject_stats.get(rk2, 0)) + 1
			return 1
	if not _ground_ok(lot, pts):
		reject_stats["slope"] = int(reject_stats.get("slope", 0)) + 1
		return 1
	if _overlaps_street_lots(lot, 0.6):
		reject_stats["street_lot"] = int(reject_stats.get("street_lot", 0)) + 1
		return 2
	# region borders: lower-priority region yields to the other region's candidates
	var c: Vector2 = lot["c"]
	var sq := Rect2(float(rk.x) * REG, float(rk.y) * REG, REG, REG)
	var edge := minf(minf(c.x - sq.position.x, sq.end.x - c.x), minf(c.y - sq.position.y, sq.end.y - c.y))
	if edge < 24.0:
		var my := _rprio(rk.x, rk.y)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nk := Vector2i(rk.x + dx, rk.y + dz)
				if _rprio(nk.x, nk.y) >= my:
					continue
				for cd in _region_cands(nk.x, nk.y):
					if c.distance_to(cd["c"]) > 40.0:
						continue
					for other in _cell_lots(cd):
						if not other.is_empty() and c.distance_to(other["c"]) < 45.0 and _overlap(lot, other, 0.4):
							reject_stats["region_border"] = int(reject_stats.get("region_border", 0)) + 1
							return 2
	return 0


# ---------------------------------------------------------------- chunks

## Region keys that supply the lots of chunk `key`.
func regions_for_chunk(key: Vector2i) -> Array:
	var x0 := float(key.x) * CHUNK - 30.0
	var x1 := float(key.x + 1) * CHUNK + 30.0
	var z0 := float(key.y) * CHUNK - 30.0
	var z1 := float(key.y + 1) * CHUNK + 30.0
	var out: Array = []
	for gj in range(floori(z0 / REG), floori(z1 / REG) + 1):
		for gi in range(floori(x0 / REG), floori(x1 / REG) + 1):
			out.append(Vector2i(gi, gj))
	return out


func lots_for_chunk(key: Vector2i) -> Array:
	var out: Array = []
	out.append_array(_street_by_chunk.get(key, []))
	out.append_array(_region_by_chunk.get(key, []))
	return out


func chunk_finished(key: Vector2i, lots: Array) -> void:
	_chunk_cache[key] = lots


## Chunk coordinates whose centre lies within `radius` metres of `centre` (default: the Forum).
func chunks_in(radius: float, centre := Vector2.ZERO) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var reach := int(ceil(radius / CHUNK)) + 1
	var base := Vector2i(floori(centre.x / CHUNK), floori(centre.y / CHUNK))
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var key := base + Vector2i(dx, dz)
			var mid := (Vector2(key) + Vector2(0.5, 0.5)) * CHUNK
			if mid.distance_to(centre) <= radius + CHUNK * 0.5:
				out.append(key)
	return out


## The houses of one 250 m chunk (urbs.gd interface): a node that fills itself over the next frames.
func build_chunk(rect: Rect2, lod: int, _new_height: Callable) -> Node3D:
	var key := Vector2i(roundi(rect.position.x / CHUNK), roundi(rect.position.y / CHUNK))
	return _chunk_job(key, lod)


func _chunk_job(key: Vector2i, lod: int) -> UrbsFillChunk:
	var job := UrbsFillChunk.new()
	job.name = "Fill_%d_%d" % [key.x, key.y]
	job.fill = self
	job.key = key
	job.lod = lod
	if sync_chunks:
		job.finish_now()
	return job


## Tool/test form: build chunk `chunk` for `for_year` under `parent`, synchronously.
func build_chunk_into(parent: Node3D, chunk: Vector2i, for_year: int, new_height: Callable, new_footprints: Array, lod := 0) -> Node3D:
	if for_year != year or not _loaded or new_footprints != footprints:
		year = for_year
		height = new_height
		footprints = new_footprints
		prepare()
	var job := _chunk_job(chunk, lod)
	job.finish_now()
	parent.add_child(job)
	return job


## One MultiMeshInstance3D for `list` of lots sharing the mesh `mesh_key`.
func make_instances(list: Array, mesh_key: String, lod: int) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = UrbsFillMeshes.get_mesh(mesh_key, lod)
	multi.instance_count = list.size()
	for n in list.size():
		var lot: Dictionary = list[n]
		var basis := Basis(Vector3.UP, float(lot["th"])) * Basis.from_scale(Vector3(lot["sx"], lot.get("sy", 1.0), lot["sz"]))
		multi.set_instance_transform(n, Transform3D(basis, Vector3(lot["c"].x, lot["y"], lot["c"].y)))
		multi.set_instance_custom_data(n, lot["tint"])
	var inst := MultiMeshInstance3D.new()
	inst.name = mesh_key.replace(":", "_")
	inst.multimesh = multi
	inst.material_override = UrbsFillMeshes.material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod < 2 and not mesh_key.begins_with("prop") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


func add_trees(lot: Dictionary, buckets: Dictionary, lod: int) -> void:
	var c: Vector2 = lot["c"]
	var a := roundi(c.x)
	var b := roundi(c.y)
	var ax := _axes(lot)
	var n := 22 if lod < 2 else 8
	for k in n:
		var lx: float = (_r(a, b, 500 + k) - 0.5) * lot["hx"] * 1.8
		var lz: float = (_r(a, b, 600 + k) - 0.5) * lot["hz"] * 1.8
		var ux: float = lx / float(lot["sx"])
		var uz: float = lz / float(lot["sz"])
		if absf(ux) < 16.0 and uz > -10.0 and uz < 11.0:
			continue
		if absf(ux) < 3.0 and uz > 0.0:
			continue
		var p: Vector2 = c + ax[0] * lx + ax[1] * lz
		var rk := _r(a, b, 700 + k)
		var tk := "tree:" + ("cypress" if rk < 0.45 else ("pine" if rk < 0.7 else "round"))
		if not buckets.has(tk):
			buckets[tk] = []
		var sc := 0.8 + _r(a, b, 800 + k) * 0.7
		var y: float = height.call(p.x, p.y)
		buckets[tk].append({"c": p, "th": _r(a, b, 900 + k) * TAU, "sx": sc, "sz": sc, "sy": sc, "y": y - 0.1, "tint": Color(1, 1, 1, _r(a, b, 950 + k)), "kind": "tree", "hx": 0, "hz": 0})


func _circuit_bounds() -> Rect2:
	if _circuit.is_empty():
		return Rect2()
	var r := Rect2(_circuit[0], Vector2.ZERO)
	for p in _circuit:
		r = r.expand(p)
	return r


# ---------------------------------------------------------------- farmland outside the walls

const PARCEL := 44.0
const FIELD_TINTS: Array[Color] = [Color(0.45, 0.32, 0.21), Color(0.42, 0.56, 0.24), Color(0.72, 0.62, 0.34), Color(0.50, 0.44, 0.28), Color(0.36, 0.50, 0.22)]


func _pick_rural(w: Dictionary, roll: float) -> String:
	var keys := w.keys()
	keys.sort()
	var total := 0.0
	for k in keys:
		total += float(w[k])
	var acc := 0.0
	for k in keys:
		acc += float(w[k]) / maxf(total, 0.001)
		if roll < acc:
			return str(k)
	return str(keys[keys.size() - 1]) if not keys.is_empty() else ""


## Overlap of a candidate with any finished lot or street-front lot near it.
func _hits_lots(cand: Dictionary, margin: float) -> bool:
	var c: Vector2 = cand["c"]
	var reach := maxf(cand["hx"], cand["hz"]) * 1.42 + 20.0
	var cells := int(ceil(reach / 30.0))
	var key := Vector2i(floori(c.x / 30.0), floori(c.y / 30.0))
	for dz in range(-cells, cells + 1):
		for dx in range(-cells, cells + 1):
			var k2 := key + Vector2i(dx, dz)
			if _street_hash.has(k2):
				for idx in _street_hash[k2]:
					var o: Dictionary = _street_lots[idx]
					var ok := str(o["kind"])
					if ok != "prop" and ok != "tomb" and ok != "furn" and c.distance_to(o["c"]) < reach + 10.0 and _overlap(cand, o, margin):
						return true
			if _lot_grid.has(k2):
				for o in _lot_grid[k2]:
					if c.distance_to(o["c"]) < reach + 10.0 and _overlap(cand, o, margin):
						return true
	return false


## Farm parcels of chunk `key` outside the walls, incrementally. True when done; st["parcels"] holds them.
func rural_step(key: Vector2i, st: Dictionary, deadline: int) -> bool:
	if not st.has("cells"):
		var cells: Array = []
		var x0 := float(key.x) * CHUNK
		var z0 := float(key.y) * CHUNK
		for j in range(floori(z0 / PARCEL) - 1, floori((z0 + CHUNK) / PARCEL) + 2):
			for i in range(floori(x0 / PARCEL) - 1, floori((x0 + CHUNK) / PARCEL) + 2):
				var c := Vector2((float(i) + 0.5) * PARCEL, (float(j) + 0.5) * PARCEL) + Vector2(_r(i, j, 81) - 0.5, _r(i, j, 82) - 0.5) * 6.0
				if c.x >= x0 and c.x < x0 + CHUNK and c.y >= z0 and c.y < z0 + CHUNK:
					cells.append([i, j, c])
		st["cells"] = cells
		st["idx"] = 0
		st["parcels"] = []
	var cells2: Array = st["cells"]
	while st["idx"] < cells2.size():
		var cd: Array = cells2[st["idx"]]
		st["idx"] += 1
		var p := _parcel_at(cd[0], cd[1], cd[2])
		if not p.is_empty():
			st["parcels"].append(p)
		if Time.get_ticks_usec() > deadline:
			return false
	return true


func _parcel_at(i: int, j: int, c: Vector2) -> Dictionary:
	if c.length() > 3250.0 or _urban(c):
		return {}
	var d := _district_at(c)
	var w: Dictionary
	if str(d["id"]).begins_with("campus_"):
		w = _rural.get("campus", {})
	elif _circuit_dist(c) < 500.0:
		w = _rural.get("near_city", {})
	else:
		w = _rural.get("default", {})
	var kind := _pick_rural(w, _r(i, j, 83))
	if kind == "":
		return {}
	var size := 40.0 + _r(i, j, 84) * 2.5
	var th := float(int(_r(i, j, 85) * 4.0)) * PI * 0.5 + (_r(i, j, 86) - 0.5) * 0.4
	var front := Vector2(sin(th), cos(th))
	var tint := Color(1, 1, 1, _r(i, j, 87))
	if kind == "field" or kind == "farm":
		tint = Color(FIELD_TINTS[int(_r(i, j, 88) * float(FIELD_TINTS.size()))], _r(i, j, 87))
	elif kind == "vineyard":
		tint = Color(0.40, 0.32, 0.22, _r(i, j, 87))
	elif kind == "garden":
		tint = Color(0.34, 0.42, 0.20, _r(i, j, 87))
	else:
		tint = Color(0.42, 0.52, 0.26, _r(i, j, 87))
	var cand := {"c": c, "th": th, "hx": size * 0.5, "hz": size * 0.5, "kind": "rural", "sub": kind, "tint": tint, "y": 0.0, "mesh": "rural", "top": 0.0}
	var pts := _corners(cand)
	for pt in pts:
		if _hazard(pt) & (M_FOOT | M_WATER) != 0:
			return {}
	var lo := 1.0e9
	var hi := -1.0e9
	for pt in pts:
		var hh: float = height.call(pt.x, pt.y)
		lo = minf(lo, hh)
		hi = maxf(hi, hh)
	if (hi - lo) / size > 0.3:
		return {}
	if _hits_lots(cand, 1.2):
		return {}
	var ax := _axes(cand)
	cand["ax"] = ax
	cand["front"] = front
	return cand


## Ground of the parcels (one mesh following the terrain) and what stands on them (trees, vine rows,
## beds, farm steadings), added to `node`.
func rural_build(node: Node3D, parcels: Array, lod: int) -> void:
	if parcels.is_empty():
		return
	var gn := 4 if lod == 0 else 2
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var buckets := {}
	for p in parcels:
		var ax: Array = p["ax"]
		var kind: String = p["sub"]
		var is_sown := kind == "field" or kind == "vineyard" or kind == "garden" or kind == "farm"
		var cid := 1.0 if is_sown else 0.5
		var tint: Color = p["tint"]
		var base := verts.size()
		for b in range(gn + 1):
			for a in range(gn + 1):
				var u: float = (float(a) / float(gn) - 0.5) * float(p["hx"]) * 2.0
				var v: float = (float(b) / float(gn) - 0.5) * float(p["hz"]) * 2.0
				var wp: Vector2 = p["c"] + ax[0] * u + ax[1] * v
				verts.append(Vector3(wp.x, float(height.call(wp.x, wp.y)) + 0.1, wp.y))
				norms.append(Vector3.UP)
				cols.append(Color(tint.r, tint.g, tint.b, cid))
				uvs.append(Vector2(u, v))
		for b in range(gn):
			for a in range(gn):
				var q := base + b * (gn + 1) + a
				idx.append_array([q, q + 1, q + gn + 1, q + 1, q + gn + 2, q + gn + 1])
		if lod >= 2:
			continue
		var c: Vector2 = p["c"]
		var ci := roundi(c.x)
		var cj := roundi(c.y)
		var gy: float = float(height.call(c.x, c.y))
		var sx: float = float(p["hx"]) * 2.0 / 44.0
		match kind:
			"orchard", "pasture", "meadow":
				var n := (4 if kind == "orchard" else 2) if lod == 0 else 2
				for a in range(n):
					for b in range(n):
						if kind != "orchard" and _r(ci, cj, 120 + a * 5 + b) > 0.5:
							continue
						var u: float = ((float(a) + 0.5) / float(n) - 0.5) * float(p["hx"]) * 1.7 + (_r(ci, cj, 130 + a) - 0.5) * 3.0
						var v: float = ((float(b) + 0.5) / float(n) - 0.5) * float(p["hz"]) * 1.7 + (_r(ci, cj, 140 + b) - 0.5) * 3.0
						var wp2: Vector2 = c + ax[0] * u + ax[1] * v
						var tk := "tree:fruit" if kind == "orchard" else ("tree:pine" if _r(ci, cj, 150 + a + b) < 0.4 else "tree:round")
						if not buckets.has(tk):
							buckets[tk] = []
						var sc := (0.9 + _r(ci, cj, 160 + a * 3 + b) * 0.5) * (1.0 if kind == "orchard" else 1.1)
						buckets[tk].append({"c": wp2, "th": _r(ci, cj, 170 + a + b) * TAU, "sx": sc, "sz": sc, "sy": sc, "y": float(height.call(wp2.x, wp2.y)) - 0.1, "tint": Color(1, 1, 1, _r(ci, cj, 180 + a + b))})
			"vineyard", "garden", "farm":
				var mk := "rural:vines" if kind == "vineyard" else ("rural:beds" if kind == "garden" else "rural:farm")
				if not buckets.has(mk):
					buckets[mk] = []
				buckets[mk].append({"c": c, "th": p["th"], "sx": sx, "sz": sx, "y": gy, "tint": Color(1, 1, 1, _r(ci, cj, 190))})
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Farmland"
	mi.mesh = mesh
	mi.material_override = UrbsFillMeshes.farm_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	var keys := buckets.keys()
	keys.sort()
	for mk2 in keys:
		node.add_child(make_instances(buckets[mk2], mk2, lod))


## Ground between the houses: packed earth over every 8 m cell near a lot. Incremental; True when done.
func floor_step(node: Node3D, key: Vector2i, lots: Array, lod: int, st: Dictionary, deadline: int) -> bool:
	var n := 32 if lod == 0 else 16
	var cell := CHUNK / float(n)
	var x0 := float(key.x) * CHUNK
	var z0 := float(key.y) * CHUNK
	if not st.has("mark"):
		var mark := PackedByteArray()
		mark.resize(n * n)
		var cnt := PackedByteArray()
		cnt.resize(n * n)
		for lot in lots:
			var kind := str(lot["kind"])
			if kind == "prop" or kind == "tree" or kind == "tomb" or kind == "furn":
				continue
			var r := maxf(lot["hx"], lot["hz"]) * 1.42 + 5.0
			var c: Vector2 = lot["c"]
			var ia := maxi(int((c.x - r - x0) / cell), 0)
			var ib := mini(int((c.x + r - x0) / cell), n - 1)
			var ja := maxi(int((c.y - r - z0) / cell), 0)
			var jb := mini(int((c.y + r - z0) / cell), n - 1)
			for j in range(ja, jb + 1):
				for i in range(ia, ib + 1):
					cnt[j * n + i] = mini(int(cnt[j * n + i]) + 1, 250)
		# outside the walls only where houses stand close together (a pad under a lone house looks
		# wrong); inside, any cell near a house, and below every cell of the circuit
		var circ_box := _circuit_bounds()
		var near_circ := circ_box.grow(60.0).intersects(Rect2(x0, z0, CHUNK, CHUNK))
		for j in range(n):
			for i in range(n):
				var k := j * n + i
				if cnt[k] == 0:
					continue
				var cp := Vector2(x0 + (float(i) + 0.5) * cell, z0 + (float(j) + 0.5) * cell)
				if cnt[k] >= 3 or (near_circ and _urban(cp)):
					mark[k] = 1
		if year >= -378 and not _circuit.is_empty() and near_circ:
			for j in range(n):
				for i in range(n):
					if mark[j * n + i] == 0:
						var cp2 := Vector2(x0 + (float(i) + 0.5) * cell, z0 + (float(j) + 0.5) * cell)
						if Geometry2D.is_point_in_polygon(cp2, _circuit) and (_hazard(cp2) & M_WATER) == 0:
							mark[j * n + i] = 1
		st["mark"] = mark
		st["row"] = 0
		st["h"] = PackedFloat32Array()
		st["h"].resize((n + 1) * (n + 1))
		var any := false
		for m in mark:
			if m != 0:
				any = true
				break
		st["any"] = any
		if not any:
			return true
	while st["row"] <= n:
		var j: int = st["row"]
		for i in range(n + 1):
			st["h"][j * (n + 1) + i] = float(height.call(x0 + float(i) * cell, z0 + float(j) * cell)) + 0.09
		st["row"] += 1
		if Time.get_ticks_usec() > deadline and st["row"] <= n:
			return false
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	for j in range(n + 1):
		for i in range(n + 1):
			verts.append(Vector3(x0 + float(i) * cell, st["h"][j * (n + 1) + i], z0 + float(j) * cell))
			normals.append(Vector3.UP)
			cols.append(UrbsFillMeshes.EARTH)
	var idx := PackedInt32Array()
	var mk: PackedByteArray = st["mark"]
	for j in range(n):
		for i in range(n):
			if mk[j * n + i] == 0:
				continue
			var a := j * (n + 1) + i
			idx.append_array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = UrbsFillMeshes.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	return true


# ---------------------------------------------------------------- collision for the walking camera

## Push `p` (x, z) out of any building footprint, keeping `radius` clear. `h` is the eye height;
## above a building's roof nothing blocks. Works on finished chunks.
func push_out(p: Vector2, radius: float, h: float) -> Vector2:
	var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k2 := key + Vector2i(dx, dz)
			if not _chunk_cache.has(k2):
				continue
			for lot in _chunk_cache[k2]:
				var kind := str(lot["kind"])
				if kind == "horti" or kind == "prop" or kind == "tree":
					continue
				var ground: float = float(lot["y"])
				if h > ground + float(lot["top"]) + 0.5:
					continue
				var ax := _axes(lot)
				var rel: Vector2 = p - lot["c"]
				if rel.length() > maxf(lot["hx"], lot["hz"]) * 1.5 + radius:
					continue
				var lx: float = rel.dot(ax[0])
				var lz: float = rel.dot(ax[1])
				var ex: float = lot["hx"] + radius
				var ez: float = lot["hz"] + radius
				if absf(lx) < ex and absf(lz) < ez:
					if ex - absf(lx) < ez - absf(lz):
						lx = signf(lx) * ex if lx != 0.0 else ex
					else:
						lz = signf(lz) * ez if lz != 0.0 else ez
					p = lot["c"] + ax[0] * lx + ax[1] * lz
	return p
