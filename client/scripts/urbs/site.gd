## Urbs U8 "site": the built works that shape the ground. UrbsTerrain carves the platforms,
## terraces and street cuts into the heightfield; this script stands the stone on them:
##   - retaining walls along the risers of the hillside terraces (per chunk, `build_chunk_walls`);
##   - substructure walls round a raised platform (the Area Capitolina) where the ground falls away;
##   - walls along the cuttings and embankments of the clivi (Clivus Capitolinus, Palatinus,
##     Publicius, Argentarius, Suburanus), which UrbsTerrain notches into the slopes as ramps;
##   - flights of steps for a `stairs` street (the Scalae Caci);
##   - the quays of the Emporium: a stone edge with steps down to the water and mooring blocks;
##   - the Tiber island's stone facing, shaped as a ship.
## and answers questions about the site for the other builders:
##   terrace_height_at(x, z) -> float   the level a building should stand at (platform or terrace)
##   platform(id) -> Dictionary         {id, polygon: PackedVector2Array, level: [west, east], blend, walls}
##   platform_at(x, z) -> String        the platform under (x, z), or ""
##   parcel_at(x, z) -> Dictionary      the farmland parcel: {kind, rural, id, angle, origin, local, size, hedge, edge}
##   tree_spots(rect) -> Array          the trees UrbsSiteFlora plants in rect: [{pos: Vector3, kind, radius}]
##
## Materials (UrbsMaterials): opus_quadratum (tufa blocks) for walls before 200 BC, opus_incertum
## after (the concrete facing of the 2nd-1st centuries BC: Vitruvius 2.8.1 # unverified, from
## memory); tufa_brown for the archaic Scalae Caci; limestone_steps, travertine, forum_travertine
## for quays and the island. Everything is deterministic.
class_name UrbsSite

const WALL_UP := 0.15            ## a terrace wall's top stands this far above the upper tread
const PARCEL_REGION := 420.0     ## farmland: square regions, each with its own field orientation
const PARCEL_CELL := Vector2(54.0, 92.0)   ## a field, metres (about 2 x 3.5 actus; the actus of 120 ft is 35.5 m)
const PARCEL_KINDS := ["ploughed", "crop", "stubble", "pasture", "olive", "vineyard"]
const M32 := 0xFFFFFFFF

static var _platforms: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var model: Dictionary = UrbsTiber.topography().get("terrain_model", {})
	for pf: Dictionary in model.get("platforms", []):
		var poly := PackedVector2Array()
		for ll: Array in pf.get("polygon", []):
			poly.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in poly:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		var lv: Array = pf.get("level", [10.0, 10.0])
		_platforms[str(pf["id"])] = {"id": str(pf["id"]), "polygon": poly, "level": [float(lv[0]), float(lv[lv.size() - 1])],
			"blend": float(pf.get("blend", 25.0)), "walls": bool(pf.get("walls", false)), "lo": lo, "hi": hi}


# ---------------------------------------------------------------- queries

## The platform `id` (topography.yaml terrain_model.platforms) in local metres, or {}.
static func platform(id: String) -> Dictionary:
	_load()
	return _platforms.get(id, {})


## Ids of all platforms.
static func platform_ids() -> Array:
	_load()
	var ids := _platforms.keys()
	ids.sort()
	return ids


## The platform whose polygon contains (x, z), or "".
static func platform_at(x: float, z: float) -> String:
	_load()
	var p := Vector2(x, z)
	for id: String in platform_ids():
		var pf: Dictionary = _platforms[id]
		var lo: Vector2 = pf["lo"]
		var hi: Vector2 = pf["hi"]
		if p.x < lo.x or p.y < lo.y or p.x > hi.x or p.y > hi.y:
			continue
		if Geometry2D.is_point_in_polygon(p, pf["polygon"]):
			return id
	return ""


