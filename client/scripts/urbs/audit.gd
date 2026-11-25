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
	_f3_monuments(out.year, args)   # F3 monuments
	out.year.merge(_f3_ground())   # F3 ground (the checks at the end of this file)
	out.year["seconds"] = (Time.get_ticks_msec() - t0) / 1000.0
	print("URBS_AUDIT " + JSON.stringify(out))
	quit()


# F3 monuments (begin) ---------------------------------------------------------------------------
## The monuments as the player sees them, part by part (monument_audit.gd): parts of one inside
## another's, parts resting on nothing, columns sunk, coplanar faces (z-fighting), and the
## `--at` street camera inside a solid or not seeing its monument's front; every enterable
## monument entered: black voids, figures through walls, no interior. --f3-coplanar=0 and
## --f3-interiors=0 skip the slowest.
func _f3_monuments(year_out: Dictionary, args: Dictionary) -> void:
	var t := Time.get_ticks_msec()
	var height := Callable(UrbsTerrain, "height_at")
	var fill := UrbsFill.new()   # the houses, as _houses sets them up (for the camera checks)
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
	var ma := UrbsMonumentAudit.new(_mon, height, fill)
	var res := ma.run(str(args.get("f3-coplanar", "1")) != "0")
	if str(args.get("f3-interiors", "1")) != "0":
		res.merge(ma.interiors(_year))
	for k in res:
		year_out[k] = res[k]
	year_out["f3_monuments_seconds"] = (Time.get_ticks_msec() - t) / 1000.0
# F3 monuments (end) -----------------------------------------------------------------------------


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


# ---------------------------------------------------------------------------------------------
# F3 ground (begin): the ground and what is laid on it, as the chunk meshes draw it. Each check
# returns a list of findings "<what> ..."; the counts go to city_audit.py (SCENE_KINDS, F3 ground).
#   bank_sawtooth    100 m squares where the water's edge (the ground mesh crossing the water
#                    surface, traced triangle by triangle) turns more than 25 degrees within 2 m at
#                    least 3 times: a saw-tooth (the 5 m grid drawn across a curved bank)
#   zfight           two surfaces within 5 cm of each other over the same spot (paving over the
#                    ground, a street over a paving, two streets, a quay over the ground, the
#                    water over a flat bank), or the ground poking through a paving
#   ground_holes     ground missing where the camera can see it: chunks the loader asks for
#                    outside the heightfield, NaN heights, cracks between chunks deeper than the skirt
#   empty_terraces   terrace walls with nothing standing on the tread above them in that year
#                    (per 50 m square), and monument terraces whose monument does not stand
#   platform_steps   a platform more than 1 m above (or below) the street that leads to it or
#                    the ground in front of its monument
#   stair_ends       steps that do not meet the ground at both ends
#   chunk_seams      edges between chunks (within 1.5 km of the Forum) where the meshes of two
#                    neighbouring levels of detail differ by more than 0.25 m in height or 6
#                    degrees in their normals (a step or a seam in the light)
#   streets_ground   stretches of a street strip that sink under the ground mesh or float 0.5 m
#                    above it
# ---------------------------------------------------------------------------------------------

const F3_ZF_M := 0.05


func _f3_ground() -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var root := Node3D.new()
	get_root().add_child(root)
	var st := UrbsStreets.new()
	st.build(root, _year, Callable(UrbsTerrain, "height_at"))
	var res := {
		"bank_sawtooth": _f3_bank_sawtooth(),
		"zfight": _f3_zfight(st),
		"ground_holes": _f3_holes(),
		"empty_terraces": _f3_empty_terraces(),
		"platform_steps": _f3_platform_steps(),
		"stair_ends": _f3_stair_ends(),
		"chunk_seams": _f3_chunk_seams(),
		"streets_ground": _f3_streets_ground(st),
	}
	res["f3_ground_seconds"] = (Time.get_ticks_msec() - t0) / 1000.0
	return res


## The step of the lod-0 chunk mesh at (x, z) (UrbsTerrain.build_chunk).
static func _f3_step(x: float, z: float) -> int:
	var key := Vector2i(floori(x / 250.0), floori(z / 250.0))
	var c := Vector2(key) * 250.0 + Vector2(125.0, 125.0)
	return 1 if c.length() < UrbsTerrain.NEAR_M else 2


static func _f3_ground_y(x: float, z: float) -> float:
	return UrbsTerrain.mesh_height_at(x, z, _f3_step(x, z))


