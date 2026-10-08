## A province's chief city, designed street first (D-281). Called by Settlements.build for each
## chief city; `s` is the Settlements object, whose helpers place and claim the buildings
## (s._add, s._fit_house, s._model, s._dry, s._free, s._claim ...), whose `ground` is told about
## every street, square and yard, and whose `rng` is seeded per city.
##
## How a city is made: the outline is marched out over the land (it stops at water and
## cliffs); each people's habit lays out its squares and main streets (a grid of insulae and a
## forum for Rome, a walled ward grid and a ceremonial axis for China, a castle town for
## Japan, a market town for the north, courtyard quarters for the south); lanes then fill the
## blocks until no house is far from a street; houses line the streets facing them, tight in
## the core, detached with yards further out, gardens and orchards at the edge and suburbs
## strung along the roads outside the walls.
extends RefCounted

const SECT := 96   ## the outline is measured in this many directions
const CELLG := 1.0   ## street index cell

var s: Settlements   ## the Settlements being built

# --- the city being planned ---------------------------------------------------------------
var c := Vector2.ZERO        ## the centre of the outline
var heart := Vector2.ZERO    ## the middle of the town's life: ranks are measured from here
var theta := 0.0             ## the grid's orientation
var half := 3.0
var tier := 0
var capital := false
var index := 0
var walled := false
var sea := Vector2.ZERO
var reach := PackedFloat32Array()   ## the outline's radius per direction
var _wet := PackedByteArray()       ## 1 where the outline ends at water
var _mean_r := 1.0
var streets: Array = []   ## {pts, w, main, side, lead}
var squares: Array = []   ## {poly, centre, r, kind, centred}
var gates: Array = []     ## {pos, dir}
var mine: Array = []      ## houses placed: [pos, yaw, r, rank]
var _seg := {}            ## Vector2i -> [[a, b, half width]]: the street index
var _dense := 1.0         ## how tight the houses stand (the culture's habit)
var _lane_gap := 1.2      ## how far a house may be from a street before a lane is cut
var _big_ok := {}


func _init(settlements: Settlements) -> void:
	s = settlements


## Plan and build the chief city of `site`.
func plan(site: Dictionary, population: int, idx: int) -> void:
	_city(site, population, idx)


# =========================================================================================
# The city, start to finish
# =========================================================================================

func _city(site: Dictionary, population: int, idx: int) -> void:
	index = idx
	tier = int(site.get("tier", 0))
	capital = bool(site["capital"])
	c = site["pixel"]
	half = clampf(0.5 + sqrt(population / 100000.0) * 0.28, 0.6, 1.8) * s.S * (1.0 + 0.12 * tier)
	sea = s._sea_direction(c, half * 1.3)
	theta = sea.angle() if sea != Vector2.ZERO else s.rng.randf_range(-0.5, 0.5)
	if s.earth.is_wet(c):   # the province's point is offshore: build on the nearest shore
		for r in range(1, 12):
			var found := false
			for k in 16:
				var p := c + Vector2(cos(k * TAU / 16.0), sin(k * TAU / 16.0)) * r * s.LOT
				if s._dry(p, s.LOT):
					c = p
					found = true
					break
			if found:
				break
	_settle()
	s.clearings.append([c, half * 1.35])
	if s.style == "steppe":
		s.rural._camp(site, c, half, clampi(population / 30000, 8, 60) * 2 + tier * 16, idx)
		return
	streets = []
	squares = []
	gates = []
	mine = []
	_seg = {}
	_big_ok = {}
	_dense = 1.0
	_lane_gap = 1.2
	_mean_r = 0.0
	heart = c
	walled = capital or tier >= 2
	var looks: Array = (site.get("buildings", []) as Array).duplicate()
	if str(site.get("works", "")) != "":
		looks.append("|works|" + str(site["works"]))
	for extra in _landmarks(site, tier):
		looks.append(extra)
	match s.style:
		"classical":
			_classical(looks)
		"east":
			if s.culture == "samurai":
				_castle_town(looks, false)
			elif s.culture == "joseon":
				_castle_town(looks, true)
			else:
				_chinese(looks)
		"northern":
			_northern(looks)
		_:
			_southern(looks)
	if _mean_r < 1.0:
		return
	_finish()
	var size := clampf(0.8 + population / 2000000.0, 0.8, 1.4)
	s._add("i_castle" if capital else "i_town", c, 0.0, PI / 5.0, Vector3.ONE * size, Color.WHITE, index, 1.0)
	if capital:
		for k in 3:
			if mine.size() > 0:
				var m: Array = mine[s.rng.randi() % mine.size()]
				s._chimneys.append(m[0])


## Shift the centre a little to where the most land lies around it (a city on a spit of land
## or a river bank is better planned from its middle).
func _settle() -> void:
	var best := c
	var best_score := -1.0
	for ring in range(0, 7):
		for k in (1 if ring == 0 else 12):
			var p := c + Vector2(cos(k * TAU / 12.0), sin(k * TAU / 12.0)) * ring * 1.0
			if not s._dry(p, 0.5):
				continue
			var score := 0.0
			for rr in [1.5, 3.0, 4.5]:
				for d in 12:
					if s._dry(p + Vector2(cos(d * TAU / 12.0), sin(d * TAU / 12.0)) * float(rr), 0.3):
						score += 1.0
			score -= ring * 0.8
			if score > best_score:
				best_score = score
				best = p
	c = best


## Everything that comes after a people's layout: walls, houses, yards, gardens, suburbs.
func _finish() -> void:
	if walled:
		_walls()
	_greens()
	_suburb_roads()
	for st in streets:
		if st["main"]:
			_frontage(st)
	for st in streets:
		if not st["main"]:
			_frontage(st)
	if s.style not in ["classical"] and not (s.style == "east" and s.culture not in ["samurai", "joseon"]):
		_infill()
	if s.style in ["nile", "near_east", "south_asian"]:
		_clusters(false)
	elif s.culture == "joseon":
		_clusters(true)
	_yards()
	_orchards()
	if tier >= 1:
		_fields()
	if sea != Vector2.ZERO:
		_piers()
	if s.style == "nile" and capital:
		_pyramid(heart, half, index)


# =========================================================================================
# Small tools
# =========================================================================================

## The yaw that turns a model's front (+z) towards `dir`.
func _face(dir: Vector2) -> float:
	return atan2(dir.x, dir.y)


## How steep the ground is at `p` (rise over run, as drawn).
func _slope(p: Vector2) -> float:
	var y0 := s.earth.ground_at_pixel(p).y
	var worst := 0.0
	var offs: Array[Vector2] = [Vector2(0.35, 0), Vector2(0, 0.35), Vector2(-0.35, 0), Vector2(0, -0.35)]
	for d in offs:
		worst = maxf(worst, absf(s.earth.ground_at_pixel(p + d).y - y0))
	return worst / 0.35


func _reach_at(phi: float) -> float:
	var t := fposmod(phi, TAU) / TAU * SECT
	var k := int(floor(t)) % SECT
	return lerpf(reach[k], reach[(k + 1) % SECT], t - floor(t))


## True when `p` is inside the outline (with `pad` to spare).
func _inside(p: Vector2, pad := 0.0) -> bool:
	var d := p - c
	return d.length() + pad <= _reach_at(d.angle())


## The wall's radius in direction `phi` (0 where the water is the wall).
func _wall_r(phi: float) -> float:
	var t := fposmod(phi, TAU) / TAU * SECT
	var k := int(floor(t)) % SECT
	var k2 := (k + 1) % SECT
	if reach[k] <= 0.0 or reach[k2] <= 0.0 or _wet[k] == 1 or _wet[k2] == 1:
		return 0.0
	return lerpf(reach[k], reach[k2], t - floor(t)) + 0.5


func _rank(p: Vector2) -> String:
	if not _inside(p):
		return "suburb"
	var u := p.distance_to(heart) / maxf(_mean_r, 1.0)
	if u < (0.38 if tier >= 3 else 0.30) and (tier >= 2 or capital):
		return "core"
	if u < 0.72:
		return "city"
	return "edge"


func _road_kind(main: bool, outside := false) -> String:
	if outside or tier <= 1:
		return "dirt"
	if tier == 2:
		return "cobble" if main else "dirt"
	return "cobble"


func _plaza_kind() -> String:
	return "earth" if tier <= 1 else "flag"


func _plen(pts: PackedVector2Array) -> float:
	var t := 0.0
	for i in pts.size() - 1:
		t += pts[i].distance_to(pts[i + 1])
	return t


## Position and direction at distance `d` along `pts`.
func _at(pts: PackedVector2Array, d: float) -> Array:
	var left := maxf(d, 0.0)
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if left <= seg or i == pts.size() - 2:
			var t := (pts[i + 1] - pts[i]).normalized() if seg > 0.0001 else Vector2.RIGHT
			return [pts[i] + t * minf(left, seg), t]
		left -= seg
	return [pts[0], Vector2.RIGHT]


## A smooth curve through `pts` (Catmull-Rom).
func _smooth(pts: PackedVector2Array, sub := 3) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for k in sub:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(k) / sub))
	out.append(pts[pts.size() - 1])
	return out


