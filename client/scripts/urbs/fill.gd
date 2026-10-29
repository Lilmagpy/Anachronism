## Urbs (D-289, step U3): the ordinary buildings of Rome between the monuments.
##
## What it makes, for a year: lots along every street (a row of tabernae -- shop-fronts -- where
## the street is a shopping street, and behind or instead of them a row of houses), and in the
## ground between the streets a loose lattice of lots (insulae, domus, casae, workshops, horti).
## Everything is deterministic: it depends only on the year, the data and fixed hash values of the
## lot position (no random state), so a chunk looks the same whenever it is built, in any order.
##
## Character (data/rome/city/regions.yaml `districts`, each with its sources): domus of the rich
## on the Palatine, the Carinae and the Quirinal (P-A s.v. Carinae: "many prominent Romans
## dwelt here"); dense insulae and workshops in the Subura (P-A s.v. Subura, Martial, Juvenal), the
## Velabrum (P-A s.v. Velabrum: trade in food, oil and wine), the Forum Boarium and Emporium
## (Livy 21.62.3 for the third storey in 218 BC), the Aventine (Livy 3.31.1, the plebeian land)
## and Transtiberim; gardens (horti) on the Pincian and Esquiline in the late Republic (P-A s.v.
## Horti); the Campus Martius open until the Circus Flaminius and Via Flaminia of 220 BC, then
## built over from the south (P-A s.v. Campus Martius). Forms: Vitruvius 2.8.17 and 6.3
## (fill_meshes.gd). After the Gallic sack the lots are irregular (Livy 5.55.2-5): the early
## eras use mostly small casae.
##
## Density = district `max_density` x (city population / `saturates_at`) ** 0.7, the population
## taken from population.json (central estimate, log-interpolated).
##
## Interface (urbs.gd): build(urbs, year, height) once per year, then build_chunk(rect, lod,
## height) -> Node3D for each 250 m chunk, push_out(p, radius, h) for the walking camera.
## Also: chunks_in(radius, centre) and build_chunk_into(parent, chunk, year, height, footprints)
## for tools and tests. The monument footprints to avoid are read from `urbs.monuments`
## (ids() and bounds(id)); `footprints` can also be set directly (list of Rect2 in local x, z).
class_name UrbsFill
extends RefCounted

const CHUNK := 250.0
const CELL := 25.0
const REGIONS_PATH := "res://data/city/regions.json"
const POP_PATH := "res://data/city/population.json"
const TOPO_PATH := "res://data/city/topography.json"
const MONUMENTS_PATH := "res://data/city/monuments.json"
const SHOP_DEPTH := 5.2
const KERB := 0.3
const LATTICE_MIN_STREET := 33.0     ## the lattice stays this far from any street
const TIBER_BAND := 50.0             ## no building within this distance of the river's centre line
const MAX_SLOPE := 0.42
const PALETTE: Array[Color] = [
	Color(0.80, 0.62, 0.40), Color(0.78, 0.50, 0.36), Color(0.84, 0.76, 0.58), Color(0.70, 0.40, 0.30),
	Color(0.62, 0.56, 0.48), Color(0.88, 0.84, 0.74), Color(0.82, 0.68, 0.36), Color(0.66, 0.36, 0.28),
	Color(0.74, 0.58, 0.44), Color(0.58, 0.48, 0.40),
]

var year := -300
var height: Callable = func(_x: float, _z: float) -> float: return 10.0
var footprints: Array = []           ## Rect2 in local metres (monuments and anything else to avoid)

var _streets := UrbsStreets.new()
var _districts: Array = []
var _default: Dictionary = {}
var _pop_pts: Array = []
var _tiber := PackedVector2Array()
var _loaded := false
var _street_lots: Array = []
var _street_hash := {}               ## Vector2i(30 m cell) -> Array of lot indices
var _street_by_chunk := {}           ## Vector2i -> Array of lots
var _chunk_cache := {}               ## Vector2i -> Array of lots (street lots + lattice lots)
var _lattice_hash := {}
var _material: StandardMaterial3D
var count_stats := {}                ## lot counts by mesh family for the last year, for reports


