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

const FILES := ["res://data/city/monuments.json", "res://data/city/monuments_empire.json"]
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


func _init() -> void:
	for path in FILES:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for m in parsed.get("monuments", []):
				_recs[str(m["id"])] = m
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
	for id in _order:
		var st := state_at(id, year)
		var key := _key(st)
		if key == _keys.get(id, "|absent"):
			continue
		if _nodes.has(id):
			(_nodes[id] as Node3D).queue_free()
			_nodes.erase(id)
			_placed.erase(id)
			_bounds.erase(id)
			_boxes.erase(id)
		_keys[id] = key
		if not st.is_empty():
			_make(id, st)


func _key(st: Dictionary) -> String:
	if st.is_empty():
		return "|absent"
	return "%s|%s|%s|%s|%s|%s|%s" % [st.state, st.model, st.variant, st.length, st.width, st.radius, st.height]


# ---------------------------------------------------------------------------------------------
# Dating
# ---------------------------------------------------------------------------------------------


## The state of monument `id` in `year`: {} when absent, else {state, model, variant, length,
## width, radius, height, podium}. state is standing, standing_scaffold, building or burnt.
func state_at(id: String, year: int) -> Dictionary:
	var m: Dictionary = _recs.get(id, {})
	if m.is_empty():
		return {}
	var model := str(m.get("model", "none"))
	if model == "none":
		return {}
	var built: Variant = m.get("built")
	var first := FAR
	if built is Dictionary and built.get("year") != null:
		first = int(built["year"])
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
	var fp: Dictionary = m.get("footprint_m", {})
	var st := {"state": "standing" if year >= first else "building", "model": model, "variant": "",
		"length": float(fp.get("length", 0.0)), "width": float(fp.get("width", 0.0)),
		"radius": float(fp.get("radius", 0.0)), "height": float(m.get("height_m", 0.0)),
		"podium": float(m.get("podium_m", 0.0)), "thickness": float(m.get("thickness_m", 3.6))}
	for ph in m.get("phases", []):
		if year < int(ph["from"]):
			break
		var s := str(ph["state"])
		if s == "gone":
			return {}
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


func _is_clockwise(route: PackedVector2Array) -> bool:
	var area := 0.0
	for i in route.size() - 1:
		area += route[i].x * route[i + 1].y - route[i + 1].x * route[i].y
	return area > 0.0


