## Urbs F3 (monuments): where the street camera stands to show a monument (`--at=<id>
## --mode=street`, the card's view, the sweep's `monument` poses), and the sight tests behind it.
##
## The camera looks at the monument's FRONT: out from the door along the front axis, far enough
## back to frame the façade. Rome was built close: a house, another monument or the hill itself
## may stand on that axis, so a few stands are tried (nearer and farther, turned up to 55° off
## the axis either way, at the last the flank) and the one that sees most of the façade wins:
## each stand is scored on sight lines from the eye to five points of the façade (the door, its
## two upper corners, the two lower corners) against the ground (terrain), every other
## monument's solids and the houses of the fill; a stand inside a solid or a house is refused.
## A venue open to the sky (circus, theatre, plaza) is seen from its entrance, looking in.
##
## Use: var v := UrbsMonumentView.new(monuments, height, fill); var pose := v.pick(id)
##   pose = {stand: Vector3 (ground y), eye: Vector3, facing: camera yaw (looks along
##           -sin, -cos), open_air: bool, seen: how many of the façade points it sees (of 5)}
class_name UrbsMonumentView
extends RefCounted

const EYE := 1.7
const NO_HOUSE := ["horti", "prop", "tree", "furn", "tomb"]   ## lots a camera may see past
## Turns off the front axis tried, in degrees, in order of preference (the flank last).
const TURNS := [0.0, -20.0, 20.0, -35.0, 35.0, -55.0, 55.0, -80.0, 80.0, -110.0, 110.0, 180.0]
## Distances tried, as shares of the framing distance.
const DISTS := [1.0, 0.7, 1.35, 0.45, 0.25, 2.0, 3.0]

var mons: UrbsMonuments
var height := Callable()
var fill: UrbsFill = null
var _lots: Array = []
var _trees: Array = []   ## {c: crown centre, r, foot}
var _lots_at := Vector2(INF, INF)


func _init(monuments: UrbsMonuments, ground: Callable, houses: UrbsFill = null) -> void:
	mons = monuments
	height = ground
	fill = houses


func _ground(x: float, z: float) -> float:
	return float(height.call(x, z)) if height.is_valid() else 10.0


