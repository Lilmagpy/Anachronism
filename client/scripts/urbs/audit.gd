## Urbs F2 audit: is everything in the built scene where it should be? Builds the city of one year
## headless (the ground, the streets, the monuments and the house lots of the fill, no meshes for
## the houses) and prints one line `URBS_AUDIT {json}`, then quits. Run from client/:
##   /tmp/claude-0/godot --headless --path . -s res://scripts/urbs/audit.gd -- --urbs-audit=-44
## `uv run anachronism-city-audit --scene` runs it for 509, 390, 264, 133, 44 and 27 BC and puts
## what it finds into docs/reports/city_audit.md.
##
## Findings (lists of strings "<id> ..." so the report can quote them):
##   overlaps             two standing monuments whose solids overlap by more than OVERLAP_M
##   floating             a footprint corner more than 0.5 m below the base, with no foundation
##   buried               a footprint corner where the ground rises more than 1 m above the base
##   houses_in_monuments  a house lot (insula, domus, shop...) overlapping a monument's footprint
##   houses_on_streets    a house lot overlapping the carriageway of a street
##   in_river             a monument (not a bridge, quay or ship-shed) with its centre in the water
##   streets_through      a street whose carriageway passes through a monument's solid
## and `terrain`: the built ground at the summits and valley floors of topography.json.
## Options: --radius=M (house lots within M metres of the Forum, default 2600).
extends SceneTree

const OVERLAP_M := 0.75        ## overlaps shallower than this are touching walls, not an error
const FLOAT_M := 0.5
const BURY_M := 1.0
const HOUSE_KINDS := ["insula", "domus", "casa", "taberna", "shop", "workshop", "horrea", "house", "villa"]
## Gates and arches stand across their street by design; plazas and courts are walked on.
const PASSABLE := ["servian_gate", "arch", "plaza", "bridge_stone", "bridge_timber", "wall", "aqueduct",
	"sewer", "road_paved", "comitium", "quay"]
const WATER_OK := ["bridge_stone", "bridge_timber", "quay", "shipsheds", "wall", "aqueduct", "sewer"]

var _year := -44
var _mon: UrbsMonuments
var _streets := UrbsStreets.new()
var _obbs := {}   ## id -> Array of {c: Vector2, ax: Vector2, az: Vector2, hx, hz, y0, y1}


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_year = int(args.get("urbs-audit", "-44"))
	var radius := float(args.get("radius", "2600"))
	var t0 := Time.get_ticks_msec()
	UrbsTerrain.year = _year
	UrbsTerrain.prepare()
	var height := Callable(UrbsTerrain, "height_at")
	var root := Node3D.new()
	get_root().add_child(root)
	_mon = UrbsMonuments.new()
	_mon.build(root, _year, height)
	_streets.height = height
	_streets.load_data(_year)
	for id in _mon.ids():
		_obbs[id] = _solid_obbs(id)
	var out := {
		"year": {
			"year": _year,
			"standing": _mon.ids().size(),
			"overlaps": _overlaps(),
			"floating": [],
			"buried": [],
			"houses_in_monuments": [],
			"houses_on_streets": [],
			"in_river": _in_river(),
			"streets_through": _streets_through(),
		},
		"terrain": _terrain(),
	}
	var ground := _ground()
	out.year.floating = ground[0]
	out.year.buried = ground[1]
	var houses := _houses(height, radius)
	out.year.houses_in_monuments = houses[0]
	out.year.houses_on_streets = houses[1]
	# F2: monuments standing on a foundation or terrace where the ground falls more than 1 m under them
	var founded := []
	var slopes := []
	var fids: Array = _mon.ids()
	fids.sort()
	for id in fids:
		var pl: Dictionary = _mon._placed.get(id, {})
		if float(pl.get("drop", 0.0)) > 1.0 and not bool(pl.get("world", false)):
			founded.append("%s on a %.1f m foundation (%s)" % [id, float(pl.drop), _model(id)])
			var c: Vector2 = pl.centre
			var hf: Vector2 = pl.get("half", Vector2.ZERO)
			slopes.append({"id": id, "model": _model(id), "x": snappedf(c.x, 0.01), "z": snappedf(c.y, 0.01),
				"yaw": float(pl.yaw), "hx": snappedf(hf.x, 0.01), "hz": snappedf(hf.y, 0.01),
				"drop": snappedf(float(pl.drop), 0.01), "ground": snappedf(UrbsTerrain.height_at(c.x, c.y), 0.01),
				"platform": UrbsSite.platform_at(c.x, c.y)})
	out.year["founded"] = founded
	out.year["slopes"] = slopes   # for city_audit.py --terraces
	out.year["f3_houses"] = _f3_houses(height, radius)   # F3 houses
	out.year["seconds"] = (Time.get_ticks_msec() - t0) / 1000.0
	print("URBS_AUDIT " + JSON.stringify(out))
	quit()


# ---------------------------------------------------------------------------------------------
# Shapes
# ---------------------------------------------------------------------------------------------


## The monument's solids as oriented rectangles on the ground (2D) with their height range.
func _solid_obbs(id: String) -> Array:
	var out := []
	var xf: Transform3D = _mon._xf.get(id, Transform3D.IDENTITY)
	for b in _mon._solids.get(id, []):
		var bb: AABB = b
		var c3 := xf * bb.get_center()
		var ax3 := xf.basis * Vector3(1, 0, 0)
		var az3 := xf.basis * Vector3(0, 0, 1)
		out.append({"c": Vector2(c3.x, c3.z), "ax": Vector2(ax3.x, ax3.z).normalized(),
			"az": Vector2(az3.x, az3.z).normalized(), "hx": bb.size.x * 0.5, "hz": bb.size.z * 0.5,
			"y0": (xf * bb.position).y, "y1": (xf * bb.end).y})
	return out


## The nominal footprint (length x width, turned to the bearing) as one rectangle.
func _footprint(id: String) -> Dictionary:
	var p: Dictionary = _mon._placed.get(id, {})
	if p.is_empty():
		return {}
	var yaw := float(p.yaw)
	var c: Vector2 = p.centre
	var w := float(p.width)
	var l := float(p.length)
	var hf: Vector2 = p.get("half", Vector2.ZERO)   # the plan size monuments.gd placed it by
	if hf.x > 0.0 and hf.y > 0.0:
		w = hf.x * 2.0
		l = hf.y * 2.0
	if w <= 0.0 or l <= 0.0:
		var n: Vector3 = p.native
		w = n.x
		l = n.z
	return {"c": c, "ax": Vector2(cos(yaw), -sin(yaw)), "az": Vector2(sin(yaw), cos(yaw)),
		"hx": w * 0.5, "hz": l * 0.5}


