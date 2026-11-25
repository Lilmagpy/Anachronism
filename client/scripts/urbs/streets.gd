## Urbs (D-289, step U3): the streets of Rome as strips laid on the terrain.
##
## Data: `res://data/city/streets.json` (from data/rome/city/streets.yaml, see its header for the
## sources). A street exists from `exists_from`; it is paved with polygonal basalt (silex) from
## `paved_from` (Livy 41.27.5: the censors of 174 BC paved the city streets with silex and
## gravelled the roads outside it; the Via Appia 293 and 189 BC, Livy 10.47.4 and 38.28.3), and
## is beaten earth (inside the walls) or gravel (roads) before. Stone kerbs edge a paved street,
## and inside the Servian circuit a raised footway (crepido, peperino slabs: the modeller's choice; at
## Pompeii they are beaten earth, mortar or slabs) runs behind each kerb up to the house fronts
## (UrbsFill sets them at KERB + FOOTPATH); outside the walls
## a paved road has kerbs only. Stepping stones cross the paved city streets. A `stairs` street (the
## Scalae Caci) is built as steps by UrbsSite and has no strip here. Surfaces come from
## UrbsMaterials: street_basalt, gravel, earth_packed, tufa_grey (kerbs and footway slabs), the modeller's choice,
## basalt (stepping stones). U8: the ground under every street is cut level across it by
## UrbsTerrain, so the strip lies flat. F3: where two streets meet or cross, the narrower one
## (UrbsTerrain cuts the wider last: width, then id) dips SINK under the wider one's carriageway,
## and every street dips under a paving (UrbsTerrain.pavings), so no two surfaces lie within a few
## centimetres of each other; its kerbs and footways stop at the other's edge.
##
## API (the spectacles and the camera use these):
##   build(parent, year, height)       make the meshes under `parent`; `height` is (x, z) -> y
##   nearest_street(p: Vector2)        {id, distance, point, t, tangent, normal, half_width,
##                                      kind, paved} or {} when nothing lies within 400 m
##   along(street_id, t) -> Vector3    point at fraction t (0..1) of the street's length, on
##                                      the ground; t=0 is the first point of the YAML list
##   street_length(street_id) -> float
##   street_ids() -> Array             ids of the streets that exist in the year
##   load_data(year)                   index only (no meshes): what fill.gd uses
class_name UrbsStreets
extends RefCounted

const DATA_PATH := "res://data/city/streets.json"
const CELL := 64.0           ## spatial index cell, metres
const STEP := 4.0            ## spacing of strip samples, metres
const KERB_W := 0.28
const KERB_H := 0.2
const SURFACE_LIFT := 0.12  ## strips float this far above the terrain to avoid z-fighting
const FOOTWAY_W := 1.25     ## the raised footway behind the kerb, inside the walls (reaches the fill's frontage, FOOTPATH 1 m + a little under the walls)
const FOOTWAY_H := 0.22
const SEARCH_RINGS := 7
const SINK := 0.5           ## F3: a strip's edge sinks this far where a wider street or a paving lies over it

var year := -300
var height: Callable = func(_x: float, _z: float) -> float: return 10.0
var streets: Array = []      ## per street: {id, kind, hw, pts: PackedVector2Array, cum: PackedFloat32Array, len, paved, ...}
var _by_id := {}
var _grid := {}              ## Vector2i -> Array of [street index, segment index]
var _root: Node3D


