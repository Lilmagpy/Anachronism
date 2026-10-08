## Towns, villages, farmsteads and camps (D-279, D-281): everything outside the chief cities.
## Called by Settlements.build after every chief city is planned; `s` is the Settlements object.
##
## Each people settles the countryside its own way: northern greens, street villages and
## lone farmsteads among strip fields; classical hill villages with olive groves, vineyards and
## a villa in its fields; paddies and bamboo along the streams of the east; dense flat-roofed
## clusters beside the Nile and the canals; tank villages of the south; the gers of the steppe in
## family clusters with their herds. Lanes follow the lie of the land, farm tracks tie each place
## to its neighbour, and every field is a lane-aligned patch of a patchwork, never overlapping.
extends RefCounted

const RELIEF_MAX := 0.2     ## how much the ground under a field may vary (world units) before it is skipped
const HILL_SLOPE := 0.09     ## ground steeper than this (rise per map unit) is farmed along its contours

var s: Settlements   ## the Settlements being built
var _fw := 1.36      ## the "field" part's footprint at scale 1 (x and z, map units)
var _fd := 0.96
var _nodes: Array = []     ## the places of this province so far: [centre: Vector2]
var _origin := Vector2.ZERO   ## the settlement being built, and how far out it reaches
var _ext := 0.0
var _lane_pts: Array = []     ## the lane points of the settlement being built (a track starts at one)
var _water := Vector2.ZERO    ## direction to the nearest water from the settlement (zero inland)
var _site := 0                ## the province index being built


func _init(settlements: Settlements) -> void:
	s = settlements
	_fw = 0.34 * s.S   # the "field" box, as Settlements builds it
	_fd = 0.24 * s.S


# --- the countryside of a province ---------------------------------------------------------

## The towns, villages and farms of province `index`, spread over its good farmland `cells`.
func countryside(site: Dictionary, population: int, cells: Array, index: int) -> void:
	var towns := clampi(population / s.PEOPLE_PER_TOWN, 0, 12)
	var villages := clampi(population / s.PEOPLE_PER_VILLAGE, 1, s.MAX_VILLAGES)
	_site = index
	_nodes = [site["pixel"]]
	for i in towns:
		_place(_town, "town", 1, cells, index)
	for i in villages:
		var form := _village_form()
		match form:
			"farm":
				_place(_farmstead, "farm", 0, cells, index)
			"herd":
				_place(_herders, "camp", 0, cells, index)
			_:
				_place(_village.bind(form), "village", 0, cells, index)


## Build one place with `maker`, then dress it and keep the trees out of it.
func _place(maker: Callable, kind: String, tier: int, cells: Array, index: int) -> void:
	_ext = 0.0
	_lane_pts = []
	_water = Vector2.ZERO
	var c: Vector2 = maker.call(cells, index)
	if c == Vector2.ZERO:
		return
	s.clearings.append([c, _ext + 0.9])
	s.dressing.decorate(kind, tier, index)
	_nodes.append(c)


## What kind of village this province's people build, from the seed.
func _village_form() -> String:
	var r := s.rng.randf()
	match s.style:
		"northern":
			if s.culture == "viking":
				return "street" if r < 0.5 else ("farm" if r < 0.8 else "green")
			return "green" if r < 0.4 else ("street" if r < 0.75 else "farm")
		"classical":
			return "hill" if r < 0.45 else ("street" if r < 0.75 else "farm")
		"east":
			return "stream" if r < 0.72 else ("farm" if r < 0.88 else "street")
		"nile", "near_east":
			return "stream" if r < 0.78 else "farm"
		"south_asian":
			return "tank" if r < 0.78 else "farm"
		"steppe":
			return "herd"
	return "street"


# --- finding ground ------------------------------------------------------------------------

func _h(p: Vector2) -> float:
	return s.earth.ground_at_pixel(p).y


## The uphill direction at `p`, as rise per map unit (zero length on the flat).
func _gradient(p: Vector2) -> Vector2:
	var e := 0.3
	return Vector2(_h(p + Vector2(e, 0)) - _h(p - Vector2(e, 0)), _h(p + Vector2(0, e)) - _h(p - Vector2(0, e))) / (2.0 * e)


## How far to the nearest water from `p` (or 99 if none within `reach`).
func _water_dist(p: Vector2, reach: float) -> float:
	for step in 12:
		var r := reach * (step + 1) / 12.0
		for k in 12:
			if s.earth.is_wet(p + Vector2(cos(k * TAU / 12.0), sin(k * TAU / 12.0)) * r):
				return r
	return 99.0


## A good place for a settlement reaching `reach`: dry, clear of other places, level, and
## near water or high up if `prefer` says "water" or "hill". Vector2.ZERO if none found.
func _find(cells: Array, reach: float, prefer: String) -> Vector2:
	var best := Vector2.ZERO
	var best_score := -1.0e9
	for attempt in 16:
		var p: Vector2 = s._pick(cells)
		if not s._dry(p, reach * 0.7) or not s._free(p, reach * 0.9):
			continue
		var score := -_gradient(p).length() * 6.0 + s.rng.randf() * 0.6
		match prefer:
			"water":
				var d := _water_dist(p, 6.0)
				score += -absf(d - 2.4) * 0.5 if d < 90.0 else -3.5
			"hill":
				var rise := 0.0
				for k in 6:
					rise += _h(p) - _h(p + Vector2(cos(k * TAU / 6.0), sin(k * TAU / 6.0)) * 1.4)
				score += clampf(rise / 6.0, -0.3, 0.6) * 4.0
		if score > best_score:
			best_score = score
			best = p
	_origin = best
	return best


## The point back from the bank where a lane beside the water should run. Sets `_water` to
## the unit vector toward the water; inland it stays zero and `c` comes back.
func _bank_point(c: Vector2, back: float) -> Vector2:
	_water = s._sea_direction(c, 6.0)
	if _water == Vector2.ZERO:
		return c
	for step in 40:
		var q := c + _water * step * 0.2
		if s.earth.is_wet(q):
			var at := q - _water * back
			if s._dry(at, 0.8) and s._free(at, 0.8):
				return at
			_water = Vector2.ZERO
			return c
	_water = Vector2.ZERO
	return c


## How hard it is to lay a lane or track at `q`: water and built ground bar the way.
func _cost(q: Vector2) -> float:
	if s.earth.is_wet(q):
		return 100.0
	var cost := _gradient(q).length() * 7.0
	if not s._free(q, 0.12):
		cost += 60.0
	elif not s._dry(q, 0.25):
		cost += 5.0
	return cost