## The pose that shows monument `id` best.
func pick(id: String) -> Dictionary:
	var door: Transform3D = mons.entrance(id)
	var model := str(mons.entry(id).get("model", ""))
	var outward := door.basis.z
	outward.y = 0.0
	outward = outward.normalized() if outward.length() > 0.01 else Vector3(0, 0, 1)
	var d0 := Vector3(door.origin.x, 0, door.origin.z)
	var p: Dictionary = mons._placed.get(id, {})
	var kind := ""
	for k in ["circus", "theatre", "amphitheatre", "stadium", "plaza", "forum", "comitium"]:
		if model.contains(k):
			kind = k
	if kind != "":
		var oa := _open_air(id, kind, d0, outward, p)
		if not oa.is_empty():
			return oa
	var all_round := model.begins_with("column") or model.begins_with("statue") or model.begins_with("temple_round")   # no front: a column, a statue, a tholos (the same all round)
	# the façade: from the door out to the front of the steps; its width and height
	var b := mons.bounds(id)
	var front := 0.0
	# from the door out to the front of what is drawn (the drawn box in its own frame: the world box
	# of a building turned on the diagonal reached far out in front of it)
	if not _drawn.has(id):
		_drawn[id] = mons._drawn_box(id)
	var dbx: AABB = _drawn[id]
	var mxf: Transform3D = mons._xf.get(id, Transform3D.IDENTITY)
	for i in 8:
		var corner := (mxf * dbx.get_endpoint(i) if dbx.size != Vector3.ZERO else b.get_endpoint(i)) - door.origin
		front = maxf(front, corner.x * outward.x + corner.z * outward.z)
	var half: Vector2 = p.get("half", Vector2.ZERO)
	var w := maxf(half.x * 2.0, 2.0)
	var base := float(p.get("y", b.position.y))
	var top := b.end.y if b.size.y > 0.0 else base + 6.0
	var back := front + clampf(maxf((top - base) * 1.8, minf(w, 60.0) * 1.1), 12.0, 60.0)
	_load_lots(Vector2(d0.x, d0.z), back * 2.2 + 40.0)
	var right := Vector3(outward.z, 0, -outward.x)
	var face := d0 + outward * maxf(front - 1.0, 0.0)
	var low := base + 1.0
	var high := base + (top - base) * 0.75
	var door_dy := door.origin.y
	# the stands tried: round the front (turned, nearer, farther), on the streets in front of it,
	# and for a wide front the same again before each part of it
	var stands: Array = []   # [stand, lateral offset of the façade point looked at, turn degrees]
	var laterals := [0.0] if w < 40.0 else [0.0, -0.3 * w, 0.3 * w]
	for lat: float in laterals:
		for ti in TURNS.size():
			var dir := outward.rotated(Vector3.UP, deg_to_rad(float(TURNS[ti])))
			for di in DISTS.size():
				var dist := maxf(back * float(DISTS[di]), front + 4.0)
				stands.append([d0 + right * lat + dir * dist, lat, float(TURNS[ti]), float(di)])
	for sp in _street_points(Vector2(d0.x, d0.z), front + 4.0, back * 2.2):
		var st := Vector3(sp.x, 0, sp.y)
		var rel := st - d0
		if rel.dot(outward) <= front + 2.0:
			continue
		var lat := clampf(rel.dot(right), -0.4 * w, 0.4 * w)
		var off := rad_to_deg(acos(clampf((st - (d0 + right * lat)).normalized().dot(outward), -1.0, 1.0)))
		stands.append([st, lat, off, 1.0])
	var best := {}
	var best_cost := INF
	var ranked: Array = []   # [cost, pose]: the best few are checked against the meshes at the end
	for sd: Array in stands:
		var st: Vector3 = sd[0]
		var lat := float(sd[1])
		var eye := Vector3(st.x, floor_at(st) + EYE, st.z)
		if not is_free(eye) or _in_drawn(id, eye, 0.5):   # not on its own steps either
			continue
		var c := face + right * lat
		var target := Vector3(d0.x + right.x * lat, door_dy, d0.z + right.z * lat)
		var reach := minf(w * 0.4, 18.0)
		var targets := [target, c + right * reach + Vector3(0, high, 0), c - right * reach + Vector3(0, high, 0),
			c + right * reach + Vector3(0, low, 0), c - right * reach + Vector3(0, low, 0)]
		var seen := 0
		for t in targets:
			if is_clear(eye, t, id):
				seen += 1
		var hi_target := false
		if not is_clear(eye, target, id) and is_clear(eye, c + Vector3(0, high, 0), id):
			# the door hidden (a temple's podium before the Tabularium): its upper front in view
			target = c + Vector3(0, high, 0)
			hi_target = true
		var to: Vector3 = target - eye
		to.y = 0.0
		var off := rad_to_deg(acos(clampf((-to.normalized()).dot(outward), -1.0, 1.0)))
		if all_round:
			off = 0.0
		var cost := float(5 - seen) * 10.0 + off / 15.0 + float(sd[3]) * 0.8 + absf(lat) / 20.0 + (5.0 if hi_target else 0.0)
		if off > 60.0:
			cost += 20.0   # beside it or behind it: the front not in view
		if seen == 0 or not is_clear(eye, target, id):
			cost += 100.0   # the door (or the part of the front looked at) hidden
		var tl: Vector3 = target - eye
		var pose := {"stand": st, "eye": eye, "facing": atan2(-tl.x, -tl.z), "open_air": false, "seen": seen,
			"target": target, "all_round": all_round}
		ranked.append([cost, pose])
		if cost < best_cost:
			best_cost = cost
			best = pose
		if seen == 5 and off < 10.0 and lat == 0.0 and float(sd[3]) == 0.0 and not _mesh_blocks(eye, target, id):
			return best
	# the best stands in order, the first whose line to the front no other monument's mesh crosses
	# (a column of a porch, a cornice: the solids are coarser than what is drawn)
	ranked.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	for k in mini(ranked.size(), 40):
		var ps: Dictionary = ranked[k][1]
		if not _mesh_blocks(ps.eye, ps.target, id):
			return ps
	# none sees its door or upper front past the others: the part of the front each sees best (a
	# point of the façade, nearest its middle first), looked at instead
	var grid: Array = []
	for fy in [0.75, 0.45, 0.95]:
		for fx in [0.0, -0.2, 0.2, -0.4, 0.4]:
			grid.append(face + right * w * float(fx) + Vector3(0, base + (top - base) * float(fy), 0))
	for k in mini(ranked.size(), 60):
		var ps: Dictionary = ranked[k][1]
		for t: Vector3 in grid:
			if is_clear(ps.eye, t, id) and not _mesh_blocks(ps.eye, t, id):
				var tl: Vector3 = t - ps.eye
				ps.target = t
				ps.facing = atan2(-tl.x, -tl.z)
				return ps
	if best.is_empty():   # nowhere free: the plain framing distance on the axis
		var st := d0 + outward * back
		best = {"stand": st, "eye": Vector3(st.x, floor_at(st) + EYE, st.z),
			"facing": atan2(outward.x, outward.z), "open_air": false, "seen": 0, "target": door.origin}
	return best