## Read the data and index the streets that exist in `new_year`. Cheap; no meshes.
func load_data(new_year: int) -> void:
	year = new_year
	streets = []
	_by_id = {}
	_grid = {}
	var text := FileAccess.get_file_as_string(DATA_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("UrbsStreets: cannot read %s" % DATA_PATH)
		return
	for entry in parsed.get("streets", []):
		var from_year: Variant = entry.get("exists_from")
		if from_year != null and int(from_year) > year:
			continue
		var raw := PackedVector2Array()
		for ll in entry["points"]:
			raw.append(UrbsGeo.to_local(float(ll[0]), float(ll[1])))
		var pts := _smooth(raw, 2)
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		var paved_from: Variant = entry.get("paved_from")
		var s := {
			"id": str(entry["id"]),
			"kind": str(entry.get("kind", "street")),
			"hw": float(entry.get("width_m", 4.0)) * 0.5,
			"pts": pts,
			"cum": cum,
			"len": cum[cum.size() - 1],
			"paved": paved_from != null and int(paved_from) <= year,
			"road": str(entry.get("kind", "street")) == "road",
			"stairs": str(entry.get("kind", "street")) == "stairs",
		}
		_by_id[s["id"]] = streets.size()
		streets.append(s)
	for si in streets.size():
		var pts: PackedVector2Array = streets[si]["pts"]
		for k in range(pts.size() - 1):
			var a := pts[k]
			var b := pts[k + 1]
			var lo := Vector2i(floori(minf(a.x, b.x) / CELL), floori(minf(a.y, b.y) / CELL))
			var hi := Vector2i(floori(maxf(a.x, b.x) / CELL), floori(maxf(a.y, b.y) / CELL))
			for cx in range(lo.x, hi.x + 1):
				for cz in range(lo.y, hi.y + 1):
					var key := Vector2i(cx, cz)
					if not _grid.has(key):
						_grid[key] = []
					_grid[key].append([si, k])


## Chaikin corner-cutting that keeps both end points.
static func _smooth(pts: PackedVector2Array, rounds: int) -> PackedVector2Array:
	var cur := pts
	for _r in rounds:
		if cur.size() < 3:
			break
		var out := PackedVector2Array([cur[0]])
		for i in range(cur.size() - 1):
			var a := cur[i]
			var b := cur[i + 1]
			if i > 0:
				out.append(a.lerp(b, 0.25))
			if i < cur.size() - 2:
				out.append(a.lerp(b, 0.75))
		out.append(cur[cur.size() - 1])
		cur = out
	return cur


func street_ids() -> Array:
	var ids := []
	for s in streets:
		ids.append(s["id"])
	return ids


func street_length(street_id: String) -> float:
	return float(streets[_by_id[street_id]]["len"]) if _by_id.has(street_id) else 0.0


## Nearest street to the local point `p` (x, z): see the file header. {} if none within ~450 m.
func nearest_street(p: Vector2) -> Dictionary:
	var best := {}
	var best_d := 1.0e9
	var centre := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for ring in range(SEARCH_RINGS + 1):
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var key := centre + Vector2i(dx, dz)
				if not _grid.has(key):
					continue
				for ref in _grid[key]:
					var s: Dictionary = streets[ref[0]]
					var pts: PackedVector2Array = s["pts"]
					var a := pts[ref[1]]
					var b := pts[ref[1] + 1]
					var ab := b - a
					var l2 := ab.length_squared()
					var u := 0.0 if l2 < 1e-6 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
					var q := a + ab * u
					var d := p.distance_to(q)
					if d < best_d:
						best_d = d
						var tangent := ab.normalized() if l2 > 1e-6 else Vector2.RIGHT
						var along_m: float = s["cum"][ref[1]] + u * sqrt(l2)
						var side := tangent.x * (p.y - q.y) - tangent.y * (p.x - q.x)
						var normal := Vector2(-tangent.y, tangent.x)
						if side < 0.0:
							normal = -normal
						best = {
							"id": s["id"], "distance": d, "point": q, "tangent": tangent,
							"normal": normal, "half_width": s["hw"], "kind": s["kind"],
							"paved": s["paved"], "t": along_m / maxf(s["len"], 0.001),
						}
		if best_d <= float(ring) * CELL:
			break
	return best


## Position and unit tangent at arc length `d` metres along street number `index` (the order of
## `streets`): [Vector2 point, Vector2 tangent]. For fill.gd.
func sample_at(index: int, d: float) -> Array:
	var s: Dictionary = streets[index]
	var dd := clampf(d, 0.0, float(s["len"]))
	var p := _point_at(s, dd)
	var q := _point_at(s, minf(dd + 1.0, float(s["len"])))
	var o := _point_at(s, maxf(dd - 1.0, 0.0))
	var tg := (q - o).normalized()
	return [p, tg if tg.length() > 0.1 else Vector2.RIGHT]


## Ground point at fraction `t` of the street's length (0 = first YAML point, 1 = last).
func along(street_id: String, t: float) -> Vector3:
	if not _by_id.has(street_id):
		return Vector3.ZERO
	var s: Dictionary = streets[_by_id[street_id]]
	var d := clampf(t, 0.0, 1.0) * float(s["len"])
	var cum: PackedFloat32Array = s["cum"]
	var pts: PackedVector2Array = s["pts"]
	var k := 0
	while k < cum.size() - 2 and cum[k + 1] < d:
		k += 1
	var seg := maxf(cum[k + 1] - cum[k], 0.0001)
	var p := pts[k].lerp(pts[k + 1], clampf((d - cum[k]) / seg, 0.0, 1.0))
	return Vector3(p.x, float(height.call(p.x, p.y)) + SURFACE_LIFT, p.y)


## Make the streets of `new_year` under `parent`.
func build(parent: Node3D, new_year: int, new_height: Callable) -> void:
	height = new_height
	load_data(new_year)
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Streets"
	parent.add_child(_root)
	var paved_mat := UrbsMaterials.get_material("street_basalt")
	var earth_mat := UrbsMaterials.get_material("earth_packed")
	var gravel_mat := UrbsMaterials.get_material("gravel")
	var kerb_mat := UrbsMaterials.get_material("tufa_grey")
	var foot_mat := UrbsMaterials.get_material("tufa_grey")
	var circuit := UrbsTerrain.circuit()
	for si in streets.size():
		var s: Dictionary = streets[si]
		if bool(s.get("stairs", false)):
			continue
		var surface: Material = paved_mat if s["paved"] else (gravel_mat if s["road"] else earth_mat)
		var mid: Vector2 = (s["pts"] as PackedVector2Array)[(s["pts"] as PackedVector2Array).size() / 2]
		var in_city := circuit.size() > 2 and Geometry2D.is_point_in_polygon(mid, circuit)
		var mesh := _street_mesh(s, float(si) * 0.004, surface, kerb_mat, foot_mat, in_city and not bool(s["road"]))
		if mesh == null:
			continue
		var node := MeshInstance3D.new()
		node.name = String(s["id"])
		node.mesh = mesh
		node.set_meta("street_id", s["id"])
		_root.add_child(node)


func _street_mesh(s: Dictionary, lift: float, surface: Material, kerb_mat: Material, foot_mat: Material, footway: bool) -> ArrayMesh:
	var pts: PackedVector2Array = s["pts"]
	var length: float = s["len"]
	if pts.size() < 2 or length < 1.0:
		return null
	var hw: float = s["hw"]
	footway = footway and bool(s["paved"])
	var n0 := maxi(2, int(ceil(length / STEP)) + 1)
	# F3: where the strip (its centre or either edge) passes under a wider street or a paving, two
	# extra samples 0.25 m either side of that edge, so it dips there at once instead of over a
	# whole 4 m step
	var dists := PackedFloat32Array()
	for i in n0:
		dists.append(length * float(i) / float(n0 - 1))
	var extra := PackedFloat32Array()
	for off: float in [-hw, 0.0, hw]:
		var prev_under := _under(_lat_point(s, 0.0, off), s)
		for i in range(1, n0):
			var d := dists[i]
			var under := _under(_lat_point(s, d, off), s)
			if under != prev_under:
				var lo := dists[i - 1]
				var hi := d
				for _it in 8:
					var mid := (lo + hi) * 0.5
					if _under(_lat_point(s, mid, off), s) == prev_under:
						lo = mid
					else:
						hi = mid
				var edge := (lo + hi) * 0.5
				extra.append(clampf(edge - 0.25, 0.0, length))
				extra.append(clampf(edge + 0.25, 0.0, length))
			prev_under = under
	if not extra.is_empty():
		var all := Array(dists) + Array(extra)
		all.sort()
		dists = PackedFloat32Array()
		for d: float in all:
			if dists.is_empty() or d - dists[dists.size() - 1] > 0.05:
				dists.append(d)
	var n := dists.size()
	var samples := PackedVector2Array()
	var tangents := PackedVector2Array()
	for i in n:
		var d := dists[i]
		var q := _point_at(s, d)
		samples.append(q)
		var q2 := _point_at(s, minf(d + 1.5, length))
		var q1 := _point_at(s, maxf(d - 1.5, 0.0))
		tangents.append((q2 - q1).normalized())
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var kv := PackedVector3Array()
	var kn := PackedVector3Array()
	var ki := PackedInt32Array()
	var fv := PackedVector3Array()
	var fnr := PackedVector3Array()
	var fuv := PackedVector2Array()
	var fi := PackedInt32Array()
	var run := 0.0
	for i in n:
		if i > 0:
			run += samples[i].distance_to(samples[i - 1])
		var t := tangents[i]
		var nrm := Vector2(-t.y, t.x)
		var l := samples[i] + nrm * hw
		var r := samples[i] - nrm * hw
		var yl := float(height.call(l.x, l.y)) + SURFACE_LIFT + lift - (SINK if _under(l, s) else 0.0)
		var yr := float(height.call(r.x, r.y)) + SURFACE_LIFT + lift - (SINK if _under(r, s) else 0.0)
		var yc := float(height.call(samples[i].x, samples[i].y)) + SURFACE_LIFT + lift + 0.04 - (SINK if _under(samples[i], s) else 0.0)   # slight camber
		verts.append(Vector3(l.x, yl, l.y)); normals.append(Vector3.UP); uvs.append(Vector2(run / 3.0, hw / 1.5))
		verts.append(Vector3(samples[i].x, yc, samples[i].y)); normals.append(Vector3.UP); uvs.append(Vector2(run / 3.0, 0.0))
		verts.append(Vector3(r.x, yr, r.y)); normals.append(Vector3.UP); uvs.append(Vector2(run / 3.0, -hw / 1.5))
		if i > 0:
			var b := (i - 1) * 3
			for row in 2:
				var a0 := b + row
				idx.append_array([a0, a0 + 3, a0 + 1, a0 + 1, a0 + 3, a0 + 4])
		if bool(s["paved"]):
			# no kerb or footway where the street crosses a paved platform (the Forum, the Circus)
			var on0 := 0.0 if UrbsSite.platform_at(samples[i].x, samples[i].y) != "" else 1.0
			for side: float in [1.0, -1.0]:
				var on := on0
				if on > 0.0 and _under(samples[i] + nrm * ((hw + KERB_W * 0.5) * side), s):
					on = 0.0   # F3: no kerb across another street's carriageway or a paving
				var inner := samples[i] + nrm * (hw * side)
				var outer := samples[i] + nrm * ((hw + KERB_W * on) * side)
				var y_in := float(height.call(inner.x, inner.y)) + SURFACE_LIFT + lift
				var y_out := float(height.call(outer.x, outer.y)) + SURFACE_LIFT + lift
				# top of the kerb stone, then its inner face dropping to the road
				kv.append(Vector3(inner.x, y_in + KERB_H * on, inner.y)); kn.append(Vector3.UP)
				kv.append(Vector3(outer.x, y_out + KERB_H * on, outer.y)); kn.append(Vector3.UP)
				kv.append(Vector3(inner.x, y_in, inner.y)); kn.append(Vector3(-nrm.x * side, 0.0, -nrm.y * side))
				if footway:   # the raised footway behind the kerb, at kerb height
					var back := samples[i] + nrm * ((hw + (KERB_W + FOOTWAY_W) * on) * side)
					var y_back := float(height.call(back.x, back.y)) + SURFACE_LIFT + lift
					var y_top := maxf(y_out, y_back) + FOOTWAY_H * on - (1.0 - on) * 0.3
					fv.append(Vector3(outer.x, y_top, outer.y)); fnr.append(Vector3.UP); fuv.append(Vector2(run / 2.0, 0.0))
					fv.append(Vector3(back.x, y_top, back.y)); fnr.append(Vector3.UP); fuv.append(Vector2(run / 2.0, 0.5))
					fv.append(Vector3(back.x, minf(y_back, y_out) - 0.3, back.y)); fnr.append(Vector3(nrm.x * side, 0.0, nrm.y * side)); fuv.append(Vector2(run / 2.0, 0.7))
	if footway:
		for i in range(1, n):
			for side_i in 2:
				var b0 := (i - 1) * 6 + side_i * 3
				var b1 := i * 6 + side_i * 3
				var flip := side_i == 1
				_quad(fi, b0, b0 + 1, b1, b1 + 1, flip)           # top
				_quad(fi, b0 + 1, b0 + 2, b1 + 1, b1 + 2, flip)   # back face
	if bool(s["paved"]):
		# kerb triangles: per sample 6 verts (2 sides x 3)
		for i in range(1, n):
			for side_i in 2:
				var b0 := (i - 1) * 6 + side_i * 3
				var b1 := i * 6 + side_i * 3
				var flip := side_i == 1
				_quad(ki, b0, b0 + 1, b1, b1 + 1, flip)           # top
				_quad(ki, b0 + 2, b0, b1 + 2, b1, flip)           # inner face
	if bool(s["paved"]) and length > 40.0:
		# stepping stones across the roadway (as at Pompeii) every ~45 m
		var sh := hash(String(s["id"])) & 0xffff
		var d := 18.0 + float(sh % 20)
		var k := 0
		while d < length - 10.0:
			var q := _point_at(s, d)
			var q2 := _point_at(s, minf(d + 1.0, length))
			var tg := (q2 - q).normalized()
			var nr := Vector2(-tg.y, tg.x)
			var hs := float(s["hw"])
			for off: float in ([-hs * 0.55, 0.0, hs * 0.55] if UrbsSite.platform_at(q.x, q.y) == "" and not _under(q, s) else []):
				var c2 := q + nr * off
				var yb := float(height.call(c2.x, c2.y)) + SURFACE_LIFT + lift
				_box_into(kv, kn, ki, Vector3(c2.x, yb, c2.y), tg, nr, Vector2(0.45, 0.7), 0.26)
			d += 42.0 + float((sh * (k + 3)) % 14)
			k += 1
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, surface)
	if bool(s["paved"]) and kv.size() > 0:
		var ka := []
		ka.resize(Mesh.ARRAY_MAX)
		ka[Mesh.ARRAY_VERTEX] = kv
		ka[Mesh.ARRAY_NORMAL] = kn
		ka[Mesh.ARRAY_INDEX] = ki
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ka)
		mesh.surface_set_material(1, kerb_mat)
	if fv.size() > 0 and fi.size() > 0:
		var fa := []
		fa.resize(Mesh.ARRAY_MAX)
		fa[Mesh.ARRAY_VERTEX] = fv
		fa[Mesh.ARRAY_NORMAL] = fnr
		fa[Mesh.ARRAY_TEX_UV] = fuv
		fa[Mesh.ARRAY_INDEX] = fi
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fa)
		mesh.surface_set_material(mesh.get_surface_count() - 1, foot_mat)
	return mesh