## Upward-facing triangles of some meshes, bucketed on a 4 m grid: {f: PackedVector3Array, g: {}}.
static func _f3_tris(mis: Array, surface := -1) -> Dictionary:
	var faces := PackedVector3Array()
	var grid := {}
	for mi: MeshInstance3D in mis:
		if mi.mesh == null:
			continue
		var xf := _f3_xf(mi)
		for s in mi.mesh.get_surface_count():
			if surface >= 0 and s != surface:
				continue
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var n := ix.size() if ix.size() > 0 else vs.size()
			for t in range(0, n - 2, 3):
				var a := xf * vs[ix[t] if ix.size() > 0 else t]
				var b := xf * vs[ix[t + 1] if ix.size() > 0 else t + 1]
				var c := xf * vs[ix[t + 2] if ix.size() > 0 else t + 2]
				var nrm := (b - a).cross(c - a)
				if nrm.length() < 1e-6 or absf(nrm.normalized().y) < 0.6:
					continue
				var k := faces.size()
				faces.append_array([a, b, c])
				for gx in range(floori(minf(a.x, minf(b.x, c.x)) / 4.0), floori(maxf(a.x, maxf(b.x, c.x)) / 4.0) + 1):
					for gz in range(floori(minf(a.z, minf(b.z, c.z)) / 4.0), floori(maxf(a.z, maxf(b.z, c.z)) / 4.0) + 1):
						var key := Vector2i(gx, gz)
						if not grid.has(key):
							grid[key] = PackedInt32Array()
						grid[key].append(k)
	return {"f": faces, "g": grid}