## A venue open to the sky. The circus, a stadium, a plaza or a forum: from its entrance, a few
## metres in, looking in. A theatre or an amphitheatre: from the middle of its orchestra or arena,
## looking at the stage (its front). The Comitium: from its edge before the front, looking in.
## {} when no free stand is found (the caller frames it like a building).
func _open_air(id: String, kind: String, d0: Vector3, outward: Vector3, p: Dictionary) -> Dictionary:
	var c2: Vector2 = p.get("centre", Vector2(d0.x, d0.z))
	var tries: Array = []
	if kind in ["theatre", "amphitheatre"]:
		var cc := Vector3(c2.x, 0, c2.y)
		for k in [0.0, -4.0, 4.0, -8.0]:
			tries.append([cc + outward * k, -1.0])
	else:
		var into := 35.0 if kind in ["circus", "stadium"] else 6.0
		var right := Vector3(outward.z, 0, -outward.x)
		for lat in [0.0, -8.0, 8.0, -16.0, 16.0]:
			for k in [into, into + 6.0, maxf(into - 4.0, 2.0), into + 14.0, into + 24.0]:
				tries.append([d0 - outward * k + right * lat, 1.0])
	for tr: Array in tries:
		var st: Vector3 = tr[0]
		var eye := Vector3(st.x, floor_at(st) + EYE, st.z)
		if not is_free(eye):
			continue
		if kind in ["theatre", "amphitheatre"]:   # looking at the stage
			return {"stand": st, "eye": eye, "facing": atan2(-outward.x, -outward.z), "open_air": true, "seen": 5,
				"target": d0}
		return {"stand": st, "eye": eye, "facing": atan2(outward.x, outward.z), "open_air": true, "seen": 5, "target": d0}
	return {}


## Points every 6 m on the year's streets between `r0` and `r1` metres from `c`.
func _street_points(c: Vector2, r0: float, r1: float) -> Array:
	var out: Array = []
	if mons._streets_cache == null or mons._streets_year != mons._year:
		mons._streets_cache = UrbsStreets.new()
		mons._streets_cache.height = height
		mons._streets_cache.load_data(mons._year)
		mons._streets_year = mons._year
	for stt in mons._streets_cache.streets:
		var pts: PackedVector2Array = stt.pts
		for k in range(pts.size() - 1):
			var a := pts[k]
			var b := pts[k + 1]
			var ln := a.distance_to(b)
			if Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c) > r1:
				continue
			var n := maxi(1, int(ln / 6.0))
			for i in n + 1:
				var q := a.lerp(b, float(i) / n)
				var d := q.distance_to(c)
				if d >= r0 and d <= r1:
					out.append(q)
	return out


