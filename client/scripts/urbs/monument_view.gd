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
const DISTS := [1.0, 0.7, 1.35, 0.45, 0.25, 2.0]

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
	var open_air := false
	var into := 0.0   # how far in from the entrance: past the stands to the arena's edge
	for k in ["circus", "theatre", "amphitheatre", "stadium", "plaza", "forum"]:
		if model.contains(k):
			open_air = true
			into = 0.0 if k in ["plaza", "forum"] else 35.0
	var outward := door.basis.z
	outward.y = 0.0
	outward = outward.normalized() if outward.length() > 0.01 else Vector3(0, 0, 1)
	var d0 := Vector3(door.origin.x, 0, door.origin.z)
	if open_air:   # a venue open to the sky: stand at its entrance, looking in (facing still looks in)
		var st := d0 - outward * into
		return {"stand": st, "eye": Vector3(st.x, floor_at(st) + EYE, st.z),
			"facing": atan2(outward.x, outward.z), "open_air": true, "seen": 5}
	# the façade: from the door out to the front of the steps; its width and height
	var b := mons.bounds(id)
	var front := 0.0
	for i in 8:
		var corner := b.get_endpoint(i) - door.origin
		front = maxf(front, corner.x * outward.x + corner.z * outward.z)
	var p: Dictionary = mons._placed.get(id, {})
	var half: Vector2 = p.get("half", Vector2.ZERO)
	var w := maxf(half.x * 2.0, 2.0)
	var base := float(p.get("y", b.position.y))
	var top := b.end.y if b.size.y > 0.0 else base + 6.0
	var back := front + clampf(maxf((top - base) * 1.8, w * 1.1), 12.0, 60.0)
	_load_lots(Vector2(d0.x, d0.z), back * 1.5 + 40.0)
	var right := Vector3(outward.z, 0, -outward.x)
	var face := d0 + outward * maxf(front - 1.0, 0.0)
	var low := base + 1.0
	var high := base + (top - base) * 0.75
	var targets := [Vector3(door.origin.x, door.origin.y, door.origin.z),
		face + right * w * 0.4 + Vector3(0, high, 0), face - right * w * 0.4 + Vector3(0, high, 0),
		face + right * w * 0.4 + Vector3(0, low, 0), face - right * w * 0.4 + Vector3(0, low, 0)]
	var best := {}
	var best_cost := INF
	for ti in TURNS.size():
		var turn := deg_to_rad(float(TURNS[ti]))
		var dir := outward.rotated(Vector3.UP, turn)
		for di in DISTS.size():
			var dist := maxf(back * float(DISTS[di]), front + 4.0)
			var st := d0 + dir * dist
			var eye := Vector3(st.x, floor_at(st) + EYE, st.z)
			if not is_free(eye):
				continue
			var seen := 0
			for t in targets:
				if is_clear(eye, t, id):
					seen += 1
			var cost := float(5 - seen) * 10.0 + absf(float(TURNS[ti])) / 15.0 + float(di) * 0.8
			if seen == 0:
				cost += 100.0   # nothing of it in sight: any stand that sees some of it is better
			if cost < best_cost:
				best_cost = cost
				var to: Vector3 = targets[0] - eye
				best = {"stand": st, "eye": eye, "facing": atan2(-to.x, -to.z), "open_air": false, "seen": seen}
			if seen == 5 and ti == 0 and di == 0:
				return best
	if best.is_empty():   # nowhere free: the plain framing distance on the axis
		var st := d0 + outward * back
		best = {"stand": st, "eye": Vector3(st.x, floor_at(st) + EYE, st.z),
			"facing": atan2(outward.x, outward.z), "open_air": false, "seen": 0}
	return best


## What a walker at `p` stands on: the ground, or a court or paving over it (a monument's
## `opens`: the Porticus Octaviae's court, the Area Capitolina), whichever is higher.
func floor_at(p: Vector3) -> float:
	var y := _ground(p.x, p.z)
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
	for t in _trees:   # not in a tree's crown
		if p.distance_to(t.c) < float(t.r) + 0.3:
			return false
	if monument_at(p, 0.3) != "":
		return false
	for mid in mons._solids:
		if bool(mons._placed.get(mid, {}).get("world", false)) or not (mons._opens.get(mid, []) as Array).is_empty():
			continue   # routes, and buildings round a court (their box holds the court)
		var wb: AABB = mons._bounds.get(mid, AABB())
		if wb.size == Vector3.ZERO or not wb.grow(3.0).has_point(p):
			continue
		if not _drawn.has(mid):
			_drawn[mid] = mons._drawn_box(mid)
		var db: AABB = _drawn[mid]
		var lp := (mons._xf[mid] as Transform3D).affine_inverse() * p
		if db.grow(0.3).has_point(lp):
			return false
	return true


var _drawn := {}   ## monument id -> its drawn box in its frame (UrbsMonuments._drawn_box)


## The monument whose solid holds `p` (within `grow`), "" if none (the routes' boxes span
## hundreds of metres: a route is not counted).
func monument_at(p: Vector3, grow := 0.0) -> String:
	for mid in mons._solids:
		if bool(mons._placed.get(mid, {}).get("world", false)):
			continue
		var wb: AABB = mons._bounds.get(mid, AABB())
		if wb.size != Vector3.ZERO and not wb.grow(grow + 0.5).has_point(p):
			continue
		var lp := (mons._xf[mid] as Transform3D).affine_inverse() * p
		for bx in mons._solids[mid]:
			if (bx as AABB).grow(grow).has_point(lp):
				return mid
	return ""


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
		if q.y < _ground(q.x, q.z) - 0.05:
			return false
	for mid in mons._solids:
		if mid == own:
			continue
		if bool(mons._placed.get(mid, {}).get("world", false)):
			if _route_hits(mid, a, end):   # a route (the wall): its own triangles, its boxes are too coarse
				return false
			continue
		var wb: AABB = mons._bounds.get(mid, AABB())
		if wb.size != Vector3.ZERO and not wb.intersects_segment(a, end):
			continue
		var inv := (mons._xf[mid] as Transform3D).affine_inverse()
		var la := inv * a
		var le := inv * end
		for bx in mons._solids[mid]:
			if (bx as AABB).intersects_segment(la, le):
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
	return box.intersects_segment(la, lb)