## A node's transform in the scene (the audit runs before the tree is live: no global_transform).
static func _f3_xf(n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## The highest of the triangles over (x, z), or -INF.
static func _f3_top(tris: Dictionary, p: Vector2) -> float:
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	var best := -INF
	if not (tris.g as Dictionary).has(key):
		return best
	var f: PackedVector3Array = tris.f
	for k: int in tris.g[key]:
		var a := f[k]
		var b := f[k + 1]
		var c := f[k + 2]
		var v0 := Vector2(b.x - a.x, b.z - a.z)
		var v1 := Vector2(c.x - a.x, c.z - a.z)
		var v2 := Vector2(p.x - a.x, p.y - a.z)
		var den := v0.x * v1.y - v1.x * v0.y
		if absf(den) < 1e-9:
			continue
		var u := (v2.x * v1.y - v1.x * v2.y) / den
		var v := (v0.x * v2.y - v2.x * v0.y) / den
		if u < -1e-4 or v < -1e-4 or u + v > 1.0001:
			continue
		best = maxf(best, a.y + u * (b.y - a.y) + v * (c.y - a.y))
	return best


static func _f3_xy(p: Vector2) -> String:
	return "(%.0f, %.0f)" % [p.x, p.y]


# --- the Tiber's banks ---

## The water's edge as the meshes draw it: in each triangle of the lod-0 ground mesh (near the
## river) the line where the ground crosses the water surface (both linear on the same triangles),
## chained into polylines. Returns Array of PackedVector2Array.
func _f3_shorelines() -> Array:
	var segs := []
	for kx in range(-10, 10):
		for kz in range(-10, 10):
			var rect := Rect2(Vector2(kx, kz) * 250.0, Vector2(250.0, 250.0))
			var c := rect.get_center()
			if UrbsTerrain.river_distance(c.x, c.y) > 400.0:
				continue
			var step := _f3_step(c.x, c.y)
			var cell := UrbsTerrain.CELL_M * step
			var nq := int(250.0 / cell)
			for j in nq:
				for i in nq:
					var x0 := rect.position.x + i * cell
					var z0 := rect.position.y + j * cell
					if UrbsTerrain.river_distance(x0, z0) > 220.0:
						continue
					var q := [Vector2(x0, z0), Vector2(x0 + cell, z0), Vector2(x0 + cell, z0 + cell), Vector2(x0, z0 + cell)]
					var f := []
					for v: Vector2 in q:
						f.append(UrbsTerrain.mesh_height_at(v.x, v.y, step) - UrbsTerrain.river_level(v.x, v.y))
					for tri in [[0, 1, 3], [1, 2, 3]]:
						var pts := []
						for e in 3:
							var ia: int = tri[e]
							var ib: int = tri[(e + 1) % 3]
							var fa: float = f[ia]
							var fb: float = f[ib]
							if (fa < 0.0) != (fb < 0.0):
								pts.append((q[ia] as Vector2).lerp(q[ib], fa / (fa - fb)))
						if pts.size() == 2:
							segs.append(pts)
	# chain the segments by their shared ends
	var ends := {}
	for k in segs.size():
		for e in 2:
			var key := Vector2i(roundi(segs[k][e].x * 100.0), roundi(segs[k][e].y * 100.0))
			if not ends.has(key):
				ends[key] = []
			ends[key].append(k)
	var used := {}
	var lines := []
	for k0 in segs.size():
		if used.has(k0):
			continue
		used[k0] = true
		var line: Array = [segs[k0][0], segs[k0][1]]
		for dirn in 2:
			while true:
				var tip: Vector2 = line[line.size() - 1] if dirn == 0 else line[0]
				var key := Vector2i(roundi(tip.x * 100.0), roundi(tip.y * 100.0))
				var nxt := -1
				for k in ends.get(key, []):
					if not used.has(k):
						nxt = k
						break
				if nxt < 0:
					break
				used[nxt] = true
				var a2: Vector2 = segs[nxt][0]
				var b2: Vector2 = segs[nxt][1]
				var other := b2 if a2.distance_to(tip) < 0.02 else a2
				if dirn == 0:
					line.append(other)
				else:
					line.push_front(other)
		lines.append(PackedVector2Array(line))
	return lines


func _f3_bank_sawtooth() -> Array:
	var out := []
	var facing: Dictionary = UrbsTiber.topography().get("terrain_model", {}).get("island_facing", {})
	var faced := not facing.is_empty() and _year >= int(facing.get("from", 0))
	var kinks := {}
	var where := {}
	var quay_lines := []   # the quays' walls (UrbsSite._quays) as polylines
	for q: Dictionary in UrbsTiber.quays():
		if _year >= int(q["from"]):
			var ql := PackedVector2Array()
			var sq := float(q["s0"])
			while sq <= float(q["s1"]):
				ql.append(UrbsTiber.bank_point(sq, float(q["side"]), 0.5))
				sq += 5.0
			quay_lines.append(ql)
	for line: PackedVector2Array in _f3_shorelines():
		# resample every 2 m along the line, then the turn at each point over 2 m either side
		var pts := PackedVector2Array([line[0]])
		var carry := 0.0
		for k in range(1, line.size()):
			var a := line[k - 1]
			var b := line[k]
			var l := a.distance_to(b)
			var t := 2.0 - carry
			while t <= l:
				pts.append(a.lerp(b, t / l))
				t += 2.0
			carry = l - (t - 2.0)
		for k in range(1, pts.size() - 1):
			var p := pts[k]
			if UrbsTiber.island_r(p.x, p.y) < 1.2 and faced:
				continue   # the island's travertine facing stands at its edge
			var quay := false
			for ql: PackedVector2Array in quay_lines:
				for k2 in range(ql.size() - 1):
					if Geometry2D.get_closest_point_to_segment(p, ql[k2], ql[k2 + 1]).distance_to(p) < 6.0:
						quay = true
						break
			if quay:
				continue   # a quay's wall stands at the water
			if rad_to_deg(absf((pts[k] - pts[k - 1]).angle_to(pts[k + 1] - pts[k]))) > 25.0:
				var key := Vector2i(floori(p.x / 100.0), floori(p.y / 100.0))
				kinks[key] = int(kinks.get(key, 0)) + 1
				where[key] = p
	var keys := kinks.keys()
	keys.sort()
	for key: Vector2i in keys:
		if int(kinks[key]) >= 3:
			out.append("the water's edge turns more than 25 degrees within 2 m %d times in the 100 m square near %s" % [kinks[key], _f3_xy(where[key])])
	return out


# --- surfaces on top of one another ---

func _f3_plazas() -> Dictionary:
	var out := {}
	var ids: Array = _mon.ids()
	ids.sort()
	for id: String in ids:
		if _model(id) != "plaza" or not _mon._nodes.has(id):
			continue
		var mis: Array = (_mon._nodes[id] as Node).find_children("*", "MeshInstance3D", true, false)
		out[id] = _f3_tris(mis)
	return out


func _f3_zfight(st: UrbsStreets) -> Array:
	var out := []
	var plazas := _f3_plazas()
	# paving over the ground: within 5 cm, or under it
	for id: String in plazas:
		var r := _footprint(id)
		if r.is_empty():
			continue
		var close := 0
		var under := 0
		var worst := INF
		var at := Vector2.ZERO
		var i := -float(r.hx) + 1.0   # from 1 m inside its edge (at the edge the two only meet)
		while i < float(r.hx) - 0.99:
			var j := -float(r.hz) + 1.0
			while j < float(r.hz) - 0.99:
				var p: Vector2 = (r.c as Vector2) + (r.ax as Vector2) * i + (r.az as Vector2) * j
				var top := _f3_top(plazas[id], p)
				if top > -INF and UrbsTerrain.ground_drawn_at(p.x, p.y, _f3_step(p.x, p.y)):
					var gap := top - _f3_ground_y(p.x, p.y)
					if gap < worst:
						worst = gap
						at = p
					if gap < 0.0:
						under += 1
					elif gap < F3_ZF_M:
						close += 1
				j += 1.0
			i += 1.0
		if close > 2:
			out.append("%s paving within 5 cm of the ground over %d m2 near %s" % [id, close, _f3_xy(at)])
		if under > 2:
			out.append("%s paving under the ground over %d m2 (worst %.2f m) near %s" % [id, under, -worst, _f3_xy(at)])
	# streets: over a paving, over another street
	var strips := {}
	for mi: Node in st._root.get_children():
		if mi is MeshInstance3D:
			strips[str(mi.name)] = _f3_tris([mi], 0)
	var seen := {}
	var hits := {}   # a pair counts once it is within 5 cm at two neighbouring samples (not where two surfaces merely cross)
	for si in st.streets.size():
		var s: Dictionary = st.streets[si]
		if bool(s.get("stairs", false)) or not strips.has(str(s.id)):
			continue
		var own: Dictionary = strips[str(s.id)]
		var d := 0.0
		while d <= float(s.len):
			var arr := st.sample_at(si, d)
			var p: Vector2 = arr[0]
			var y := _f3_top(own, p)
			if y > -INF:
				for pid: String in plazas:
					var key := "%s|%s" % [s.id, pid]
					if seen.has(key):
						continue
					var top := _f3_top(plazas[pid], p)
					if top > -INF and absf(top - y) < F3_ZF_M:
						hits[key] = int(hits.get(key, 0)) + 1
						if int(hits[key]) >= 2:
							seen[key] = true
							out.append("street %s within 5 cm of the %s paving at %s" % [s.id, pid, _f3_xy(p)])
					else:
						hits[key] = 0
				for oid: String in strips:
					if oid == str(s.id):
						continue
					var key := "%s|%s" % [oid, s.id] if oid < str(s.id) else "%s|%s" % [s.id, oid]
					if seen.has(key):
						continue
					var y2 := _f3_top(strips[oid], p)
					if y2 > -INF and absf(y2 - y) < F3_ZF_M:
						hits[key] = int(hits.get(key, 0)) + 1
						if int(hits[key]) >= 2:
							seen[key] = true
							out.append("streets %s and %s within 5 cm of each other at %s" % [s.id, oid, _f3_xy(p)])
					else:
						hits[key] = 0
			d += 2.0
	# the quays' paving over the ground; the water over a flat bank
	var works := Node3D.new()
	get_root().add_child(works)
	UrbsSite.build(works, _year, Callable(UrbsTerrain, "height_at"))
	var quay_mis: Array = works.find_children("*", "MeshInstance3D", true, false)
	var qt := _f3_tris(quay_mis)
	for q: Dictionary in UrbsTiber.quays():
		if _year < int(q["from"]):
			continue
		var bad := 0
		var at := Vector2.ZERO
		var s := float(q["s0"])
		while s < float(q["s1"]):
			for off in [6.0, 15.0, 25.0, 34.0]:
				var p := UrbsTiber.bank_point(s, float(q["side"]), off)
				var top := _f3_top(qt, p)
				if top > -INF and top - _f3_ground_y(p.x, p.y) < F3_ZF_M:
					bad += 1
					at = p
			s += 2.0
		if bad > 2:
			out.append("quay %s paving within 5 cm of (or under) the ground at %d points near %s" % [q["id"], bad, _f3_xy(at)])
	works.queue_free()
	var flat := {}
	var where := {}
	var x := -2400.0
	while x < 2400.0:
		var z := -2400.0
		while z < 2400.0:
			if UrbsTerrain.river_distance(x, z) < 200.0:
				var wl := UrbsTerrain.river_level(x, z)
				var g := _f3_ground_y(x, z)
				if absf(g - wl) < F3_ZF_M:
					var gx := absf(_f3_ground_y(x + 1.0, z) - _f3_ground_y(x - 1.0, z)) * 0.5
					var gz := absf(_f3_ground_y(x, z + 1.0) - _f3_ground_y(x, z - 1.0)) * 0.5
					if gx < 0.03 and gz < 0.03:
						var key := Vector2i(floori(x / 100.0), floori(z / 100.0))
						flat[key] = int(flat.get(key, 0)) + 1
						where[key] = Vector2(x, z)
			z += 2.0
		x += 2.0
	var fk := flat.keys()
	fk.sort()
	for key: Vector2i in fk:
		if int(flat[key]) * 4 >= 40:
			out.append("tiber water within 5 cm of a flat bank over %d m2 near %s" % [int(flat[key]) * 4, _f3_xy(where[key])])
	return out


# --- holes ---

func _f3_holes() -> Array:
	var out := []
	var h := UrbsTerrain.field()
	var nan := 0
	for v in h:
		if is_nan(v) or is_inf(v):
			nan += 1
	if nan > 0:
		out.append("heightfield: %d NaN or infinite heights" % nan)
	# the loader asks for chunks within UrbsGeo.RADIUS_M (+ a chunk) of the Forum (chunks.gd _plan)
	var reach := int(ceil((UrbsGeo.RADIUS_M + 250.0) / 250.0))
	var b := UrbsTerrain.bounds()
	var missing := 0
	for kx in range(-reach, reach):
		for kz in range(-reach, reach):
			var r := Rect2(Vector2(kx, kz) * 250.0, Vector2(250.0, 250.0))
			if r.get_center().length() > UrbsGeo.RADIUS_M + 250.0:
				continue
			if b.encloses(r):
				continue
			var m := UrbsTerrain.chunk_mesh(r, 2)
			var ab := m.get_aabb() if m != null and m.get_surface_count() > 0 else AABB()
			if ab.size.x < 249.0 or ab.size.z < 249.0:
				missing += 1
	if missing > 0:
		out.append("%d chunks the loader can ask for lie outside the heightfield (%s) and have no ground" % [missing, b])
	return out


# --- terraces ---

func _f3_empty_terraces() -> Array:
	var out := []
	# monument terraces (topography.yaml platforms with `monument`) stamped while their monument is absent
	var model: Dictionary = UrbsTiber.topography().get("terrain_model", {})
	for pf: Dictionary in model.get("platforms", []):
		var mid := str(pf.get("monument", ""))
		if mid == "" or _mon.ids().has(mid):
			continue
		for live: Dictionary in UrbsTerrain.platforms():
			if str(live["id"]) == str(pf.id):
				out.append("terrace %s cut and walled, but %s does not stand in %d" % [pf.id, mid, _year])
	# hillside terrace walls with nothing on the tread above: the walls as UrbsChunks stands them
	# (UrbsSite.build_chunk_walls with the houses of the chunk and its neighbours)
	var keys := {}
	for kx in range(-10, 10):
		for kz in range(-10, 10):
			if not UrbsSite.terrace_wall_segments(Rect2(Vector2(kx, kz) * 250.0, Vector2(250.0, 250.0))).is_empty():
				keys[Vector2i(kx, kz)] = true
	if keys.is_empty():
		return out
	var lf := _f3_lots(keys.keys())
	var lots: Dictionary = lf[0]
	var segs := []
	for key: Vector2i in keys:
		var near: Array = []
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				near.append(key + Vector2i(dx, dz))
		segs.append_array(UrbsSite.terrace_wall_segments(Rect2(Vector2(key) * 250.0, Vector2(250.0, 250.0)), UrbsSite.wall_uses(lf[1], near)))
	var fps := []
	for id in _mon.ids():
		var r := _footprint(id)
		if not r.is_empty() and _model(id) not in ["wall", "aqueduct", "sewer"]:
			fps.append(r)
	var empty := {}
	var where := {}
	for w: Array in segs:
		var a: Vector2 = w[0]
		var bb: Vector2 = w[1]
		var dn: Vector2 = w[2]
		var mid := (a + bb) * 0.5
		var tread := mid - dn * 4.0
		var used := false
		for lr: Dictionary in lots.get(Vector2i(floori(tread.x / 20.0), floori(tread.y / 20.0)), []):
			if _contains(lr, tread, -4.0):
				used = true
				break
		if not used:
			for r: Dictionary in fps:
				if (r.c as Vector2).distance_to(tread) < float(r.hx) + float(r.hz) + 6.0 and _contains(r, tread, -6.0):
					used = true
					break
		if not used:
			var ns := _streets.nearest_street(tread)
			used = not ns.is_empty() and float(ns.distance) < float(ns.half_width) + 4.0
		if not used:
			var key := Vector2i(floori(mid.x / 50.0), floori(mid.y / 50.0))
			empty[key] = float(empty.get(key, 0.0)) + a.distance_to(bb)
			where[key] = mid
	var ek := empty.keys()
	ek.sort()
	for key: Vector2i in ek:
		if float(empty[key]) >= 5.0:
			out.append("terrace walls across empty ground near %s: %.0f m" % [_f3_xy(where[key]), empty[key]])
	return out


## The fill's house lots in these 250 m chunks, as rectangles bucketed on a 20 m grid, and the fill.
func _f3_lots(chunk_keys: Array) -> Array:
	var fill := UrbsFill.new()
	fill.year = _year
	fill.height = Callable(UrbsTerrain, "height_at")
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
	var grid := {}
	for key: Vector2i in chunk_keys:
		for rk in fill.regions_for_chunk(key):
			while not fill.advance_region(rk, Time.get_ticks_usec() + 1000000000):
				pass
		for lot in fill.lots_for_chunk(key):
			var lr := _lot_rect(lot)
			var c: Vector2 = lot["c"]
			var reach := float(lr.hx) + float(lr.hz) + 4.0
			for gx in range(floori((c.x - reach) / 20.0), floori((c.x + reach) / 20.0) + 1):
				for gz in range(floori((c.y - reach) / 20.0), floori((c.y + reach) / 20.0) + 1):
					var g := Vector2i(gx, gz)
					if not grid.has(g):
						grid[g] = []
					grid[g].append(lr)
	return [grid, fill]


# --- platforms against what leads to them ---

func _f3_platform_steps() -> Array:
	var out := []
	for pid: String in UrbsSite.platform_ids():
		var pf := UrbsSite.platform(pid)
		var poly: PackedVector2Array = pf.polygon
		# streets that end at the platform (and at no other floor of their own level)
		for s: Dictionary in _streets.streets:
			var pts: PackedVector2Array = s.pts
			for e in [pts[0], pts[pts.size() - 1]]:
				var p: Vector2 = e
				if Geometry2D.is_point_in_polygon(p, poly):
					continue
				var road := _f3_ground_y(p.x, p.y)
				var near := INF
				var edge := p
				for i in poly.size():
					var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
					if q.distance_to(p) < near:
						near = q.distance_to(p)
						edge = q
				if near > 15.0:
					continue
				var lvl := UrbsSite.platform_level(pf, edge.x)
				var other := false   # the street leads to another floor at its own level
				for oid: String in UrbsSite.platform_ids():
					if oid == pid:
						continue
					var opf := UrbsSite.platform(oid)
					var opoly: PackedVector2Array = opf.polygon
					var od := 0.0 if Geometry2D.is_point_in_polygon(p, opoly) else INF
					for i in opoly.size():
						od = minf(od, Geometry2D.get_closest_point_to_segment(p, opoly[i], opoly[(i + 1) % opoly.size()]).distance_to(p))
					if od < 15.0 and absf(UrbsSite.platform_level(opf, p.x) - road) <= 1.0:
						other = true
				if not other and absf(lvl - road) > 1.0:
					out.append("platform %s stands %.1f m %s the end of street %s at %s" % [pid, absf(lvl - road), "above" if lvl > road else "below", s.id, _f3_xy(p)])
		# the ground in front of the monument it carries
		var mid := pid if _mon.ids().has(pid) else ""
		for rec: Dictionary in (UrbsTiber.topography().get("terrain_model", {}) as Dictionary).get("platforms", []):
			if str(rec.get("id", "")) == pid and str(rec.get("monument", "")) != "":
				mid = str(rec["monument"]) if _mon.ids().has(str(rec["monument"])) else ""
		if mid == "" or _model(mid) in ["servian_gate", "arch", "plaza"]:
			continue
		var r := _footprint(mid)
		if r.is_empty():
			continue
		# the front: monuments.gd turns a model's +z (az) to its bearing
		var dir: Vector2 = r.az
		var far := 0.0
		var lvl := 0.0
		var p := r.c as Vector2
		while far < 200.0 and Geometry2D.is_point_in_polygon(p, poly):
			far += 1.0
			p = (r.c as Vector2) + dir * far
		lvl = UrbsSite.platform_level(pf, p.x)
		var q := p + dir * 4.0
		var g := _f3_ground_y(q.x, q.y)
		if UrbsTerrain.river_distance(q.x, q.y) < UrbsTerrain.river_half_width(q.x, q.y) + 40.0:
			continue   # it faces the river: the ground falls to the water (the Theatre of Marcellus)
		if lvl - g > 1.0:
			out.append("platform %s stands %.1f m over the ground in front of %s at %s" % [pid, lvl - g, mid, _f3_xy(q)])
	return out


# --- steps ---

func _f3_stair_ends() -> Array:
	var out := []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(UrbsTerrain.STREETS_PATH))
	if not parsed is Dictionary:
		return out
	for entry: Dictionary in parsed.get("streets", []):
		if str(entry.get("kind", "")) != "stairs":
			continue
		var from_y: Variant = entry.get("exists_from")
		if from_y != null and int(from_y) > _year:
			continue
		var raw := PackedVector2Array()
		for ll in entry["points"]:
			raw.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
		var pts := UrbsStreets._smooth(raw, 2)
		for end in 2:
			var p := pts[0] if end == 0 else pts[pts.size() - 1]
			var q := pts[1] if end == 0 else pts[pts.size() - 2]
			var beyond := p + (p - q).normalized() * 2.0
			var step_y := UrbsTerrain.height_at(p.x, p.y)
			var g := _f3_ground_y(beyond.x, beyond.y)
			if absf(step_y - g) > 0.35:
				out.append("stairs %s %s step %.1f m %s the ground beyond it at %s" % [entry.id, "first" if end == 0 else "last", absf(step_y - g), "above" if step_y > g else "below", _f3_xy(p)])
	return out