func _make(id: String, st: Dictionary) -> void:
	var m: Dictionary = _recs[id]
	var like: Dictionary = _recs.get(str(m.get("place_like", "")), m)
	var model: String = st.model
	var node := Node3D.new()
	node.name = id
	var centre: Vector2
	var yaw := 0.0
	var world := false
	var route: PackedVector2Array = _routes.get(id, PackedVector2Array())
	var form_st: Dictionary = st.duplicate()
	var snap := str(m.get("snap_to", ""))
	if snap != "" and _routes.has(snap):
		var wall: PackedVector2Array = _routes[snap]
		var pr := _project(wall, UrbsGeo.to_local(float(m["lat"]), float(m["lon"])))
		centre = pr.pos
		var dir: Vector2 = pr.dir
		var out_n := Vector2(-dir.y, dir.x) * (1.0 if _is_clockwise(wall) else -1.0)
		yaw = atan2(out_n.x, out_n.y)
	else:
		centre = UrbsGeo.to_local(float(like["lat"]), float(like["lon"]))
		var off: Variant = m.get("offset_m")
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
	var res: Dictionary = Forms.make(m, form_st, route, Callable(self, "_ground"))
	world = bool(res.get("world", false))
	_kinds[id] = str(res.kind)
	if str(res.todo) != "":
		_todo[model] = str(res.todo)
	var base_y := 10.0
	var skirt := 0.0
	var half := Vector2(maxf(float(st.width), float(st.radius) * 2.0), maxf(float(st.length), float(st.radius) * 2.0)) * 0.5
	if model == "bridge_stone" or model == "bridge_timber":
		var axis := Vector2(sin(yaw), cos(yaw))
		base_y = maxf(_ground_at(centre + axis * half.y), _ground_at(centre - axis * half.y))
	elif not world:
		var lo := INF
		var hi := -INF
		var rot := Basis(Vector3.UP, yaw)
		for off in [Vector2.ZERO, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var lp := Vector3(off.x * half.x, 0, off.y * half.y)
			var wp := rot * lp
			var gy := _ground_at(centre + Vector2(wp.x, wp.z))
			lo = minf(lo, gy)
			hi = maxf(hi, gy)
		base_y = lo
		skirt = hi - lo
	if world:
		node.position = Vector3.ZERO
	else:
		node.position = Vector3(centre.x, base_y, centre.y)
		node.rotation.y = yaw
	_root.add_child(node)
	for part in res.parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part.mesh
		mi.transform = part.xform
		mi.material_override = _material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(mi)
	if skirt > 0.3 and not world and model != "plaza":
		var k := Kit.new()
		k.box(Vector3(0, -skirt - 0.4, 0), Vector3(half.x * 1.9, skirt + 0.4, half.y * 1.9), Color(0.55, 0.49, 0.40), Kit.STONE)
		var mi := MeshInstance3D.new()
		mi.mesh = k.finish()
		mi.material_override = _material
		node.add_child(mi)
	# collision for the pick: boxes in the monument's frame
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (PICK_LAYER - 1)
	body.collision_mask = 0
	body.set_meta("monument_id", id)
	var world_boxes: Array = []
	var aabb := AABB()
	var first := true
	for bx in res.boxes:
		var size: Vector3 = (bx.size as Vector3).max(Vector3(3, 3, 3))
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.position = bx.centre
		body.add_child(cs)
		var xf := Transform3D(Basis(Vector3.UP, 0.0 if world else yaw), node.position)
		var wc := xf * (bx.centre as Vector3)
		var corner_box := AABB(Vector3.ZERO, Vector3.ZERO)
		var lo2 := Vector3(INF, INF, INF)
		var hi2 := Vector3(-INF, -INF, -INF)
		for sx in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				var c := xf * ((bx.centre as Vector3) + Vector3(sx * size.x, 0, sz * size.z))
				lo2 = lo2.min(c)
				hi2 = hi2.max(c)
		lo2.y = wc.y - size.y * 0.5
		hi2.y = wc.y + size.y * 0.5
		corner_box = AABB(lo2, hi2 - lo2)
		world_boxes.append(corner_box)
		aabb = corner_box if first else aabb.merge(corner_box)
		first = false
	node.add_child(body)
	_nodes[id] = node
	_bounds[id] = aabb
	_boxes[id] = world_boxes
	_placed[id] = {"centre": centre, "yaw": yaw, "y": base_y, "length": maxf(float(st.length), float(st.radius) * 2.0),
		"width": maxf(float(st.width), float(st.radius) * 2.0), "radius": float(st.radius), "model": model, "state": st.state,
		"native": aabb.size}


func _ground_at(p: Vector2) -> float:
	return _ground(p.x, p.y)


## The wall: the stretch that is the agger (between the Colline and Esquiline gates) and the
## gate positions, as distances along the route, so the wall leaves openings at the gates.
func _wall_extras(st: Dictionary, route: PackedVector2Array) -> void:
	if route.size() < 2:
		return
	var gates: Array = []
	for gid in _order:
		var g: Dictionary = _recs[gid]
		if str(g.get("snap_to", "")) == "murus_servianus" and not state_at(gid, _year).is_empty():
			gates.append(float(_project(route, UrbsGeo.to_local(float(g["lat"]), float(g["lon"]))).s))
	st["gates"] = gates
	if _recs.has("porta_collina") and _recs.has("porta_esquilina"):
		var a := float(_project(route, UrbsGeo.to_local(float(_recs["porta_collina"]["lat"]), float(_recs["porta_collina"]["lon"]))).s)
		var b := float(_project(route, UrbsGeo.to_local(float(_recs["porta_esquilina"]["lat"]), float(_recs["porta_esquilina"]["lon"]))).s)
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


## The id under a screen position, "" if none. Casts the camera ray against each monument's boxes.
func pick(camera: Camera3D, screen_pos: Vector2) -> String:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	return pick_ray(origin, dir)


## The id of the nearest monument box on a ray ("" if none).
func pick_ray(origin: Vector3, dir: Vector3) -> String:
	var best := ""
	var best_t := INF
	for id in _boxes:
		for b in _boxes[id]:
			var hit: Variant = (b as AABB).intersects_ray(origin, dir)
			if hit != null:
				var t := origin.distance_to(hit)
				if t < best_t:
					best_t = t
					best = id
	return best


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


# ---------------------------------------------------------------------------------------------
# Report (for the lead and the preview)
# ---------------------------------------------------------------------------------------------


## Counts over the whole dataset in `year`: how many stand with a kit form, an own form, a
## placeholder, and which kit forms are missing.
func report(year: int) -> Dictionary:
	var c := {"kit": 0, "own": 0, "placeholder": 0, "site": 0, "ruin": 0, "absent": 0, "none": 0}
	var by_model := {}
	for id in _order:
		var m: Dictionary = _recs[id]
		var model := str(m.get("model", "none"))
		if model == "none":
			c["none"] += 1
			continue
		var kind := str(Forms.FORMS.get(model, "placeholder"))
		c[kind] = int(c.get(kind, 0)) + 1
		by_model[model] = int(by_model.get(model, 0)) + 1
	return {"by_kind": c, "by_model": by_model, "todo": Forms.TODO_KIT}