## The street index: every segment goes into the cells it touches.
func _index(pts: PackedVector2Array, hw: float) -> void:
	for i in pts.size() - 1:
		var total := pts[i].distance_to(pts[i + 1])
		var parts := maxi(1, int(ceil(total / CELLG)))
		for m in parts:
			var a := pts[i].lerp(pts[i + 1], float(m) / parts)
			var b := pts[i].lerp(pts[i + 1], float(m + 1) / parts)
			var lo := a.min(b) - Vector2(hw, hw)
			var hi := a.max(b) + Vector2(hw, hw)
			for gx in range(floori(lo.x / CELLG), floori(hi.x / CELLG) + 1):
				for gy in range(floori(lo.y / CELLG), floori(hi.y / CELLG) + 1):
					var key := Vector2i(gx, gy)
					if not _seg.has(key):
						_seg[key] = []
					_seg[key].append([a, b, hw])


## Distance from `p` to the nearest street edge, up to `maxd`.
func _street_dist(p: Vector2, maxd: float) -> float:
	return float(_nearest(p, maxd).get("dist", maxd))


## The nearest street to `p` within `maxd`: {dist (to its edge), pos (on its centre line)}, or {}.
func _nearest(p: Vector2, maxd: float) -> Dictionary:
	var best := maxd
	var at := Vector2.ZERO
	var found := false
	for gx in range(floori((p.x - maxd) / CELLG), floori((p.x + maxd) / CELLG) + 1):
		for gy in range(floori((p.y - maxd) / CELLG), floori((p.y + maxd) / CELLG) + 1):
			var list: Variant = _seg.get(Vector2i(gx, gy))
			if list == null:
				continue
			for e in (list as Array):
				var q := Geometry2D.get_closest_point_to_segment(p, e[0], e[1])
				var d := p.distance_to(q) - float(e[2])
				if d < best:
					best = d
					at = q
					found = true
	if not found:
		return {}
	return {"dist": best, "pos": at}


## Lay a street: remember it for houses to face and for the ground to draw.
func _street(pts: PackedVector2Array, w: float, main: bool, side := 0, outside := false, draw := true) -> Dictionary:
	if pts.size() < 2 or _plen(pts) < 0.4:
		return {}
	var st := {"pts": pts, "w": w, "main": main, "side": side, "lead": 0.0}
	streets.append(st)
	_index(pts, w * 0.5)
	if draw:
		s.ground.road(pts, w, _road_kind(main, outside))
	return st


func _centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / maxf(poly.size(), 1.0)