## The point `off` metres to the left of street `s` at `d` metres along it.
func _lat_point(s: Dictionary, d: float, off: float) -> Vector2:
	var length: float = s["len"]
	var t := (_point_at(s, minf(d + 1.5, length)) - _point_at(s, maxf(d - 1.5, 0.0))).normalized()
	return _point_at(s, d) + Vector2(-t.y, t.x) * off


## True where `p` lies under a wider street's carriageway (and its kerbs) or a paving: the strip of
## street `s` dips there (see the header).
func _under(p: Vector2, s: Dictionary) -> bool:
	for pv: Dictionary in UrbsTerrain.pavings():
		var poly: PackedVector2Array = pv["poly"]
		var c: Vector2 = pv["centre"]
		if p.distance_to(c) < poly[0].distance_to(c) + 1.0:
			# the paving and the kerb round it (0.3 m: monument_civic.gd), with a margin
			if Geometry2D.is_point_in_polygon(p, poly) or UrbsTerrain._poly_edge(poly, p)[1] < 0.6:
				return true
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var me := _rank(s)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for ref in _grid.get(key + Vector2i(dx, dz), []):
				var o: Dictionary = streets[ref[0]]
				if bool(o.get("stairs", false)) or _rank(o) <= me:
					continue
				var pts: PackedVector2Array = o["pts"]
				var k := int(ref[1])
				var q := Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])
				# F3: not past the other street's ends (its strip ends square there, with no cap)
				var ab := pts[k + 1] - pts[k]
				var t := (p - pts[k]).dot(ab) / maxf(ab.length_squared(), 0.0001)
				if (k == 0 and t < 0.0) or (k == pts.size() - 2 and t > 1.0):
					continue
				if q.distance_to(p) < float(o["hw"]) + KERB_W + 0.05:
					return true
	return false