## Overlap depth of two oriented rectangles along the axis of least overlap (<= 0: apart).
static func _depth(a: Dictionary, b: Dictionary) -> float:
	var dc: Vector2 = b.c - a.c
	var best := INF
	for ax in [a.ax, a.az, b.ax, b.az]:
		var axis: Vector2 = ax
		var ra := absf(axis.dot(a.ax)) * float(a.hx) + absf(axis.dot(a.az)) * float(a.hz)
		var rb := absf(axis.dot(b.ax)) * float(b.hx) + absf(axis.dot(b.az)) * float(b.hz)
		best = minf(best, ra + rb - absf(dc.dot(axis)))
	return best


static func _contains(r: Dictionary, p: Vector2, margin := 0.0) -> bool:
	var d := p - (r.c as Vector2)
	return absf(d.dot(r.ax)) <= float(r.hx) - margin and absf(d.dot(r.az)) <= float(r.hz) - margin


static func _lot_rect(lot: Dictionary) -> Dictionary:
	var th := float(lot["th"])
	return {"c": lot["c"], "ax": Vector2(cos(th), -sin(th)), "az": Vector2(sin(th), cos(th)),
		"hx": float(lot["hx"]), "hz": float(lot["hz"])}


func _model(id: String) -> String:
	return str(_mon._placed.get(id, {}).get("model", ""))


# ---------------------------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------------------------


func _overlaps() -> Array:
	var out := []
	var ids: Array = _mon.ids()
	ids.sort()
	for i in ids.size():
		var a: String = ids[i]
		if _model(a) in ["wall", "aqueduct", "sewer"]:
			continue
		for j in range(i + 1, ids.size()):
			var b: String = ids[j]
			if _model(b) in ["wall", "aqueduct", "sewer"]:
				continue
			var ba: AABB = _mon.bounds(a)
			var bb: AABB = _mon.bounds(b)
			if ba.size != Vector3.ZERO and bb.size != Vector3.ZERO and not ba.grow(1.0).intersects(bb):
				continue
			var worst := 0.0
			for sa in _obbs[a]:
				for sb in _obbs[b]:
					if float(sa.y1) <= float(sb.y0) + 0.2 or float(sb.y1) <= float(sa.y0) + 0.2:
						continue   # one stands on the other (a statue on a base, a roof over a court)
					worst = maxf(worst, _depth(sa, sb))
			if worst > OVERLAP_M:
				out.append("%s overlaps %s by %.1f m" % [a, b, worst])
	return out


## Footprint corners against the base: [floating, buried].
func _ground() -> Array:
	var floating := []
	var buried := []
	var ids: Array = _mon.ids()
	ids.sort()
	for id in ids:
		var p: Dictionary = _mon._placed.get(id, {})
		if p.is_empty() or bool(p.get("world", false)) or _model(id) in ["plaza", "bridge_stone", "bridge_timber", "circus_maximus"]:
			continue
		var r := _footprint(id)
		if r.is_empty():
			continue
		var base := float(p.y)
		var lo := INF
		var hi := -INF
		for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var q: Vector2 = (r.c as Vector2) + (r.ax as Vector2) * float(r.hx) * s.x + (r.az as Vector2) * float(r.hz) * s.y
			var g := UrbsTerrain.height_at(q.x, q.y)
			lo = minf(lo, g)
			hi = maxf(hi, g)
		var founded := bool(p.get("skirted", false)) or str(p.get("base_mode", "lo")) == "hi"
		if base - lo > FLOAT_M and not founded:
			floating.append("%s base %.1f m above the ground at a corner" % [id, base - lo])
		if hi - base > BURY_M and not bool(p.get("retains", false)):   # F2: built against the hill
			buried.append("%s ground %.1f m above its base at a corner" % [id, hi - base])
	return [floating, buried]


func _in_river() -> Array:
	var out := []
	var ids: Array = _mon.ids()
	ids.sort()
	for id in ids:
		if _model(id) in WATER_OK or str(_mon.entry(id).get("type", "")) in ["bridge", "port", "island"]:
			continue
		var r := _footprint(id)
		if r.is_empty():
			continue
		var wet := 0
		var n := 0
		for i in 5:
			for j in 5:
				var q: Vector2 = (r.c as Vector2) + (r.ax as Vector2) * float(r.hx) * (i / 2.0 - 1.0) + (r.az as Vector2) * float(r.hz) * (j / 2.0 - 1.0)
				n += 1
				if UrbsTerrain.in_river(q.x, q.y):
					wet += 1
		if wet > 0:
			out.append("%s %d of %d footprint points in the water" % [id, wet, n])
	return out


func _streets_through() -> Array:
	var out := []
	var seen := {}
	for s in _streets.streets:
		if bool(s.get("stairs", false)):
			continue
		var pts: PackedVector2Array = s.pts
		var cum: PackedFloat32Array = s.cum
		var length := float(s.len)
		var d := 0.0
		while d <= length:
			var k := 0
			while k < cum.size() - 2 and cum[k + 1] < d:
				k += 1
			var seg := maxf(cum[k + 1] - cum[k], 0.0001)
			var p := pts[k].lerp(pts[k + 1], clampf((d - cum[k]) / seg, 0.0, 1.0))
			var gy := UrbsTerrain.height_at(p.x, p.y)
			for id in _obbs:
				if _model(id) in PASSABLE:
					continue
				for o in _obbs[id]:
					if float(o.y1) < gy + 1.3 or float(o.y0) > gy + 2.5:
						continue   # a kerb or a step, or a roof high above the street
					if _contains(o, p, 0.3):
						var key := "%s|%s" % [s.id, id]
						if not seen.has(key):
							seen[key] = true
							out.append("%s passes through street %s at (%.0f, %.0f)" % [id, s.id, p.x, p.y])
						break
			d += 3.0
	return out