## Which way is out of the polygon: +1 or -1 on the left-hand normal of its edges.
func _outward(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return -1.0 if area > 0.0 else 1.0


func _edge_dist(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, p.distance_to(q))
	return best


func _rect(ctr: Vector2, u: Vector2, hx: float, hy: float, wob := 0.0) -> PackedVector2Array:
	var v := Vector2(-u.y, u.x)
	var out := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var cc: Vector2 = corner
		var jit := Vector2(s.rng.randf_range(-wob, wob), s.rng.randf_range(-wob, wob))
		out.append(ctr + u * (cc.x * hx + jit.x) + v * (cc.y * hy + jit.y))
	return out


## An irregular roundish shape.
func _blob(ctr: Vector2, rx: float, ry: float, rot: float, n := 10, wob := 0.12) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n:
		var a := k * TAU / n
		var f := 1.0 + s.rng.randf_range(-wob, wob)
		out.append(ctr + Vector2(cos(a) * rx * f, sin(a) * ry * f).rotated(rot))
	return out


## The polygon's outline as a closed walk.
func _ring_pts(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(poly)
	out.append(poly[0])
	return out


## A square, court or green: told to the ground, kept clear of buildings, and remembered.
func _square(poly: PackedVector2Array, kind: String, centred := false, claim := true) -> Dictionary:
	s.ground.area(poly, kind)
	var ctr := _centroid(poly)
	var r := 0.0
	for p in poly:
		r = maxf(r, p.distance_to(ctr))
	var sq := {"poly": poly, "kind": kind, "centre": ctr, "r": r, "centred": centred}
	squares.append(sq)
	if claim:
		_claim_poly(poly)
	return sq


## Claim the inside of a polygon so nothing is built on it (a margin is left at its edge so
## houses can face it).
func _claim_poly(poly: PackedVector2Array) -> void:
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var x := lo.x
	while x <= hi.x:
		var y := lo.y
		while y <= hi.y:
			var q := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(q, poly) and _edge_dist(q, poly) >= 0.17:
				s._claim(q, 0.2)
			y += 0.3
		x += 0.3


## True when every corner of a rectangle lies inside the outline.
func _rect_inside(ctr: Vector2, u: Vector2, hx: float, hy: float) -> bool:
	for p in _rect(ctr, u, hx + 0.3, hy + 0.3):
		if not _inside(p, 0.3):
			return false
	return true


func _in_square(p: Vector2, pad := 0.0) -> bool:
	for sq in squares:
		var poly: PackedVector2Array = sq["poly"]
		if Geometry2D.is_point_in_polygon(p, poly) or (pad > 0.0 and _edge_dist(p, poly) < pad):
			return true
	return false


## A place to build: dry, not steep, nothing there.
func _can(p: Vector2, r: float) -> bool:
	return s._dry(p, r) and s._free(p, r) and _slope(p) < 0.3


func _highest(centre: Vector2, radius: float) -> Vector2:
	var best := centre
	var best_y := -INF
	var x := -radius
	while x <= radius:
		var y := -radius
		while y <= radius:
			var p := centre + Vector2(x, y)
			if Vector2(x, y).length() <= radius and _inside(p, 1.0) and s._dry(p, 1.0) and _slope(p) < 0.3:
				var h := s.earth.ground_at_pixel(p).y - Vector2(x, y).length() * 0.01
				if h > best_y:
					best_y = h
					best = p
			y += 0.5
		x += 0.5
	return best


## A prop (or tree) that also claims its ground; false if the model does not exist yet.
func _prop(kind: String, p: Vector2, yaw: float, size := 1.0, r := 0.15) -> bool:
	if not s._dry(p, r * 0.6) or not s._free(p, r):
		return false
	if not s.prop(kind, p, yaw, size, -1):
		return false
	s._claim(p, r)
	return true


# =========================================================================================
# The outline
# =========================================================================================

## March out from the centre in every direction until the ground turns to water or cliff.
func _outline(nominal: Callable) -> void:
	reach = PackedFloat32Array()
	reach.resize(SECT)
	_wet = PackedByteArray()
	_wet.resize(SECT)
	var base_y := s.earth.ground_at_pixel(c).y
	var cut: Array = []
	cut.resize(SECT)
	for k in SECT:
		var phi := k * TAU / SECT
		var dir := Vector2(cos(phi), sin(phi))
		var limit: float = nominal.call(phi)
		var r := 0.0
		var hit := false
		var hit_wet := false
		while r < limit:
			var q := minf(r + 0.25, limit)
			var p := c + dir * q
			var w := not s._dry(p, 0.3)
			if w or _slope(p) > 0.45 or absf(s.earth.ground_at_pixel(p).y - base_y) > 0.6:
				hit = true
				hit_wet = w
				break
			r = q
		reach[k] = r if r >= 1.2 else 0.0
		cut[k] = hit
		_wet[k] = 1 if (hit_wet and r >= 1.2) else 0
	for pass_no in 5:   # an even edge where the land gave out, not a saw
		var next := PackedFloat32Array(reach)
		for k in SECT:
			if reach[k] <= 0.0:
				continue
			var near_cut := false
			for d in range(-3, 4):
				near_cut = near_cut or cut[(k + d + SECT) % SECT]
			if near_cut:
				var sum5 := 0.0
				for d in range(-2, 3):
					sum5 += reach[(k + d + SECT) % SECT]
				next[k] = minf(reach[k], sum5 / 5.0 * 1.02)
		reach = next
	var sum := 0.0
	for k in SECT:
		sum += reach[k]
	_mean_r = sum / SECT


## A rounded rectangle's radius in direction `phi` (relative to its axes).
func _rect_reach(phi: float, hx: float, hy: float, noise: float, seed_a: float) -> float:
	var cx := absf(cos(phi)) / hx
	var cy := absf(sin(phi)) / hy
	var r := pow(pow(cx, 4.0) + pow(cy, 4.0), -0.25)
	return r * (1.0 + noise * sin(3.0 * phi + seed_a))


## A city's own irregular outline.
func _blob_reach(phi: float, base: float, a: float, b: float, d: float) -> float:
	return base * (0.88 + 0.12 * sin(2.0 * phi + a) + 0.07 * sin(3.0 * phi + b) + 0.04 * sin(5.0 * phi + d))


func _max_reach() -> float:
	var m := 0.0
	for k in SECT:
		m = maxf(m, reach[k])
	return m


# =========================================================================================
# Streets
# =========================================================================================

func _terrain_cost(q: Vector2, y_ref: float) -> float:
	if not s._dry(q, 0.25):
		return 60.0
	return absf(s.earth.ground_at_pixel(q).y - y_ref) * 14.0 + _slope(q) * 4.0


## A road from `a` to `b` that bends gently, preferring level ground.
func _wander(a: Vector2, b: Vector2, bend: float, depth := 3) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	var y_ref := (s.earth.ground_at_pixel(a).y + s.earth.ground_at_pixel(b).y) * 0.5
	for level in depth:
		var out := PackedVector2Array()
		for i in pts.size() - 1:
			var p0 := pts[i]
			var p1 := pts[i + 1]
			out.append(p0)
			var mid := (p0 + p1) * 0.5
			var d := p1 - p0
			var n := Vector2(-d.y, d.x).normalized()
			var best := mid
			var best_cost := INF
			for oi in 5:
				var off := (oi - 2) * 0.5
				var q := mid + n * (off * bend * d.length())
				var cost := absf(off) * 0.25 + s.rng.randf() * 0.3 + _terrain_cost(q, y_ref)
				if cost < best_cost:
					best_cost = cost
					best = q
			out.append(best)
		out.append(pts[pts.size() - 1])
		pts = out
	return _smooth(pts, 2)


## Grow a lane from `start` in direction `dir`: it feels its way over the ground (round
## steep places, along the contours), and stops at the outline, at water, at a building or
## where it meets another street.
func _grow(start: Vector2, dir: Vector2, max_len: float, wob: float, outside := false) -> PackedVector2Array:
	var pts := PackedVector2Array([start])
	var p := start
	var h := dir.normalized()
	var travelled := 0.0
	var step := 0.3
	while travelled < max_len:
		var best_q := Vector2.ZERO
		var best_h := h
		var best_c := INF
		var y0 := s.earth.ground_at_pixel(p).y
		for ti in 3:
			var turn := (ti - 1) * 0.35 + s.rng.randf_range(-wob, wob)
			var hh := h.rotated(turn)
			var q := p + hh * step
			var cost := absf(turn) * 0.5 + absf(s.earth.ground_at_pixel(q).y - y0) * 30.0
			if not s._dry(q, 0.2):
				cost += 100.0
			if cost < best_c:
				best_c = cost
				best_q = q
				best_h = hh
		if best_c >= 100.0:
			break
		h = (h * 0.55 + best_h * 0.45).normalized()
		p = best_q
		travelled += step
		if not outside and not _inside(p, 0.0):
			break
		if _in_square(p) or not s._free(p, 0.12):
			break
		if travelled > 0.8:
			var near := _nearest(p, 0.45)
			if not near.is_empty():
				pts.append(near["pos"])
				break
		pts.append(p)
	return pts


## Lay straight `a` to `b` where it is open ground: the runs that fit (inside the outline,
## clear of squares and buildings). Returns the streets made.
func _line_run(a: Vector2, b: Vector2, w: float, main: bool) -> Array:
	var out: Array = []
	var total := a.distance_to(b)
	var steps := maxi(2, int(ceil(total / 0.3)))
	var cur := PackedVector2Array()
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var ok := _inside(p, 0.0) and not _in_square(p, 0.0) and s._free(p, 0.1) and s._dry(p, 0.2)
		if ok:
			cur.append(p)
		if (not ok or i == steps) and cur.size() >= 2:
			var st := _street(cur, w, main)
			if not st.is_empty():
				out.append(st)
			cur = PackedVector2Array()
		elif not ok:
			cur = PackedVector2Array()
	return out


## A way out of the city at angle `a`: a gate in the wall of a walled city, else just the
## edge of the town. {} where the water guards that way.
func _exit(a: float) -> Dictionary:
	var dir := Vector2(cos(a), sin(a))
	var g: Dictionary
	if walled:
		var wr := _wall_r(a)
		if wr <= 0.0:
			return {}
		g = {"pos": c + dir * wr, "dir": dir}
	else:
		var rr := _reach_at(a)
		if rr < 1.5 or _wet[int(fposmod(a, TAU) / TAU * SECT) % SECT] == 1:
			return {}
		g = {"pos": c + dir * rr, "dir": dir}
	gates.append(g)
	return g


## Lanes until no part of the city is far from a street: the blocks between them are what
## the houses fill.
func _fill_gaps(wob: float, w: float, max_lanes: int) -> void:
	var cands: Array = []   # [pos, distance to the nearest street]
	var n := int(ceil(_max_reach() / 0.8)) + 1
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var p := c + Vector2(i, j) * 0.8 + Vector2(s.rng.randf_range(-0.2, 0.2), s.rng.randf_range(-0.2, 0.2))
			if not _inside(p, 0.4) or not s._dry(p, 0.25) or not s._free(p, 0.25):
				continue
			cands.append([p, _street_dist(p, 5.0)])
	for lane_no in max_lanes:
		var best := -1
		var best_excess := 0.0
		for i in cands.size():
			var p: Vector2 = cands[i][0]
			var excess: float = float(cands[i][1]) - _gap_limit(p)
			if excess > best_excess:
				best_excess = excess
				best = i
		if best < 0:
			break
		var target: Vector2 = cands[best][0]
		var near := _nearest(target, 6.0)
		if near.is_empty():
			cands[best][1] = 0.0
			continue
		var from: Vector2 = near["pos"]
		var heading := (target - from).normalized()
		var lane := _grow(from, heading, _max_reach() * 1.6, wob)
		if lane.size() < 3 or _plen(lane) < 0.9:
			cands[best][1] = 0.0
			continue
		lane = _smooth(lane, 2)
		var st := _street(lane, w, false)
		if st.is_empty():
			cands[best][1] = 0.0
			continue
		for cand in cands:   # the new lane serves the blocks beside it
			var cp: Vector2 = cand[0]
			for i in lane.size() - 1:
				var q := Geometry2D.get_closest_point_to_segment(cp, lane[i], lane[i + 1])
				cand[1] = minf(float(cand[1]), cp.distance_to(q) - w * 0.5)
		cands[best][1] = 0.0


func _gap_limit(p: Vector2) -> float:
	var rank := _rank(p)
	var base := 0.95 if rank == "core" else (1.1 if rank == "city" else 1.45)
	return base * _lane_gap


## A lane round the city just inside the wall, so the outermost houses face a street.
func _pomerium(inset: float) -> void:
	var run := PackedVector2Array()
	var made: Array = []
	var segs := 64
	for k in segs + 1:
		var phi := (k % segs) * TAU / segs
		var r := _reach_at(phi) + inset
		var p := c + Vector2(cos(phi), sin(phi)) * r
		var ok := r > 1.5 + inset and _wet[int(fposmod(phi, TAU) / TAU * SECT) % SECT] == 0 and s._dry(p, 0.2) and not _in_square(p) and s._free(p, 0.1)
		if ok:
			run.append(p)
		if (not ok or k == segs) and run.size() >= 4:
			made.append(run)
			run = PackedVector2Array()
		elif not ok:
			run = PackedVector2Array()
	for r in made:
		_street(_smooth(r, 2), 0.3, false, 0)


## A ring lane at `frac` of the outline's radius, in runs where the ground allows.
func _ring(frac: float, w: float) -> void:
	var run := PackedVector2Array()
	var made: Array = []
	var segs := 48
	var noise := s.rng.randf() * TAU
	for k in segs + 1:
		var phi := (k % segs) * TAU / segs
		var r := _reach_at(phi) * (frac + 0.04 * sin(3.0 * phi + noise))
		var p := c + Vector2(cos(phi), sin(phi)) * r
		var ok := r > 1.0 and s._dry(p, 0.2) and not _in_square(p, 0.3) and s._free(p, 0.1) and _slope(p) < 0.3
		if ok:
			run.append(p)
		if (not ok or k == segs) and run.size() >= 4:
			made.append(run)
			run = PackedVector2Array()
		elif not ok:
			run = PackedVector2Array()
	for r in made:
		_street(_smooth(r, 2), w, false)


## Cut a road where it enters a square.
func _trim_at_squares(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		if _in_square(pts[i]):
			if i > 0:
				var lo := pts[i - 1]
				var hi := pts[i]
				for it in 5:   # find the edge
					var mid := (lo + hi) * 0.5
					if _in_square(mid):
						hi = mid
					else:
						lo = mid
				out.append(lo)
			return out
		out.append(pts[i])
	return out


## Gates where a main street's two ends reach the edge.
func _gate_at_ends(st: Dictionary) -> void:
	var pts: PackedVector2Array = st["pts"]
	for e in [pts[0], pts[pts.size() - 1]]:
		var ep: Vector2 = e
		var a := (ep - c).angle()
		if ep.distance_to(c) > _reach_at(a) - 0.8:
			_exit(a)


## Positions of grid lines: 0, then outward each way, tighter in the core.
func _grid_lines(extent: float, pitch: float, core_scale: float) -> Array:
	var out: Array = [0.0]
	for dirn in [1.0, -1.0]:
		var pos := 0.0
		while true:
			var t := clampf(absf(pos) / (extent * 0.8), 0.0, 1.0)
			pos += float(dirn) * pitch * lerpf(core_scale, 1.1, t) * s.rng.randf_range(0.92, 1.08)
			if absf(pos) > extent:
				break
			out.append(pos)
	return out


## Roads from `angles` to `target`, each trimmed at the squares.
func _mains(angles: Array, target: Vector2, bend: float, w: float) -> void:
	for a in angles:
		var g := _exit(float(a))
		if g.is_empty():
			continue
		var pts := _trim_at_squares(_wander(g["pos"], target, bend))
		_street(pts, w, true)


# =========================================================================================
# Houses along the streets
# =========================================================================================

func _plot(rank: String) -> Dictionary:
	var rng := s.rng
	match rank:
		"core":
			return {"f": rng.randf_range(0.30, 0.335), "gap": rng.randf_range(0.0, 0.03), "set": 0.03, "size": 1.12}
		"city":
			return {"f": rng.randf_range(0.28, 0.33), "gap": rng.randf_range(0.0, 0.12) * _dense, "set": rng.randf_range(0.05, 0.14), "size": 1.05}
		"edge":
			return {"f": rng.randf_range(0.25, 0.30), "gap": rng.randf_range(0.05, 0.35) * _dense, "set": rng.randf_range(0.10, 0.28), "size": 0.92}
	return {"f": rng.randf_range(0.26, 0.31), "gap": rng.randf_range(0.5, 1.6), "set": rng.randf_range(0.15, 0.4), "size": 0.95}


func _zone_ok(p: Vector2, rank: String) -> bool:
	if rank != "suburb":
		return true
	if not (walled or tier >= 2):
		return false
	var d := p - c
	var wr := _wall_r(d.angle())
	var edge := wr if wr > 0.0 else _reach_at(d.angle()) + 0.3
	return d.length() > edge + 0.5 and d.length() < edge + 3.2 + tier * 0.7


## One house at `p` facing `yaw`, if the ground allows.
func _house(p: Vector2, yaw: float, f: float, rank: String, size: float, big := false) -> bool:
	if not _zone_ok(p, rank) or _slope(p) > 0.3:
		return false
	if not s._fit_house(p, yaw, size, f, index, 0.4, rank, big):
		return false
	mine.append([p, yaw, f, rank])
	return true


func _can_big(rank: String) -> bool:
	if not _big_ok.has(rank):
		_big_ok[rank] = not s._house_kinds(rank, true).is_empty()
	return _big_ok[rank]


## Houses along both sides of a street, facing it.
func _frontage(st: Dictionary) -> void:
	var pts: PackedVector2Array = st["pts"]
	var hw: float = float(st["w"]) * 0.5
	var length := _plen(pts)
	var only: int = int(st["side"])
	var wobble := 0.04 if s.style in ["northern", "nile", "near_east", "south_asian"] else 0.012
	for side in [1, -1]:
		if only != 0 and side != only:
			continue
		var cur := s.rng.randf_range(0.0, 0.25) + float(st["lead"])
		var guard := 0
		while cur < length - 0.2 and guard < 600:
			guard += 1
			var probe := _at(pts, minf(cur + 0.3, length))
			var pt: Vector2 = probe[0]
			var tt: Vector2 = probe[1]
			var rank := _rank(pt + Vector2(-tt.y, tt.x) * float(side) * 0.6)
			var plot := _plot(rank)
			var f: float = plot["f"]
			var here := _at(pts, minf(cur + f, length))
			var t: Vector2 = here[1]
			var n := Vector2(-t.y, t.x) * float(side)
			var base: Vector2 = here[0]
			var p: Vector2 = base + n * (hw + float(plot["set"]) + f)
			var size: float = plot["size"]
			var yaw := _face(-n) + s.rng.randf_range(-wobble, wobble)
			# a plot left empty for a garden, now and then at the edge
			if rank == "edge" and s.rng.randf() < 0.1 and not _in_square(p):
				if s._dry(p, f) and s._free(p, f) and _street_dist(p, f) > f * 0.8:
					s.ground.patch(p, f * 1.15, "garden", 0.9)
					_prop("tree_fruit", p + n * 0.1, s.rng.randf() * TAU, 1.0, 0.2)
					s._claim(p, f * 0.8)
				cur += 2.0 * f + 0.1
				continue
			if (rank == "core" and s.rng.randf() < 0.5) or (rank == "city" and s.rng.randf() < 0.12):
				if _can_big(rank):
					var fb := 0.66
					var hb := _at(pts, minf(cur + fb, length))
					var tb: Vector2 = hb[1]
					var nb := Vector2(-tb.y, tb.x) * float(side)
					var pb: Vector2 = (hb[0] as Vector2) + nb * (hw + float(plot["set"]) + 0.42)
					if _street_dist(pb, 0.6) > 0.18 and _house(pb, _face(-nb), fb, rank, size, true):
						cur += 2.0 * fb + float(plot["gap"])
						continue
			var placed := false
			if _street_dist(p, f + 0.1) >= f * 0.98 and not _in_square(p, 0.05):
				placed = _house(p, yaw, f, rank, size)
			if placed:
				cur += 2.0 * f + float(plot["gap"])
			else:
				cur += 0.18


## A second row behind the first, filling the blocks.
func _infill() -> void:
	var step := 0.68
	var n := int(ceil(_max_reach() / step)) + 1
	var cand: Array = []
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var p := c + Vector2(i, j) * step + Vector2(s.rng.randf_range(-0.14, 0.14), s.rng.randf_range(-0.14, 0.14))
			if _inside(p, 0.25):
				cand.append(p)
	cand.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(heart) < b.distance_to(heart))
	for p in cand:
		var rank := _rank(p)
		var prob := 0.95 if rank == "core" else (0.6 if rank == "city" else 0.28)
		if s.rng.randf() > prob:
			continue
		var near := _nearest(p, 2.6)
		if near.is_empty() or float(near["dist"]) < 0.3:
			continue
		if float(near["dist"]) > (2.4 if rank == "core" else 1.9):
			continue
		var plot := _plot(rank)
		var f: float = float(plot["f"]) * 0.97
		if _in_square(p, 0.1) or not s._free(p, f):
			continue
		_house(p, _face((near["pos"] as Vector2) - p) + s.rng.randf_range(-0.1, 0.1), f, rank, float(plot["size"]) * 0.95)


## Courtyard clusters (the south's and Korea's way): houses round a small yard.
func _clusters(rect: bool) -> void:
	var step := 1.5
	var n := int(ceil(_max_reach() / step)) + 1
	var cand: Array = []
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var p := c + Vector2(i, j) * step + Vector2(s.rng.randf_range(-0.35, 0.35), s.rng.randf_range(-0.35, 0.35))
			if not _inside(p, 1.0) or not s._dry(p, 0.9):
				continue
			if _street_dist(p, 3.0) < 0.95 or _in_square(p, 0.5):
				continue
			cand.append(p)
	cand.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(heart) < b.distance_to(heart))
	for p in cand:
		if not s._free(p, 0.35):
			continue
		var near := _nearest(p, 4.0)
		var toward: Vector2 = ((near["pos"] as Vector2) - p).normalized() if not near.is_empty() else Vector2.RIGHT
		var rank := _rank(p)
		var count := 0
		var f := 0.27
		var spots: Array = []   # [position, facing]
		if rect:
			for q in [Vector2(-0.31, -0.62), Vector2(0.31, -0.62), Vector2(-0.31, 0.62), Vector2(0.31, 0.62), Vector2(-0.68, 0.0), Vector2(0.68, 0.0)]:
				var off: Vector2 = q
				spots.append([p + off.rotated(toward.angle()), (-off).rotated(toward.angle())])
		else:
			var k := s.rng.randi_range(5, 6)
			var rr := s.rng.randf_range(0.7, 0.8)
			for m in k:
				var a: float = toward.angle() + PI + m * TAU / k + (TAU / k) * 0.5
				spots.append([p + Vector2(cos(a), sin(a)) * rr, -Vector2(cos(a), sin(a))])
		for sp in spots:
			var pos: Vector2 = sp[0]
			var fc: Vector2 = sp[1]
			if _street_dist(pos, 0.6) < f * 0.9:
				continue
			if _house(pos, _face(fc), f, rank, 0.9):
				count += 1
		if count >= 3:
			s.ground.area(_blob(p, 0.42, 0.42, 0.0, 8, 0.1), "earth")
			s._claim(p, 0.3)
			if s.style == "south_asian" and s.rng.randf() < 0.5:
				s.prop("prop_tree_platform", p, 0.0, 0.9)
			elif not s.prop("well", p, 0.0, 0.8):
				_prop("palm" if s.style != "south_asian" else "tree_broadleaf", p, 0.0, 0.7, 0.2)


## Backyards behind the houses: gardens, worn earth, an odd fruit tree.
func _yards() -> void:
	var idx := 0
	var tree := _tree_kind()
	for m in mine:
		idx += 1
		var rank: String = m[3]
		if rank == "core":
			continue
		if rank == "city" and idx % 3 != 0:
			continue
		var yaw: float = m[1]
		var front := Vector2(sin(yaw), cos(yaw))
		var r: float = m[2]
		var p: Vector2 = (m[0] as Vector2) - front * (r + 0.3)
		if not s._dry(p, 0.25) or not s._free(p, 0.2) or _street_dist(p, 0.4) < 0.3 or _in_square(p, 0.2):
			continue
		var kind := "garden" if s.rng.randf() < 0.6 else ("grass" if rank != "city" else "earth")
		s.ground.patch(p, 0.34, kind, 0.9)
		if rank != "city" and s.rng.randf() < 0.35:
			_prop(tree, p + Vector2(s.rng.randf_range(-0.1, 0.1), s.rng.randf_range(-0.1, 0.1)), s.rng.randf() * TAU, 0.9, 0.18)
		elif rank == "city" and s.rng.randf() < 0.25:
			s.prop("vegetable_patch", p, yaw, 0.8)


func _tree_kind() -> String:
	return {"classical": "olive", "nile": "palm", "near_east": "palm", "south_asian": "tree_broadleaf",
		"east": "tree_fruit", "northern": "tree_fruit"}.get(s.style, "tree_fruit")


## Orchards and gardens in the open ground at the city's edge.
func _orchards() -> void:
	var want := 2 + tier
	var made := 0
	var tree := _tree_kind()
	for attempt in want * 16:
		if made >= want:
			break
		var a := s.rng.randf() * TAU
		var r := _reach_at(a) * s.rng.randf_range(0.55, 1.05)
		var p := c + Vector2(cos(a), sin(a)) * r
		var rad := s.rng.randf_range(0.8, 1.2)
		if not s._dry(p, rad) or not s._free(p, rad) or _street_dist(p, rad) < rad * 0.7 or _slope(p) > 0.25:
			continue
		s.ground.area(_blob(p, rad, rad * 0.85, s.rng.randf() * PI, 9, 0.1), "grass")
		var rows := int(rad / 0.45)
		for i in range(-rows, rows + 1):
			for j in range(-rows, rows + 1):
				var q := p + Vector2(i, j) * 0.5
				if q.distance_to(p) < rad * 0.82:
					_prop(tree, q + Vector2(s.rng.randf_range(-0.05, 0.05), s.rng.randf_range(-0.05, 0.05)), s.rng.randf() * TAU, 0.85, 0.2)
		s._claim(p, rad * 0.95)
		made += 1


## Ploughed fields just outside the walls.
func _fields() -> void:
	var crops := [Color(0.86, 0.72, 0.30), Color(0.55, 0.70, 0.28), Color(0.74, 0.64, 0.30), Color(0.45, 0.62, 0.26)]
	var fr: float = s._foot("field") * 1.05
	var want := 3 + tier * 2
	var made := 0
	for attempt in want * 10:
		if made >= want:
			break
		var a := s.rng.randf() * TAU
		var wr := _wall_r(a)
		var edge := wr if wr > 0.0 else _reach_at(a) + 0.5
		var p := c + Vector2(cos(a), sin(a)) * (edge + s.rng.randf_range(1.2, 3.8 + tier * 0.5))
		if s._dry(p, fr) and s._free(p, fr) and _slope(p) < 0.2 and _street_dist(p, fr) > fr * 0.6:
			s._add("field", p, 0.0, a + PI / 2.0, Vector3.ONE, crops[s.rng.randi() % crops.size()])
			s._claim(p, fr)
			made += 1


## Small greens: a bit of grass with a tree, houses facing it.
func _greens() -> void:
	var want := 1 + tier
	var made := 0
	for attempt in want * 20:
		if made >= want:
			break
		var a := s.rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * _reach_at(a) * s.rng.randf_range(0.3, 0.8)
		var sd := _street_dist(p, 1.6)
		if sd < 0.5 or sd > 1.3 or not _can(p, 0.65) or _in_square(p, 0.6) or not _inside(p, 0.8):
			continue
		var poly := _blob(p, 0.5, 0.42, s.rng.randf() * PI, 8, 0.12)
		_square(poly, "grass")
		if not _prop("tree_broadleaf", p, 0.0, 1.0, 0.25):
			s.prop("well", p, 0.0, 0.9)
		_street(_ring_pts(poly), 0.1, false, int(_outward(poly)), false, false)
		made += 1


## Dirt roads out of the gates, which suburbs and fields line.
func _suburb_roads() -> void:
	for g in gates:
		var dir: Vector2 = g["dir"]
		var length := 1.4 + (2.6 + tier * 0.8 if (walled or tier >= 2) else 0.0)
		var pts := _grow(g["pos"], dir, length, 0.06, true)
		if pts.size() >= 3:
			var st := _street(_smooth(pts, 2), 0.4, true, 0, true)
			if not st.is_empty():
				st["lead"] = 0.5


# =========================================================================================
# Public buildings and squares
# =========================================================================================

## Positions round a square's edge, outside it, facing in: [pos, yaw].
func _slots(sq: Dictionary, r: float) -> Array:
	var poly: PackedVector2Array = sq["poly"]
	var out: Array = []
	var out_sign := _outward(poly)
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var len := a.distance_to(b)
		if len < 0.05:
			continue
		var t := (b - a) / len
		var nrm := Vector2(-t.y, t.x) * out_sign
		var steps := maxi(1, int(len / (r * 1.1)))
		for j in steps:
			var base := a + t * (len * (j + 0.5) / steps)
			out.append([base + nrm * (r + 0.1), _face(-nrm)])
	var shift := s.rng.randi() % maxi(out.size(), 1)
	return out.slice(shift) + out.slice(0, shift)


## Find a place for a building of radius `r`: on one of the `venues`, else near the heart.
## Returns [pos, yaw] or [].
func _spot(r: float, venues: Array, prefer := Vector2.ZERO) -> Array:
	for v in venues:
		var sq: Dictionary = v
		if sq.get("centred", false):
			var cp: Vector2 = sq["centre"]
			if _can(cp, r * 0.9):
				return [cp, _face(heart - cp) if cp.distance_to(heart) > 0.5 else -theta]
			continue
		var slots := _slots(sq, r)
		if prefer != Vector2.ZERO:
			var sc: Vector2 = sq["centre"]
			slots.sort_custom(func(a: Array, b: Array) -> bool:
				return ((a[0] as Vector2) - sc).normalized().dot(prefer) > ((b[0] as Vector2) - sc).normalized().dot(prefer))
		for sl in slots:
			var p: Vector2 = sl[0]
			if _can(p, r) and _street_dist(p, r) > r * 0.5:
				return sl
	for ring in range(1, 16):
		for k in 12:
			var a := k * TAU / 12.0 + ring * 0.5
			var p := heart + Vector2(cos(a), sin(a)) * ring * 0.55 * maxf(r, 0.6)
			if _inside(p, r * 0.5) and _can(p, r) and _street_dist(p, r) > r * 0.5:
				return [p, _face(heart - p)]
	return []


## The palace, facing a square.
func _place_palace(venues: Array, prefer := Vector2.ZERO) -> Array:
	var part := s._palace_part() if capital else ""
	var r: float = s._foot(part) if part != "" else float(s.PALACE_R.get(s.style, 0.6)) * s.S
	var sp := _spot(r, venues, prefer)
	if sp.is_empty():
		return []
	var p: Vector2 = sp[0]
	var yaw: float = sp[1]
	if part != "":
		s._add(part, p, 0.0, yaw, Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.85)
	else:
		s._palace(p, index, yaw)
	s._claim(p, r)
	return sp


## A banner by the palace: modest, and one only.
func _banner(near: Vector2, outward: Vector2) -> void:
	var p := near + outward
	if _can(p, 0.2):
		s._add("k_flag", p, 0.0, 0.0, Vector3.ONE * 0.4, Color.WHITE, index, 1.0)
		s._claim(p, 0.2)


## Put each of `looks` on a venue (a square) of its kind: the sacred ones on `sacred` first.
func _publics(looks: Array, venues: Array, sacred: Array = []) -> void:
	for look in looks:
		var is_sacred := false
		for key in ["pagoda", "church", "stupa", "shikhara", "ziggurat", "obelisk", "sphinx", ":temple", "forum_hall"]:
			if str(look).contains(key):
				is_sacred = true
		var use: Array = venues
		if is_sacred and not sacred.is_empty():
			use = sacred + venues
		_public_building(str(look), use)


## True when one of `looks` is a temple-like building that wants a court.
func _has_sacred(looks: Array) -> bool:
	for look in looks:
		for key in ["pagoda", "church", "stupa", "shikhara", "ziggurat", "obelisk", "sphinx", ":temple"]:
			if str(look).contains(key):
				return true
	return false


func _landmarks(site: Dictionary, t: int) -> Array:
	var out: Array = []
	var cap: bool = site["capital"]
	match s.style:
		"east":
			if cap or t >= 2:
				out.append("|m:east:pagoda")
			if t >= 1:
				out.append("|m:east:gate")
		"classical":
			if t >= 2 or cap:
				out.append("|m:classical:forum_hall")
			if t >= 3:
				out.append("|m:classical:triumphal_arch")
			if t >= 3 or (cap and t >= 2):
				out.append("|m:classical:villa_great")
		"northern":
			if t >= 1 or cap:
				out.append("|m:northern:church")
			if t >= 2:
				out.append("|m:northern:market_hall")
		"nile":
			if cap or t >= 2:
				out.append("|m:south:obelisk")
			if cap and t >= 2:
				out.append("|m:south:sphinx")
		"near_east":
			if t >= 2 and not cap:
				out.append("|m:south:ziggurat")
		"south_asian":
			if cap or t >= 2:
				out.append("|m:south:stupa")
			if t >= 1:
				out.append("|m:south:temple_shikhara")
	return out


## A public building (D-111) on its venue, facing the square. "|works|look" is one going up
## (in scaffolding); "|pagoda" the pagoda of an eastern city.
func _public_building(look: String, venues: Array) -> void:
	var building := look
	var part := ""
	if look.begins_with("|m:"):
		var bits := look.split(":")
		part = s._model(bits[1], bits[2], s.GRAND_UNIT)
		if part == "":
			return
	elif look == "|pagoda":
		part = "f_pagoda"
	else:
		if look.begins_with("|works|"):
			building = look.substr(7)
		var entry_look: Array = Buildings.CITY_LOOKS.get(building, Buildings.CITY_LOOKS["hall"])
		var civic := str(s.CIVIC_OF.get(str(entry_look[0]), ""))
		part = s._model("civic", civic, s.CIVIC_UNIT) if civic != "" else ""
		if part == "":
			part = "b_" + building
		if not s._parts.has(part):
			var entry: Array = Buildings.CITY_LOOKS.get(building, Buildings.CITY_LOOKS["hall"])
			s._parts[part] = {"mesh": Buildings.city_building(building, float(entry[1]) * s.S), "transforms": [],
				"colours": [], "kit": true}
	var scale := 1.3 if part == "f_pagoda" else 1.0
	var r: float = s._foot(part) * scale
	var sp := _spot(r, venues)
	if sp.is_empty():
		return
	var p: Vector2 = sp[0]
	var face: float = sp[1]
	if look.begins_with("|works|"):
		_scaffold_at(part, p, face, r, index)
	elif part.begins_with("m_civic_") or look.begins_with("|m:"):
		s._add(part, p, 0.0, face, Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.6)
	elif part == "f_pagoda":
		s._add(part, p, 0.0, face, Vector3.ONE * scale, Color(0.36, 0.38, 0.42), index, 0.3)
	else:
		s._add(part, p, 0.0, face, Vector3.ONE, Color(0.88, 0.55, 0.38), index, 0.4)
	s._claim(p, r)


## Building work in a city (D-127): the new building half-risen in its place, wrapped in
## timber scaffolding, with a crane over it.
func _scaffold_at(part: String, spot: Vector2, face: float, r: float, site_index: int) -> void:
	s._add(part, spot, 0.0, face, Vector3(1.0, 0.55, 1.0), Color(0.88, 0.55, 0.38), site_index, 0.4)
	var timber := Color(0.62, 0.44, 0.26)
	var e := r * 0.8
	for corner in [Vector2(-e, -e), Vector2(e, -e), Vector2(e, e), Vector2(-e, e)]:
		s._add("pole", spot + corner, 0.0, 0.0, Vector3(1.6, 0.9, 1.6), timber)
	for height in [0.18, 0.4]:   # walkways of planks
		s._add("terrace", spot, height * s.S, face, Vector3(e * 2.0 / (0.7 * s.S), 0.2, e * 2.0 / (0.5 * s.S)), timber.lightened(0.1))
	var mast := spot + Vector2(e, 0)
	s._add("pole", mast, 0.0, 0.0, Vector3(2.0, 1.8, 2.0), timber.darkened(0.1))
	s._add("terrace", mast + Vector2(-e * 0.7, 0), 1.2 * s.S, 0.0, Vector3(1.1, 0.8, 0.1), timber.darkened(0.1))


## Market stalls round the inside of a square.
func _stalls(sq: Dictionary, n: int) -> void:
	var ctr: Vector2 = sq["centre"]
	var r: float = sq["r"]
	var poly: PackedVector2Array = sq["poly"]
	for k in n:
		var a := k * TAU / n + s.rng.randf_range(-0.1, 0.1)
		var p := ctr + Vector2(cos(a), sin(a)) * r * 0.55
		if Geometry2D.is_point_in_polygon(p, poly) and _edge_dist(p, poly) > 0.3:
			s.prop("market_stall", p, _face(ctr - p), 1.0, index)


## A low stone wall (or hedge) round a precinct, open towards `gate`.
func _enclose(poly: PackedVector2Array, kind: String, gate: Vector2) -> void:
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var len := a.distance_to(b)
		var parts := maxi(1, int(len / 0.67))
		var t := (b - a) / maxf(len, 0.001)
		for j in parts:
			var p := a + t * (len * (j + 0.5) / parts)
			if p.distance_to(gate) < 0.55:
				continue
			if s._dry(p, 0.1) and _street_dist(p, 0.2) > 0.05:
				s.prop(kind, p, _face(Vector2(-t.y, t.x)), 1.0)


# =========================================================================================
# Walls
# =========================================================================================

## Walls along the outline, towers at the turns, a gatehouse where each road leaves; nothing
## where the water guards the city.
func _walls() -> void:
	var family: String = {"east": "east", "classical": "classical", "northern": "northern", "nile": "mud",
		"near_east": "mud", "south_asian": "south_asian", "steppe": "steppe"}.get(s.style, "northern")
	var wall_part := s._model("walls", "wall_" + family, s.WALL_UNIT)
	var tower_part := s._model("walls", "tower_" + family, s.WALL_UNIT)
	var gate_part := s._model("walls", "gate_nile" if s.style == "nile" else "gate_" + family, s.WALL_UNIT)
	var kit := wall_part != "" and tower_part != "" and gate_part != ""
	var piece: float = s.WALL_UNIT if kit else 0.24 * s.S / 1.31
	var tint: Color = s.ROOF_BASE.get(s.style, Color.WHITE)
	var pts: Array = []   # the wall line, Vector2 or null
	var any_gap := false
	for k in SECT:
		var phi := k * TAU / SECT
		var wr := _wall_r(phi)
		if wr <= 0.0:
			pts.append(null)
			any_gap = true
		else:
			pts.append(c + Vector2(cos(phi), sin(phi)) * wr)
	var runs: Array = []
	var start := 0
	if any_gap:
		for k in SECT:
			if pts[k] == null:
				start = (k + 1) % SECT
				break
	var cur := PackedVector2Array()
	for m in SECT:
		var k := (start + m) % SECT
		if pts[k] == null:
			if cur.size() >= 2:
				runs.append(cur)
			cur = PackedVector2Array()
		else:
			cur.append(pts[k])
	if not any_gap and cur.size() >= 2:
		cur.append(cur[0])
	if cur.size() >= 2:
		runs.append(cur)
	var near_gate := func(p: Vector2) -> bool:
		for g in gates:
			if p.distance_to(g["pos"]) < piece * 0.62:
				return true
		return false
	for run in runs:
		var rp: PackedVector2Array = run
		var total := _plen(rp)
		var n := maxi(1, int(round(total / piece)))
		var prev_dir := Vector2.ZERO
		for i in n:
			var a: Vector2 = _at(rp, total * i / n)[0]
			var b: Vector2 = _at(rp, total * (i + 1) / n)[0]
			var mid := (a + b) * 0.5
			var dir := (b - a).normalized()
			var yaw := -(b - a).angle() + PI
			var stretch := a.distance_to(b) / piece
			if not s.earth.is_wet(mid) and not near_gate.call(mid):
				if kit:
					s._add(wall_part, mid, 0.0, yaw, Vector3(stretch, 1, 1), tint, index, 0.9)
				else:
					s._add("k_wall", mid, 0.0, yaw - PI, Vector3(stretch * 1.02, 1, 1), Color.WHITE, index, 1.0)
				s._claim(mid, 0.25)
			var turned := absf(prev_dir.angle_to(dir)) if prev_dir != Vector2.ZERO else 0.0
			if i > 0 and (turned > 0.28 or i % 5 == 0) and not s.earth.is_wet(a) and not near_gate.call(a):
				if kit:
					s._add(tower_part, a, 0.0, yaw, Vector3.ONE, tint, index, 0.9)
				else:
					s._add("k_round" if s.style in ["northern", "classical"] else "k_tower", a, 0.0, 0.0, Vector3.ONE, Color.WHITE, index, 1.0)
				s._claim(a, 0.32)
			prev_dir = dir
	for g in gates:
		var gp: Vector2 = g["pos"]
		var ga := (gp - c).angle()
		if _wall_r(ga) <= 0.0:
			continue
		var t1 := c + Vector2(cos(ga - 0.03), sin(ga - 0.03)) * _wall_r(ga - 0.03)
		var t2 := c + Vector2(cos(ga + 0.03), sin(ga + 0.03)) * _wall_r(ga + 0.03)
		var yaw := -(t2 - t1).angle() + PI
		if kit:
			s._add(gate_part, gp, 0.0, yaw, Vector3.ONE, tint, index, 0.9)
		else:
			s._add("k_gate", gp, 0.0, yaw - PI, Vector3.ONE, Color.WHITE, index, 1.0)
		s._claim(gp, 0.5)


# =========================================================================================
# Water: wooden piers where the city meets the sea or a river
# =========================================================================================

func _piers() -> void:
	var timber := Color(0.50, 0.36, 0.22)
	var made := 0
	var order: Array = []
	for k in SECT:
		if _wet[k] == 1:
			order.append(k)
	if order.is_empty():
		return
	var step := maxi(1, order.size() / 3)
	for oi in range(order.size() / 2 % step, order.size(), step):
		if made >= 3:
			return
		var k: int = order[oi]
		var phi := k * TAU / SECT
		var dir := Vector2(cos(phi), sin(phi))
		var p := c + dir * reach[k]
		if not s._free(p, 0.25):
			continue
		var shore := s.earth.ground_at_pixel(p).y
		var ok := true
		for m in 3:
			ok = ok and s.earth.is_wet(p + dir * (0.6 + m * 0.5))
		if not ok:
			continue
		for m in 3:
			var q := p + dir * (0.45 + m * 0.5)
			var lift := shore - s.earth.ground_at_pixel(q).y + 0.05
			s._add("terrace", q, lift, -phi, Vector3(0.35, 0.25, 0.12) * 4.0 / s.S, timber)
		s._claim(p, 0.3)
		made += 1


## A pyramid on the desert edge beyond a Nile capital: dry ground, away from the river.
func _pyramid(centre: Vector2, reach_r: float, site_index: int) -> void:
	var r := 0.45 * s.S * 2.0
	for step in 16:
		var a := step * TAU / 16.0
		for dist in [reach_r * 1.6, reach_r * 2.0, reach_r * 2.5]:
			var p := centre + Vector2(cos(a), sin(a)) * float(dist)
			if s._dry(p, r * 1.4) and s._free(p, r * 1.2):
				var model := s._model("south", "pyramid", s.GRAND_UNIT * 1.2)
				if model != "":
					s._add(model, p, 0.0, -(centre - p).angle() + PI / 2.0, Vector3.ONE, Color.WHITE, site_index, 0.0)
				else:
					s._add("pyramid", p, 0.0, PI / 4.0, Vector3.ONE, Color(0.84, 0.70, 0.46))
				s._claim(p, r * 1.2)
				s.clearings.append([p, r * 1.5])
				return


# =========================================================================================
# The peoples' cities
# =========================================================================================

## Rome, Carthage and the Mediterranean: a grid of insulae, a forum where cardo and
## decumanus cross, a colonnade, the temple beside it.
func _classical(looks: Array) -> void:
	var sx := half * s.rng.randf_range(0.88, 0.98)
	var sy := half * s.rng.randf_range(0.74, 0.84)
	var na := s.rng.randf() * TAU
	_outline(func(phi: float) -> float: return _rect_reach(phi - theta, sx, sy, 0.05, na))
	if _mean_r < 1.0:
		return
	var u := Vector2(cos(theta), sin(theta))
	var v := Vector2(-u.y, u.x)
	heart = c
	var fw := clampf(_mean_r * 0.22, 1.2, 3.0) * s.rng.randf_range(0.9, 1.1)
	var fh := fw * s.rng.randf_range(0.5, 0.6)
	var poly := _rect(c, u, fw, fh, 0.05)
	var marble := Color(0.95, 0.93, 0.87)
	# the colonnade along the forum's long sides, open where the streets come in
	var x := -fw + 0.3
	while x <= fw - 0.25:
		for side in [-1.0, 1.0]:
			if absf(x) > 0.5:
				var p := c + u * x + v * (float(side) * (fh - 0.13))
				s._add("column", p, 0.0, 0.0, Vector3.ONE * 0.8, marble)
		x += 0.45
	var forum := _square(poly, _plaza_kind())
	s.prop("fountain" if tier >= 2 else "well", c + u * (fw * 0.45), 0.0, 1.0)
	s.prop("statue", c - u * (fw * 0.45), 0.0, 1.0)
	var venues: Array = [forum]
	# the temple at the forum's side, clear of the streets, facing in
	if capital:
		var part := s._palace_part()
		var pr: float = s._foot(part) if part != "" else float(s.PALACE_R["classical"]) * s.S
		var pp := c + u * (pr + 0.6) - v * (fh + pr + 0.35)
		if _can(pp, pr) and _inside(pp, pr * 0.6):
			if part != "":
				s._add(part, pp, 0.0, _face(v), Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.85)
			else:
				s._palace(pp, index, _face(v))
			s._claim(pp, pr)
			_banner(pp, u * (pr + 0.3))
		else:
			_place_palace(venues)
	# a second square: the market
	var mk_c := c + u * (fw + 2.6) * (1.0 if s.rng.randf() < 0.5 else -1.0) + v * (fh + 1.2)
	if _inside(mk_c, 1.4) and _can(mk_c, 1.0):
		var market := _square(_rect(mk_c, u, 1.0, 0.8, 0.05), _plaza_kind())
		_stalls(market, 6)
		venues.append(market)
	_publics(looks, venues)
	var px := s.rng.randf_range(2.5, 3.1)
	var py := s.rng.randf_range(2.2, 2.7)
	var xs := _grid_lines(_max_reach(), px, 0.62)
	var ys := _grid_lines(_max_reach(), py, 0.62)
	var ext := _max_reach() * 1.15
	for xv in xs:
		var main := absf(float(xv)) < 0.01
		var made := _line_run(c + u * float(xv) - v * ext, c + u * float(xv) + v * ext, 0.5 if main else 0.3, main)
		if main:
			for st in made:
				_gate_at_ends(st)
	for yv in ys:
		var main := absf(float(yv)) < 0.01
		var made := _line_run(c + v * float(yv) - u * ext, c + v * float(yv) + u * ext, 0.5 if main else 0.3, main)
		if main:
			for st in made:
				_gate_at_ends(st)
	if walled:
		_pomerium(0.1)


## China: a walled grid of wards, a straight ceremonial axis to the palace, markets east and
## west, a pagoda in its temple court.
func _chinese(looks: Array) -> void:
	theta = s.rng.randf_range(-0.05, 0.05) if sea == Vector2.ZERO else snappedf(sea.angle(), PI / 2.0)
	var sx := half * s.rng.randf_range(0.90, 0.98)
	var sy := half * s.rng.randf_range(0.86, 0.94)
	_outline(func(phi: float) -> float: return _rect_reach(phi - theta, sx, sy, 0.0, 0.0))
	if _mean_r < 1.0:
		return
	var u := Vector2(cos(theta), sin(theta))
	var v := Vector2(-u.y, u.x)   # south; the palace stands at the north (-v)
	heart = c
	_dense = 0.6
	var hy := _max_reach() * 0.75
	# the palace, its forecourt and the axis
	var pr := 1.0
	var part := s._palace_part() if capital else ""
	if capital:
		pr = s._foot(part) if part != "" else float(s.PALACE_R["east"]) * s.S
	var dp := clampf(maxf(hy * 0.55, 1.4), 1.4, maxf(hy, 1.4))
	var fh := 0.8 if (capital or tier >= 2) else 0.6
	var fx := 1.3 if capital else 1.0
	var pal_c := c - v * dp
	var court_c := pal_c + v * (pr + 0.15 + fh) if capital else c - v * hy * 0.3
	var court := _square(_rect(court_c, u, fx, fh), _plaza_kind())
	var venues: Array = [court]
	if capital:
		if part != "":
			s._add(part, pal_c, 0.0, _face(v), Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.85)
		else:
			s._palace(pal_c, index, _face(v))
		s._claim(pal_c, pr)
		_banner(court_c, u * (fx + 0.4))
	# markets east and west
	var pitch_x := s.rng.randf_range(3.0, 3.5)
	var pitch_y := s.rng.randf_range(2.7, 3.1)
	for sgn in [-1.0, 1.0]:
		var mc := c + u * (float(sgn) * (pitch_x * 1.1)) + v * (pitch_y * 0.5)
		if _inside(mc, 1.4) and _can(mc, 1.0):
			var mk := _square(_rect(mc, u, 1.0, 0.75), _plaza_kind())
			_stalls(mk, 6)
			venues.append(mk)
	# the temple court
	var tc := c + u * (-pitch_x * 1.1) - v * (pitch_y * 0.9)
	var sacred: Array = []
	if _has_sacred(looks) and _inside(tc, 1.4) and _can(tc, 1.2):
		var tcourt := _square(_rect(tc, u, 1.1, 1.1), _plaza_kind(), true)
		sacred.append(tcourt)
		_enclose(tcourt["poly"], "stone_wall", tc + v * 1.1)
	_publics(looks, venues, sacred)
	# streets: the axis, avenues and wards with alleys between
	var xs := _grid_lines(_max_reach(), pitch_x, 0.9)
	var ys := _grid_lines(_max_reach(), pitch_y, 0.9)
	var ext := _max_reach() * 1.15
	for xv in xs:
		var main := absf(float(xv)) < 0.01
		var made := _line_run(c + u * float(xv) - v * ext, c + u * float(xv) + v * ext, 0.8 if main else 0.34, main)
		if main:
			for st in made:
				_gate_at_ends(st)
	for yv in ys:
		var main := absf(float(yv)) < 0.01
		var made := _line_run(c + v * float(yv) - u * ext, c + v * float(yv) + u * ext, 0.6 if main else 0.34, main)
		if main:
			for st in made:
				_gate_at_ends(st)
	# an alley through the middle of every ward, running east-west
	ys.sort()
	for i in ys.size() - 1:
		var ym := (float(ys[i]) + float(ys[i + 1])) * 0.5
		_line_run(c + v * ym - u * ext, c + v * ym + u * ext, 0.22, false)
	if walled:
		_pomerium(0.1)


## Japan and Korea: a castle (or palace) on the best ground with its approach, the warrior
## quarter beside it, merchants dense along the roads, temples at the edge.
func _castle_town(looks: Array, joseon: bool) -> void:
	var na := s.rng.randf() * TAU
	var nb := s.rng.randf() * TAU
	var nd := s.rng.randf() * TAU
	var base := half * 1.02
	_outline(func(phi: float) -> float: return _blob_reach(phi, base, na, nb, nd))
	if _mean_r < 1.0:
		return
	_dense = 0.5
	_lane_gap = 0.8
	# the castle: the highest dry ground near the middle (Japan); at the head of the town (Korea)
	var seat := c
	var v := Vector2(0, 1)
	if joseon:
		seat = c - v * _mean_r * 0.45
		if not (_inside(seat, 1.5) and _can(seat, 1.0)):
			seat = _highest(c, _mean_r * 0.5)
	elif capital:
		seat = _highest(c, _mean_r * 0.45)
	heart = seat
	var part := s._palace_part() if capital else ""
	var pr := 0.8
	if capital:
		pr = s._foot(part) if part != "" else float(s.PALACE_R["east"]) * s.S
	# the main gate: the way the town is widest, away from the castle
	var best_a := 0.0
	var best_r := -1.0
	for k in 24:
		var a := k * TAU / 24.0
		var rr := _wall_r(a) if walled else _reach_at(a)
		var bonus := 0.0
		if joseon:
			bonus = 4.0 * maxf(0.0, Vector2(cos(a), sin(a)).dot(v))
		elif (c - seat).length() > 0.3:
			bonus = maxf(0.0, Vector2(cos(a), sin(a)).dot((c - seat).normalized()))
		if rr + bonus > best_r:
			best_r = rr + bonus
			best_a = a
	var appr := Vector2(cos(best_a), sin(best_a))
	if joseon:
		appr = v
		best_a = v.angle()
	# the castle's bailey
	var bsq := _square(_blob(seat, pr * 1.2, pr * 1.2, 0.0, 10, 0.06), _plaza_kind(), capital)
	if capital:
		if part != "":
			s._add(part, seat, 0.0, _face(appr), Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.85)
		else:
			s._palace(seat, index, _face(appr))
		s._claim(seat, pr)
		_banner(seat, appr.rotated(1.1) * (pr + 0.3))
	var venues: Array = [bsq]
	# the town's crossing, where the approach meets the cross road: the market
	var jc := seat + appr * (pr * 1.2 + 1.6 + 0.2 * tier)
	if not (_inside(jc, 1.2) and _can(jc, 0.9)):
		jc = c if _can(c, 0.9) else seat
	var junction_sq := _square(_blob(jc, 0.9, 0.7, appr.angle(), 9, 0.1), _plaza_kind())
	_stalls(junction_sq, 4)
	venues.push_front(junction_sq)
	# the approach, then the roads from the gates
	var approach := _trim_at_squares(_wander(seat + appr * (pr * 1.2 + 0.1), c + appr * _reach_at(best_a), 0.05))
	_street(approach, 0.8 if joseon else 0.6, true)
	_exit(best_a)
	var n := 2 + (1 if tier >= 2 else 0)
	var start := s.rng.randf() * TAU
	var angles: Array = []
	for k in n:
		var a := start + TAU * k / n
		if absf(angle_difference(a, best_a)) > 0.9:
			angles.append(a)
	_mains(angles, jc, 0.12, 0.5)
	var link := _trim_at_squares(_wander(c + appr * _reach_at(best_a), jc, 0.08))
	_street(link, 0.5, true)
	var sacred: Array = []
	# the temple court at the edge of town
	var ta := best_a + PI + s.rng.randf_range(-0.6, 0.6)
	var tc := c + Vector2(cos(ta), sin(ta)) * _reach_at(ta) * 0.65
	if _has_sacred(looks) and _can(tc, 1.2) and _inside(tc, 1.2):
		var tcourt := _square(_blob(tc, 1.1, 1.0, 0.0, 8, 0.05), "earth", true)
		sacred.append(tcourt)
		s.prop("prop_torii", tc + Vector2(cos(ta + PI), sin(ta + PI)) * 1.2, _face(Vector2(cos(ta), sin(ta))), 1.0)
	_publics(looks, venues, sacred)
	_fill_gaps(0.12, 0.3, 40)
	if walled:
		_pomerium(0.1)


## The north: an organic market town. Roads converge on a market place that widens at the
## junction, the church stands in its churchyard beside it, long narrow burgage plots run
## back from the street.
func _northern(looks: Array) -> void:
	var na := s.rng.randf() * TAU
	var nb := s.rng.randf() * TAU
	var nd := s.rng.randf() * TAU
	var base := half * 1.02
	_outline(func(phi: float) -> float: return _blob_reach(phi, base, na, nb, nd))
	if _mean_r < 1.0:
		return
	_dense = 0.5
	_lane_gap = 0.9
	var start := s.rng.randf() * TAU
	var n := s.rng.randi_range(3, 5)
	var jc := c + Vector2(s.rng.randf_range(-0.1, 0.1), s.rng.randf_range(-0.1, 0.1)) * _mean_r
	if not _can(jc, 1.0):
		jc = c
	heart = jc
	var roads: Array = []
	for k in n:
		var a := start + TAU * k / n + s.rng.randf_range(-0.3, 0.3)
		if sea != Vector2.ZERO and k == 0:
			a = sea.angle()
		if _reach_at(a) >= 1.6:
			roads.append(a)
	if roads.is_empty():
		roads.append(start)
	var axis_a: float = roads[0]
	var mrx := clampf(_mean_r * 0.15, 0.8, 1.5)
	var market := _square(_blob(jc, mrx * 1.35, mrx * 0.8, axis_a, 10, 0.1), _plaza_kind())
	s.prop("prop_market_cross", jc, 0.0, 1.0)
	_stalls(market, 5)
	var venues: Array = [market]
	_mains(roads, jc, 0.12, 0.5)
	# the churchyard beside the market, the palace (keep) on its other side
	var church_a := axis_a + PI / 2.0 + s.rng.randf_range(-0.3, 0.3)
	var cdir := Vector2(cos(church_a), sin(church_a))
	var cc := jc + cdir * (mrx * 0.8 + 1.6)
	var sacred: Array = []
	if _can(cc, 1.1) and _inside(cc, 1.0):
		var yard := _square(_blob(cc, 1.0, 0.9, 0.0, 9, 0.08), "grass", true)
		sacred.append(yard)
		_enclose(yard["poly"], "stone_wall", cc - cdir * 1.0)
	if capital:
		_place_palace([market], -cdir)
	_publics(looks, venues, sacred)
	if walled or tier >= 1:
		_ring(0.58, 0.3)
	if walled:
		_pomerium(0.1)
	_fill_gaps(0.2, 0.3, 50)


## The south and the Near East: narrow winding lanes, dense courtyard quarters, a temple
## precinct with an open court, palm groves by the water.
func _southern(looks: Array) -> void:
	var na := s.rng.randf() * TAU
	var nb := s.rng.randf() * TAU
	var nd := s.rng.randf() * TAU
	var base := half * 1.0
	_outline(func(phi: float) -> float: return _blob_reach(phi, base, na, nb, nd))
	if _mean_r < 1.0:
		return
	_dense = 0.35
	_lane_gap = 0.75
	var jc := c
	heart = jc
	var start := s.rng.randf() * TAU
	var n := s.rng.randi_range(3, 4)
	var roads: Array = []
	for k in n:
		var a := start + TAU * k / n + s.rng.randf_range(-0.35, 0.35)
		if sea != Vector2.ZERO and k == 0:
			a = sea.angle()
		if _reach_at(a) >= 1.6:
			roads.append(a)
	if roads.is_empty():
		roads.append(start)
	var market := _square(_blob(jc, clampf(_mean_r * 0.14, 0.8, 1.5), clampf(_mean_r * 0.11, 0.7, 1.2), s.rng.randf() * PI, 9, 0.12), _plaza_kind())
	if s.style == "near_east":
		s.prop("prop_rugs", jc, 0.0, 1.0)
	_stalls(market, 6)
	var venues: Array = [market]
	# the temple precinct: an open court with its great building at the far end
	var pa := start + PI / n + s.rng.randf_range(-0.2, 0.2)
	var pdir := Vector2(cos(pa), sin(pa))
	var court_c := jc + pdir * (float(market["r"]) + 2.2 + 0.2 * tier)
	var sacred: Array = []
	var cu := pdir.rotated(PI / 2.0)
	var cw := 1.0 + 0.06 * tier
	var cl := 1.4 + 0.08 * tier
	if (capital or _has_sacred(looks)) and _rect_inside(court_c, cu, cw, cl) and _can(court_c, cl * 0.7):
		var court := _square(_rect(court_c, cu, cw, cl), _plaza_kind())
		sacred.append(court)
		_enclose(court["poly"], "stone_wall", court_c - pdir * cl)
		if capital:
			var part := s._palace_part()
			var pr: float = s._foot(part) if part != "" else float(s.PALACE_R.get(s.style, 0.6)) * s.S
			var pp := court_c + pdir * (cl + pr + 0.1)
			if _can(pp, pr) and _inside(pp, 0.5):
				if part != "":
					s._add(part, pp, 0.0, _face(-pdir), Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.85)
				else:
					s._palace(pp, index, _face(-pdir))
				s._claim(pp, pr)
			else:
				_place_palace(sacred + venues)
	elif capital:
		_place_palace(venues)
	_mains(roads, jc, 0.2, 0.4)
	if not sacred.is_empty():
		var tp := _trim_at_squares(_wander(jc, (sacred[0]["centre"] as Vector2) - pdir * cl, 0.1))
		_street(tp, 0.4, true)
	_publics(looks, venues, sacred)
	_fill_gaps(0.32, 0.24, 60)
	if walled:
		_pomerium(0.1)
	_groves()


## Palms and gardens along the water's edge.
func _groves() -> void:
	if sea == Vector2.ZERO:
		return
	var tree := "palm" if s.style != "south_asian" else "tree_broadleaf"
	var made := 0
	for k in SECT:
		if _wet[k] == 0 or made > 24 + tier * 6:
			continue
		var phi := k * TAU / SECT
		var dir := Vector2(cos(phi), sin(phi))
		for m in 2:
			var p := c + dir * (reach[k] - 0.1 - m * 0.55) + Vector2(-dir.y, dir.x) * s.rng.randf_range(-0.3, 0.3)
			if s._free(p, 0.3) and _street_dist(p, 0.4) > 0.25:
				s.ground.patch(p, 0.4, "garden", 0.8)
				if _prop(tree, p, s.rng.randf() * TAU, 1.0, 0.25):
					made += 1
