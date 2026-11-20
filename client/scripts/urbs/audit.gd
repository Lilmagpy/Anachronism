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
		if hi - base > BURY_M:
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