# --- chunk seams ---

## The top vertices of a chunk mesh on one side (0 east x = end, 1 west x = start, 2 south z = end,
## 3 north z = start), sorted along it: [[t, y, normal]].
func _f3_edge(mesh: ArrayMesh, rect: Rect2, side: int) -> Array:
	var arr := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var line := rect.end.x if side == 0 else (rect.position.x if side == 1 else (rect.end.y if side == 2 else rect.position.y))
	var best := {}
	for k in vs.size():
		var v := vs[k]
		var on := v.x if side <= 1 else v.z
		if absf(on - line) > 0.01:
			continue
		var t := snappedf(v.z if side <= 1 else v.x, 0.01)
		if not best.has(t) or float(best[t][1]) < v.y:
			best[t] = [t, v.y, ns[k]]
	var out := best.values()
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


## [y, normal] on an edge polyline at t (linear between its vertices, as the GPU draws it).
static func _f3_edge_at(e: Array, t: float) -> Array:
	for k in range(e.size() - 1):
		if t <= float(e[k + 1][0]) + 1e-4:
			var f := clampf((t - float(e[k][0])) / maxf(float(e[k + 1][0]) - float(e[k][0]), 1e-4), 0.0, 1.0)
			return [lerpf(e[k][1], e[k + 1][1], f), (e[k][2] as Vector3).lerp(e[k + 1][2], f).normalized()]
	return [e[e.size() - 1][1], e[e.size() - 1][2]]