## The floor level of platform `pf` at x (its level runs from the west end to the east end).
static func platform_level(pf: Dictionary, x: float) -> float:
	var lo: Vector2 = pf["lo"]
	var hi: Vector2 = pf["hi"]
	var lv: Array = pf["level"]
	return lerpf(float(lv[0]), float(lv[1]), clampf((x - lo.x) / maxf(hi.x - lo.x, 1.0), 0.0, 1.0))


## The level a building should stand at, at (x, z): the floor of the platform it is on, else the
## tread of the hillside terrace (UrbsTerrain.TERRACE_M steps), else the ground. For the fill and
## monument builders: stand on this, and let a foundation drop to height_at where it is lower.
static func terrace_height_at(x: float, z: float) -> float:
	var id := platform_at(x, z)
	if id != "":
		return platform_level(_platforms[id], x)
	var y := UrbsTerrain.height_at(x, z)
	if UrbsTerrain.terrace_at(x, z) > 0.5:
		var step := UrbsTerrain.TERRACE_M
		return step * floorf((y + 0.6) / step)
	return y


## The trees planted in `rect` (local x, z metres) for the current year: [{pos, kind, radius}].
## Builders can keep their lots clear of them.
static func tree_spots(rect: Rect2) -> Array:
	var out := []
	for item: Array in UrbsSiteFlora.spots(rect, 0, UrbsTerrain.year):
		var xf: Transform3D = item[1]
		out.append({"pos": xf.origin, "kind": item[0], "radius": UrbsSiteFlora.crown_radius(item[0]) * xf.basis.get_scale().x})
	return out


static func _pcg(v: int) -> int:
	var s := (v * 747796405 + 2891336453) & M32
	var w := (((s >> ((s >> 28) + 4)) ^ s) * 277803737) & M32
	return ((w >> 22) ^ w) & M32


## A hash of three integers to 0..1, the same as `ih` in the ground shader (terrain.gd).
static func ihash(a: int, b: int, s: int) -> float:
	return float(_pcg((a & M32) ^ _pcg((b & M32) ^ _pcg(s & M32)))) / 4294967295.0


## The farmland parcel at (x, z), as the ground shader draws it: {kind (PARCEL_KINDS), rural
## (0..1, how much this is farmland), id (Vector2i), angle (radians), origin (Vector2), local
## (Vector2, position in the parcel frame), size (PARCEL_CELL), hedge (bool: hedged), edge
## (distance to the parcel's border, m)}.
static func parcel_at(x: float, z: float) -> Dictionary:
	var rc := Vector2i(floori(x / PARCEL_REGION), floori(z / PARCEL_REGION))
	var ang := ihash(rc.x, rc.y, 1) * PI
	var cs := cos(ang)
	var sn := sin(ang)
	var origin := Vector2(ihash(rc.x, rc.y, 2), ihash(rc.x, rc.y, 3)) * 300.0
	var d := Vector2(x, z) - origin
	var q := Vector2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y)
	var cid := Vector2i(floori(q.x / PARCEL_CELL.x), floori(q.y / PARCEL_CELL.y))
	var f := Vector2(q.x / PARCEL_CELL.x - cid.x, q.y / PARCEL_CELL.y - cid.y)
	var ia := cid.x + rc.x * 131
	var ib := cid.y + rc.y * 71
	var k := ihash(ia, ib, 4)
	var kind := 0 if k < 0.28 else (1 if k < 0.52 else (2 if k < 0.68 else (3 if k < 0.80 else (4 if k < 0.92 else 5))))
	var edge := minf(minf(f.x, 1.0 - f.x) * PARCEL_CELL.x, minf(f.y, 1.0 - f.y) * PARCEL_CELL.y)
	var rf := Vector2(x / PARCEL_REGION - rc.x, z / PARCEL_REGION - rc.y)
	edge = minf(edge, minf(minf(rf.x, 1.0 - rf.x), minf(rf.y, 1.0 - rf.y)) * PARCEL_REGION)
	return {"kind": PARCEL_KINDS[kind], "rural": UrbsTerrain.rural_at(x, z), "id": Vector2i(ia, ib), "angle": ang,
		"origin": origin, "local": q, "size": PARCEL_CELL, "hedge": ihash(ia, ib, 5) < 0.7, "edge": edge}