# ---------------------------------------------------------------- set-up

## Per-year set-up (called by urbs.gd after the terrain, streets and monuments).
func build(urbs: Node3D, new_year: int, new_height: Callable) -> void:
	year = new_year
	height = new_height
	footprints = []
	var mon: Variant = urbs.get("monuments") if urbs != null else null
	if mon != null and mon.has_method("ids"):
		for id in mon.ids():
			var b: AABB = mon.bounds(id)
			footprints.append(Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
	prepare()


## Load the data and lay out the street-front lots for the current `year`/`height`/`footprints`.
func prepare() -> void:
	if not _loaded:
		_load()
	_streets.height = height
	_streets.load_data(year)
	_chunk_cache = {}
	_lattice_hash = {}
	_gen_street_lots()


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
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.95
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED


## Footprints (Rect2) of the monuments standing in `year`, read straight from monuments.json
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


func _occupancy(d: Dictionary) -> float:
	if year < int(d["onset"]):
		return 0.0
	return float(d["max"]) * pow(clampf(_population() / float(d["sat"]), 0.0, 1.0), 0.7)


func _near_tiber(p: Vector2, band: float) -> bool:
	for i in range(_tiber.size() - 1):
		var a := _tiber[i]
		var ab := _tiber[i + 1] - a
		var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
		if p.distance_to(a + ab * u) < band:
			return true
	return false


# ---------------------------------------------------------------- lots

## A lot: {mesh, c, th, sx, sz, hx, hz, y, tint, top, kind}. `th` is the yaw of a local frame whose
## +z points to the front (the street); (hx, hz) are half sizes along local x and z.
func _make_lot(mesh: String, nominal: Vector2, c: Vector2, front: Vector2, w: float, d: float, tint: Color, top: float, kind: String) -> Dictionary:
	var th := atan2(front.x, front.y)
	return {"mesh": mesh, "c": c, "th": th, "sx": w / nominal.x, "sz": d / nominal.y, "hx": w * 0.5, "hz": d * 0.5,
		"y": 0.0, "tint": tint, "top": top, "kind": kind}


static func _axes(lot: Dictionary) -> Array:
	var th: float = lot["th"]
	return [Vector2(cos(th), -sin(th)), Vector2(sin(th), cos(th))]


## Separating-axis test of two oriented lot rectangles, with a margin.
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


## True if the lot can stand: not on water, not on a monument, off other streets, not too steep.
## `own` is the index of the street the lot fronts (its own strip is already accounted for).
func _acceptable(lot: Dictionary, own: String) -> bool:
	var pts := _corners(lot)
	var c: Vector2 = lot["c"]
	if _near_tiber(c, TIBER_BAND):
		return false
	var rad := maxf(lot["hx"], lot["hz"]) * 1.42
	var bbox := Rect2(c.x - rad, c.y - rad, rad * 2.0, rad * 2.0)
	for f in footprints:
		if (f as Rect2).grow(1.5).intersects(bbox):
			# test the real corners against the footprint
			for p in pts:
				if (f as Rect2).grow(1.5).has_point(p):
					return false
			if bbox.size.x > 0.0 and (f as Rect2).grow(1.5).encloses(Rect2(c.x - 1, c.y - 1, 2, 2)):
				return false
	var near := _streets.nearest_street(c)
	if not near.is_empty() and near["distance"] < rad + 24.0:
		for p in pts:
			var ns := _streets.nearest_street(p)
			if ns.is_empty():
				continue
			if str(ns["id"]) != own and ns["distance"] < float(ns["half_width"]) + 0.8:
				return false
			if str(ns["id"]) == own and ns["distance"] < float(ns["half_width"]) + 0.1:
				return false
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


func _pick_type(d: Dictionary, era: Dictionary, roll: float) -> String:
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


func _storeys(d: Dictionary, r: float) -> int:
	# insulae are rare and low in the early Republic (Livy 21.62.3: a third storey by 218 BC)
	if year < -250:
		return 2 + int(r * 2.0)
	if year < -150:
		return 3 + int(r * 2.0)
	return 3 + int(r * 2.99)


func _shape(r: float) -> String:
	return "gable" if r < 0.5 else ("hip" if r < 0.75 else "stepped")


func _roof_kind(r: float) -> String:
	if year < -280:    # shingles and thatch until the war with Pyrrhus (Pliny NH 16.36, unverified)
		return "thatch" if r < 0.55 else "shingle"
	return "tile" if r < 0.8 else "shingle"


## Build the lot of `type` at centre `c`, front direction `front`, from hash values `h` (3 ints).
## Returns {} if the type makes no building.
func _lot_of(type: String, c: Vector2, front: Vector2, a: int, b: int, salt: int) -> Dictionary:
	var tint: Color = PALETTE[_hash(a, b, salt + 90) % PALETTE.size()]
	match type:
		"insula":
			var s := _storeys({}, _r(a, b, salt + 1))
			var w := 14.0 + _r(a, b, salt + 2) * 8.5
			var d := 14.0 + _r(a, b, salt + 3) * 8.5
			var shape := _shape(_r(a, b, salt + 4))
			var top := 3.7 + 3.1 * float(s - 1) + 2.4
			return _make_lot("insula:%s:%d" % [shape, s], Vector2(18, 18), c, front, w, d, tint, top, "insula")
		"casa":
			var w2 := 6.5 + _r(a, b, salt + 2) * 4.0
			var d2 := 7.5 + _r(a, b, salt + 3) * 4.0
			return _make_lot("casa:" + _roof_kind(_r(a, b, salt + 5)), Vector2(8, 9), c, front, w2, d2, tint, 4.9, "casa")
		"workshop":
			var w3 := 13.0 + _r(a, b, salt + 2) * 4.0
			var d3 := 12.0 + _r(a, b, salt + 3) * 3.0
			return _make_lot("workshop:%d" % int(_r(a, b, salt + 4) * 2.0), Vector2(16, 14), c, front, w3, d3, tint, 7.8, "workshop")
		"domus":
			var w4 := 17.0 + _r(a, b, salt + 2) * 7.0
			var d4 := 29.0 + _r(a, b, salt + 3) * 13.0
			return _make_lot("domus", Vector2(20, 34), c, front, w4, d4, tint, 6.3, "domus")
	return {}


## Street-front lots: for each street and side, stretches of tabernae (shop-fronts) with houses
## behind them, or houses directly on the street. Deterministic: depends on the street, the
## stretch and the position along it only.
func _gen_street_lots() -> void:
	_street_lots = []
	_street_hash = {}
	_street_by_chunk = {}
	for si in _streets.streets.size():
		var st: Dictionary = _streets.streets[si]
		var sid := str(st["id"])
		var sh := hash(sid) & 0xfffff
		var length: float = st["len"]
		var hw: float = st["hw"]
		for side in [1, -1]:
			# 1. the stretches: [end, shops?]
			var stretches: Array = []
			var s := 0.0
			var n := 0
			while s < length:
				var p0: Vector2 = _streets.sample_at(si, s)[0]
				var era0 := _era(_district_at(p0))
				var e := s + 22.0 + _r(sh, n, side + 5) * 40.0
				stretches.append([e, _r(sh, n, side + 7) < float(era0["shops"])])
				s = e
				n += 1
			# 2. tabernae along the shop stretches
			s = 0.0
			var item := 0
			while s < length:
				var shops_here := _shops_at(stretches, s)
				if not shops_here:
					s = _stretch_end(stretches, s)
					continue
				var tw := 3.7 + _r(sh, item, side + 11) * 1.9
				var mid := _streets.sample_at(si, s + tw * 0.5)
				var mp: Vector2 = mid[0]
				var mt: Vector2 = mid[1]
				if mp.length() < 3600.0:
					var mn := Vector2(-mt.y, mt.x) * float(side)
					var occ := _occupancy(_district_at(mp))
					if _r(sh, item, side + 13) < 0.93 and _r(sh, item, side + 15) < clampf(occ * 1.25, 0.0, 1.0):
						var dd := 5.0 + _r(sh, item, side + 17) * 0.4
						var pos := mp + mn * (hw + KERB + 0.4 + dd * 0.5)
						var variant := int(_r(sh, item, side + 19) * 3.0)
						_add_street_lot(_make_lot("taberna:%d" % variant, Vector2(4.6, 5.2), pos, -mn, tw, dd,
							PALETTE[_hash(sh, item, side + 21) % PALETTE.size()], 4.5, "taberna"), sid, 0.2)
				s += tw + (2.4 if _r(sh, item, side + 22) < 0.07 else 0.0)
				item += 1
			# 3. houses along the whole street (behind the shops where there are any)
			s = 0.0
			item = 0
			while s < length:
				var sp := _streets.sample_at(si, s)
				var p: Vector2 = sp[0]
				if p.length() > 3600.0:
					s += 30.0
					continue
				var d := _district_at(p)
				var era := _era(d)
				var type := _pick_type(d, era, _r(sh, item, side + 25))
				var probe := _lot_of(type, Vector2.ZERO, Vector2.UP, sh, item, side * 31 + 3) if type != "" else {}
				if probe.is_empty() or _r(sh, item, side + 27) >= _occupancy(d):
					s += 12.0 + _r(sh, item, side + 28) * 8.0
					item += 1
					continue
				var wide: float = probe["hx"] * 2.0
				var depth: float = probe["hz"] * 2.0
				var mid2 := _streets.sample_at(si, s + wide * 0.5)
				var np: Vector2 = mid2[0]
				var nt: Vector2 = mid2[1]
				var nn := Vector2(-nt.y, nt.x) * float(side)
				var rowdist := hw + KERB + 0.5 + (SHOP_DEPTH + 0.5 if _shops_at(stretches, s + wide * 0.5) else 0.0)
				var lot := _lot_of(type, np + nn * (rowdist + depth * 0.5), -nn, sh, item, side * 31 + 3)
				_add_street_lot(lot, sid, 0.25)
				s += wide + _r(sh, item, side + 29) * 2.2
				item += 1
	# bucket by chunk
	for lot in _street_lots:
		var key := Vector2i(floori(lot["c"].x / CHUNK), floori(lot["c"].y / CHUNK))
		if not _street_by_chunk.has(key):
			_street_by_chunk[key] = []
		_street_by_chunk[key].append(lot)
	count_stats = {}
	for lot in _street_lots:
		var k := str(lot["mesh"]).split(":")[0]
		count_stats[k] = int(count_stats.get(k, 0)) + 1


static func _shops_at(stretches: Array, s: float) -> bool:
	for e in stretches:
		if s < e[0]:
			return e[1]
	return false


static func _stretch_end(stretches: Array, s: float) -> float:
	for e in stretches:
		if s < e[0]:
			return e[0] + 0.01
	return 1.0e9


func _add_street_lot(lot: Dictionary, own: String, margin: float) -> void:
	if lot.is_empty():
		return
	var c: Vector2 = lot["c"]
	var key := Vector2i(floori(c.x / 30.0), floori(c.y / 30.0))
	# overlap with lots already placed nearby
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k2 := key + Vector2i(dx, dz)
			if _street_hash.has(k2):
				for idx in _street_hash[k2]:
					var other: Dictionary = _street_lots[idx]
					if c.distance_to(other["c"]) < 60.0 and _overlap(lot, other, margin):
						return
	if not _acceptable(lot, own):
		return
	_street_hash[key] = _street_hash.get(key, [])
	_street_hash[key].append(_street_lots.size())
	_street_lots.append(lot)


## Lattice lots of one chunk: the ground between the streets.
func _lattice_lots(key: Vector2i) -> Array:
	var out: Array = []
	var i0 := key.x * 10
	var j0 := key.y * 10
	var placed: Array = []
	for j in range(j0, j0 + 10):
		for i in range(i0, i0 + 10):
			var lot := _lattice_cell(i, j)
			if lot.is_empty():
				continue
			var hit := false
			for o in placed:
				if lot["c"].distance_to(o["c"]) < 40.0 and _overlap(lot, o, 0.5):
					hit = true
					break
			if hit:
				continue
			if _overlaps_street_lots(lot):
				continue
			if not _acceptable(lot, ""):
				continue
			placed.append(lot)
			out.append(lot)
	return out


func _overlaps_street_lots(lot: Dictionary) -> bool:
	var c: Vector2 = lot["c"]
	var key := Vector2i(floori(c.x / 30.0), floori(c.y / 30.0))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var k2 := key + Vector2i(dx, dz)
			if _street_hash.has(k2):
				for idx in _street_hash[k2]:
					var other: Dictionary = _street_lots[idx]
					if c.distance_to(other["c"]) < 70.0 and _overlap(lot, other, 0.8):
						return true
	return false


func _horti_cell(i: int, j: int) -> bool:
	var hi := floori(float(i) / 3.0)
	var hj := floori(float(j) / 3.0)
	var mc := Vector2((hi * 3 + 1.5) * CELL, (hj * 3 + 1.5) * CELL)
	var d := _district_at(mc)
	var era := _era(d)
	var w: Dictionary = era["w"]
	var total := 0.0
	for k in w:
		total += float(w[k])
	if total <= 0.0 or not w.has("horti"):
		return false
	return _r(hi, hj, 11) < float(w["horti"]) / total and _r(hi, hj, 12) < _occupancy(d) * 1.4


func _domus_macro(i: int, j: int) -> bool:
	var di := floori(float(i) / 2.0)
	var dj := floori(float(j) / 2.0)
	var mc := Vector2((di * 2 + 1.0) * CELL, (dj * 2 + 1.0) * CELL)
	var d := _district_at(mc)
	var era := _era(d)
	var w: Dictionary = era["w"]
	var total := 0.0
	for k in w:
		total += float(w[k])
	if total <= 0.0 or not w.has("domus"):
		return false
	if not (_r(di, dj, 21) < float(w["domus"]) / total and _r(di, dj, 22) < _occupancy(d)):
		return false
	for oi in 2:
		for oj in 2:
			if _horti_cell(di * 2 + oi, dj * 2 + oj):
				return false
	return true


## Smooth value noise in [0, 1) on a unit lattice (for clustering).
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


func _block_angle(c: Vector2) -> float:
	var gi := floori(c.x / 130.0)
	var gj := floori(c.y / 130.0)
	var pick := [-12.0, -6.0, 0.0, 0.0, 6.0, 12.0, 20.0]
	return deg_to_rad(pick[int(_r(gi, gj, 41) * float(pick.size()))])


func _lattice_cell(i: int, j: int) -> Dictionary:
	var centre := Vector2((float(i) + 0.5) * CELL, (float(j) + 0.5) * CELL)
	if centre.length() > 3300.0:
		return {}
	# horti: 3 x 3 cells
	if _horti_cell(i, j):
		if posmod(i, 3) != 1 or posmod(j, 3) != 1:
			return {}
		var hi := floori(float(i) / 3.0)
		var hj := floori(float(j) / 3.0)
		var hc := Vector2((hi * 3 + 1.5) * CELL, (hj * 3 + 1.5) * CELL)
		if _streets.nearest_street(hc).get("distance", 999.0) < 46.0:
			return {}
		var th := _block_angle(hc) + float(int(_r(hi, hj, 13) * 4.0)) * PI * 0.5
		var s := 0.92 + _r(hi, hj, 14) * 0.1
		return _make_lot("horti", Vector2(70, 70), hc, Vector2(sin(th), cos(th)), 70.0 * s, 70.0 * s, Color(1, 1, 1), 8.0, "horti")
	# domus: 2 x 2 cells
	if _domus_macro(i, j):
		if posmod(i, 2) != 0 or posmod(j, 2) != 0:
			return {}
		var di := floori(float(i) / 2.0)
		var dj := floori(float(j) / 2.0)
		var mc := Vector2((di * 2 + 1.0) * CELL, (dj * 2 + 1.0) * CELL)
		if _streets.nearest_street(mc).get("distance", 999.0) < 30.0:
			return {}
		var th2 := _block_angle(mc) + float(int(_r(di, dj, 23) * 4.0)) * PI * 0.5
		var lot := _lot_of("domus", mc + Vector2(_r(di, dj, 24) - 0.5, _r(di, dj, 25) - 0.5) * 4.0, Vector2(sin(th2), cos(th2)), di, dj, 100)
		return lot
	# a cell of a domus macro that failed? then a single lot
	var d := _district_at(centre)
	var near := _streets.nearest_street(centre)
	if not near.is_empty() and near["distance"] < LATTICE_MIN_STREET:
		return {}
	var era := _era(d)
	var cluster := 0.55 + 0.9 * _smooth_noise(centre / 90.0)
	if _r(i, j, 32) >= clampf(_occupancy(d) * cluster, 0.0, 1.0):
		return {}
	var type := _pick_type(d, era, _r(i, j, 31))
	if type == "" or type == "field" or type == "horti" or type == "domus":
		return {}
	var small := type == "casa" or type == "workshop"
	var jitter := Vector2(_r(i, j, 33) - 0.5, _r(i, j, 34) - 0.5) * (12.0 if small else 1.6)
	var ang := _block_angle(centre) + float(int(_r(i, j, 35) * 4.0)) * PI * 0.5
	if small:   # irregular, as after the Gallic sack (Livy 5.55.5)
		ang += (_r(i, j, 36) - 0.5) * deg_to_rad(50.0)
	var lot2 := _lot_of(type, centre + jitter, Vector2(sin(ang), cos(ang)), i, j, 200)
	# keep rotated lots small enough for their 25 m cell
	if not lot2.is_empty():
		var off_axis := absf(fposmod(ang, PI * 0.5))
		off_axis = minf(off_axis, PI * 0.5 - off_axis)
		if not small and off_axis > 0.2 and (lot2["hx"] > 8.6 or lot2["hz"] > 8.6):
			var k := 8.6 / maxf(lot2["hx"], lot2["hz"])
			lot2["sx"] *= k
			lot2["sz"] *= k
			lot2["hx"] *= k
			lot2["hz"] *= k
	return lot2


# ---------------------------------------------------------------- chunks

func _lots_of_chunk(key: Vector2i) -> Array:
	if _chunk_cache.has(key):
		return _chunk_cache[key]
	var lots: Array = []
	lots.append_array(_street_by_chunk.get(key, []))
	lots.append_array(_lattice_lots(key))
	_chunk_cache[key] = lots
	return lots


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


## The houses of one 250 m chunk (urbs.gd interface). lod 0 best .. 2 coarsest.
func build_chunk(rect: Rect2, lod: int, new_height: Callable) -> Node3D:
	if not _loaded or new_height != height and not height.is_valid():
		height = new_height
	var key := Vector2i(roundi(rect.position.x / CHUNK), roundi(rect.position.y / CHUNK))
	return _chunk_node(key, lod)


## Tool/test form: build chunk `chunk` for `for_year` under `parent`.
func build_chunk_into(parent: Node3D, chunk: Vector2i, for_year: int, new_height: Callable, new_footprints: Array, lod := 0) -> Node3D:
	if for_year != year or not _loaded or new_footprints != footprints:
		year = for_year
		height = new_height
		footprints = new_footprints
		prepare()
	var node := _chunk_node(chunk, lod)
	parent.add_child(node)
	return node


func _chunk_node(key: Vector2i, lod: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Fill_%d_%d" % [key.x, key.y]
	var lots := _lots_of_chunk(key)
	var buckets := {}
	for lot in lots:
		var mesh_key := str(lot["mesh"])
		if lod >= 2 and mesh_key.begins_with("taberna"):
			continue
		if not buckets.has(mesh_key):
			buckets[mesh_key] = []
		buckets[mesh_key].append(lot)
		if mesh_key == "horti":
			_add_trees(lot, buckets, lod)
	var keys := buckets.keys()
	keys.sort()
	for mk in keys:
		var list: Array = buckets[mk]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = UrbsFillMeshes.get_mesh(mk, lod)
		multi.instance_count = list.size()
		for n in list.size():
			var lot: Dictionary = list[n]
			var basis := Basis(Vector3.UP, float(lot["th"])) * Basis.from_scale(Vector3(lot["sx"], lot.get("sy", 1.0), lot["sz"]))
			multi.set_instance_transform(n, Transform3D(basis, Vector3(lot["c"].x, lot["y"], lot["c"].y)))
			multi.set_instance_color(n, lot["tint"])
		var inst := MultiMeshInstance3D.new()
		inst.name = mk.replace(":", "_")
		inst.multimesh = multi
		inst.material_override = _material
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod < 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(inst)
	return root


## Scatter the trees of one horti estate (deterministic from its position).
func _add_trees(lot: Dictionary, buckets: Dictionary, lod: int) -> void:
	var c: Vector2 = lot["c"]
	var a := roundi(c.x)
	var b := roundi(c.y)
	var ax := _axes(lot)
	var n := 26 if lod < 2 else 10
	for k in n:
		var lx: float = (_r(a, b, 500 + k) - 0.5) * lot["hx"] * 1.8
		var lz: float = (_r(a, b, 600 + k) - 0.5) * lot["hz"] * 1.8
		# keep clear of the villa (local, unscaled coordinates) and the gate path
		var ux: float = lx / float(lot["sx"])
		var uz: float = lz / float(lot["sz"])
		if absf(ux) < 16.0 and uz > -10.0 and uz < 11.0:
			continue
		if absf(ux) < 3.0 and uz > 0.0:
			continue
		var p: Vector2 = c + ax[0] * lx + ax[1] * lz
		var kind := "cypress" if _r(a, b, 700 + k) < 0.45 else ("pine" if _r(a, b, 700 + k) < 0.7 else "round")
		var tk := "tree:" + kind
		if not buckets.has(tk):
			buckets[tk] = []
		var sc := 0.8 + _r(a, b, 800 + k) * 0.7
		var y: float = height.call(p.x, p.y)
		buckets[tk].append({"c": p, "th": _r(a, b, 900 + k) * TAU, "sx": sc, "sz": sc, "sy": sc, "y": y - 0.1, "tint": Color(1, 1, 1)})


# ---------------------------------------------------------------- collision for the walking camera

## Push `p` (x, z) out of any building footprint, keeping `radius` clear. `h` is the eye height;
## above a building's roof nothing blocks.
func push_out(p: Vector2, radius: float, h: float) -> Vector2:
	var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k2 := key + Vector2i(dx, dz)
			if not (_street_by_chunk.has(k2) or _chunk_cache.has(k2)):
				continue
			for lot in _lots_of_chunk(k2):
				if not lot.has("hx") or str(lot["kind"]) == "horti":
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
					var push_x := ex - absf(lx)
					var push_z := ez - absf(lz)
					if push_x < push_z:
						lx = signf(lx) * ex if lx != 0.0 else ex
					else:
						lz = signf(lz) * ez if lz != 0.0 else ez
					p = lot["c"] + ax[0] * lx + ax[1] * lz
	return p