func _f3_chunk_seams() -> Array:
	var out := []
	var meshes := {}
	var mesh_of := func(key: Vector2i, lod: int) -> ArrayMesh:
		var mk := Vector3i(key.x, key.y, lod)
		if not meshes.has(mk):
			meshes[mk] = UrbsTerrain.chunk_mesh(Rect2(Vector2(key) * 250.0, Vector2(250.0, 250.0)), lod)
		return meshes[mk]
	for kx in range(-6, 6):
		for kz in range(-6, 6):
			var ka := Vector2i(kx, kz)
			var ra := Rect2(Vector2(ka) * 250.0, Vector2(250.0, 250.0))
			for edge in 2:   # the east and the south neighbour
				var kb := ka + (Vector2i(1, 0) if edge == 0 else Vector2i(0, 1))
				var rb := Rect2(Vector2(kb) * 250.0, Vector2(250.0, 250.0))
				var gap := 0.0
				var ang := 0.0
				var at := Vector2.ZERO
				var lods := [[0, 1], [1, 0], [1, 2], [2, 1]]
				if (ra.get_center().length() < UrbsTerrain.NEAR_M) != (rb.get_center().length() < UrbsTerrain.NEAR_M):
					lods.append([0, 0])
				for lp: Array in lods:
					var ea := _f3_edge(mesh_of.call(ka, lp[0]), ra, 0 if edge == 0 else 2)
					var eb := _f3_edge(mesh_of.call(kb, lp[1]), rb, 1 if edge == 0 else 3)
					if ea.size() < 2 or eb.size() < 2:
						continue
					var ts := {}
					for v in ea:
						ts[v[0]] = true
					for v in eb:
						ts[v[0]] = true
					for t: float in ts:
						var a := _f3_edge_at(ea, t)
						var b := _f3_edge_at(eb, t)
						var g := absf(float(a[0]) - float(b[0]))
						var an := rad_to_deg((a[1] as Vector3).angle_to(b[1]))
						if g > gap or an > ang:
							at = Vector2(ra.end.x, t) if edge == 0 else Vector2(t, ra.end.y)
						gap = maxf(gap, g)
						ang = maxf(ang, an)
				if gap > 0.25 or ang > 6.0:
					out.append("chunk edge %s-%s near %s: levels of detail differ by %.2f m and %.0f degrees" % [ka, kb, _f3_xy(at), gap, ang])
	return out