## World (x, z) of a point given in a parcel frame (`angle`, `origin` from parcel_at).
static func parcel_to_world(angle: float, origin: Vector2, q: Vector2) -> Vector2:
	var cs := cos(angle)
	var sn := sin(angle)
	return origin + Vector2(cs * q.x - sn * q.y, sn * q.x + cs * q.y)


# ---------------------------------------------------------------- building

## A mesh builder with one surface per UrbsMaterials name.
class Mesher:
	var surfaces := {}   ## name -> [verts, normals, uvs, indices]

	func _s(mat: String) -> Array:
		if not surfaces.has(mat):
			surfaces[mat] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedInt32Array()]
		return surfaces[mat]

	## A quad a-b-c-d (counter-clockwise seen from the front) with the given normal; uv in metres / 2.
	func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
		if (b - a).cross(d - a).dot(n) < 0.0:   # keep the front on the normal's side
			var t := b
			b = d
			d = t
		var s := _s(mat)
		var vs: PackedVector3Array = s[0]
		var ns: PackedVector3Array = s[1]
		var us: PackedVector2Array = s[2]
		var ix: PackedInt32Array = s[3]
		var base := vs.size()
		var w := a.distance_to(b)
		var hgt := a.distance_to(d)
		vs.append_array([a, b, c, d])
		ns.append_array([n, n, n, n])
		var u0 := (a.x + a.z) * 0.5
		us.append_array([Vector2(u0, a.y * 0.5), Vector2(u0 + w * 0.5, b.y * 0.5), Vector2(u0 + w * 0.5, b.y * 0.5 + hgt * 0.5), Vector2(u0, a.y * 0.5 + hgt * 0.5)])
		ix.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
		# packed arrays are copied out of an Array: write them back
		s[0] = vs
		s[1] = ns
		s[2] = us
		s[3] = ix

	## A wall block along a-b (ground points, x/z), `out` the face's outward direction (2D), its
	## foot at ya0/yb0 and its top at ya1/yb1, `thick` metres deep behind the face.
	func wall(mat: String, a: Vector2, b: Vector2, out: Vector2, ya0: float, ya1: float, yb0: float, yb1: float, thick: float) -> void:
		var o := out.normalized()
		var n := Vector3(o.x, 0.0, o.y)
		var ba := a - o * thick
		var bb := b - o * thick
		quad(mat, Vector3(a.x, ya0, a.y), Vector3(b.x, yb0, b.y), Vector3(b.x, yb1, b.y), Vector3(a.x, ya1, a.y), n)
		quad(mat, Vector3(a.x, ya1, a.y), Vector3(b.x, yb1, b.y), Vector3(bb.x, yb1, bb.y), Vector3(ba.x, ya1, ba.y), Vector3.UP)
		quad(mat, Vector3(ba.x, ya0, ba.y), Vector3(bb.x, yb0, bb.y), Vector3(bb.x, yb1, bb.y), Vector3(ba.x, ya1, ba.y), -n)

	## An axis-free box: centre of its base `c`, `u` along (unit, 2D), half sizes hu, hv, height h.
	func block(mat: String, c: Vector3, u: Vector2, hu: float, hv: float, h: float) -> void:
		var v := Vector2(-u.y, u.x)
		var p := [Vector2(c.x, c.z) - u * hu - v * hv, Vector2(c.x, c.z) + u * hu - v * hv, Vector2(c.x, c.z) + u * hu + v * hv, Vector2(c.x, c.z) - u * hu + v * hv]
		var y0 := c.y
		var y1 := c.y + h
		quad(mat, Vector3(p[0].x, y1, p[0].y), Vector3(p[3].x, y1, p[3].y), Vector3(p[2].x, y1, p[2].y), Vector3(p[1].x, y1, p[1].y), Vector3.UP)
		for i in 4:
			var a: Vector2 = p[i]
			var b: Vector2 = p[(i + 1) % 4]
			var e := (b - a).normalized()
			var n := Vector3(e.y, 0.0, -e.x)
			quad(mat, Vector3(b.x, y0, b.y), Vector3(a.x, y0, a.y), Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), n)

	func finish(node_name: String) -> MeshInstance3D:
		if surfaces.is_empty():
			return null
		var mesh := ArrayMesh.new()
		var names := surfaces.keys()
		names.sort()
		for mat: String in names:
			var s: Array = surfaces[mat]
			if (s[3] as PackedInt32Array).is_empty():
				continue
			var arr: Array = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = s[0]
			arr[Mesh.ARRAY_NORMAL] = s[1]
			arr[Mesh.ARRAY_TEX_UV] = s[2]
			arr[Mesh.ARRAY_INDEX] = s[3]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mesh.surface_set_material(mesh.get_surface_count() - 1, UrbsMaterials.get_material(mat))
		var mi := MeshInstance3D.new()
		mi.name = node_name
		mi.mesh = mesh
		return mi