## House lots of the fill within `radius` of the Forum: [in monuments, on streets].
func _houses(height: Callable, radius: float) -> Array:
	var fill := UrbsFill.new()
	fill.year = _year
	fill.height = height
	var fps := []
	for id in _mon.ids():
		var b: AABB = _mon.bounds(id)
		if minf(b.size.x, b.size.z) >= 600.0:
			continue
		var bc := b.get_center()
		if maxf(b.size.x, b.size.z) > 120.0 and UrbsSite.platform_at(bc.x, bc.z) != "":
			continue
		fps.append(Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
	fill.footprints = fps
	fill.obstacles = _mon.oriented_footprints()   # as UrbsFill.build does
	fill.prepare()
	var rects := {}
	for id in _mon.ids():
		if _model(id) in ["wall", "aqueduct", "sewer", "bridge_stone", "bridge_timber", "road_paved"]:
			continue
		rects[id] = _footprint(id)
	var inside := []
	var on_street := []
	var seen := {}
	for key in fill.chunks_in(radius):
		for rk in fill.regions_for_chunk(key):
			while not fill.advance_region(rk, Time.get_ticks_usec() + 1000000000):
				pass
		for lot in fill.lots_for_chunk(key):
			var kind := str(lot.get("kind", ""))
			var mesh := str(lot.get("mesh", ""))
			var is_house := false
			for hk in HOUSE_KINDS:
				if kind.contains(hk) or mesh.contains(hk):
					is_house = true
			if not is_house:
				continue
			var lr := _lot_rect(lot)
			var c: Vector2 = lot["c"]
			var lk := "%.1f,%.1f" % [c.x, c.y]
			if seen.has(lk):
				continue
			seen[lk] = true
			for id in rects:
				var r: Dictionary = rects[id]
				if r.is_empty():
					continue
				if (r.c as Vector2).distance_to(c) > float(r.hx) + float(r.hz) + float(lr.hx) + float(lr.hz):
					continue
				var dep := _depth(r, lr)
				if dep > 1.0:
					inside.append("%s has a %s lot inside it at (%.0f, %.0f), %.1f m deep" % [id, mesh, c.x, c.y, dep])
			var ns := _streets.nearest_street(c)
			if not ns.is_empty() and str(ns.get("kind", "")) != "stairs":
				# the lot's half extent across the street's direction
				var nrm: Vector2 = ns.normal
				var reach := absf(nrm.dot(lr.ax)) * float(lr.hx) + absf(nrm.dot(lr.az)) * float(lr.hz)
				var gap := float(ns.distance) - reach - float(ns.half_width)
				if gap < -0.75:
					on_street.append("%s %s lot at (%.0f, %.0f) %.1f m into the carriageway" % [ns.id, mesh, c.x, c.y, -gap])
	return [inside, on_street]


## The built ground at the summits and valley floors of topography.json.
func _terrain() -> Array:
	var out := []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/city/topography.json"))
	if not parsed is Dictionary:
		return out
	for group in ["hills", "other_heights", "valleys"]:
		for h in parsed.get(group, []):
			if not h is Dictionary or not h.has("lat"):
				continue
			var c := UrbsGeo.to_local(float(h["lat"]), float(h["lon"]))
			var top := -INF
			var pts := [c]
			for s in h.get("summits", []):
				pts.append(UrbsGeo.to_local(float(s["lat"]), float(s["lon"])))
			for q in pts:
				for dx in range(-150, 151, 25):
					for dz in range(-150, 151, 25):
						top = maxf(top, UrbsTerrain.height_at(q.x + dx, q.y + dz))
			out.append({"id": str(h["id"]), "height": snappedf(UrbsTerrain.height_at(c.x, c.y), 0.1), "max": snappedf(top, 0.1)})
	return out


# =============================================================================================
# F3 houses: the fill (houses, shops, workshops, horrea, horti, tombs, farms), the trees and the
# street life, against each other and against the monuments, the site works, the streets and the
# river, by their REAL meshes: each mesh's triangles are clipped into 1 m height bands and the box
# of each band (in the building's own frame) is what is tested, so eaves, balconies, stairs,
# counters and awnings count, not only the lot's rectangle. Findings go to `out.year.f3_houses`:
# {counts: {kind: n}, worst: {kind: [strings, worst first, at most F3_KEEP]}}.
#   house_house      two buildings of the fill interpenetrating (above the ground)
#   house_monument   a building of the fill inside a monument's solids
#   house_wall       a terrace, platform or clivus wall, a flight of steps or a quay inside a house
#   house_street     a building's ground storey on the footway or the carriageway, or any part of
#                    it below 4.5 m over the carriageway
#   house_river      a building standing in the river
#   house_base       a building's floor buried in the ground, or its plinth not reaching the ground
#   tree_building    a tree's trunk inside a building, or its crown through a wall or roof
#   tree_street      a tree standing in a carriageway
#   tree_river       a tree standing in the river
#   life_solid       a person, stall, cart, mule or litter (or a walker's or cart's lane) inside a
#                    monument's solid or a building
#   stall_street     a stall in a carriageway, or sunk into or floating over its footway
#   lamp_smoke       a lamp not on a wall, or kitchen smoke not rising from a roof
# =============================================================================================

const F3_BAND := 1.0
const F3_NB := 24
const F3_KEEP := 60
const F3_BUILDINGS := ["insula", "domus", "casa", "taberna", "workshop", "horrea", "horti", "tomb", "farm"]
const F3_KINDS := ["house_house", "house_monument", "house_wall", "house_street", "house_river", "house_base",
	"tree_building", "tree_street", "tree_river", "life_solid", "stall_street", "lamp_smoke"]
const F3_TOL := 0.2            ## interpenetration below this is two walls touching
const F3_CART_HW := 1.05       ## half the width of an ox cart with its pair of oxen (life.gd)

var _f3_prof := {}             ## mesh key -> {bands: [[y0, y1, x0, x1, z0, z1]], plinth: [x0, x1, z0, z1]}
var _f3_found := {}            ## kind -> Array of [score, text]
var _f3_inst: Array = []       ## buildings: {key, kind, c, th, sx, sy, sz, y, ax, az, r, bands: [obb]}
var _f3_grid := {}             ## 20 m cell -> indices into _f3_inst
var _f3_fill: UrbsFill
var _f3_mon_grid := {}         ## 40 m cell -> [monument id, solid obb]


class F3Urbs extends Node3D:
	var streets: UrbsStreets
	var monuments: UrbsMonuments
	var fill: UrbsFill


func _f3_note(kind: String, score: float, text: String) -> void:
	if not _f3_found.has(kind):
		_f3_found[kind] = []
	(_f3_found[kind] as Array).append([score, text])


func _f3_report() -> Dictionary:
	var counts := {}
	var worst := {}
	for k in F3_KINDS:
		var items: Array = _f3_found.get(k, [])
		counts[k] = items.size()
		items.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and str(a[1]) < str(b[1])))
		var keep := []
		for i in mini(items.size(), F3_KEEP):
			keep.append(str(items[i][1]))
		worst[k] = keep
	return {"counts": counts, "worst": worst}


