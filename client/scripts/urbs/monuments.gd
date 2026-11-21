## Urbs (U3): every monument of Rome, placed, dated, oriented and clickable.
##
## Reads client/data/city/monuments.json (and monuments_empire.json if present), keeps what
## stands in a given year, puts each at UrbsGeo.to_local(lat, lon) on the ground, turned to its
## `bearing_deg`, built to its `footprint_m` by its `model` key (monument_forms.gd, which calls
## the Roman kit in scripts/models/roman.gd where it has the form).
##
## Which state a monument is in, in a year (see state_at):
##   before its first year        absent
##   work begun, not dedicated    "building": foundations and scaffolding (field `construction`)
##   standing                     its model; `phases` change the state, model or variant by year
##   burnt, not yet rebuilt       "burnt": a blackened shell (phases state: burnt)
##   `ended` or phase gone        absent
##
## Interface used by urbs.gd: build(urbs, year, height), ids(), bounds(id), info(id), entrance(id),
## entry(id), footprints(); also pick(camera, screen_pos), set_year(year), report().
## Every monument also gets a StaticBody3D (collision layer 20) with metadata `monument_id`.
class_name UrbsMonuments
extends RefCounted

const Forms := preload("res://scripts/urbs/monument_forms.gd")
const Kit := preload("res://scripts/models/kit.gd")

const FILES := ["res://data/city/monuments.json", "res://data/city/monuments_empire.json", "res://data/city/monuments_domus.json"]   # F2 play: the houses of the great families
const PICK_LAYER := 20
const FAR := -100000   ## year of a monument whose date is unknown: it stands from the start

var _recs := {}          ## id -> dataset record
var _order: Array = []   ## sorted ids
var _root: Node3D
var _year := 0
var _height := Callable()
var _material: ShaderMaterial
var _nodes := {}         ## id -> Node3D
var _keys := {}          ## id -> state key (to rebuild only what changed)
var _placed := {}        ## id -> {centre: Vector2, yaw, y, length, width, radius, model, state}
var _bounds := {}        ## id -> AABB (local metres)
var _boxes := {}         ## id -> Array of {centre, size} in world axes (for picking)
var _kinds := {}         ## id -> "kit"|"own"|"placeholder"|"site"|"ruin"
var _todo := {}          ## model -> what the kit agent could add
var _routes := {}        ## id -> PackedVector2Array
var _empire := {}        ## ids from monuments_empire.json
var _circ := {}          ## the gate circuit (see _circuit)
var _solids := {}        ## id -> Array of AABB in the monument's own frame (walls, podia, roofs)
var _opens := {}         ## id -> Array of AABB in its frame: courts and plazas (walked on, never picked)
var _xf := {}            ## id -> Transform3D of the monument's frame
var _tris := {}          ## id -> [triangles at lod 0, 1, 2]


func _init() -> void:
	for path in FILES:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for m in parsed.get("monuments", []):
				_recs[str(m["id"])] = m
				if path.contains("empire"):
					_empire[str(m["id"])] = true
	_order = _recs.keys()
	_order.sort()
	for id in _order:
		var m: Dictionary = _recs[id]
		var route := PackedVector2Array()
		for p in m.get("route", []):
			route.append(UrbsGeo.to_local(float(p[0]), float(p[1])))
		if route.size() > 0:
			_routes[id] = route


## Builds the monuments standing in `year` under `urbs`. `height` is (x, z) -> y of the ground
## (flat y = 10 when empty).
func build(urbs: Node3D, year: int, height: Callable = Callable()) -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_nodes.clear()
	_keys.clear()
	_placed.clear()
	_bounds.clear()
	_boxes.clear()
	_kinds.clear()
	_solids.clear()
	_opens.clear()
	_xf.clear()
	_tris.clear()
	_root = Node3D.new()
	_root.name = "Monuments"
	urbs.add_child(_root)
	_height = height
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/models.gdshader")
	set_year(year)


## Brings the city to `year`: builds what has appeared or changed, removes what is gone.
func set_year(year: int) -> void:
	_year = year
	if _root == null:
		return
	# F3 monuments: the routes (the wall, the aqueducts) after everything else, so they stop where
	# a standing monument stands on their line (route_cuts)
	# and a monument that yields to another (`yields_to`, monument_clip.gd) after that one
	for pass_ in 3:
		for id in _order:
			var is_route := str(_recs[id].get("model", "")) in ROUTE_CUT
			var yields: bool = not is_route and _recs[id].get("yields_to") is Array
			var want := 2 if is_route else (1 if yields else 0)
			if want == pass_:
				_set_one(id, year)
	_fit_sizes()   # F3 monuments


## F3 monuments: one monument brought to `year` (the body of set_year's loop).
func _set_one(id: String, year: int) -> void:
	var st := state_at(id, year)
	if not st.is_empty() and str(st.model) in ROUTE_CUT:   # F3 monuments
		st["cuts"] = route_cuts(id, str(st.model))
	if not st.is_empty() and _recs[id].get("yields_to") is Array:   # F3 monuments
		var ys: Array = []
		for oid in _recs[id]["yields_to"]:
			if _solids.has(str(oid)):
				ys.append({"id": "%s=%s" % [oid, _keys.get(str(oid), "")], "oid": str(oid)})
		st["yields"] = ys
	var key := _key(st)
	if key == _keys.get(id, "|absent"):
		return
	if _nodes.has(id):
		(_nodes[id] as Node3D).queue_free()
		_nodes.erase(id)
		_placed.erase(id)
		_bounds.erase(id)
		_boxes.erase(id)
		_solids.erase(id)
		_opens.erase(id)
		_xf.erase(id)
		_tris.erase(id)
	_keys[id] = key
	if not st.is_empty():
		_make(id, st)