## What a walker at `p` stands on: the ground, or a court or paving over it (a monument's
## `opens`: the Porticus Octaviae's court, the Area Capitolina), whichever is higher.
func floor_at(p: Vector3) -> float:
	var y := _ground(p.x, p.z)
	var g := y
	# a podium or platform a person can stand on: a solid at least 4 m across whose top is 0.3 to
	# 6 m over the ground (the steps of a neighbouring temple, a raised floor)
	for mid in mons._solids:
		if bool(mons._placed.get(mid, {}).get("world", false)):
			continue
		var wb: AABB = mons._bounds.get(mid, AABB())
		if wb.size == Vector3.ZERO or p.x < wb.position.x or p.x > wb.end.x or p.z < wb.position.z or p.z > wb.end.z:
			continue
		var xf0: Transform3D = mons._xf[mid]
		var lp0 := xf0.affine_inverse() * Vector3(p.x, g, p.z)
		for bx in mons._solids[mid]:
			var bb: AABB = bx
			var top := xf0.origin.y + bb.end.y
			if bb.size.x < 4.0 or bb.size.z < 4.0 or top - g < 0.3 or top - g > 6.0:
				continue
			if lp0.x >= bb.position.x and lp0.x <= bb.end.x and lp0.z >= bb.position.z and lp0.z <= bb.end.z:
				y = maxf(y, top)
	for mid in mons._opens:
		var xf: Transform3D = mons._xf.get(mid, Transform3D.IDENTITY)
		var lp := xf.affine_inverse() * Vector3(p.x, y, p.z)
		for o in mons._opens[mid]:
			var ob: AABB = o
			if lp.x >= ob.position.x and lp.x <= ob.end.x and lp.z >= ob.position.z and lp.z <= ob.end.z:
				y = maxf(y, xf.origin.y + ob.end.y)
	return y


# ---------------------------------------------------------------------------------------------
# Sight tests
# ---------------------------------------------------------------------------------------------


## The houses of the fill within `r` of `c` (their regions laid out now if they were not).
func _load_lots(c: Vector2, r: float) -> void:
	if fill == null or c.distance_to(_lots_at) < 1.0:
		return
	_lots_at = c
	_lots = []
	var seen := {}
	var ck := UrbsFill.CHUNK
	for i in range(floori((c.x - r) / ck), floori((c.x + r) / ck) + 1):
		for j in range(floori((c.y - r) / ck), floori((c.y + r) / ck) + 1):
			var key := Vector2i(i, j)
			var lots: Array = fill._chunk_cache.get(key, [])
			if lots.is_empty():
				for rk in fill.regions_for_chunk(key):
					while not fill.advance_region(rk, Time.get_ticks_usec() + 1000000000):
						pass
				lots = fill.lots_for_chunk(key)
			for lot in lots:
				if str(lot.get("kind", "")) in NO_HOUSE:
					continue
				var lc: Vector2 = lot["c"]
				if lc.distance_to(c) > r + 30.0:
					continue
				var k := "%.2f,%.2f" % [lc.x, lc.y]
				if seen.has(k):
					continue
				seen[k] = true
				var th := float(lot["th"])
				_lots.append({"c": lc, "ax": Vector2(cos(th), -sin(th)), "az": Vector2(sin(th), cos(th)),
					"hx": float(lot["hx"]), "hz": float(lot["hz"]), "y0": _ground(lc.x, lc.y) - 1.0,
					"y1": _ground(lc.x, lc.y) + float(lot.get("top", 6.0))})
	# the trees: a crown (a sphere of the crown radius above a trunk) that hides what is behind it
	_trees = []
	for t in UrbsSite.tree_spots(Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0)):
		var tp: Vector3 = t.pos
		var tr := float(t.radius)
		_trees.append({"c": Vector3(tp.x, _ground(tp.x, tp.z) + 1.5 + tr * 1.2, tp.z), "r": tr * 0.85, "foot": tp})