# --- streets on the ground ---

func _f3_streets_ground(st: UrbsStreets) -> Array:
	var out := []
	var strips := {}
	for mi: Node in st._root.get_children():
		if mi is MeshInstance3D:
			strips[str(mi.name)] = _f3_tris([mi], 0)
	var plazas := _f3_plazas()
	for mi: Node in st._root.get_children():
		if not mi is MeshInstance3D:
			continue
		var sid := str(mi.name)
		var tris: Dictionary = strips[sid]
		var idx := -1
		for i in st.streets.size():
			if str(st.streets[i].id) == sid:
				idx = i
		if idx < 0:
			continue
		var s: Dictionary = st.streets[idx]
		var hw := float(s.hw)
		var sunk := 0
		var floating := 0
		var worst_s := 0.0
		var worst_f := 0.0
		var at_s := Vector2.ZERO
		var at_f := Vector2.ZERO
		var d := 0.5
		while d < float(s.len):
			var arr := st.sample_at(idx, d)
			if absf((arr[0] as Vector2).x) > 2450.0 or absf((arr[0] as Vector2).y) > 2450.0:
				d += 1.0
				continue   # beyond the heightfield (ground_holes)
			var c: Vector2 = arr[0]
			var t: Vector2 = arr[1]
			var nrm := Vector2(-t.y, t.x)
			var bad_s := false
			var bad_f := false
			for off in [-hw + 0.3, -hw * 0.5, 0.0, hw * 0.5, hw - 0.3]:
				var p: Vector2 = c + nrm * off
				var y := _f3_top(tris, p)
				if y == -INF or not UrbsTerrain.ground_drawn_at(p.x, p.y, _f3_step(p.x, p.y)):
					continue
				var hidden := false   # another street or a paving lies over this one here
				for oid: String in strips:
					if oid != sid and _f3_top(strips[oid], p) > y + 0.02:
						hidden = true
				for pid: String in plazas:
					if _f3_top(plazas[pid], p) > y:
						hidden = true
				if hidden:
					continue
				var g := _f3_ground_y(p.x, p.y)
				if y - g < 0.02:
					bad_s = true
					if g - y > worst_s:
						worst_s = g - y
						at_s = p
				elif y - g > 0.5:
					bad_f = true
					if y - g > worst_f:
						worst_f = y - g
						at_f = p
			sunk += 1 if bad_s else 0
			floating += 1 if bad_f else 0
			d += 1.0
		if sunk >= 2:
			out.append("street %s under the ground over %d m (worst %.2f m) near %s" % [sid, sunk, worst_s, _f3_xy(at_s)])
		if floating >= 2:
			out.append("street %s floating over the ground over %d m (worst %.2f m) near %s" % [sid, floating, worst_f, _f3_xy(at_f)])
	return out
# F3 ground (end)