func _key(st: Dictionary) -> String:
	if st.is_empty():
		return "|absent"
	var cut := ""   # F3 monuments: the monuments a route stops at, or this one yields to
	for c in st.get("cuts", []) + st.get("yields", []):
		cut += "|" + str(c.id)
	return "%s|%s|%s|%s|%s|%s|%s%s" % [st.state, st.model, st.variant, st.length, st.width, st.radius, st.height, cut]


# F3 monuments (begin) ----------------------------------------------------------------------------
## Route forms that stop where a standing monument stands on their line: the Servian wall at its
## gates and at the buildings later raised over it (the Theatre of Marcellus, the Porticus inter
## lignarios, the temples by the Quirinal gates), the Appia's arches at the Porta Capena.
const ROUTE_CUT := ["wall", "aqueduct"]
## Footprints a route does not stop at: open pavings (the route stands on them), the river works,
## other routes.
const ROUTE_PASS := ["wall", "aqueduct", "sewer", "road_paved", "plaza", "lacus_curtius", "comitium",
	"bridge_stone", "bridge_timber", "quay"]


## Footprints an assumed size does not have to clear: open pavings, routes, the river works.
const FIT_PASS := ["wall", "aqueduct", "sewer", "road_paved", "plaza", "bridge_stone", "bridge_timber", "quay"]


## The oriented footprints of the standing monuments within 60 m of route `id`'s line, sorted by
## id: {id, c, ax, az, hx, hz}. The route's tiles keep off them (monument_forms.gd _route_runs).
func route_cuts(id: String, model: String) -> Array:
	var route: PackedVector2Array = _circuit().pos if model == "wall" else _routes.get(id, PackedVector2Array())
	var out: Array = []
	if route.size() < 2:
		return out
	var fps := oriented_footprints()
	fps.sort_custom(func(a, b): return str(a.id) < str(b.id))
	for f0 in fps:
		if str(_placed.get(f0.id, {}).get("model", "")) in ROUTE_PASS:
			continue
		var f := _drawn_rect(f0)
		var r := Vector2(float(f.hx), float(f.hz)).length() + 60.0
		var c: Vector2 = f.c
		for k in range(1, route.size()):
			var q := Geometry2D.get_closest_point_to_segment(c, route[k - 1], route[k])
			if q.distance_to(c) <= r:
				out.append(f)
				break
	return out


## F3 monuments: a monument whose size is ASSUMED (its record's `size_fits: true`: no measured
## plan, the kit's or the model's default size) and that runs into a standing neighbour is made
## smaller, evenly, in steps of 5 % down to 70 %, until it clears every other standing
## monument's drawn footprint (pavings and routes aside). Its centre, bearing and form stay.
func _fit_sizes() -> void:
	for id in _order:
		if not bool(_recs[id].get("size_fits", false)) or not _placed.has(id):
			continue
		var st := state_at(id, _year)
		if st.is_empty() or str(st.state) != "standing":
			continue
		var me := _my_rect(id)
		if _worst_depth(id, me) <= 0.05:
			continue
		var w0 := float(me.hx) * 2.0
		var l0 := float(me.hz) * 2.0
		for k in [0.95, 0.9, 0.85, 0.8, 0.75, 0.7]:
			var st2 := st.duplicate()
			st2.width = w0 * float(k)
			st2.length = l0 * float(k)
			_unmake(id)
			_make(id, st2)
			_keys[id] = _key(st) + "|fit%.2f" % float(k)
			if _worst_depth(id, _my_rect(id)) <= 0.05:
				break


## The box of a monument as drawn at the nearest level of detail (every mesh and instance), in
## its frame (AABB() when it has nothing drawn).
func _drawn_box(id: String) -> AABB:
	var out := AABB()
	var first := true
	if not _nodes.has(id):
		return out
	for ch in (_nodes[id] as Node3D).get_children():
		var boxes: Array = []
		if ch is MeshInstance3D and (ch as MeshInstance3D).visibility_range_begin <= 0.0 and (ch as MeshInstance3D).mesh != null:
			boxes.append((ch as MeshInstance3D).transform * (ch as MeshInstance3D).mesh.get_aabb())
		elif ch is MultiMeshInstance3D and (ch as MultiMeshInstance3D).visibility_range_begin <= 0.0:
			var mm := (ch as MultiMeshInstance3D).multimesh
			if mm != null and mm.mesh != null:
				for k in mm.instance_count:
					boxes.append((ch as MultiMeshInstance3D).transform * mm.get_instance_transform(k) * mm.mesh.get_aabb())
		for b in boxes:
			out = b if first else out.merge(b)
			first = false
	return out


## Its plan as drawn at the nearest level of detail (every mesh and instance), in its frame.
func _my_rect(id: String) -> Dictionary:
	var p: Dictionary = _placed[id]
	var yaw := float(p.yaw)
	var db := _drawn_box(id)
	var lo := Vector2(db.position.x, db.position.z) if db.size != Vector3.ZERO else Vector2(INF, INF)
	var hi := Vector2(db.end.x, db.end.z)
	if lo.x == INF:
		return _drawn_rect({"id": id, "c": p.centre, "ax": Vector2(cos(yaw), -sin(yaw)), "az": Vector2(sin(yaw), cos(yaw)),
			"hx": 0.0, "hz": 0.0})
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var mid := (lo + hi) * 0.5
	return {"id": id, "c": (p.centre as Vector2) + ax * mid.x + az * mid.y, "ax": ax, "az": az,
		"hx": (hi.x - lo.x) * 0.5, "hz": (hi.y - lo.y) * 0.5}


