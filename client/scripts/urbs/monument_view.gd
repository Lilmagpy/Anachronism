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
const TURNS := [0.0, -20.0, 20.0, -35.0, 35.0, -55.0, 55.0, -80.0, 80.0]
## Distances tried, as shares of the framing distance.
const DISTS := [1.0, 0.7, 1.35, 0.45]

var mons: UrbsMonuments
var height := Callable()
var fill: UrbsFill = null
var _lots: Array = []
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
		return {"stand": st, "eye": Vector3(st.x, _ground(st.x, st.z) + EYE, st.z),
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
			var dist := maxf(back * float(DISTS[di]), front + 6.0)
			var st := d0 + dir * dist
			var eye := Vector3(st.x, _ground(st.x, st.z) + EYE, st.z)
			if not is_free(eye):
				continue
			var seen := 0
			for t in targets:
				if is_clear(eye, t, id):
					seen += 1
			var cost := float(5 - seen) * 10.0 + absf(float(TURNS[ti])) / 15.0 + float(di) * 0.8
			if cost < best_cost:
				best_cost = cost
				var to: Vector3 = targets[0] - eye
				best = {"stand": st, "eye": eye, "facing": atan2(-to.x, -to.z), "open_air": false, "seen": seen}
			if seen == 5 and ti == 0 and di == 0:
				return best
	if best.is_empty():   # nowhere free: the plain framing distance on the axis
		var st := d0 + outward * back
		best = {"stand": st, "eye": Vector3(st.x, _ground(st.x, st.z) + EYE, st.z),
			"facing": atan2(outward.x, outward.z), "open_air": false, "seen": 0}
	return best


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


## The house lot holding `p` (within `grow`), {} if none.
func house_at(p: Vector3, grow := 0.3) -> Dictionary:
	for lot in _lots:
		if p.y < float(lot.y0) or p.y > float(lot.y1):
			continue
		var d := Vector2(p.x, p.z) - (lot.c as Vector2)
		if absf(d.dot(lot.ax)) <= float(lot.hx) + grow and absf(d.dot(lot.az)) <= float(lot.hz) + grow:
			return lot
	return {}


## Whether an eye at `p` stands clear: not inside a monument's solid nor a house.
func is_free(p: Vector3) -> bool:
	if not house_at(p, 0.4).is_empty():
		return false
	return monument_at(p, 0.3) == ""


## The monument whose solid holds `p` (within `grow`), "" if none.
func monument_at(p: Vector3, grow := 0.0) -> String:
	for mid in mons._solids:
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
	return true


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