## The house lot holding `p` (within `grow`), {} if none.
func house_at(p: Vector3, grow := 0.3) -> Dictionary:
	for lot in _lots:
		if p.y < float(lot.y0) or p.y > float(lot.y1):
			continue
		var d := Vector2(p.x, p.z) - (lot.c as Vector2)
		if absf(d.dot(lot.ax)) <= float(lot.hx) + grow and absf(d.dot(lot.az)) <= float(lot.hz) + grow:
			return lot
	return {}


## Whether an eye at `p` stands clear: not inside a monument's solid nor a house, nor within
## the drawn body of a compact monument (its steps and mouldings stand out of its solids).
func is_free(p: Vector3) -> bool:
	if not house_at(p, 0.4).is_empty():
		return false
	# not at the foot of a terrace wall or a cut in the hill (the eye in the drawn bank)
	var g := _ground(p.x, p.z)
	for dv in [Vector2(2.5, 0), Vector2(-2.5, 0), Vector2(0, 2.5), Vector2(0, -2.5)]:
		if _ground(p.x + dv.x, p.z + dv.y) - g > 1.5:
			return false
	for t in _trees:   # not in a tree's crown
		if p.distance_to(t.c) < float(t.r) + 0.3:
			return false
	if monument_at(p, 0.3) != "":
		return false
	for mid in mons._solids:
		if bool(mons._placed.get(mid, {}).get("world", false)):
			continue   # routes
		if not (mons._opens.get(mid, []) as Array).is_empty():
			# a building round a court (a portico): its court is free, its wings are not
			if _in_drawn(mid, p, 0.3) and not _in_open(mid, p):
				return false
			continue
		var wb: AABB = mons._bounds.get(mid, AABB())
		if wb.size == Vector3.ZERO or not wb.grow(15.0).has_point(p):   # its steps reach out of its solids
			continue
		var rad := float(mons._placed.get(mid, {}).get("radius", 0.0))
		if rad > 0.0:   # a round building: its circle, not the square round it
			var cc: Vector2 = mons._placed[mid].centre
			if Vector2(p.x, p.z).distance_to(cc) < rad + 0.3:
				return false
			continue
		if not _drawn.has(mid):
			_drawn[mid] = mons._drawn_box(mid)
		var db: AABB = _drawn[mid]
		var lp := (mons._xf[mid] as Transform3D).affine_inverse() * p
		if db.grow(0.3).has_point(lp):
			return false
	return true


var _drawn := {}   ## monument id -> its drawn box in its frame (UrbsMonuments._drawn_box)


## Whether `p` stands over one of monument `mid`'s courts (its `opens`).
func _in_open(mid: String, p: Vector3) -> bool:
	var lp := (mons._xf[mid] as Transform3D).affine_inverse() * p
	for o in mons._opens.get(mid, []):
		var ob: AABB = o
		if lp.x >= ob.position.x and lp.x <= ob.end.x and lp.z >= ob.position.z and lp.z <= ob.end.z:
			return true
	return false


## Whether `p` stands within monument `mid`'s drawn box (grown by `grow`).
func _in_drawn(mid: String, p: Vector3, grow: float) -> bool:
	if not mons._xf.has(mid):
		return false
	if not _drawn.has(mid):
		_drawn[mid] = mons._drawn_box(mid)
	var db: AABB = _drawn[mid]
	return db.size != Vector3.ZERO and db.grow(grow).has_point((mons._xf[mid] as Transform3D).affine_inverse() * p)