func _worst_depth(id: String, me: Dictionary) -> float:
	var worst := 0.0
	for f in oriented_footprints():
		if f.id == id or str(_placed.get(f.id, {}).get("model", "")) in FIT_PASS:
			continue
		var o := _my_rect(str(f.id))
		if (o.c as Vector2).distance_to(me.c) > float(o.hx) + float(o.hz) + float(me.hx) + float(me.hz):
			continue
		worst = maxf(worst, Forms._rect_depth(me, o))
	return worst


func _unmake(id: String) -> void:
	if _nodes.has(id):
		(_nodes[id] as Node3D).free()
	for d in [_nodes, _placed, _bounds, _boxes, _solids, _opens, _xf, _tris]:
		(d as Dictionary).erase(id)


## A footprint grown to what is drawn: the plan extent of the monument's solids (a kit form
## scaled evenly can be wider than its record's footprint), in the same frame.
func _drawn_rect(f: Dictionary) -> Dictionary:
	var lo := Vector2(-float(f.hx), -float(f.hz))
	var hi := Vector2(float(f.hx), float(f.hz))
	for b in _solids.get(f.id, []):
		var bb: AABB = b
		lo = lo.min(Vector2(bb.position.x, bb.position.z))
		hi = hi.max(Vector2(bb.end.x, bb.end.z))
	var mid := (lo + hi) * 0.5
	var c: Vector2 = (f.c as Vector2) + (f.ax as Vector2) * mid.x + (f.az as Vector2) * mid.y
	return {"id": f.id, "c": c, "ax": f.ax, "az": f.az, "hx": (hi.x - lo.x) * 0.5, "hz": (hi.y - lo.y) * 0.5}
# F3 monuments (end) ------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------
# Dating
# ---------------------------------------------------------------------------------------------


## A number from the dataset, or the default when the field is missing or null.
static func _num(v: Variant, default: float) -> float:
	return float(v) if (v is float or v is int) else default


## The state of monument `id` in `year`: {} when absent, else {state, model, variant, length,
## width, radius, height, podium}. state is standing, standing_scaffold, building or burnt.
func state_at(id: String, year: int) -> Dictionary:
	var m: Dictionary = _recs.get(id, {})
	if m.is_empty():
		return {}
	var model := str(m.get("model", "none"))
	if model == "none":
		return {}
	# An Empire entry that is the same building as a Republican one (`twin_of`) is drawn only
	# while its twin is absent, so the city never holds two copies of the Basilica Iulia.
	var twin := str(m.get("twin_of", ""))
	if twin != "" and _recs.has(twin) and not state_at(twin, year).is_empty():
		return {}
	var built: Variant = m.get("built")
	# No date at all: it has always stood (as the engine rules, U7); a floor from the sources
	# ("after 27 BC", `not_before`) counts as its year.
	var first := FAR
	if built is Dictionary and built.get("year") != null:
		first = int(built["year"])
	elif built is Dictionary and built.get("not_before") != null:
		first = int(built["not_before"])
	var begun := first
	var cons: Variant = m.get("construction")
	if cons is Dictionary:
		begun = int(cons["begun"])
		first = int(cons["completed"])
	if year < begun:
		return {}
	var ended: Variant = m.get("ended")
	if ended is Dictionary and ended.get("year") != null and year >= int(ended["year"]):
		return {}
	var fp_raw: Variant = m.get("footprint_m")
	var fp: Dictionary = fp_raw if fp_raw is Dictionary else {}
	var st := {"state": "standing" if year >= first else "building", "model": model, "variant": "",
		"length": _num(fp.get("length"), 0.0), "width": _num(fp.get("width"), 0.0),
		"radius": _num(fp.get("radius"), 0.0), "height": _num(m.get("height_m"), 0.0),
		"podium": _num(m.get("podium_m"), 0.0), "thickness": _num(m.get("thickness_m"), 3.6)}
	var gone := false
	for ph in m.get("phases", []):
		if year < int(ph["from"]):
			break
		var s := str(ph["state"])
		gone = s == "gone"   # a later phase can bring it back (rebuilt on the site)
		if gone:
			continue
		st.state = s
		if ph.has("model"):
			st.model = str(ph["model"])
		if ph.has("variant"):
			st.variant = str(ph["variant"])
		if ph.has("footprint_m"):
			var pf: Dictionary = ph["footprint_m"]
			st.length = float(pf.get("length", st.length))
			st.width = float(pf.get("width", st.width))
			st.radius = float(pf.get("radius", st.radius))
	if gone:
		return {}
	if st.state == "standing" and year < first:
		st.state = "building"
	return st


## Ids of the monuments standing (or being built, or burnt) now.
func ids() -> Array:
	return _nodes.keys()


# ---------------------------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------------------------


func _ground(x: float, z: float) -> float:
	return float(_height.call(x, z)) if _height.is_valid() else 10.0


## Nearest point on a polyline: {s (distance along), pos, dir}.
func _project(route: PackedVector2Array, p: Vector2) -> Dictionary:
	var best := {"d": INF, "s": 0.0, "pos": route[0], "dir": Vector2.RIGHT}
	var acc := 0.0
	for i in range(1, route.size()):
		var a := route[i - 1]
		var b := route[i]
		var ab := b - a
		var len := ab.length()
		var t := clampf((p - a).dot(ab) / maxf(len * len, 0.001), 0.0, 1.0)
		var q := a + ab * t
		var dd := q.distance_to(p)
		if dd < best.d:
			best = {"d": dd, "s": acc + len * t, "pos": q, "dir": ab / maxf(len, 0.001)}
		acc += len
	return best