## The whole F3 houses audit for the year (the monuments, streets and terrain are built).
func _f3_houses(height: Callable, radius: float) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	_f3_index_monuments()
	_f3_lay_fill(height, radius)
	_f3_check_houses()
	_f3_check_site_walls()
	_f3_check_trees(radius)
	_f3_check_life(height)
	var rep := _f3_report()
	rep["buildings"] = _f3_inst.size()
	rep["seconds"] = (Time.get_ticks_msec() - t0) / 1000.0
	return rep


# --- profiles ---------------------------------------------------------------------------------

## The clipped part of a triangle between heights y0 and y1, as its xz box, or [] if none.
static func _f3_clip(tri: Array, y0: float, y1: float) -> Array:
	var poly: Array = tri
	for side in 2:
		var lim := y0 if side == 0 else y1
		var out: Array = []
		for i in poly.size():
			var a: Vector3 = poly[i]
			var b: Vector3 = poly[(i + 1) % poly.size()]
			var ina := a.y >= lim if side == 0 else a.y <= lim
			var inb := b.y >= lim if side == 0 else b.y <= lim
			if ina:
				out.append(a)
			if ina != inb and absf(b.y - a.y) > 1e-6:
				out.append(a.lerp(b, (lim - a.y) / (b.y - a.y)))
		poly = out
		if poly.is_empty():
			return []
	var x0 := INF
	var x1 := -INF
	var z0 := INF
	var z1 := -INF
	for v: Vector3 in poly:
		x0 = minf(x0, v.x)
		x1 = maxf(x1, v.x)
		z0 = minf(z0, v.z)
		z1 = maxf(z1, v.z)
	return [x0, x1, z0, z1]


## Height bands of mesh `key` at lod 0 (merged where a band's box is the same as the one below).
func _f3_profile(key: String) -> Dictionary:
	if _f3_prof.has(key):
		return _f3_prof[key]
	var mesh := UrbsFillMeshes.get_mesh(key, 0)
	var boxes := []
	for b in F3_NB:
		boxes.append([INF, -INF, INF, -INF])
	var plinth := [INF, -INF, INF, -INF]
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var n := idx.size() if idx.size() > 0 else v.size()
		for t in range(0, n - 2, 3):
			var a := v[idx[t]] if idx.size() > 0 else v[t]
			var b := v[idx[t + 1]] if idx.size() > 0 else v[t + 1]
			var c := v[idx[t + 2]] if idx.size() > 0 else v[t + 2]
			var ylo := minf(a.y, minf(b.y, c.y))
			var yhi := maxf(a.y, maxf(b.y, c.y))
			if yhi <= 0.01:
				plinth = [minf(plinth[0], minf(a.x, minf(b.x, c.x))), maxf(plinth[1], maxf(a.x, maxf(b.x, c.x))),
					minf(plinth[2], minf(a.z, minf(b.z, c.z))), maxf(plinth[3], maxf(a.z, maxf(b.z, c.z)))]
				continue
			var b0 := clampi(floori(maxf(ylo, 0.0) / F3_BAND), 0, F3_NB - 1)
			var b1 := clampi(floori(yhi / F3_BAND), 0, F3_NB - 1)
			for bi in range(b0, b1 + 1):
				var r := _f3_clip([a, b, c], bi * F3_BAND, (bi + 1) * F3_BAND)
				if r.is_empty() or r[1] - r[0] < 0.0:
					continue
				var bx: Array = boxes[bi]
				boxes[bi] = [minf(bx[0], r[0]), maxf(bx[1], r[1]), minf(bx[2], r[2]), maxf(bx[3], r[3])]
	var bands := []
	for bi in F3_NB:
		var bx: Array = boxes[bi]
		if bx[1] < bx[0]:
			continue
		var y0 := bi * F3_BAND
		if not bands.is_empty():
			var last: Array = bands[-1]
			if is_equal_approx(float(last[1]), y0) and absf(float(last[2]) - float(bx[0])) < 0.05 and absf(float(last[3]) - float(bx[1])) < 0.05 \
					and absf(float(last[4]) - float(bx[2])) < 0.05 and absf(float(last[5]) - float(bx[3])) < 0.05:
				last[1] = y0 + F3_BAND
				continue
		bands.append([y0, y0 + F3_BAND, bx[0], bx[1], bx[2], bx[3]])
	var res := {"bands": bands, "plinth": plinth if plinth[1] >= plinth[0] else []}
	_f3_prof[key] = res
	return res


## World obb {c, ax, az, hx, hz, y0, y1} of a local box [y0, y1, x0, x1, z0, z1] of instance `it`.
static func _f3_obb(it: Dictionary, b: Array) -> Dictionary:
	var lx := (float(b[2]) + float(b[3])) * 0.5 * float(it.sx)
	var lz := (float(b[4]) + float(b[5])) * 0.5 * float(it.sz)
	var ax: Vector2 = it.ax
	var az: Vector2 = it.az
	return {"c": (it.c as Vector2) + ax * lx + az * lz, "ax": ax, "az": az,
		"hx": (float(b[3]) - float(b[2])) * 0.5 * float(it.sx), "hz": (float(b[5]) - float(b[4])) * 0.5 * float(it.sz),
		"y0": float(it.y) + float(b[0]) * float(it.sy), "y1": float(it.y) + float(b[1]) * float(it.sy)}


static func _f3_inside(o: Dictionary, p: Vector2, margin := 0.0) -> bool:
	var d := p - (o.c as Vector2)
	return absf(d.dot(o.ax)) <= float(o.hx) - margin and absf(d.dot(o.az)) <= float(o.hz) - margin