## The masonry of retaining walls in `year`.
static func wall_material(year: int) -> String:
	return "opus_quadratum" if year < -200 else "opus_incertum"


## The site works of `year` (whole-scene, not chunked) under a new node "SiteWorks" in `parent`.
static func build(parent: Node3D, year: int, height: Callable) -> Node3D:
	_load()
	var root := Node3D.new()
	root.name = "SiteWorks"
	parent.add_child(root)
	var m := Mesher.new()
	_platform_walls(m, year, height)
	_street_works(m, year, height)
	_quays(m, year)
	_island_facing(m, year)
	var mi := m.finish("Works")
	if mi != null:
		root.add_child(mi)
	return root


## Substructure walls round platforms marked `walls: true` where the ground falls away (and
## retaining walls where it rises above the floor).
static func _platform_walls(m: Mesher, year: int, height: Callable) -> void:
	var mat := wall_material(year)
	for id: String in platform_ids():
		var pf: Dictionary = _platforms[id]
		if not bool(pf["walls"]):
			continue
		var poly: PackedVector2Array = pf["polygon"]
		var ccw := _signed_area(poly) > 0.0
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var e := (b - a).normalized()
			var out := Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)
			var length := a.distance_to(b)
			var n := maxi(int(ceil(length / 3.0)), 1)
			for k in n:
				var p0 := a.lerp(b, float(k) / n)
				var p1 := a.lerp(b, float(k + 1) / n)
				var l0 := platform_level(pf, p0.x)
				var l1 := platform_level(pf, p1.x)
				var g0: float = height.call(p0.x + out.x * 9.0, p0.y + out.y * 9.0)
				var g1: float = height.call(p1.x + out.x * 9.0, p1.y + out.y * 9.0)
				if l0 - g0 > 1.2 or l1 - g1 > 1.2:   # the platform stands up: a substructure with a parapet
					m.wall(mat, p0 + out * 1.0, p1 + out * 1.0, out, minf(g0, l0) - 1.5, l0 + 0.9, minf(g1, l1) - 1.5, l1 + 0.9, 3.0)
				elif g0 - l0 > 1.2 or g1 - l1 > 1.2:   # the hill above it: a retaining wall
					m.wall(mat, p0, p1, -out, l0 - 0.4, maxf(g0, l0) + WALL_UP, l1 - 0.4, maxf(g1, l1) + WALL_UP, 3.0)