## A lane marched from `start` along `heading` for `length`, bending by `curve` (radians
## per map unit) and steering round water and steep ground. Includes `start`.
func _march(start: Vector2, heading: float, length: float, curve := 0.0) -> PackedVector2Array:
	var step := 0.5
	var pts := PackedVector2Array([start])
	var p := start
	var h := heading
	for i in int(length / step):
		var best := 1.0e9
		var best_h := h
		for off: float in [0.0, 0.3, -0.3, 0.6, -0.6]:
			var hh: float = h + curve * step + off * 0.5
			var q := p + Vector2(cos(hh), sin(hh)) * step
			var c := _cost(q) + absf(off) * 2.0
			if c < best:
				best = c
				best_h = hh
		if best >= 40.0:
			break
		h = best_h + s.rng.randf_range(-0.05, 0.05)
		p += Vector2(cos(best_h), sin(best_h)) * step
		pts.append(p)
	return pts


## A track from `a` to `b` that follows the terrain; the part of it that gets through.
func _route(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var p := a
	var prev := (b - a).angle()
	var step := 0.6
	for i in int(a.distance_to(b) / step * 1.8):
		if p.distance_to(b) < step * 1.2:
			break
		var want := (b - p).angle()
		var best := 1.0e9
		var best_h := want
		for off: float in [0.0, 0.3, -0.3, 0.6, -0.6, 0.95, -0.95]:
			var hh: float = want + off
			var q := p + Vector2(cos(hh), sin(hh)) * step
			var c := _cost(q) + absf(off) * 2.0 + q.distance_to(b) * 1.2 + absf(angle_difference(prev, hh)) * 2.0
			if c < best:
				best = c
				best_h = hh
		if best >= 60.0 + p.distance_to(b) * 1.2:
			break
		prev = best_h
		p += Vector2(cos(best_h), sin(best_h)) * step
		pts.append(p)
	return pts


## Lay the farm track from this place to its nearest neighbour in the province, claiming the
## strip so fields leave it be. Only places within a day's walk are tied, to keep them few.
func _track(c: Vector2) -> void:
	var goal := Vector2.ZERO
	var near_d := 1.0e9
	for n: Vector2 in _nodes:
		var d := c.distance_to(n)
		if d < near_d:
			near_d = d
			goal = n
	if goal == Vector2.ZERO or near_d < 2.0 or near_d > 15.0:
		return
	var from := c
	var nearest := 1.0e9
	for q: Vector2 in _lane_pts:
		var d := q.distance_to(goal)
		if d < nearest:
			nearest = d
			from = q
	var pts := _route(from, goal)
	if pts.size() < 3:
		return
	s.ground.road(pts, 0.13, "dirt")
	for i in pts.size() - 1:
		for k in 3:
			s._claim(pts[i].lerp(pts[i + 1], k / 3.0), 0.12)


# --- small geometry ------------------------------------------------------------------------

func _dir(a: float) -> Vector2:
	return Vector2(cos(a), sin(a))


## The yaw that turns a model's front (+z) toward `d`.
func _yaw_to(d: Vector2) -> float:
	return atan2(d.x, d.y)


## The yaw that turns a model's length (x) along `d` (fences, hedges, walls).
func _yaw_along(d: Vector2) -> float:
	return atan2(-d.y, d.x)


func _r(lo: float, hi: float) -> float:
	return s.rng.randf_range(lo, hi)


func _chance(p: float) -> bool:
	return s.rng.randf() < p


## An irregular ring round `c` for a green, a square or a yard.
func _blob(c: Vector2, radius: float, n := 12, wobble := 0.12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var phase := s.rng.randf() * TAU
	for k in n:
		var a := TAU * k / n
		pts.append(c + _dir(a) * radius * (1.0 + wobble * sin(a * 2.0 + phase) + _r(-0.04, 0.04)))
	return pts


func _length(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in pts.size() - 1:
		l += pts[i].distance_to(pts[i + 1])
	return l


## The point `d` along a lane and the way it runs there: [position, tangent].
func _along(pts: PackedVector2Array, d: float) -> Array:
	var run := 0.0
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if run + seg >= d or i == pts.size() - 2:
			var t := clampf((d - run) / maxf(seg, 0.001), 0.0, 1.0)
			return [pts[i].lerp(pts[i + 1], t), (pts[i + 1] - pts[i]).normalized()]
		run += seg
	return [pts[0], Vector2.RIGHT]


## Note that something stands at `p` (radius `r`), for the clearing round the place.
func _note(p: Vector2, r: float) -> void:
	_ext = maxf(_ext, p.distance_to(_origin) + r)


## Both marches out of `c`, joined into one lane through it.
func _spine(c: Vector2, heading: float, half_length: float, curve: float) -> PackedVector2Array:
	var fwd := _march(c, heading, half_length, curve)
	var back := _march(c, heading + PI, half_length, -curve)
	var pts := PackedVector2Array()
	for i in range(back.size() - 1, 0, -1):
		pts.append(back[i])
	pts.append_array(fwd)
	return pts


# --- houses --------------------------------------------------------------------------------

## One house of `rank` at `p` facing `face`, fitting radius `fit`. False if it would not fit.
func _house(p: Vector2, face: float, rank: String, fit: float, mix: float, size := -1.0) -> bool:
	var sz := _r(0.85, 1.1) if size < 0.0 else size
	if s._fit_house(p, face, sz, fit, _site, mix, rank):
		_note(p, fit)
		return true
	return false


## Houses along both sides of `lane`, facing it, each with a yard behind. `density` is the
## chance of a house at each station. Returns how many were built.
func _row(lane: PackedVector2Array, spacing: float, rank: String, mix: float, setback: float, density: float,
		skip_start := 0.0, skip_end := 0.0, limit := 99) -> int:
	var total := _length(lane)
	var d := skip_start
	var built := 0
	while d < total - skip_end and built < limit:
		var at := _along(lane, d)
		var pos: Vector2 = at[0]
		var tan: Vector2 = at[1]
		var nor := Vector2(-tan.y, tan.x)
		for side: float in [-1.0, 1.0]:
			if not _chance(density):
				continue
			var p := pos + nor * side * (setback + _r(-0.05, 0.08)) + tan * _r(-0.08, 0.08)
			var face := _yaw_to(-nor * side) + _r(-0.14, 0.14)
			if _house(p, face, rank, spacing * 0.47, mix):
				built += 1
				_yard(p, nor * side, spacing)
		d += spacing * _r(0.95, 1.35)
	return built


## The yard behind a house at `p` (`back` points away from the lane): a garden, a fruit tree
## or a hedge, and the ground kept for it.
func _yard(p: Vector2, back: Vector2, spacing: float) -> void:
	var yard := p + back * spacing * 0.62
	if not s._dry(yard, 0.15) or not s._free(yard, 0.2):
		return
	var roll := s.rng.randf()
	if roll < 0.5:
		s.ground.patch(yard, spacing * 0.36, "garden", 0.7)
		s.prop("vegetable_patch", yard, _yaw_to(back), 0.9)
	elif roll < 0.8:
		s.prop(_orchard_tree(), yard, s.rng.randf() * TAU, _r(0.8, 1.1))
	else:
		s.prop("hedge", yard, _yaw_along(Vector2(-back.y, back.x)), 1.0)
	s._claim(yard, 0.2)


## The fruit or shade tree a people plant by their houses.
func _orchard_tree() -> String:
	match s.style:
		"nile", "near_east":
			return "palm_small"
		"east":
			return "cherry" if s.culture in ["samurai", "joseon"] else "tree_fruit"
		"classical":
			return "olive"
	return "tree_fruit"


# --- fields, groves and pastures -----------------------------------------------------------

## A crop colour from the palette of `kind`.
func _crop(kind: String) -> Color:
	var wheat := Color(0.86, 0.72, 0.30)
	var palette: Array
	match kind:
		"northern":
			palette = [wheat, Color(0.78, 0.74, 0.38), Color(0.55, 0.70, 0.28), Color(0.50, 0.40, 0.26),
				Color(0.44, 0.33, 0.22), Color(0.46, 0.64, 0.28), wheat]
		"classical":
			palette = [Color(0.82, 0.70, 0.34), Color(0.72, 0.62, 0.38), Color(0.50, 0.64, 0.30), Color(0.62, 0.48, 0.32)]
		"paddy":
			palette = [Color(0.42, 0.66, 0.28), Color(0.52, 0.72, 0.34), Color(0.46, 0.60, 0.50), Color(0.36, 0.60, 0.26),
				Color(0.50, 0.68, 0.40)]
		"millet":
			palette = [Color(0.78, 0.68, 0.32), Color(0.60, 0.66, 0.30), Color(0.66, 0.52, 0.30), Color(0.52, 0.64, 0.28)]
		"nile":
			palette = [Color(0.34, 0.62, 0.24), Color(0.50, 0.72, 0.30), Color(0.82, 0.70, 0.30), Color(0.30, 0.52, 0.22)]
		"near_east":
			palette = [Color(0.72, 0.62, 0.32), Color(0.46, 0.58, 0.26), Color(0.62, 0.50, 0.30), Color(0.80, 0.68, 0.34)]
		"south_asian":
			palette = [Color(0.45, 0.66, 0.26), Color(0.88, 0.76, 0.22), Color(0.62, 0.46, 0.28), Color(0.40, 0.60, 0.26)]
		"meadow":
			palette = [Color(0.40, 0.62, 0.26), Color(0.46, 0.66, 0.30), Color(0.36, 0.56, 0.24)]
		_:
			palette = [wheat]
	return palette[s.rng.randi() % palette.size()]


## Whether a w x d rectangle at `c` turned by `yaw` (its length along z) is dry, clear of
## buildings and level enough; returns [ok, lowest ground, highest ground].
func _area_ok(c: Vector2, yaw: float, w: float, d: float, relief_max: float) -> Array:
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var nx := maxi(2, ceili(w / 0.25))
	var nz := maxi(2, ceili(d / 0.25))
	var lo := 1.0e9
	var hi := -1.0e9
	for i in nx + 1:
		for j in nz + 1:
			var u := (float(i) / nx - 0.5) * (w - 0.1)
			var v := (float(j) / nz - 0.5) * (d - 0.1)
			var p := c + ax * u + az * v
			if s.earth.is_wet(p) or not s._free(p, 0.02):
				return [false, 0.0, 0.0]
			var h := _h(p)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	if hi - lo > relief_max:
		return [false, 0.0, 0.0]
	return [true, lo, hi]


## Reserve a rectangle as a chain of circles along its length (never past its edges).
func _claim_rect(c: Vector2, yaw: float, w: float, d: float) -> void:
	var az := Vector2(sin(yaw), cos(yaw))
	var ax := Vector2(cos(yaw), -sin(yaw))
	var long_d := maxf(w, d)
	var along := az if d >= w else ax
	var r := minf(w, d) * 0.5 * 0.96
	var n := maxi(1, ceili(long_d / (2.0 * r)))
	for k in n:
		var t := 0.0 if n == 1 else (float(k) / (n - 1) - 0.5) * (long_d - 2.0 * r)
		s._claim(c + along * t, r)


## One field w x d across, lying along z when turned by `yaw`, in `crop` colour. It stands
## on the ground as a slab thick enough to reach the lowest corner, so a field on a slope
## reads as a terrace. Only if its ground allows. True when placed.
func _field(c: Vector2, yaw: float, w: float, d: float, crop: Color, relief_max := RELIEF_MAX) -> bool:
	var ok := _area_ok(c, yaw, w, d, relief_max)
	if not ok[0]:
		return false
	var low: float = ok[1]
	var high: float = ok[2]
	var base := _h(c)
	s.ground.field(c, yaw, w, d, crop)
	_claim_rect(c, yaw, w, d)
	_note(c, maxf(w, d) * 0.5)
	return true


## `n` fields side by side, `width` wide and about `length` long, their length along `along`.
## Returns how many fitted.
func _strips(c: Vector2, along: Vector2, n: int, width: float, length: float, kind: String) -> int:
	var yaw := _yaw_to(along)
	var across := Vector2(along.y, -along.x)
	var made := 0
	for i in n:
		var t := (i - (n - 1) / 2.0) * width
		if _field(c + across * t, yaw, width * 0.99, length * _r(0.8, 1.1), _crop(kind)):
			made += 1
	return made


## A block of plots in a grid of `cols` x `rows`, each a little different.
func _plots(c: Vector2, along: Vector2, cols: int, rows: int, cw: float, rw: float, kind: String) -> int:
	var yaw := _yaw_to(along)
	var across := Vector2(along.y, -along.x)
	var made := 0
	for i in cols:
		for j in rows:
			var u := (i - (cols - 1) / 2.0) * cw
			var v := (j - (rows - 1) / 2.0) * rw
			if _field(c + across * u + along * v, yaw, cw * 0.99, rw * _r(0.9, 1.0), _crop(kind)):
				made += 1
	return made


## A low wall, hedge or fence from `a` to `b`.
func _boundary(a: Vector2, b: Vector2, kind: String) -> void:
	var step := 0.67
	var dir := (b - a).normalized()
	var yaw := _yaw_along(dir)
	for k in int(a.distance_to(b) / step):
		var p := a + dir * (k + 0.5) * step
		if s.earth.is_wet(p) or not s._free(p, 0.0):
			continue
		s.prop(kind, p, yaw, 1.0)


## A grove or orchard of `kind` trees in rows over a w x d rectangle turned by `yaw`.
func _grove(c: Vector2, yaw: float, w: float, d: float, kind: String, spacing: float) -> bool:
	var ok := _area_ok(c, yaw, w, d, RELIEF_MAX * 1.4)
	if not ok[0]:
		return false
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var cols := maxi(1, int(w / spacing))
	var rows := maxi(1, int(d / spacing))
	for i in cols:
		for j in rows:
			var u := (i - (cols - 1) / 2.0) * spacing + _r(-0.06, 0.06)
			var v := (j - (rows - 1) / 2.0) * spacing + _r(-0.06, 0.06)
			s.prop(kind, c + ax * u + az * v, s.rng.randf() * TAU, _r(0.85, 1.15))
	_claim_rect(c, yaw, w, d)
	_note(c, maxf(w, d) * 0.5)
	return true


## A vineyard: trellis rows over a w x d rectangle, rows along z.
func _vineyard(c: Vector2, yaw: float, w: float, d: float) -> bool:
	var ok := _area_ok(c, yaw, w, d, RELIEF_MAX * 1.4)
	if not ok[0]:
		return false
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var rows := maxi(2, int(w / 0.34))
	var run := maxi(1, int(d / 0.67))
	s.ground.patch(c, maxf(w, d) * 0.45, "garden", 0.5)
	for i in rows:
		var u := (i - (rows - 1) / 2.0) * 0.34
		for j in run:
			var v := (j - (run - 1) / 2.0) * 0.67
			s.prop("vine_trellis", c + ax * u + az * v, _yaw_along(az), 1.0)
	_claim_rect(c, yaw, w, d)
	_note(c, maxf(w, d) * 0.5)
	return true


## A pasture with some animals grazing in it, fenced on three sides if `fence` names a kind.
func _pasture(c: Vector2, yaw: float, w: float, d: float, fence: String, animals: Array) -> bool:
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	if not _field(c, yaw, w * 0.99, d * 0.99, _crop("meadow")):
		return false
	var hw := w * 0.5
	var hd := d * 0.5
	if fence != "":
		_boundary(c - ax * hw - az * hd, c - ax * hw + az * hd, fence)
		_boundary(c - ax * hw + az * hd, c + ax * hw + az * hd, fence)
		_boundary(c + ax * hw + az * hd, c + ax * hw - az * hd, fence)
	for k in clampi(int(w * d * 1.4), 2, 6):
		var p := c + ax * _r(-hw * 0.7, hw * 0.7) + az * _r(-hd * 0.7, hd * 0.7)
		s.prop(str(animals[s.rng.randi() % animals.size()]), p, s.rng.randf() * TAU, _r(0.9, 1.1))
	return true


## Farmland round a place: patch by patch from `inner` to `outer` away from `c`, up to
## `count` fields. `along` is the way the place's own lane runs (fields line up with it).
func _farmland(c: Vector2, inner: float, outer: float, count: int, along: Vector2) -> int:
	var made := 0
	for attempt in count * 10:
		if made >= count:
			break
		var p := c + _dir(s.rng.randf() * TAU) * _r(inner, outer)
		if not s._dry(p, 0.4) or not s._free(p, 0.3):
			continue
		var grad := _gradient(p)
		var hill := grad.length() > HILL_SLOPE
		var o := along
		if hill:
			o = Vector2(-grad.y, grad.x).normalized()   # along the contour
		elif _chance(0.4):
			o = Vector2(-along.y, along.x)
		made += _patch(p, o, hill, grad)
	return made


## One patch of the patchwork at `p`, styled by people and ground.
func _patch(p: Vector2, o: Vector2, hill: bool, grad: Vector2) -> int:
	var made := 0
	var roll := s.rng.randf()
	match s.style:
		"northern":
			if roll < 0.18:
				var animals: Array = ["cow", "sheep", "horse"] if s.culture != "viking" else ["sheep", "cow", "goat"]
				return 1 if _pasture(p, _yaw_to(o), _r(1.5, 2.2), _r(1.2, 1.7), "stone_wall" if hill else "hedge", animals) else 0
			if roll < 0.26:
				return 1 if _grove(p, _yaw_to(o), _r(1.1, 1.6), _r(1.0, 1.4), "tree_fruit", 0.55) else 0
			made = _strips(p, o, s.rng.randi_range(3, 6), _r(0.45, 0.7), _r(1.6, 2.6), "northern")
		"classical":
			if roll < 0.22:
				return 1 if _grove(p, _yaw_to(o), _r(1.4, 2.0), _r(1.2, 1.8), "olive", 0.62) else 0
			if roll < 0.36:
				return 1 if _vineyard(p, _yaw_to(o), _r(1.1, 1.6), _r(1.2, 1.8)) else 0
			if hill:
				made = _strips(p, o, s.rng.randi_range(2, 4), _r(0.45, 0.65), _r(1.6, 2.4), "classical")
			else:
				made = _plots(p, o, s.rng.randi_range(1, 3), s.rng.randi_range(1, 2), _r(0.9, 1.3), _r(1.1, 1.7), "classical")
		"east":
			if _water_dist(p, 3.5) < 90.0 or (not hill and _chance(0.2)):
				made = _plots(p, o, s.rng.randi_range(2, 3), s.rng.randi_range(2, 3), _r(0.8, 1.1), _r(0.8, 1.1), "paddy")
			else:
				if roll < 0.2:
					return 1 if _grove(p, _yaw_to(o), _r(0.9, 1.3), _r(0.9, 1.3), "bamboo", 0.5) else 0
				made = _strips(p, o, s.rng.randi_range(2, 5), _r(0.5, 0.75), _r(1.4, 2.2), "millet")
		"nile", "near_east":
			var to_water := _water if _water != Vector2.ZERO else o
			if roll < 0.18:
				return 1 if _grove(p, _yaw_to(to_water), _r(1.0, 1.5), _r(1.2, 1.8), "palm", 0.62) else 0
			if s.style == "near_east" and roll < 0.3:
				return 1 if _pasture(p, _yaw_to(o), _r(1.3, 1.8), _r(1.1, 1.5), "", ["sheep", "goat", "camel"]) else 0
			made = _strips(p, to_water, s.rng.randi_range(3, 6), _r(0.5, 0.7), _r(1.3, 2.0), s.style)
		"south_asian":
			if roll < 0.22:
				return 1 if _grove(p, _yaw_to(o), _r(1.2, 1.8), _r(1.2, 1.7), "tree_fruit", 0.7) else 0
			if roll < 0.32:
				return 1 if _pasture(p, _yaw_to(o), _r(1.2, 1.7), _r(1.0, 1.4), "fence", ["cow", "ox", "goat"]) else 0
			made = _plots(p, o, s.rng.randi_range(2, 3), s.rng.randi_range(1, 2), _r(0.9, 1.4), _r(0.9, 1.4), "south_asian")
		_:
			made = _strips(p, o, 3, 0.45, 1.8, "northern")
	if hill and made > 0 and s.style != "nile":
		# a dry-stone wall holds the downhill edge of a terraced hillside field
		var down := -grad.normalized()
		_boundary(p + down * 0.3 - o * 0.9, p + down * 0.3 + o * 0.9, "stone_wall")
	return made


# --- towns ---------------------------------------------------------------------------------

## A market town: a square, three lanes of houses leading away from it, its temple or
## church, and farmland round about.
func _town(cells: Array, index: int) -> Vector2:
	var prefer := "water" if s.style in ["nile", "near_east", "east"] else ""
	var c := _find(cells, 3.6, prefer)
	if c == Vector2.ZERO:
		return c
	if prefer == "water":
		c = _bank_point(c, 2.6)
		_origin = c
	var spacing: float = s.LOT * 0.92
	var sq := _r(0.75, 1.0)
	var mix := 0.45
	var a0 := s.rng.randf() * TAU
	var paving := "cobble" if s.style == "northern" else ("earth" if s.style == "east" else "flag")
	s.ground.area(_blob(c, sq, 12, 0.08), paving)
	s._claim(c, sq * 0.55)   # the square's heart is kept open for its stalls and well
	_lane_pts.append(c)
	# three lanes out of the square
	var lanes: Array = []
	for k in 3:
		var a := a0 + TAU * k / 3.0 + _r(-0.35, 0.35)
		var lane := _march(c + _dir(a) * sq * 0.9, a, _r(2.6, 3.6), _r(-0.12, 0.12))
		if lane.size() < 3:
			continue
		lanes.append([a, lane])
		s.ground.road(lane, 0.2, "cobble" if s.style == "northern" else "dirt")
		_lane_pts.append_array(lane)
	# houses ring the square between the lanes, and the temple takes one place
	var ring := sq + 0.5
	var n := int(TAU * ring / spacing)
	var temple_at := a0 + PI / 3.0
	var temple_done := false
	for k in n:
		var a := TAU * k / n + a0 + 0.2
		var on_lane := false
		for l in lanes:
			if absf(angle_difference(a, float(l[0]))) < 0.42:
				on_lane = true
		if on_lane:
			continue
		var p := c + _dir(a) * ring
		if not temple_done and absf(angle_difference(a, temple_at)) < 0.4:
			temple_done = _temple(p, a, index)
			if temple_done:
				continue
		_house(p, _yaw_to(-_dir(a)) + _r(-0.1, 0.1), "town", spacing * 0.47, mix)
	if not temple_done:
		_temple(c + _dir(temple_at) * (sq + 0.9), temple_at, index)
	for l in lanes:
		_row(l[1], spacing, "town", mix, 0.46, 0.9, 0.4, 0.2)
	_square_dressing(c, sq, index)
	_track(c)
	_farmland(c, 2.8, 6.0, s.rng.randi_range(6, 10), _dir(a0))
	return c


## The town's temple, church or shrine on the square's edge, facing the square's middle.
## True when it stood.
func _temple(p: Vector2, a: float, index: int) -> bool:
	var part := ""
	match s.style:
		"northern":
			part = s._model("northern", "church", s.GRAND_UNIT)
		"east":
			part = s._model("east", "pagoda", s.GRAND_UNIT) if _chance(0.5) else ""
			if part == "":
				part = s._model("civic", "temple", s.CIVIC_UNIT)
		"south_asian":
			part = s._model("south", "temple_shikhara", s.GRAND_UNIT)
		_:
			part = s._model("civic", "temple", s.CIVIC_UNIT)
	if part == "":
		return false
	var f: float = s._foot(part)
	var at := p + _dir(a) * f * 0.5
	if not s._dry(at, f) or not s._free(at, f):
		return false
	s._add(part, at, 0.0, _yaw_to(-_dir(a)), Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.3)
	s._claim(at, f)
	_note(at, f)
	return true


## A well or cross, stalls and a little life on the town square.
func _square_dressing(c: Vector2, sq: float, index: int) -> void:
	var centre_prop: String = {"northern": "prop_market_cross", "classical": "prop_fountain_basin", "near_east": "prop_rugs",
		"south_asian": "prop_shrine_india", "east": "prop_lantern_post"}.get(s.style, "well")
	if not s.prop(centre_prop, c, s.rng.randf() * TAU, 1.0, index):
		s.prop("well", c, 0.0, 1.0)
	for k in s.rng.randi_range(3, 5):
		var a := TAU * k / 4.0 + _r(-0.4, 0.4)
		s.prop("market_stall", c + _dir(a) * sq * _r(0.45, 0.62), _yaw_to(-_dir(a)), 1.0, index)


# --- villages ------------------------------------------------------------------------------

## A village of `form`: "green", "street", "hill", "stream" or "tank".
func _village(cells: Array, index: int, form: String) -> Vector2:
	match form:
		"green":
			return _green_village(cells, index)
		"hill":
			return _hill_village(cells, index)
		"tank":
			return _tank_village(cells, index)
		_:
			return _street_village(cells, index, form == "stream")


## A northern green village: houses round a green with a pond or well, a church at its edge,
## a lane or two running out between the houses, strip fields all round.
func _green_village(cells: Array, index: int) -> Vector2:
	var gr := _r(0.85, 1.2)
	var c := _find(cells, gr + 2.4, "")
	if c == Vector2.ZERO:
		return c
	var spacing: float = s.LOT * 0.95
	s.ground.area(_blob(c, gr, 12, 0.1), "grass")
	_lane_pts.append(c)
	if _chance(0.55):   # a pond with a willow
		_pond(c, gr * 0.7, gr * 0.5, s.rng.randf() * PI)
		s.prop("willow", c + _dir(s.rng.randf() * TAU) * gr * 0.62, 0.0, 1.0)
	else:
		if not s.prop("prop_well_roofed", c, 0.0, 1.0):
			s.prop("well", c, 0.0, 1.0)
		s.prop("tree_broadleaf", c + _dir(s.rng.randf() * TAU) * gr * 0.5, 0.0, _r(1.0, 1.3))
	s._claim(c, gr * 0.5)
	# two lanes out between the houses
	var a0 := s.rng.randf() * TAU
	var lanes: Array = []
	for k in 2:
		var a := a0 + k * PI + _r(-0.5, 0.5)
		var lane := _march(c + _dir(a) * (gr + 0.2), a, _r(1.6, 2.8), _r(-0.1, 0.1))
		if lane.size() >= 2:
			lanes.append([a, lane])
			s.ground.road(lane, 0.16, "dirt")
			_lane_pts.append_array(lane)
	# the church on the green's edge
	var church_a := a0 + PI / 2.0 + _r(-0.3, 0.3)
	var church := s._model("northern", "church", s.GRAND_UNIT)
	if church != "":
		var f: float = s._foot(church)
		var at := c + _dir(church_a) * (gr + f * 0.75)
		if s._dry(at, f) and s._free(at, f):
			s._add(church, at, 0.0, _yaw_to(-_dir(church_a)), Vector3.ONE, s.ROOF_BASE["northern"], index, 0.3)
			s._claim(at, f)
			_note(at, f)
			s.prop("tree_small", at + _dir(church_a + 1.2) * f * 1.1, 0.0, 1.0)
	# houses round the green, leaving gaps at the lanes and the church
	var ring := gr + 0.5
	var n := int(TAU * ring / spacing)
	var built := 0
	var want := s.rng.randi_range(5, 9)
	for k in n:
		if built >= want:
			break
		var a := a0 + TAU * (k + 0.5) / n
		var skip := absf(angle_difference(a, church_a)) < 0.5
		for l in lanes:
			if absf(angle_difference(a, float(l[0]))) < 0.4:
				skip = true
		if skip:
			continue
		var p := c + _dir(a) * ring
		if _house(p, _yaw_to(-_dir(a)) + _r(-0.12, 0.12), "village", spacing * 0.47, 0.0):
			built += 1
			_yard(p, _dir(a), spacing)
	for l in lanes:
		_row(l[1], spacing, "village", 0.0, 0.45, 0.65, 0.7, 0.3, 3)
	_track(c)
	_farmland(c, ring + 1.4, ring + 4.4, s.rng.randi_range(5, 9), _dir(a0 + PI / 2.0))
	return c


## A little pond: a flat patch of water-coloured field.
func _pond(c: Vector2, w: float, d: float, yaw: float) -> void:
	var ok := _area_ok(c, yaw, w, d, 0.08)
	if not ok[0]:
		return
	s._add("field", c, 0.0, yaw, Vector3(w / _fw, 1, d / _fd), Color(0.30, 0.50, 0.60))
	_claim_rect(c, yaw, w, d)


## A street village (northern, classical, or beside a stream in the east and the river lands):
## a winding lane of houses with a church or shrine, farmland beyond. `stream` puts the
## lane along the water, with its fields, paddies or irrigated strips between.
func _street_village(cells: Array, index: int, stream: bool) -> Vector2:
	var houses := s.rng.randi_range(4, 9)
	var length := houses * 0.3 + 1.4
	var c := _find(cells, length + 2.2, "water" if stream else "")
	if c == Vector2.ZERO:
		return c
	if stream:
		c = _bank_point(c, 1.9)
		_origin = c
	var heading := s.rng.randf() * TAU
	if _water != Vector2.ZERO:
		heading = _water.angle() + PI / 2.0
	else:
		var g := _gradient(c)
		if g.length() > 0.05:
			heading = Vector2(-g.y, g.x).angle()
	var spacing: float = s.LOT * (0.82 if s.style in ["nile", "near_east"] else 0.95)
	var lane := _spine(c, heading, length * 0.5, _r(-0.1, 0.1))
	if lane.size() < 3:
		return Vector2.ZERO
	s.ground.road(lane, 0.17, "dirt")
	_lane_pts.append_array(lane)
	if _row(lane, spacing, "village", 0.0, 0.46, 0.9, 0.0, 0.0, houses) == 0:
		return Vector2.ZERO
	# the village's shrine, church or well in the middle of its street
	var mid := _along(lane, _length(lane) * 0.5)
	var mt: Vector2 = mid[1]
	_street_centre(mid[0], mt, index)
	if _water != Vector2.ZERO:
		_waterside(c, heading)
	_track(c)
	_farmland(c, 1.8, 4.6, s.rng.randi_range(5, 9), mt)
	return c


## What stands in the middle of a street village.
func _street_centre(p: Vector2, tan: Vector2, index: int) -> void:
	var nor := Vector2(-tan.y, tan.x)
	var side := 1.0 if _chance(0.5) else -1.0
	var part := ""
	match s.style:
		"northern":
			part = s._model("northern", "church", s.GRAND_UNIT)
		"classical":
			part = s._model("civic", "temple", s.CIVIC_UNIT) if _chance(0.3) else ""
	if part != "":
		var f: float = s._foot(part)
		for sd: float in [side, -side]:
			var at: Vector2 = p + nor * sd * (f + 0.35)
			if s._dry(at, f) and s._free(at, f):
				s._add(part, at, 0.0, _yaw_to(-nor * sd), Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.3)
				s._claim(at, f)
				_note(at, f)
				break
	var at := p + nor * side * 0.2
	if s.style in ["east", "nile", "near_east"]:
		var shrine := "prop_shrine" if s.style == "east" else "prop_water_jars"
		if not s.prop(shrine, p + nor * side * 0.45, _yaw_to(-nor * side), 1.0, index):
			s.prop("well", at, 0.0, 1.0)
	elif not s.prop("well", at, 0.0, 1.0):
		s.prop("bench", at, _yaw_along(tan), 1.0)


## The edge of the water below a streamside village: bamboo or palms, boats and shadufs.
func _waterside(c: Vector2, heading: float) -> void:
	var bank := c
	for step in 40:
		var q := c + _water * step * 0.2
		if s.earth.is_wet(q):
			break
		bank = q
	var along := _dir(heading)
	match s.style:
		"nile":
			for k in 2:
				var at := bank + along * (k * 1.3 - 0.6)
				if s._free(at, 0.1):
					s.prop("prop_shaduf", at, _yaw_to(_water), 1.0)
					s._claim(at, 0.15)
			for k in 4:
				var at := bank - _water * _r(0.2, 0.9) + along * _r(-2.0, 2.0)
				if s._free(at, 0.1) and not s.earth.is_wet(at):
					s.prop("palm", at, s.rng.randf() * TAU, _r(0.9, 1.2))
					s._claim(at, 0.12)
			if _chance(0.4):
				s.prop("prop_reed_boat", bank, _yaw_along(along), 1.0)
		"near_east":
			for k in 3:
				var at := bank - _water * _r(0.1, 0.8) + along * _r(-1.8, 1.8)
				if s._free(at, 0.1) and not s.earth.is_wet(at):
					s.prop("palm", at, s.rng.randf() * TAU, _r(0.9, 1.2))
					s._claim(at, 0.12)
			var dove := c + along * _r(-1.0, 1.0) - _water * 0.7
			if s._free(dove, 0.2):
				s.prop("prop_dovecote", dove, 0.0, 1.0)
				s._claim(dove, 0.2)
		"east":
			for k in 3:   # a bamboo grove behind the village
				var at := c - _water * _r(1.0, 1.7) + along * _r(-1.6, 1.6)
				if s._free(at, 0.15) and not s.earth.is_wet(at):
					s.prop("bamboo", at, s.rng.randf() * TAU, _r(0.9, 1.2))
					s._claim(at, 0.15)
			if _chance(0.4):
				s.prop("boat", bank, _yaw_along(along), 1.0)
			s.prop("reeds", bank, 0.0, 1.0)
		_:
			s.prop("reeds", bank, 0.0, 1.0)
			if _chance(0.4):
				s.prop("boat", bank, _yaw_along(along), 1.0)


## A classical hill village: a tight knot of houses on a rise round a small square with a
## well, olive groves and vineyards on the slopes.
func _hill_village(cells: Array, index: int) -> Vector2:
	var c := _find(cells, 3.4, "hill")
	if c == Vector2.ZERO:
		return c
	var spacing: float = s.LOT * 0.85
	var sq := _r(0.4, 0.6)
	s.ground.area(_blob(c, sq, 10, 0.1), "flag")
	s.prop("well" if _chance(0.6) else "prop_fountain_basin", c, 0.0, 1.0, index)
	s.prop("olive", c + _dir(s.rng.randf() * TAU) * sq * 0.9, 0.0, 1.1)
	s._claim(c, sq * 0.6)
	_lane_pts.append(c)
	var grad := _gradient(c)
	var a0 := Vector2(grad.y, -grad.x).angle() if grad.length() > 0.03 else s.rng.randf() * TAU
	var built := 0
	var want := s.rng.randi_range(5, 9)
	# houses on tight, slightly bent arcs round the square, facing it
	for ringno in 3:
		var radius := sq + 0.46 + ringno * spacing * 0.9
		var n := int(TAU * radius / spacing)
		for k in n:
			if built >= want:
				break
			var a := a0 + TAU * (k + 0.5 * (ringno % 2)) / n
			if ringno > 0 and not _chance(0.55):
				continue
			var p := c + _dir(a) * (radius + _r(-0.08, 0.1))
			if _house(p, _yaw_to(-_dir(a)) + _r(-0.2, 0.2), "village", spacing * 0.48, 0.0):
				built += 1
	for k in 2:   # two lanes down the hill, so it can be reached
		var a := a0 + k * PI + _r(-0.5, 0.5)
		var lane := _march(c + _dir(a) * (sq + 0.1), a, _r(2.0, 3.0), _r(-0.15, 0.15))
		if lane.size() >= 2:
			s.ground.road(lane, 0.15, "dirt")
			_lane_pts.append_array(lane)
	if built == 0:
		return Vector2.ZERO
	_track(c)
	_farmland(c, 1.8, 4.6, s.rng.randi_range(5, 9), _dir(a0))
	return c


## A village of the south: houses round a water tank with a sacred tree on its platform,
## mango groves and fields beyond.
func _tank_village(cells: Array, index: int) -> Vector2:
	var tw := _r(1.1, 1.6)
	var td := _r(0.8, 1.1)
	var c := _find(cells, 3.6, "")
	if c == Vector2.ZERO:
		return c
	var spacing: float = s.LOT * 0.9
	var yaw := s.rng.randf() * PI
	s.ground.patch(c, tw * 0.85, "earth", 0.9)
	_pond(c, tw, td, yaw)
	s._claim(c, td * 0.5)
	_lane_pts.append(c)
	var tree_a := s.rng.randf() * TAU
	var tp := c + _dir(tree_a) * (tw * 0.5 + 0.6)
	if s._free(tp, 0.3) and not s.earth.is_wet(tp):
		if not s.prop("prop_tree_platform", tp, 0.0, 1.0, index):
			s.prop("tree_broadleaf", tp, 0.0, 1.3)
		s._claim(tp, 0.3)
	var sp := c + _dir(tree_a + 0.7) * (tw * 0.5 + 0.7)
	if s._free(sp, 0.2) and s.prop("prop_shrine_india", sp, tree_a, 1.0, index):
		s._claim(sp, 0.2)
	var built := 0
	var want := s.rng.randi_range(6, 10)
	for ringno in 2:
		var radius := tw * 0.5 + 0.95 + ringno * spacing
		var n := int(TAU * (radius + 0.2) / spacing)
		for k in n:
			if built >= want:
				break
			var a := TAU * (k + 0.5) / n
			if absf(angle_difference(a, tree_a)) < 0.5:
				continue
			var p := c + _dir(a) * (radius + _r(-0.05, 0.1))
			if _house(p, _yaw_to(-_dir(a)) + _r(-0.15, 0.15), "village", spacing * 0.47, 0.0):
				built += 1
				if ringno == 0 and _chance(0.5):
					s.prop("chickens" if _chance(0.5) else "pots", p + _dir(a) * 0.5, s.rng.randf() * TAU, 1.0)
	if built == 0:
		return Vector2.ZERO
	var lane := _march(c + _dir(tree_a + PI) * (tw * 0.5 + 1.2), tree_a + PI, _r(1.8, 2.8), _r(-0.1, 0.1))
	if lane.size() >= 2:
		s.ground.road(lane, 0.15, "dirt")
		_lane_pts.append_array(lane)
	s.prop("prop_bullock_cart", c + _dir(tree_a + 2.2) * (tw * 0.5 + 1.0), s.rng.randf() * TAU, 1.0, index)
	_track(c)
	_farmland(c, 2.4, 5.4, s.rng.randi_range(6, 10), _dir(yaw))
	return c


# --- farms ---------------------------------------------------------------------------------

## A lone farmstead (or in the classical lands a villa rustica): a yard with its house and
## barns round it, a garden and orchard behind, a pasture and a ring of fields.
func _farmstead(cells: Array, index: int) -> Vector2:
	var c := _find(cells, 4.2, "water" if s.style in ["nile", "near_east", "east"] and _chance(0.5) else "")
	if c == Vector2.ZERO:
		return c
	var villa := s.style == "classical" and _chance(0.5)
	var yard := _r(0.8, 1.05)
	_water = s._sea_direction(c, 5.0)
	var a0 := s.rng.randf() * TAU
	s.ground.area(_blob(c, yard, 10, 0.1), "earth")
	s._claim(c, yard * 0.32)
	_lane_pts.append(c + _dir(a0 + PI) * (yard + 0.5))
	var spacing: float = s.LOT * 0.95
	# the farmhouse: a two-lot farmhouse if the region has one
	var hp := c + _dir(a0) * (yard + 0.1)
	var face := _yaw_to(-_dir(a0))
	var built := 0
	if villa or _chance(0.5):
		if s._fit_house(hp, face, 1.0, spacing * 0.7, index, 0.0, "farm", true):
			_note(hp, spacing * 0.7)
			built += 1
	if built == 0 and _house(hp, face, "farm", spacing * 0.5, 0.0):
		built += 1
	# barns and sheds round the yard
	for k in s.rng.randi_range(2, 3):
		var a := a0 + PI / 2.0 + k * PI / 2.0 + _r(-0.15, 0.15)
		var p := c + _dir(a) * (yard + 0.05)
		if _house(p, _yaw_to(-_dir(a)) + _r(-0.1, 0.1), "farm", spacing * 0.46, 0.0):
			built += 1
	if built == 0:
		return Vector2.ZERO
	# yard life
	s.prop("well", c, 0.0, 0.9)
	for kind in ["haystack", "cart", "woodpile", "chickens", "trough"]:
		s.prop(kind, c + _dir(s.rng.randf() * TAU) * _r(0.3, yard * 0.8), s.rng.randf() * TAU, 0.9)
	var behind := _dir(a0 + PI)
	var sideways := Vector2(-behind.y, behind.x)
	_grove(c + behind * (yard + 1.0), _yaw_to(behind), 1.5, 1.1, _orchard_tree(), 0.55)
	s.ground.patch(c + behind * (yard + 0.2) + sideways * 0.9, 0.35, "garden", 0.7)
	s.prop("vegetable_patch", c + behind * (yard + 0.2) + sideways * 0.9, _yaw_to(behind), 1.0)
	# a pasture beside, and the fields
	var side_a := a0 + PI / 2.0 + (PI if _chance(0.5) else 0.0)
	var animals: Array = ["cow", "sheep", "horse"]
	match s.style:
		"east":
			animals = ["ox", "goat"]
		"nile", "near_east":
			animals = ["goat", "sheep", "ox"]
		"south_asian":
			animals = ["cow", "ox", "goat"]
	var fence := "stone_wall" if s.style == "classical" else ("hedge" if s.style == "northern" else "fence")
	_pasture(c + _dir(side_a) * (yard + 1.5), _yaw_to(_dir(side_a)), 1.6, 1.3, fence, animals)
	if villa:
		_grove(c + _dir(a0 + 2.3) * 3.0, a0, 1.6, 1.4, "olive", 0.62)
		_vineyard(c + _dir(a0 - 2.3) * 3.0, a0, 1.3, 1.5)
	_track(c)
	_farmland(c, yard + 1.6, yard + 4.2, s.rng.randi_range(4, 8), _dir(a0))
	return c


# --- the steppe ----------------------------------------------------------------------------

## A family cluster of gers round a hearth at `cc`, their doors all to the south as on the
## steppe, with its wagon and horse line. Returns how many gers stood.
func _ger_cluster(cc: Vector2, gers: int, door: float, index: int, mix: float) -> int:
	var built := 0
	var a0 := s.rng.randf() * TAU
	for k in gers:
		var p := cc + _dir(a0 + TAU * k / gers) * (0.62 if gers > 1 else 0.0)
		if s._fit_house(p, door + _r(-0.35, 0.35), _r(0.95, 1.25), s.LOT * 0.46, index, mix, "camp"):
			built += 1
			_note(p, s.LOT * 0.46)
	if built == 0:
		return 0
	s.ground.patch(cc, 0.8, "earth", 0.55)
	var back := cc + Vector2(0.0, -1.05)   # wagons stand behind, to the north
	if s._free(back, 0.25) and not s.earth.is_wet(back):
		s.prop("prop_wagon", back, door + PI / 2.0 + _r(-0.4, 0.4), 1.0)
		s._claim(back, 0.25)
	var line := cc + _dir(a0 + 0.5) * 1.5
	if s._free(line, 0.25) and not s.earth.is_wet(line):
		s.prop("prop_horse_tether", line, s.rng.randf() * TAU, 1.0)
		s._claim(line, 0.25)
	return built


## A herd grazing at `p`: a few animals loosely together.
func _herd(p: Vector2, kinds: Array) -> void:
	if s.earth.is_wet(p) or not s._free(p, 0.3):
		return
	var kind := str(kinds[s.rng.randi() % kinds.size()])
	for k in s.rng.randi_range(2, 3):
		var q := p + _dir(s.rng.randf() * TAU) * _r(0.0, 0.5)
		if not s.earth.is_wet(q):
			s.prop(kind, q, s.rng.randf() * TAU, _r(0.9, 1.1))
	s._claim(p, 0.35)
	_note(p, 0.35)


## An ovoo (cairn with blue scarves) on the highest ground within `reach` of `c`.
func _ovoo(c: Vector2, reach: float) -> void:
	var best := Vector2.ZERO
	var best_h := -1.0e9
	for k in 12:
		var p := c + _dir(s.rng.randf() * TAU) * _r(reach * 0.5, reach)
		if s.earth.is_wet(p) or not s._free(p, 0.3):
			continue
		var h := _h(p)
		if h > best_h:
			best_h = h
			best = p
	if best != Vector2.ZERO:
		if not s.prop("prop_ovoo", best, 0.0, 1.0):
			s.prop("rocks", best, 0.0, 1.0)
		s._claim(best, 0.3)
		_note(best, 0.3)


## A herders' camp out on the steppe: one or two family clusters of gers, their wagons and
## horse lines, the herds grazing round about and an ovoo on a rise.
func _herders(cells: Array, index: int) -> Vector2:
	var c := _find(cells, 3.6, "")
	if c == Vector2.ZERO:
		return c
	_lane_pts.append(c)
	var door := _r(-0.4, 0.4)
	var built := 0
	for k in s.rng.randi_range(1, 2):
		var cc := c + (_dir(s.rng.randf() * TAU) * 1.5 if k > 0 else Vector2.ZERO)
		built += _ger_cluster(cc, s.rng.randi_range(2, 4), door, index, 0.4)
	if built == 0:
		return Vector2.ZERO
	var herds := ["sheep", "goat", "horse", "cow", "camel"]
	for k in s.rng.randi_range(3, 5):
		_herd(c + _dir(s.rng.randf() * TAU) * _r(2.0, 3.6), herds)
	_ovoo(c, 3.6)
	_track(c)
	return c


## A khan's camp: gers in family clusters round the great tent, none touching, with wagons,
## horse lines and herds outside and an ovoo on a rise. Called by plan_city for steppe cities.
func _camp(site: Dictionary, centre: Vector2, half: float, tents: int, index: int) -> void:
	_site = index
	_origin = centre
	var court: String = s._palace_part() if site["capital"] else ""
	var core := s.LOT * 0.5
	if court != "":   # the khan's court from the model kit, with its own standards (D-280)
		s._add(court, centre, 0.0, _r(-0.3, 0.3), Vector3.ONE, s.ROOF_BASE.get(s.style, Color.WHITE), index, 0.85)
		core = s._foot(court)
		s._claim(centre, core)
	elif site["capital"]:
		s._palace(centre, index, 0.0)
		core = float(s.PALACE_R["steppe"]) * s.S
		s._claim(centre, core)
		s._add("k_flag", centre + Vector2(s.LOT, -s.LOT), 0.0, 0.0, Vector3.ONE, Color.WHITE, index, 1.0)
	s.prop("prop_tug", centre + Vector2(core * 0.8, core * 0.8), 0.0, 1.0, index)
	var door := _r(-0.35, 0.35)
	var placed := 0
	var per := 4
	var tries := 0
	while placed < tents and tries < ceili(tents / float(per)) * 12:
		tries += 1
		var cc := centre + _dir(s.rng.randf() * TAU) * (core + 0.9 + sqrt(s.rng.randf()) * maxf(half - core, 1.5))
		if not s._dry(cc, 1.0) or not s._free(cc, 0.9):
			continue
		placed += _ger_cluster(cc, clampi(tents - placed, 1, per), door, index, 0.4)
	var herds := ["sheep", "goat", "horse", "cow", "camel"]
	for k in clampi(tents / 3, 3, 12):
		_herd(centre + _dir(s.rng.randf() * TAU) * (half * _r(1.05, 1.5) + 1.0), herds)
	_ovoo(centre, half * 1.3 + 1.0)