static func _f3_corners(o: Dictionary) -> Array:
	var c: Vector2 = o.c
	var x: Vector2 = (o.ax as Vector2) * float(o.hx)
	var z: Vector2 = (o.az as Vector2) * float(o.hz)
	return [c + x + z, c + x - z, c - x - z, c - x + z, c + x, c - x, c + z, c - z, c]


static func _f3_name(it: Dictionary) -> String:
	return "%s@%.0f,%.0f" % [it.key, (it.c as Vector2).x, (it.c as Vector2).y]


# --- the buildings --------------------------------------------------------------------------------

func _f3_add(key: String, kind: String, c: Vector2, th: float, sx: float, sy: float, sz: float, y: float, extra := {}) -> void:
	var prof := _f3_profile(key)
	var it := {"key": key, "kind": kind, "c": c, "th": th, "sx": sx, "sy": sy, "sz": sz, "y": y,
		"ax": Vector2(cos(th), -sin(th)), "az": Vector2(sin(th), cos(th)), "bands": [], "plinth": {}}
	it.merge(extra)
	var r := 0.0
	for b in prof.bands:
		var o := _f3_obb(it, b)
		(it.bands as Array).append(o)
		r = maxf(r, (o.c as Vector2).distance_to(c) + Vector2(float(o.hx), float(o.hz)).length())
	if not (prof.plinth as Array).is_empty():
		var pl: Array = prof.plinth
		it.plinth = _f3_obb(it, [-UrbsFillParts.SKIRT, 0.0, pl[0], pl[1], pl[2], pl[3]])
	it["r"] = r
	var k := _f3_inst.size()
	_f3_inst.append(it)
	for gz in range(floori((c.y - r) / 20.0), floori((c.y + r) / 20.0) + 1):
		for gx in range(floori((c.x - r) / 20.0), floori((c.x + r) / 20.0) + 1):
			var g := Vector2i(gx, gz)
			if not _f3_grid.has(g):
				_f3_grid[g] = []
			(_f3_grid[g] as Array).append(k)


## Indices of the buildings whose bounding circle may reach within `r` of `p`.
func _f3_near(p: Vector2, r: float) -> Array:
	var out := {}
	for gz in range(floori((p.y - r) / 20.0), floori((p.y + r) / 20.0) + 1):
		for gx in range(floori((p.x - r) / 20.0), floori((p.x + r) / 20.0) + 1):
			for k in _f3_grid.get(Vector2i(gx, gz), []):
				out[k] = true
	return out.keys()