## The Servian circuit: the gates in order round the city, threaded along the wall's measured
## line (`route_measured` of murus_servianus: the gate circuit with the bends of the surviving
## stretches between the gates; F2). Without it the wall runs straight from gate to gate.
## Returns {ids: Array (gates in order), pos: PackedVector2Array (closed), at: {gate id: index}}.
func _circuit() -> Dictionary:
	if not _circ.is_empty():
		return _circ
	var centre := Vector2(150, 350)
	var list := []
	for gid in _order:
		var g: Dictionary = _recs[gid]
		if str(g.get("snap_to", "")) == "murus_servianus":
			var p := UrbsGeo.to_local(float(g["lat"]), float(g["lon"]))
			var off: Variant = g.get("offset_m")
			if off is Array:
				p += Vector2(float(off[0]), -float(off[1]))
			list.append({"id": gid, "pos": p, "ang": (p - centre).angle()})
	list.sort_custom(func(a, b): return a.ang < b.ang)
	var ids := []
	var pos := PackedVector2Array()
	var at := {}
	for e in list:
		at[e.id] = ids.size()
		ids.append(e.id)
		pos.append(e.pos)
	if pos.size() > 0:
		pos.append(pos[0])
	# F2: the measured line, if every gate is one of its points and they come in the same order
	var meas: Variant = _recs.get("murus_servianus", {}).get("route_measured")
	if meas is Array and (meas as Array).size() > ids.size():
		var mp := PackedVector2Array()
		for ll in meas:
			mp.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
		if mp[0].distance_to(mp[mp.size() - 1]) > 0.5:
			mp.append(mp[0])
		var mat := {}
		var ok := true
		var last := -1
		for e in list:
			var best := -1
			var bd := INF
			for k in mp.size() - 1:
				var d: float = mp[k].distance_to(e.pos)
				if d < bd:
					bd = d
					best = k
			if bd > 2.0 or best <= last:
				ok = false
				break
			mat[e.id] = best
			last = best
		if ok:
			pos = mp
			at = mat
		else:
			push_warning("murus_servianus.route_measured does not pass through the gates in order; the wall runs gate to gate")
	_circ = {"ids": ids, "pos": pos, "at": at}
	return _circ


func _is_clockwise(route: PackedVector2Array) -> bool:
	var area := 0.0
	for i in route.size() - 1:
		area += route[i].x * route[i + 1].y - route[i + 1].x * route[i].y
	return area > 0.0