## The monument whose solid holds `p` (within `grow`), "" if none (the routes' boxes span
## hundreds of metres: a route is not counted).
func monument_at(p: Vector3, grow := 0.0) -> String:
	for mid in mons._solids:
		if bool(mons._placed.get(mid, {}).get("world", false)):
			continue
		var wb: AABB = mons._bounds.get(mid, AABB())
		if wb.size != Vector3.ZERO and not wb.grow(grow + 0.5).has_point(p):
			continue
		if _yielded_at(mid, p):
			continue   # cut away there: it gives way to the building it meets (yields_to)
		var lp := (mons._xf[mid] as Transform3D).affine_inverse() * p
		for bx in mons._solids[mid]:
			if (bx as AABB).grow(grow).has_point(lp):
				return mid
	return ""


## Whether `p` stands where monument `mid` was cut away for a building it yields to.
func _yielded_at(mid: String, p: Vector3) -> bool:
	var ys: Variant = mons.entry(mid).get("yields_to")
	if not ys is Array:
		return false
	for oid in ys:
		if mons._xf.has(str(oid)) and _in_drawn(str(oid), p, 0.3):
			return true
	return false


## Whether the sight line from `a` to `b` is clear of the ground, the other monuments' solids
## and the houses (the last 1.5 m before `b` is not tested: that is the façade itself).
func is_clear(a: Vector3, b: Vector3, own: String) -> bool:
	var len := a.distance_to(b)
	if len < 0.1:
		return true
	var end := a.lerp(b, maxf(0.0, 1.0 - 1.5 / len))
	# the ground, every 2 m
	var n := int(len / 2.0)
	for i in range(1, n):
		var q := a.lerp(end, float(i) / float(n))
		if q.y < _ground(q.x, q.z) - 0.05 and q.y < floor_at(q) - 0.05:
			return false
	for mid in mons._solids:
		if mid == own:
			continue
		if bool(mons._placed.get(mid, {}).get("world", false)):
			if _route_hits(mid, a, end):   # a route (the wall): its own triangles, its boxes are too coarse
				return false
			continue
		var wb: AABB = mons._bounds.get(mid, AABB())
		if wb.size != Vector3.ZERO and wb.intersects_segment(a, end) == null:
			continue
		var inv := (mons._xf[mid] as Transform3D).affine_inverse()
		var la := inv * a
		var le := inv * end
		for bx in mons._solids[mid]:
			var hit: Variant = (bx as AABB).intersects_segment(la, le)
			if hit != null and not _yielded_at(mid, (mons._xf[mid] as Transform3D) * (hit as Vector3)):
				return false
	for lot in _lots:
		if _segment_hits_lot(a, end, lot):
			return false
	for t in _trees:
		var q := Geometry3D.get_closest_point_to_segment(t.c, a, end)
		if q.distance_to(t.c) < float(t.r):
			return false
	return true


static var _faces := {}   ## mesh instance id -> PackedVector3Array of its triangles