## Lay the fill out as UrbsFill does for urbs.gd and record every building as an instance.
func _f3_lay_fill(height: Callable, radius: float) -> void:
	var fill := UrbsFill.new()
	fill.year = _year
	fill.height = height
	var fps := []
	for id in _mon.ids():
		var b: AABB = _mon.bounds(id)
		if minf(b.size.x, b.size.z) >= 600.0:
			continue
		var bc := b.get_center()
		if maxf(b.size.x, b.size.z) > 120.0 and UrbsSite.platform_at(bc.x, bc.z) != "":
			continue
		fps.append(Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
	fill.footprints = fps
	fill.obstacles = _mon.oriented_footprints()
	fill.prepare()
	_f3_fill = fill
	for key in fill.chunks_in(radius):
		for rk in fill.regions_for_chunk(key):
			while not fill.advance_region(rk, Time.get_ticks_usec() + 1000000000):
				pass
		var buckets := {}
		for lot in fill.lots_for_chunk(key):
			var mk := str(lot["mesh"])
			var kind := str(lot.get("kind", ""))
			if kind in F3_BUILDINGS or mk.begins_with("horti") or mk.begins_with("horrea"):
				var c: Vector2 = lot["c"]
				_f3_add(mk, kind if kind != "" else mk.split(":")[0], c, float(lot["th"]), float(lot["sx"]), float(lot.get("sy", 1.0)), float(lot["sz"]), float(lot["y"]))
			if mk == "horti":
				fill.add_trees(lot, buckets, 0)
		# the horti's own trees: kept for the tree checks
		for tk in buckets:
			for t in buckets[tk]:
				_f3_trees_extra.append({"pos": Vector3((t.c as Vector2).x, float(t.y), (t.c as Vector2).y), "kind": tk, "radius": 2.5 * float(t.sx), "garden": true})
		var st := {}
		fill.rural_step(key, st, Time.get_ticks_usec() + 1000000000)
		var node := Node3D.new()
		fill.rural_build(node, st.get("parcels", []), 0)
		for mmi in node.get_children():
			var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var xf := mm.get_instance_transform(i)
				var sc := xf.basis.get_scale()
				var fwd := xf.basis.z
				_f3_add("rural:farm", "farm", Vector2(xf.origin.x, xf.origin.z), atan2(fwd.x, fwd.z), sc.x, sc.y, sc.z, xf.origin.y)
		node.free()


var _f3_trees_extra: Array = []


func _f3_index_monuments() -> void:
	for id in _obbs:
		if _model(id) in ["wall", "aqueduct", "sewer", "plaza", "road_paved"]:
			continue
		for o in _obbs[id]:
			if float(o.y1) - float(o.y0) < 0.4:
				continue
			var c: Vector2 = o.c
			var r := Vector2(float(o.hx), float(o.hz)).length()
			for gz in range(floori((c.y - r) / 40.0), floori((c.y + r) / 40.0) + 1):
				for gx in range(floori((c.x - r) / 40.0), floori((c.x + r) / 40.0) + 1):
					var g := Vector2i(gx, gz)
					if not _f3_mon_grid.has(g):
						_f3_mon_grid[g] = []
					(_f3_mon_grid[g] as Array).append([id, o])


## Monument solids that hold point `p` (margin m inside) between heights y0 and y1: [[id, obb]].
func _f3_mon_at(p: Vector2, y0: float, y1: float, margin := 0.0) -> Array:
	var out := []
	for e in _f3_mon_grid.get(Vector2i(floori(p.x / 40.0), floori(p.y / 40.0)), []):
		var o: Dictionary = e[1]
		if float(o.y1) <= y0 or float(o.y0) >= y1:
			continue
		if _f3_inside(o, p, margin):
			out.append(e)
	return out


## How far `p` is inside the carriageway of any street (<= 0: not in one), and that street.
func _f3_carriageway(p: Vector2) -> Array:
	var best := -INF
	var sid := ""
	var cell := UrbsStreets.CELL
	var key := Vector2i(floori(p.x / cell), floori(p.y / cell))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for ref in _streets._grid.get(key + Vector2i(dx, dz), []):
				var s: Dictionary = _streets.streets[ref[0]]
				if bool(s.get("stairs", false)):
					continue
				var pts: PackedVector2Array = s.pts
				var q := Geometry2D.get_closest_point_to_segment(p, pts[ref[1]], pts[ref[1] + 1])
				var dep := float(s.hw) - p.distance_to(q)
				if dep > best:
					best = dep
					sid = str(s.id)
	return [best, sid]


## Whether the street `sid` has a raised footway (UrbsFill._has_footway).
func _f3_footway(sid: String) -> bool:
	for s in _streets.streets:
		if str(s.id) == sid:
			return _f3_fill._has_footway(s)
	return false


func _f3_check_houses() -> void:
	var n := _f3_inst.size()
	for i in n:
		var a: Dictionary = _f3_inst[i]
		var ca: Vector2 = a.c
		var name_a := _f3_name(a)
		# --- against the other buildings
		for j in _f3_near(ca, float(a.r)):
			if j <= i:
				continue
			var b: Dictionary = _f3_inst[j]
			if ca.distance_to(b.c) > float(a.r) + float(b.r):
				continue
			var worst := 0.0
			var at := 0.0
			for oa in a.bands:
				for ob in b.bands:
					if minf(float(oa.y1), float(ob.y1)) - maxf(float(oa.y0), float(ob.y0)) < 0.15:
						continue
					var d := _depth(oa, ob)
					if d > worst:
						worst = d
						at = maxf(float(oa.y0), float(ob.y0)) - minf(float(a.y), float(b.y))
			if worst > F3_TOL:
				_f3_note("house_house", worst, "%s overlaps %s by %.1f m (%.0f m up)" % [name_a, _f3_name(b), worst, at])
		# --- against the monuments' solids
		var hits := {}
		for oa in a.bands:
			var c: Vector2 = oa.c
			var reach := Vector2(float(oa.hx), float(oa.hz)).length()
			for gz in range(floori((c.y - reach) / 40.0), floori((c.y + reach) / 40.0) + 1):
				for gx in range(floori((c.x - reach) / 40.0), floori((c.x + reach) / 40.0) + 1):
					for e in _f3_mon_grid.get(Vector2i(gx, gz), []):
						var o: Dictionary = e[1]
						if minf(float(oa.y1), float(o.y1)) - maxf(float(oa.y0), float(o.y0)) < 0.15:
							continue
						var d := _depth(oa, o)
						if d > 0.3 and d > float(hits.get(e[0], 0.0)):
							hits[e[0]] = d
		for id in hits:
			_f3_note("house_monument", hits[id], "%s inside %s by %.1f m" % [name_a, id, hits[id]])
		# --- the streets: the ground storey off the footway, nothing low over the carriageway
		var worst_s := 0.0
		var what := ""
		for oa in a.bands:
			var low := float(oa.y0) - float(a.y) < 2.4
			var over := float(oa.y0) - float(a.y) < 4.5
			if not over:
				continue
			for p in _f3_corners(oa):
				var cw := _f3_carriageway(p)
				var dep: float = cw[0]
				if low and dep > -(UrbsFill.KERB + UrbsFill.FOOTPATH) and _f3_footway(cw[1]):
					var into: float = dep + UrbsFill.KERB + UrbsFill.FOOTPATH
					if into > 0.25 and into > worst_s:
						worst_s = into
						what = "on the footway of %s" % cw[1]
				if dep > 0.1 and dep > worst_s:
					worst_s = dep
					what = "%.0f m up over the carriageway of %s" % [float(oa.y0) - float(a.y), cw[1]]
		if worst_s > 0.0:
			_f3_note("house_street", worst_s, "%s %s by %.1f m" % [name_a, what, worst_s])
		# --- the river and the ground
		var wet := 0
		var buried := 0.0
		var floats := 0.0
		if not (a.bands as Array).is_empty():
			var g0: Dictionary = a.bands[0]
			for p in _f3_corners(g0):
				if UrbsTerrain.in_river(p.x, p.y) or UrbsTerrain.height_at(p.x, p.y) < UrbsTerrain.river_level(p.x, p.y) + 0.2:
					wet += 1
				var gy := UrbsTerrain.height_at(p.x, p.y)
				buried = maxf(buried, gy - float(a.y))
				var pl: Dictionary = a.plinth
				var held := not pl.is_empty() and _f3_inside(pl, p, -0.05)
				var bottom := float(a.y) - (UrbsFillParts.SKIRT * float(a.sy) if held else 0.0)
				if str(a.kind) in ["tomb", "farm"] and not held:
					bottom = float(a.y) + float(g0.y0) - float(a.y)
				floats = maxf(floats, bottom - gy)
		if wet > 0:
			_f3_note("house_river", float(wet), "%s %d of 9 points in the river" % [name_a, wet])
		if buried > 0.35:
			_f3_note("house_base", buried, "%s floor %.1f m under the ground at a corner" % [name_a, buried])
		if floats > 0.3:
			_f3_note("house_base", floats, "%s base %.1f m above the ground at a corner" % [name_a, floats])


## Terrace, platform and clivus walls, steps and quays (UrbsSite) inside a building.
func _f3_check_site_walls() -> void:
	var meshes := []
	var root := Node3D.new()
	var site: Variant = UrbsSite.build(root, _year, Callable(UrbsTerrain, "height_at"))
	var seen_chunks := {}
	for it in _f3_inst:
		var key := Vector2i(floori((it.c as Vector2).x / 250.0), floori((it.c as Vector2).y / 250.0))
		seen_chunks[key] = true
	UrbsTerrain.year = _year
	for key in seen_chunks:
		var w: Variant = UrbsSite.build_chunk_walls(Rect2(Vector2(key) * 250.0, Vector2(250, 250)), 0, _year)
		if w != null:
			root.add_child(w)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mi)
	var hits := {}
	for mi: MeshInstance3D in meshes:
		var mesh := mi.mesh
		if mesh == null:
			continue
		var xf := mi.global_transform if mi.is_inside_tree() else mi.transform
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var n := idx.size() if idx.size() > 0 else v.size()
			for t in range(0, n - 2, 3):
				var p0 := xf * (v[idx[t]] if idx.size() > 0 else v[t])
				var p1 := xf * (v[idx[t + 1]] if idx.size() > 0 else v[t + 1])
				var p2 := xf * (v[idx[t + 2]] if idx.size() > 0 else v[t + 2])
				for w3 in [p0, p1, p2, (p0 + p1) * 0.5, (p1 + p2) * 0.5, (p0 + p2) * 0.5, (p0 + p1 + p2) / 3.0]:
					var q: Vector3 = w3
					var q2 := Vector2(q.x, q.z)
					for k in _f3_near(q2, 0.0):
						var it: Dictionary = _f3_inst[k]
						if str(it.kind) == "horti":
							continue
						var up := q.y - float(it.y)
						if up < 0.08:
							continue   # under the floor: inside the plinth
						for o in it.bands:
							if q.y > float(o.y0) and q.y < float(o.y1) and _f3_inside(o, q2, 0.15):
								var nm := "%s|%s" % [_f3_name(it), mi.name]
								if up > float(hits.get(nm, 0.0)):
									hits[nm] = up
								break
	for nm in hits:
		var parts: PackedStringArray = str(nm).split("|")
		_f3_note("house_wall", hits[nm], "%s has %s %.1f m above its floor inside it" % [parts[0], parts[1], hits[nm]])
	root.free()
	var _u: Variant = site