func _make(id: String, st: Dictionary) -> void:
	var m: Dictionary = _recs[id]
	var like: Dictionary = _recs.get(str(m.get("place_like", m.get("twin_of", ""))), m)
	var model: String = st.model
	var node := Node3D.new()
	node.name = id
	var centre: Vector2
	var yaw := 0.0
	var world := false
	var route: PackedVector2Array = _routes.get(id, PackedVector2Array())
	if model == "wall":
		route = _circuit().pos
	var form_st: Dictionary = st.duplicate()
	var snap := str(m.get("snap_to", ""))
	if snap != "" and not _circuit().ids.is_empty() and (_circuit().ids as Array).has(id):
		var circ := _circuit()
		var pts: PackedVector2Array = circ.pos
		var n := pts.size() - 1   # the line is closed: the last point is the first
		var i := int(circ.at[id])
		centre = pts[i]
		var prev := pts[(i - 1 + n) % n]
		var next := pts[(i + 1) % n]
		var dir := (next - prev).normalized()
		var out_n := Vector2(-dir.y, dir.x) * (1.0 if _is_clockwise(pts) else -1.0)
		yaw = atan2(out_n.x, out_n.y)
	else:
		centre = UrbsGeo.to_local(float(like["lat"]), float(like["lon"]))
		var off: Variant = like.get("offset_m")
		if off is Array:
			centre += Vector2(float(off[0]), -float(off[1]))
		var br: Variant = like.get("bearing_deg")
		if br != null:
			yaw = UrbsGeo.yaw_from_bearing(float(br))
	var kind_route := model in ["wall", "aqueduct", "sewer"]
	if kind_route:
		world = true
		if model == "wall":
			_wall_extras(form_st, route)
		elif model == "aqueduct":
			_arcade_extras(id, m, form_st, route)
	# the ground under the footprint: its lowest and highest corner (the new forms draw their own
	# foundations down from the highest, or sit on the lowest; `base` in the result says which)
	var half0 := Vector2(maxf(float(st.width), float(st.radius) * 2.0), maxf(float(st.length), float(st.radius) * 2.0)) * 0.5
	var lo0 := INF
	var hi0 := -INF
	if not kind_route:
		var rot0 := Basis(Vector3.UP, yaw)
		for off0 in [Vector2.ZERO, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1),
				Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var wp0 := rot0 * Vector3(off0.x * half0.x, 0, off0.y * half0.y)
			var gy0 := _ground_at(centre + Vector2(wp0.x, wp0.z))
			lo0 = minf(lo0, gy0)
			hi0 = maxf(hi0, gy0)
		form_st["skirt"] = hi0 - lo0
	form_st["year"] = _year
	if model == "plaza" and not kind_route:
		# F3 monuments: a paving is laid where the ground under it is near its level; where the
		# ground falls away (the Area Capitolina's edge over the Clivus cutting) it stops at the
		# platform's own retaining wall instead of hanging a bed down the slope
		var p_base := lo0
		if UrbsSite.platform_at(centre.x, centre.y) != "":
			p_base = UrbsSite.terrace_height_at(centre.x, centre.y)
		var rot_p := Basis(Vector3.UP, yaw)
		form_st["drop_at"] = func(lx: float, lz: float) -> float:
			var w := rot_p * Vector3(lx, 0, lz)
			return p_base - _ground_at(centre + Vector2(w.x, w.z))
	var res: Dictionary = Forms.make(m, form_st, route, Callable(self, "_ground"))
	world = bool(res.get("world", false))
	_kinds[id] = str(res.kind)
	if str(res.todo) != "":
		_todo[model] = str(res.todo)
	var base_y := 10.0
	var skirt := 0.0
	var found := false   # F2: a foundation (the form's own or ours) reaches the lowest ground
	var half := Vector2(maxf(float(st.width), float(st.radius) * 2.0), maxf(float(st.length), float(st.radius) * 2.0)) * 0.5
	# F2: a form drawn at its own size (no footprint in the data): its solids' extent in plan
	if not world and (half.x <= 0.0 or half.y <= 0.0):
		var ext := Vector2.ZERO
		for bx in res.boxes:
			var c3: Vector3 = bx.centre
			var s3: Vector3 = bx.size
			ext.x = maxf(ext.x, absf(c3.x) + s3.x * 0.5)
			ext.y = maxf(ext.y, absf(c3.z) + s3.z * 0.5)
		half = Vector2(half.x if half.x > 0.0 else ext.x, half.y if half.y > 0.0 else ext.y)
	if model == "bridge_stone" or model == "bridge_timber":
		var axis := Vector2(sin(yaw), cos(yaw))
		base_y = maxf(_ground_at(centre + axis * half.y), _ground_at(centre - axis * half.y))
	elif not world:
		var lo := INF
		var hi := -INF
		var rot := Basis(Vector3.UP, yaw)
		for off in [Vector2.ZERO, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1),
				Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var wp := rot * Vector3(off.x * half.x, 0, off.y * half.y)
			var gy := _ground_at(centre + Vector2(wp.x, wp.z))
			lo = minf(lo, gy)
			hi = maxf(hi, gy)
		skirt = hi - lo
		var mode := str(res.get("base", "lo"))
		if mode == "centre":
			# built into a valley against the hills (the circus): the floor at the centre's
			# ground, the foundation down to the lowest point, the slopes over the outer seats
			base_y = _ground_at(centre)
			found = true
		elif model == "plaza" and UrbsSite.platform_at(centre.x, centre.y) != "":
			# F2: open paving on a built platform (the Area Capitolina, the Forum Iulium): its floor
			base_y = UrbsSite.terrace_height_at(centre.x, centre.y)
			found = true
		elif model in AGAINST_HILL:
			# F2: built against the hillside (the Tabularium's back is the Capitol's rock): it stands
			# on its lowest ground and its own form walls the hill behind it
			base_y = lo
			found = true
		elif model == "plaza" or (mode == "lo" and skirt <= LEVEL_OK_M):
			# open paving, or ground level enough: it sits on its lowest point
			base_y = lo
			found = true
		else:
			# F2: on a slope every monument stands on a podium or platform that reaches down to the
			# lowest ground under it, its floor at the highest corner, so no corner is buried and
			# none floats (a steep site is cut and terraced in topography.yaml terrain_model.platforms,
			# where UrbsSite builds the retaining walls; what is left is this foundation)
			base_y = hi
			found = mode == "hi" and not bool(res.get("no_skirt", false)) and float(form_st.get("skirt", 0.0)) >= skirt - 0.2
	if world:
		node.position = Vector3.ZERO
	else:
		node.position = Vector3(centre.x, base_y, centre.y)
		node.rotation.y = yaw
	_root.add_child(node)
	for part in res.parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part.mesh if part.get("own", false) else Forms.to_library(part.mesh, _unit_of(part))
		mi.transform = part.xform
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_set_range(mi, part.get("range", Vector2.ZERO))
		node.add_child(mi)
	# repeated parts (columns): one MultiMesh per kind, in the monument's frame
	for inst in res.get("instances", []):
		var xfs: Array = inst.xforms
		var mmesh := MultiMesh.new()
		mmesh.transform_format = MultiMesh.TRANSFORM_3D
		# white instance colours: under the GL compatibility renderer a MultiMesh multiplies the
		# vertex colour by the instance colour even when it has none (then black)
		mmesh.use_colors = true
		mmesh.mesh = inst.mesh
		mmesh.instance_count = xfs.size()
		for k in xfs.size():
			mmesh.set_instance_transform(k, xfs[k])
			mmesh.set_instance_color(k, Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mmesh
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_set_range(mmi, inst.range)
		node.add_child(mmi)
	if not world and not found and skirt > 0.05:
		# F2: the foundation down to the lowest ground under the footprint (and 0.5 m into it)
		var fm := UrbsMonumentMesh.new()
		fm.box(Vector3(0, -skirt - 0.5, 0), Vector3(half.x * 2.0, skirt + 0.52, half.y * 2.0), "opus_quadratum")
		var mi := MeshInstance3D.new()
		mi.mesh = fm.finish_mesh()
		node.add_child(mi)
		found = true
	# collision and picking: boxes in the monument's frame (exact solids from the new forms;
	# the older forms' boxes are kept at least 3 m on a side)
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (PICK_LAYER - 1)
	body.collision_mask = 0
	body.set_meta("monument_id", id)
	var xf := Transform3D(Basis(Vector3.UP, 0.0 if world else yaw), node.position)
	var local: Array = []
	var world_boxes: Array = []
	var aabb := AABB()
	var first := true
	for bx in res.boxes:
		var size: Vector3 = bx.size
		if not bx.get("exact", false):
			size = size.max(Vector3(3, 3, 3))
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.position = bx.centre
		body.add_child(cs)
		local.append(AABB((bx.centre as Vector3) - size * 0.5, size))
		var corner_box := _world_aabb(xf, AABB((bx.centre as Vector3) - size * 0.5, size))
		world_boxes.append(corner_box)
		aabb = corner_box if first else aabb.merge(corner_box)
		first = false
	var opens: Array = []
	for o in res.get("opens", []):
		opens.append(AABB((o.centre as Vector3) - (o.size as Vector3) * 0.5, o.size))
	if world and not first:
		# a route (the Servian wall, an aqueduct): its box would span the whole city, and urbs.gd's
		# push_out treats each monument's bounds as one solid, so a walker anywhere inside the
		# walls was thrown hundreds of metres. The bounds are its centre only; its own segments
		# still collide and pick in push_out() and pick() here.
		aabb = AABB(aabb.get_center(), Vector3.ZERO)
	elif first and not opens.is_empty():
		# only an open footprint (a plaza): the bounds are its centre, so nothing collides with
		# it or picks it by its box, but `--at` still finds it
		var oa := _world_aabb(xf, opens[0])
		aabb = AABB(oa.get_center(), Vector3.ZERO)
	node.add_child(body)
	_nodes[id] = node
	_bounds[id] = aabb
	_boxes[id] = world_boxes
	_solids[id] = local
	_opens[id] = opens
	_xf[id] = xf
	_tris[id] = res.get("tris", [0, 0, 0])
	# F3 monuments: where it truly overlaps a sourced building it yields to, it abuts it instead
	for y in st.get("yields", []):
		# the other as drawn (every mesh and instance at the nearest level of detail: its steps and
		# cornices too), 0.3 m round: yields are set between compact buildings, so its box is its body
		var gb := _drawn_box(str(y.oid))
		var boxes := [{"xf": _xf[str(y.oid)], "box": AABB(gb.position - Vector3(0.3, 0, 0.3), gb.size + Vector3(0.6, 0.5, 0.6))}]
		UrbsMonumentClip.clip(node, boxes)
	_placed[id] = {"centre": centre, "yaw": yaw, "y": base_y, "length": maxf(float(st.length), float(st.radius) * 2.0),
		"width": maxf(float(st.width), float(st.radius) * 2.0), "radius": float(st.radius), "model": model, "state": st.state,
		"native": aabb.size, "door": res.get("door", null),
		# F2 audit (audit.gd): how the base meets the ground, and the plan size used for it
		"base_mode": str(res.get("base", "lo")), "world": world, "skirted": found and not world, "drop": skirt, "retains": model in AGAINST_HILL,
		"half": half}


## Metres per mesh unit of an old kit part: the length of its transform's x axis (kit meshes
## are in 10 m units and placed with a scale; the route forms are built in metres).
static func _unit_of(part: Dictionary) -> float:
	var xf: Transform3D = part.xform
	var sc := xf.basis.get_scale()
	return maxf((sc.x + sc.y + sc.z) / 3.0, 0.001)


## Shows a part only within its distance band (Vector2(begin, end), 0 = no limit), with a small
## margin so a part does not flicker at the edge.
static func _set_range(g: GeometryInstance3D, r: Vector2) -> void:
	if r == Vector2.ZERO:
		return
	g.visibility_range_begin = r.x
	g.visibility_range_end = r.y
	g.visibility_range_begin_margin = 4.0 if r.x > 0.0 else 0.0
	g.visibility_range_end_margin = 4.0 if r.y > 0.0 else 0.0
	g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## The world-axis box round a box `b` given in a frame `xf`.
static func _world_aabb(xf: Transform3D, b: AABB) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in 8:
		var c := xf * b.get_endpoint(i)
		lo = lo.min(c)
		hi = hi.max(c)
	return AABB(lo, hi - lo)


func _ground_at(p: Vector2) -> float:
	return _ground(p.x, p.y)


## The wall: the stretch that is the agger (between the Colline and Esquiline gates) and the
## gate positions, as distances along the route, so the wall leaves openings at the gates.
func _wall_extras(st: Dictionary, route: PackedVector2Array) -> void:
	if route.size() < 2:
		return
	var circ := _circuit()
	var ids: Array = circ.ids
	var cum := PackedFloat32Array([0.0])   # distance along the line to each of its points
	for k in range(1, route.size()):
		cum.append(cum[k - 1] + route[k].distance_to(route[k - 1]))
	var total: float = cum[cum.size() - 1]
	var gates: Array = []
	var dist := {}
	for gid in ids:
		var acc: float = cum[int(circ.at[gid])]
		dist[gid] = acc
		gates.append(acc)
	st["gates"] = gates
	# stretches drawn without a wall (the record's `open_between`: pairs of neighbouring gates)
	var gaps := []
	var wrec: Dictionary = _recs.get("murus_servianus", {})
	for pair in wrec.get("open_between", []):
		var a := str(pair[0])
		var b := str(pair[1])
		if dist.has(a) and dist.has(b):
			var ia := ids.find(a)
			var ib := ids.find(b)
			if absi(ia - ib) == 1:
				gaps.append(Vector2(minf(float(dist[a]), float(dist[b])), maxf(float(dist[a]), float(dist[b]))))
			elif (ia == 0 and ib == ids.size() - 1) or (ib == 0 and ia == ids.size() - 1):
				var last := maxf(float(dist[a]), float(dist[b]))
				gaps.append(Vector2(last, total))
	st["gaps"] = gaps
	if dist.has("porta_collina") and dist.has("porta_esquilina"):
		var a := float(dist["porta_collina"])
		var b := float(dist["porta_esquilina"])
		st["agger"] = Vector2(minf(a, b), maxf(a, b))


## Where an aqueduct ran on arches: `arcade_m` metres at the city end (or round Porta Capena
## for the Appia), otherwise the whole part inside the city radius.
func _arcade_extras(id: String, m: Dictionary, st: Dictionary, route: PackedVector2Array) -> void:
	if route.size() < 2:
		return
	var total := Forms._route_length(route)
	var arcade := []
	if m.has("arcade_m"):
		var am := float(m["arcade_m"])
		if id == "aqua_appia" and _recs.has("porta_capena"):
			var s := float(_project(route, UrbsGeo.to_local(float(_recs["porta_capena"]["lat"]), float(_recs["porta_capena"]["lon"]))).s)
			arcade.append([maxf(0.0, s - am / 2.0), minf(total, s + am / 2.0)])
		else:
			arcade.append([maxf(0.0, total - am), total])
	else:
		var s := 0.0
		var start := -1.0
		while s <= total:
			var p: Vector2 = Forms._route_at(route, s).pos
			var inside := p.length() < UrbsGeo.RADIUS_M
			if inside and start < 0.0:
				start = s
			if (not inside) and start >= 0.0:
				arcade.append([start, s])
				start = -1.0
			s += 20.0
		if start >= 0.0:
			arcade.append([start, total])
	st["arcade"] = arcade


# ---------------------------------------------------------------------------------------------
# Questions
# ---------------------------------------------------------------------------------------------


## The local-metre box of a monument (for clicking); AABB() when it is not standing.
func bounds(id: String) -> AABB:
	return _bounds.get(id, AABB())


## The dataset record (the raw dictionary from monuments.json), {} if unknown.
func entry(id: String) -> Dictionary:
	return _recs.get(id, {})


## The id under a screen position, "" if none: the camera ray against each monument's solid
## boxes in its own frame (open courts and plazas are walked on, not picked).
func pick(camera: Camera3D, screen_pos: Vector2) -> String:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	return pick_ray(origin, dir)


## The id of the nearest solid on a ray ("" if none).
func pick_ray(origin: Vector3, dir: Vector3) -> String:
	var best := ""
	var best_t := INF
	for id in _solids:
		var wb: AABB = _bounds.get(id, AABB())
		if wb.size != Vector3.ZERO and wb.grow(0.5).intersects_ray(origin, dir) == null:
			continue
		var inv: Transform3D = (_xf[id] as Transform3D).affine_inverse()
		var o := inv * origin
		var d := inv.basis * dir
		for b in _solids[id]:
			var hit: Variant = (b as AABB).intersects_ray(o, d)
			if hit != null:
				var t := o.distance_to(hit)
				if t < best_t:
					best_t = t
					best = id
	return best


## The solid boxes of a monument as world-axis AABBs (local metres), [] when it is absent.
func solid_boxes(id: String) -> Array[AABB]:
	var out: Array[AABB] = []
	if not _solids.has(id):
		return out
	for b in _solids[id]:
		out.append(_world_aabb(_xf[id], b))
	return out


## Keeps a walker of `radius` whose eye is at height `eye_y` (y a.s.l.) out of the monuments'
## solids: the new (x, z). A solid stops the walker when it rises above the
## feet (eye_y - 1.7) by more than 1.3 m and its bottom is below the eye; the courts and plazas
## never stop anyone.
func push_out(p: Vector2, radius: float, eye_y: float) -> Vector2:
	for id in _solids:
		var wb: AABB = _bounds.get(id, AABB())
		if wb.size == Vector3.ZERO:
			continue   # plazas, and routes (their 250 m segment boxes are too coarse to walk against)
		if p.x < wb.position.x - radius or p.x > wb.end.x + radius or p.y < wb.position.z - radius or p.y > wb.end.z + radius:
			continue
		var xf: Transform3D = _xf[id]
		var inv := xf.affine_inverse()
		var lp := inv * Vector3(p.x, eye_y, p.y)
		var lfeet := lp.y - 1.7
		var moved := false
		for b in _solids[id]:
			var bb: AABB = b
			# a step or a low platform (up to 1.3 m, a basilica's floor) is walked over: the camera
			# follows the ground and cannot climb, so it would otherwise stop at every plinth
			if bb.end.y <= lfeet + 1.3 or bb.position.y >= lp.y:
				continue
			var x0 := bb.position.x - radius
			var x1 := bb.end.x + radius
			var z0 := bb.position.z - radius
			var z1 := bb.end.z + radius
			if lp.x <= x0 or lp.x >= x1 or lp.z <= z0 or lp.z >= z1:
				continue
			var dl := lp.x - x0
			var dr := x1 - lp.x
			var dn := lp.z - z0
			var ds := z1 - lp.z
			var mn := minf(minf(dl, dr), minf(dn, ds))
			if mn == dl:
				lp.x = x0
			elif mn == dr:
				lp.x = x1
			elif mn == dn:
				lp.z = z0
			else:
				lp.z = z1
			moved = true
		if moved:
			var w := xf * lp
			p = Vector2(w.x, w.z)
	return p


## Triangles of a monument at lod 0, 1, 2 (the new forms; [0, 0, 0] for the older ones).
func triangles(id: String) -> Array:
	return _tris.get(id, [0, 0, 0])


## Card text: name, date, builder, form, events, sources.
func info(id: String) -> Dictionary:
	var m: Dictionary = _recs.get(id, {})
	if m.is_empty():
		return {}
	var built: Dictionary = m.get("built", {}) if m.get("built") is Dictionary else {}
	var yr: Variant = built.get("year")
	var events := []
	for e in m.get("events", []):
		events.append({"year": int(e["year"]), "what": str(e["what"])})
	var st: Dictionary = _placed.get(id, {})
	return {"id": id, "latin": str(m.get("latin", "")), "english": str(m.get("english", id)),
		"year": int(yr) if yr != null else 0, "date": _date_text(yr, built),
		"by": str(built.get("by", "")), "form": str(m.get("form", "")),
		"type": str(m.get("type", "")), "location": str(m.get("location", "")),
		"events": events, "sources": m.get("sources", []), "state": str(st.get("state", "")),
		"model": str(st.get("model", "")), "enterable": _enterable(m),
		"geometry_source": str(m.get("geometry_source", "")),
		"geometry_unverified": m.get("geometry_unverified", [])}


func _date_text(yr: Variant, built: Dictionary) -> String:
	if yr == null:
		return "date unknown (%s)" % str(built.get("certainty", ""))
	var y := int(yr)
	var t := ("%d BC" % -y) if y < 0 else ("AD %d" % y)
	var c := str(built.get("certainty", ""))
	return t if c == "certain" or c == "" else "%s (%s)" % [t, c]


func _enterable(m: Dictionary) -> bool:
	return str(m.get("type", "")) in ["temple", "basilica", "curia", "theatre", "circus", "amphitheatre", "portico",
		"horrea", "public_building", "archive", "house", "baths", "prison", "market", "rostra", "comitium", "forum", "tomb"]


## A transform at the door looking inwards: the middle of the front, at eye height above the
## threshold (the top of the podium for a temple). The circus: the middle of the Palatine flank.
func entrance(id: String) -> Transform3D:
	var p: Dictionary = _placed.get(id, {})
	if p.is_empty():
		return Transform3D.IDENTITY
	var yaw: float = p.yaw
	var front := Vector3(sin(yaw), 0, cos(yaw))
	var left := Vector3(cos(yaw), 0, -sin(yaw))    # local +x
	var c: Vector2 = p.centre
	var pos := Vector3(c.x, float(p.y), c.y)
	var look := -front
	var depth := float(p.length) * 0.5
	var model: String = p.model
	if model == "circus_maximus":
		pos += left * (float(p.width) * 0.5 - 3.0)
		look = -left
	elif float(p.radius) > 0.0 and model.begins_with("temple_round"):
		pos += front * float(p.radius)
	elif model in ["wall", "aqueduct", "sewer"]:
		return Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), Vector3(c.x, float(p.y) + 1.7, c.y))
	else:
		pos += front * (depth if depth > 0.0 else 4.0)
	if p.get("door") is Vector3:
		# the new temples know their door: stand on the threshold, eye height above the floor
		var xf: Transform3D = _xf.get(id, Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, float(p.y), c.y)))
		var dp: Vector3 = xf * ((p.door as Vector3) + Vector3(0, 1.7, 0))
		return Transform3D(Basis.looking_at(look, Vector3.UP), dp)
	var m: Dictionary = _recs[id]
	var podium := float(m.get("podium_m", 0.0))
	if podium <= 0.0 and str(m.get("type", "")) == "temple":
		podium = 2.5
	pos.y += podium + 1.7
	return Transform3D(Basis.looking_at(look, Vector3.UP), pos)