## Whether a drawn triangle of another monument (its nearest level of detail, its columns too)
## lies across the line from `a` to the last 1.5 m before `b`. Pavings are walked on.
func _mesh_blocks(a: Vector3, b: Vector3, own: String) -> bool:
	var len := a.distance_to(b)
	if len < 0.1:
		return false
	var end := a.lerp(b, maxf(0.0, 1.0 - 1.5 / len))
	var seg := AABB(a, Vector3.ZERO).expand(end)
	for mid in mons._nodes:
		if mid == own or str(mons._placed.get(mid, {}).get("model", "")) in ["plaza", "road_paved", "lacus_curtius", "comitium"]:
			continue
		var node: Node3D = mons._nodes[mid]
		var wb: AABB = mons._bounds.get(mid, AABB())
		if wb.size != Vector3.ZERO and not wb.grow(2.0).intersects(seg):
			continue
		for ch in node.get_children():
			var meshes: Array = []   # [mesh, transform to world]
			if ch is MeshInstance3D and (ch as MeshInstance3D).visibility_range_begin <= 0.0 and (ch as MeshInstance3D).mesh != null:
				meshes.append([(ch as MeshInstance3D).mesh, node.transform * (ch as MeshInstance3D).transform])
			elif ch is MultiMeshInstance3D and (ch as MultiMeshInstance3D).visibility_range_begin <= 0.0:
				var mm := (ch as MultiMeshInstance3D).multimesh
				if mm != null and mm.mesh != null:
					for it in UrbsMonumentClip.instance_xforms(ch):
						meshes.append([mm.mesh, node.transform * (ch as MultiMeshInstance3D).transform * (it as Transform3D)])
			for me: Array in meshes:
				var xf: Transform3D = me[1]
				var mesh: Mesh = me[0]
				if not (xf * mesh.get_aabb()).intersects(seg):
					continue
				var key := mesh.get_instance_id()
				if not _faces.has(key):
					_faces[key] = mesh.get_faces()
				var f: PackedVector3Array = _faces[key]
				var inv := xf.affine_inverse()
				var la := inv * a
				var lb := inv * end
				var lseg := AABB(la, Vector3.ZERO).expand(lb)
				for i in range(0, f.size(), 3):
					var lo := f[i].min(f[i + 1]).min(f[i + 2])
					var hi := f[i].max(f[i + 1]).max(f[i + 2])
					if hi.x < lseg.position.x or lo.x > lseg.end.x or hi.z < lseg.position.z or lo.z > lseg.end.z \
							or hi.y < lseg.position.y or lo.y > lseg.end.y:
						continue
					if Geometry3D.segment_intersects_triangle(la, lb, f[i], f[i + 1], f[i + 2]) != null:
						return true
	return false


## Whether the segment a-b passes through a triangle of route monument `mid` (world meshes).
func _route_hits(mid: String, a: Vector3, b: Vector3) -> bool:
	var node: Node3D = mons._nodes.get(mid)
	if node == null:
		return false
	var seg := AABB(a, Vector3.ZERO).expand(b)
	for ch in node.get_children():
		if not ch is MeshInstance3D:
			continue
		var mi: MeshInstance3D = ch
		if mi.visibility_range_begin > 0.0 or mi.mesh == null:
			continue
		var xf := node.transform * mi.transform
		if not (xf * mi.mesh.get_aabb()).intersects(seg):
			continue
		var key := mi.mesh.get_instance_id()
		if not _faces.has(key):
			_faces[key] = mi.mesh.get_faces()
		var f: PackedVector3Array = _faces[key]
		var inv := xf.affine_inverse()
		var la := inv * a
		var lb := inv * b
		var lseg := AABB(la, Vector3.ZERO).expand(lb)
		for i in range(0, f.size(), 3):
			var lo := f[i].min(f[i + 1]).min(f[i + 2])
			var hi := f[i].max(f[i + 1]).max(f[i + 2])
			if hi.x < lseg.position.x or lo.x > lseg.end.x or hi.z < lseg.position.z or lo.z > lseg.end.z \
					or hi.y < lseg.position.y or lo.y > lseg.end.y:
				continue
			if Geometry3D.segment_intersects_triangle(la, lb, f[i], f[i + 1], f[i + 2]) != null:
				return true
	return false


static func _segment_hits_lot(a: Vector3, b: Vector3, lot: Dictionary) -> bool:
	var c: Vector2 = lot.c
	var ax: Vector2 = lot.ax
	var az: Vector2 = lot.az
	# into the lot's frame: x along ax, z along az
	var a2 := Vector2(a.x, a.z) - c
	var b2 := Vector2(b.x, b.z) - c
	var la := Vector3(a2.dot(ax), a.y, a2.dot(az))
	var lb := Vector3(b2.dot(ax), b.y, b2.dot(az))
	var box := AABB(Vector3(-float(lot.hx), float(lot.y0), -float(lot.hz)),
		Vector3(float(lot.hx) * 2.0, float(lot.y1) - float(lot.y0), float(lot.hz) * 2.0))
	return box.intersects_segment(la, lb) != null