## Trees (UrbsSiteFlora at lod 0, 1 and 2, the horti's own) against buildings, streets and the river.
func _f3_check_trees(radius: float) -> void:
	UrbsSiteFlora._ensure_meshes()
	var tall := {}
	for kind in UrbsSiteFlora.KINDS:
		tall[kind] = (UrbsSiteFlora._meshes[kind][0] as ArrayMesh).get_aabb()
	for lod in 3:
		for key in _f3_fill.chunks_in(radius):
			var rect := Rect2(Vector2(key) * UrbsFill.CHUNK, Vector2(UrbsFill.CHUNK, UrbsFill.CHUNK))
			for item: Array in UrbsSiteFlora.spots(rect, lod, _year):
				var xf: Transform3D = item[1]
				var bb: AABB = xf * (tall[item[0]] as AABB)
				_f3_tree(str(item[0]), xf.origin, bb, lod, false)
	for t in _f3_trees_extra:
		var p: Vector3 = t.pos
		var r := float(t.radius)
		_f3_tree(str(t.kind), p, AABB(p + Vector3(-r, 2.0, -r), Vector3(2 * r, 6.0, 2 * r)), 0, true)


func _f3_tree(kind: String, p: Vector3, bb: AABB, lod: int, garden: bool) -> void:
	var p2 := Vector2(p.x, p.z)
	var tag := "%s tree at (%.0f, %.0f)%s" % [kind, p.x, p.z, "" if lod == 0 else " (lod %d)" % lod]
	# the crown: the inscribed box of the tree's bounds above its trunk
	var cr := minf(bb.size.x, bb.size.z) * 0.35
	var cy0 := bb.position.y + bb.size.y * 0.35
	var crown := {"c": p2, "ax": Vector2.RIGHT, "az": Vector2.DOWN, "hx": cr, "hz": cr, "y0": cy0, "y1": bb.end.y}
	var worst := 0.0
	var where := ""
	for k in _f3_near(p2, cr + 1.0):
		var it: Dictionary = _f3_inst[k]
		if str(it.kind) == "horti" and garden:
			continue
		if str(it.kind) == "horti" and not _f3_inside(it.bands[0], p2, 3.0):
			pass
		for o in it.bands:
			# the trunk (lower 3 m) inside a building
			if float(o.y0) < p.y + 3.0 and float(o.y1) > p.y + 0.3 and _f3_inside(o, p2, 0.1):
				if str(it.kind) == "horti":
					continue   # a garden estate: its walls enclose trees
				worst = maxf(worst, 9.0)
				where = "trunk inside %s" % _f3_name(it)
				break
			if minf(float(o.y1), crown.y1) - maxf(float(o.y0), crown.y0) < 0.3 or str(it.kind) == "horti":
				continue
			var d := _depth(o, crown)
			if d > 0.6 and d > worst:
				worst = d
				where = "crown %.1f m through %s" % [d, _f3_name(it)]
	if worst > 0.0:
		_f3_note("tree_building", worst + (0.0 if lod == 0 else -0.01 * lod), "%s: %s" % [tag, where])
	var cw := _f3_carriageway(p2)
	if float(cw[0]) > -0.2:
		_f3_note("tree_street", float(cw[0]) + 0.2, "%s in the carriageway of %s (%.1f m in)" % [tag, cw[1], maxf(float(cw[0]), 0.0)])
	if UrbsTerrain.in_river(p.x, p.z) or UrbsTerrain.height_at(p.x, p.z) < UrbsTerrain.river_level(p.x, p.z) + 0.3:
		_f3_note("tree_river", 1.0, "%s in the river" % tag)


## Street life (UrbsLife built as urbs.gd builds it, at the tenth hour and at night).
func _f3_check_life(height: Callable) -> void:
	for hour in [10.0, 21.0]:
		var fake := F3Urbs.new()
		fake.streets = _streets
		fake.monuments = _mon
		fake.fill = _f3_fill
		get_root().add_child(fake)
		var life := UrbsLife.new()
		life.auto_tick = false
		life.near_figures = 0
		fake.add_child(life)
		life.build(fake, _year, hour, height)
		_f3_check_life_once(life, hour)
		fake.queue_free()


## A point inside a building's walls (between y0 and y1 above the ground): the building, or {}.
func _f3_house_at(p: Vector2, y0: float, y1: float, margin := 0.1) -> Dictionary:
	for k in _f3_near(p, 0.0):
		var it: Dictionary = _f3_inst[k]
		if str(it.kind) == "horti":
			continue
		for o in it.bands:
			if float(o.y1) > y0 and float(o.y0) < y1 and _f3_inside(o, p, margin):
				return it
	return {}