static func _signed_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## The clivi's cuttings and embankments walled; the stairs built as steps.
static func _street_works(m: Mesher, year: int, height: Callable) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(UrbsTerrain.STREETS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var mat := wall_material(year)
	for entry: Dictionary in parsed.get("streets", []):
		var kind := str(entry.get("kind", "street"))
		if kind != "clivus" and kind != "stairs":
			continue
		var from_y: Variant = entry.get("exists_from")
		if from_y != null and int(from_y) > year:
			continue
		var raw := PackedVector2Array()
		for ll in entry["points"]:
			raw.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
		var pts := UrbsStreets._smooth(raw, 2)
		var hw := float(entry.get("width_m", 4.0)) * 0.5
		if kind == "stairs":
			_stairs(m, pts, hw, height, "tufa_brown" if year < -200 else "limestone_steps", mat)
		else:
			_clivus_walls(m, pts, hw, height, mat)


static func _clivus_walls(m: Mesher, pts: PackedVector2Array, hw: float, height: Callable, mat: String) -> void:
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	var length := cum[cum.size() - 1]
	var n := maxi(int(ceil(length / 3.0)), 1)
	var edge := hw + 1.4
	for side: float in [1.0, -1.0]:
		var prev := {}
		for i in n + 1:
			var d := length * float(i) / n
			var p := UrbsTerrain._polyline_at(pts, cum, d)
			var q := UrbsTerrain._polyline_at(pts, cum, minf(d + 1.0, length))
			var o := UrbsTerrain._polyline_at(pts, cum, maxf(d - 1.0, 0.0))
			var t := (q - o).normalized()
			var nrm := Vector2(-t.y, t.x) * side
			var road: float = height.call(p.x, p.y)
			var at := p + nrm * edge
			var beyond: float = height.call(p.x + nrm.x * (edge + 4.5), p.y + nrm.y * (edge + 4.5))
			var cur := {"at": at, "nrm": nrm, "road": road, "g": beyond}
			if not prev.is_empty():
				var cut := maxf(float(prev["g"]) - float(prev["road"]), beyond - road)
				var fill := maxf(float(prev["road"]) - float(prev["g"]), road - beyond)
				if cut > 1.0:   # the bank above the road held back
					m.wall(mat, prev["at"], at, -nrm, float(prev["road"]) - 0.3, maxf(float(prev["g"]), float(prev["road"])) + WALL_UP, road - 0.3, maxf(beyond, road) + WALL_UP, 1.2)
				elif fill > 1.0:   # the road carried on an embankment, with a parapet
					m.wall(mat, prev["at"], at, nrm, minf(float(prev["g"]), float(prev["road"])) - 0.6, float(prev["road"]) + 0.9, minf(beyond, road) - 0.6, road + 0.9, 0.8)
			prev = cur


## Steps up a stepped street: risers of about 0.2 m, side walls, on the ground's own slope.
static func _stairs(m: Mesher, pts: PackedVector2Array, hw: float, height: Callable, step_mat: String, wall_mat: String) -> void:
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	var length := cum[cum.size() - 1]
	var riser := 0.2
	var d := 0.0
	var start := 0.0
	var start_y: float = height.call(pts[0].x, pts[0].y)
	var level := snappedf(start_y, riser)
	while d < length:
		d = minf(d + 0.25, length)
		var p := UrbsTerrain._polyline_at(pts, cum, d)
		var y: float = height.call(p.x, p.y)
		var lv := snappedf(y, riser)
		if absf(lv - level) >= riser * 0.99 or d >= length:
			var a := UrbsTerrain._polyline_at(pts, cum, start)
			var mid := a.lerp(p, 0.5)
			var u := (p - a).normalized() if p.distance_to(a) > 0.01 else Vector2.RIGHT
			var top := maxf(level, minf(start_y, y) - 0.05)
			m.block(step_mat, Vector3(mid.x, top - 0.7, mid.y), u, maxf(p.distance_to(a) * 0.5, 0.15), hw, 0.7)
			for side: float in [1.0, -1.0]:
				var nrm := Vector2(-u.y, u.x) * side
				m.block(wall_mat, Vector3(mid.x + nrm.x * (hw + 0.3), top - 0.7, mid.y + nrm.y * (hw + 0.3)), u, maxf(p.distance_to(a) * 0.5, 0.15), 0.3, 1.4)
			start = d
			start_y = y
			level = lv


## The stone quays of the year: a wall at the water's edge, the paved quay behind, flights of
## steps down to the water and mooring blocks.
static func _quays(m: Mesher, year: int) -> void:
	for q: Dictionary in UrbsTiber.quays():
		if year < int(q["from"]):
			continue
		var side := float(q["side"])
		var s0 := float(q["s0"])
		var s1 := float(q["s1"])
		var rise := float(q["rise"])
		var n := maxi(int((s1 - s0) / 4.0), 1)
		var flight := 0
		for i in n:
			var sa := s0 + (s1 - s0) * float(i) / n
			var sb := s0 + (s1 - s0) * float(i + 1) / n
			var a := UrbsTiber.bank_point(sa, side, 0.5)
			var b := UrbsTiber.bank_point(sb, side, 0.5)
			var wl := UrbsTiber.water_level_at_s(sa)
			var tang: Vector2 = UrbsTiber.at_s(sa)[1]
			var out := Vector2(-tang.y, tang.x) * -side   # toward the water
			var top := wl + rise
			m.wall("opus_quadratum", a, b, out, wl - 2.0, top + 0.1, wl - 2.0, top + 0.1, 3.0)
			# the paved quay behind the wall
			var a2 := a - out * 3.0
			var b2 := b - out * 3.0
			var a3 := a - out * 36.0
			var b3 := b - out * 36.0
			m.quad("forum_travertine", Vector3(a2.x, top + 0.1, a2.y), Vector3(a3.x, top + 0.1, a3.y), Vector3(b3.x, top + 0.1, b3.y), Vector3(b2.x, top + 0.1, b2.y), Vector3.UP)
			if i % 3 == 1:   # a mooring block every 12 m
				var c := a.lerp(b, 0.5) + out * 0.3
				m.block("travertine", Vector3(c.x, wl + 1.4, c.y), tang, 0.45, 0.35, 0.7)
			if i % 18 == 9 and i + 3 < n:   # a flight of steps down along the face every ~70 m
				flight += 1
				var steps := int(ceil((rise + 0.6) / 0.25))
				for k in steps:
					var f := float(k) / steps
					var c2 := a + tang * (f * 10.0) + out * 1.2
					m.block("limestone_steps", Vector3(c2.x, wl - 0.6, c2.y), tang, 0.3, 1.1, top - wl + 0.6 - f * (rise + 0.6))


## The Tiber island's stone facing, shaped as a ship, from the year topography.yaml gives.
static func _island_facing(m: Mesher, year: int) -> void:
	var facing: Dictionary = UrbsTiber.topography().get("terrain_model", {}).get("island_facing", {})
	if facing.is_empty() or year < int(facing.get("from", 0)):
		return
	var isl := UrbsTiber.island()
	var c: Vector2 = isl["center"]
	var wl := UrbsTiber.water_level_at_s(0.0)
	var k := 0
	var best := INF
	var course := UrbsTiber.course()
	for i in course.size():
		var dd := course[i].distance_squared_to(c)
		if dd < best:
			best = dd
			k = i
	wl = UrbsTiber.water_level_at_s(float(k) * UrbsTiber.STEP_M)
	var ring := PackedVector2Array()
	var n := 96
	for i in n:
		var ang := TAU * float(i) / n
		var dir := Vector2(cos(ang), sin(ang))
		var lo := 0.0
		var hi := 200.0
		for _it in 18:   # where island_r crosses 0.95 along this ray
			var mid := (lo + hi) * 0.5
			var p := c + dir * mid
			if UrbsTiber.island_r(p.x, p.y) < 0.95:
				lo = mid
			else:
				hi = mid
		ring.append(c + dir * lo)
	var top := wl + UrbsTiber.ISLAND_RAISE * 0.86 + 0.5
	for i in n:
		var a := ring[i]
		var b := ring[(i + 1) % n]
		var out := ((a + b) * 0.5 - c).normalized()
		m.wall("travertine", a, b, out, wl - 1.5, top, wl - 1.5, top, 3.0)


## Unit vector down the slope at p (from the ground 7.5 m either side: smooth along a contour).
static func _down(p: Vector2) -> Vector2:
	var e := 7.5
	var g := Vector2(UrbsTerrain.height_at(p.x + e, p.y) - UrbsTerrain.height_at(p.x - e, p.y), UrbsTerrain.height_at(p.x, p.y + e) - UrbsTerrain.height_at(p.x, p.y - e))
	return -g.normalized() if g.length() > 0.001 else Vector2.RIGHT


## The retaining walls of the hillside terraces in `rect` (a contour walk at the middle of each
## riser), or null. lod 0 and 1 only.
static func build_chunk_walls(rect: Rect2, lod: int, year: int) -> Node3D:
	var h := UrbsTerrain.field()
	var n := UrbsTerrain.VERTS
	var cell := UrbsTerrain.CELL_M
	var half := UrbsTerrain.HALF_M
	var step := UrbsTerrain.TERRACE_M
	var i0 := clampi(roundi((rect.position.x + half) / cell), 1, n - 2)
	var j0 := clampi(roundi((rect.position.y + half) / cell), 1, n - 2)
	var i1 := clampi(roundi((rect.end.x + half) / cell), 1, n - 2)
	var j1 := clampi(roundi((rect.end.y + half) / cell), 1, n - 2)
	var m := Mesher.new()
	var mat := wall_material(year)
	var any := false
	for j in range(j0, j1):
		for i in range(i0, i1):
			var x := -half + i * cell
			var z := -half + j * cell
			var tw := minf(UrbsTerrain.terrace_at(x + cell * 0.5, z + cell * 0.5), UrbsTerrain.terrace_at(x, z))
			if tw < 0.6 or UrbsTerrain.built_at(x + cell * 0.5, z + cell * 0.5) > 0.35:
				continue
			if UrbsTerrain.river_distance(x, z) < UrbsTerrain.river_half_width(x, z) + 30.0:
				continue
			var hs := [h[j * n + i], h[j * n + i + 1], h[(j + 1) * n + i + 1], h[(j + 1) * n + i]]
			var corners := [Vector2(x, z), Vector2(x + cell, z), Vector2(x + cell, z + cell), Vector2(x, z + cell)]
			var lo := minf(minf(hs[0], hs[1]), minf(hs[2], hs[3]))
			var hi := maxf(maxf(hs[0], hs[1]), maxf(hs[2], hs[3]))
			if hi - lo < step * 0.45:
				continue
			var lvl := (floorf(lo / step) + 0.5) * step
			while lvl < hi:
				if lvl > lo:
					var cross: Array = []
					for e in 4:
						var ha: float = hs[e]
						var hb: float = hs[(e + 1) % 4]
						if (ha - lvl) * (hb - lvl) < 0.0:
							cross.append((corners[e] as Vector2).lerp(corners[(e + 1) % 4], (lvl - ha) / (hb - ha)))
					if cross.size() >= 2:
						for c in range(0, cross.size() - 1, 2):
							# each end shifted down its own slope, so neighbouring segments meet
							var da := _down(cross[c])
							var db := _down(cross[c + 1])
							var a: Vector2 = cross[c] + da * 1.0
							var b: Vector2 = cross[c + 1] + db * 1.0
							var ya0 := UrbsTerrain.height_at(a.x + da.x * 2.5, a.y + da.y * 2.5) - 0.3
							var yb0 := UrbsTerrain.height_at(b.x + db.x * 2.5, b.y + db.y * 2.5) - 0.3
							var ya1 := UrbsTerrain.height_at(a.x - da.x * 3.5, a.y - da.y * 3.5) + WALL_UP
							var yb1 := UrbsTerrain.height_at(b.x - db.x * 3.5, b.y - db.y * 3.5) + WALL_UP
							if ya1 - ya0 > 1.0 and yb1 - yb0 > 1.0:
								m.wall(mat, a, b, (da + db).normalized(), ya0, ya1, yb0, yb1, 0.9)
								any = true
				lvl += step
	if not any:
		return null
	var mi := m.finish("TerraceWalls")
	if mi != null:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 1600.0
	return mi