## Circles for the fill agent: {id, centre: Vector2 (local x, z), radius} of everything standing
## that has a footprint (walls, aqueducts and the bare plazas that people may fill are left out).
func footprints() -> Array:
	var res := []
	for id in _placed:
		var p: Dictionary = _placed[id]
		if p.model in ["wall", "aqueduct", "sewer"]:
			continue
		var r := float(p.radius) if float(p.radius) > 0.0 else 0.5 * Vector2(float(p.width), float(p.length)).length()
		if r <= 0.0:
			r = 0.5 * Vector2((p.native as Vector3).x, (p.native as Vector3).z).length()
		res.append({"id": id, "centre": p.centre, "radius": r})
	return res


## F2: the oriented footprints of everything standing that houses must keep off, for the fill:
## {id, c: Vector2, ax, az: unit axes (local x, z), hx, hz: half sizes}. Plazas and precincts
## count (their record size: the Forum Boarium, the Area Capitolina); routes and bridges do not
## (the wall is kept clear along its line, the river by the terrain).
const _NOT_OBSTACLES := ["wall", "aqueduct", "sewer", "bridge_stone", "bridge_timber", "road_paved"]
## F2: a monument whose ground falls less than this across its footprint sits on its lowest point
const LEVEL_OK_M := 1.0
## F2: forms built against a hillside, whose back is the hill (not buried: retaining)
const AGAINST_HILL := ["tabularium"]