func _f3_solid_at(p: Vector2, gy: float, top: float) -> String:
	var hm := _f3_mon_at(p, gy + 0.3, gy + top, 0.05)
	if not hm.is_empty():
		return str(hm[0][0])
	var hh := _f3_house_at(p, gy + 0.3, gy + top)
	return _f3_name(hh) if not hh.is_empty() else ""


func _f3_check_life_once(life: UrbsLife, hour: float) -> void:
	var tag := "%02dh" % int(hour)
	# people standing or crossing (the Forum's groups, the stallholders and their customers)
	for a in life._agents:
		var mode := str(a.get("mode", ""))
		if mode not in ["stand", "plaza"] or not bool(a.get("active", true)):
			continue
		var p: Vector3 = a.pos
		var s := _f3_solid_at(Vector2(p.x, p.z), p.y - 0.2, 1.7)
		if s != "":
			_f3_note("life_solid", 1.0, "%s person (%s) at (%.0f, %.0f) inside %s" % [tag, mode, p.x, p.z, s])
	if hour < 12.0:
		# the lanes: walkers keep within 0.85 of the half width, carts their whole width
		var seen := {}
		for si in _streets.streets.size():
			var st: Dictionary = _streets.streets[si]
			if bool(st.get("stairs", false)):
				continue
			var hw := float(st.hw)
			var length := float(st.len)
			if hw < F3_CART_HW:
				_f3_note("life_solid", F3_CART_HW - hw, "street %s (%.1f m) narrower than a cart" % [st.id, hw * 2.0])
			var d := 1.0
			while d < length - 1.0:
				var sp := _streets.sample_at(si, d)
				var q: Vector2 = sp[0]
				var tg: Vector2 = sp[1]
				var nrm := Vector2(-tg.y, tg.x)
				for lat in [0.85 * hw, -0.85 * hw, minf(F3_CART_HW, hw), -minf(F3_CART_HW, hw)]:
					var pp: Vector2 = q + nrm * float(lat)
					var gy := UrbsTerrain.height_at(pp.x, pp.y)
					var s := _f3_solid_at(pp, gy, 1.7)
					if s != "":
						var k := "%s|%s" % [st.id, s]
						if not seen.has(k):
							seen[k] = true
							_f3_note("life_solid", 0.5, "lane of %s at (%.0f, %.0f) through %s" % [st.id, pp.x, pp.y, s])
				d += 2.0
	# stalls
	var done := {}
	for e in life._stall_inst:
		var c: Vector2 = e[3]
		var ck := "%.1f,%.1f" % [c.x, c.y]
		if done.has(ck):
			continue
		done[ck] = true
		var xf: Transform3D = e[2]
		var fwd := Vector2(xf.basis.z.x, xf.basis.z.z).normalized()
		var side := Vector2(xf.basis.x.x, xf.basis.x.z).normalized()
		var gy := UrbsTerrain.height_at(c.x, c.y)
		var worst := ""
		var score := 0.0
		for u in [-1.1, 0.0, 1.1]:
			for v in [-0.9, 0.0, 1.05]:
				var p: Vector2 = c + side * float(u) + fwd * float(v)
				var s := _f3_solid_at(p, xf.origin.y - 0.1, 2.4)
				if s != "" and score < 2.0:
					worst = "inside %s" % s
					score = 2.0
				var cw := _f3_carriageway(p)
				if float(cw[0]) > 0.05 and score < 1.0 + float(cw[0]):
					worst = "%.1f m into the carriageway of %s" % [float(cw[0]), cw[1]]
					score = 1.0 + float(cw[0])
		if score > 0.0:
			_f3_note("life_solid" if score >= 2.0 else "stall_street", score, "%s stall at (%.0f, %.0f) %s" % [tag, c.x, c.y, worst])
		# its feet on the footway's top where it stands on one
		var cw2 := _f3_carriageway(c)
		var on_fw := float(cw2[0]) > -(UrbsFill.KERB + UrbsFill.FOOTPATH) and float(cw2[0]) < -UrbsFill.KERB and _f3_footway(cw2[1])
		var ground := gy + (UrbsStreets.SURFACE_LIFT + UrbsStreets.FOOTWAY_H if on_fw else 0.0)
		if absf(xf.origin.y - ground) > 0.08:
			_f3_note("stall_street", absf(xf.origin.y - ground), "%s stall at (%.0f, %.0f) %.2f m %s the %s" % [tag, c.x, c.y, absf(xf.origin.y - ground),
				"under" if xf.origin.y < ground else "over", "footway" if on_fw else "ground"])
	# lamps on walls, smoke from roofs (only at night for lamps; smoke by day)
	if hour > 12.0:
		for lp in life._lamps:
			var p2 := Vector2(lp.x, lp.z)
			var wall := false
			for k in _f3_near(p2, 1.0):
				var it: Dictionary = _f3_inst[k]
				for o in it.bands:
					if lp.y > float(o.y0) and lp.y < float(o.y1) and _f3_inside(o, p2, -0.7):
						wall = true
						break
				if wall:
					break
			if not wall and _f3_mon_at(p2, lp.y - 0.5, lp.y + 0.5, -0.7).is_empty():
				_f3_note("lamp_smoke", 1.0, "lamp at (%.0f, %.0f) %.1f m up on no wall" % [lp.x, lp.z, lp.y - UrbsTerrain.height_at(lp.x, lp.z)])
	elif life._smoke != null:
		var mm := life._smoke.multimesh
		var seen := {}
		for i in mm.instance_count:
			var o := mm.get_instance_transform(i).origin
			var k := "%.1f,%.1f" % [o.x, o.z]
			if seen.has(k):
				continue
			seen[k] = true
			var p2 := Vector2(o.x, o.z)
			var roof := false
			for kk in _f3_near(p2, 0.0):
				var it: Dictionary = _f3_inst[kk]
				var top := -INF
				for ob in it.bands:
					if _f3_inside(ob, p2, 0.0):
						top = maxf(top, float(ob.y1))
				if o.y > top - 0.3 and o.y < top + 1.6:
					roof = true
					break
			if not roof:
				_f3_note("lamp_smoke", 0.5, "smoke at (%.0f, %.0f) %.1f m up rises from no roof" % [o.x, o.z, o.y - UrbsTerrain.height_at(o.x, o.z)])