## The order UrbsTerrain cuts the streets in (the wider last): a street ranked higher lies on top.
static func _rank(s: Dictionary) -> String:
	return "%06.2f|%s" % [float(s["hw"]), s["id"]]


## A box (stepping stone) standing on the road: centre on the ground, `u` along, `v` across.
static func _box_into(kv: PackedVector3Array, kn: PackedVector3Array, ki: PackedInt32Array, c: Vector3, u: Vector2, v: Vector2, size: Vector2, h: float) -> void:
	var hu := u * size.x * 0.5
	var hv := v * size.y * 0.5
	var corners := [c + Vector3(-hu.x - hv.x, 0, -hu.y - hv.y), c + Vector3(hu.x - hv.x, 0, hu.y - hv.y),
		c + Vector3(hu.x + hv.x, 0, hu.y + hv.y), c + Vector3(-hu.x + hv.x, 0, -hu.y + hv.y)]
	var base := kv.size()
	for p in corners:
		kv.append(p + Vector3(0, h, 0))
		kn.append(Vector3.UP)
	ki.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var nb := kv.size()
		var out := (Vector3((a + b) * 0.5) - c).normalized()
		out.y = 0.0
		kv.append(a); kv.append(b); kv.append(b + Vector3(0, h, 0)); kv.append(a + Vector3(0, h, 0))
		for _j in 4:
			kn.append(out.normalized())
		ki.append_array([nb, nb + 1, nb + 2, nb, nb + 2, nb + 3])


## Two triangles for the strip quad a-b (this sample) / c-d (next sample).
static func _quad(idx: PackedInt32Array, a: int, b: int, c: int, d: int, flip: bool) -> void:
	if flip:
		idx.append_array([a, b, c, b, d, c])
	else:
		idx.append_array([a, c, b, b, c, d])


func _point_at(s: Dictionary, d: float) -> Vector2:
	var cum: PackedFloat32Array = s["cum"]
	var pts: PackedVector2Array = s["pts"]
	var k := 0
	while k < cum.size() - 2 and cum[k + 1] < d:
		k += 1
	var seg := maxf(cum[k + 1] - cum[k], 0.0001)
	return pts[k].lerp(pts[k + 1], clampf((d - cum[k]) / seg, 0.0, 1.0))