func oriented_footprints() -> Array:
	var res := []
	for id in _placed:
		var p: Dictionary = _placed[id]
		if str(p.model) in _NOT_OBSTACLES or bool(p.get("world", false)):
			continue
		var hf: Vector2 = p.get("half", Vector2.ZERO)
		var w := hf.x * 2.0
		var l := hf.y * 2.0
		if w <= 0.0 or l <= 0.0:
			continue
		var yaw := float(p.yaw)
		res.append({"id": id, "c": p.centre, "ax": Vector2(cos(yaw), -sin(yaw)), "az": Vector2(sin(yaw), cos(yaw)),
			"hx": w * 0.5, "hz": l * 0.5})
	return res


# ---------------------------------------------------------------------------------------------
# Report (for the lead and the preview)
# ---------------------------------------------------------------------------------------------


## Counts over the whole dataset in `year`: how many stand with a kit form, an own form, a
## placeholder, and which kit forms are missing.
func report(_year: int) -> Dictionary:
	var rep := {"republic": {"kit": 0, "own": 0, "placeholder": 0, "none": 0}, "empire": {"kit": 0, "own": 0, "placeholder": 0, "none": 0}}
	var by_model := {}
	for id in _order:
		var m: Dictionary = _recs[id]
		var fp: Variant = m.get("footprint_m")
		var ln := float((fp as Dictionary).get("length", 0.0)) if fp is Dictionary else 0.0
		var model := Forms._alias(str(m.get("model", "none")), {"length": ln})
		var part: Dictionary = rep["empire"] if _empire.has(id) else rep["republic"]
		var kind := Forms.kind_of(model)
		part[kind] = int(part.get(kind, 0)) + 1
		if kind == "placeholder":
			by_model[model] = int(by_model.get(model, 0)) + 1
	return {"by_kind": rep, "placeholder_models": by_model, "todo": Forms.TODO_KIT}
