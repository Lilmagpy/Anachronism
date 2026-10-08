## The ground of the settlements (D-281): trodden earth round the houses, lanes and streets,
## paved squares, gardens and yards, and footings where a building meets sloping ground, so
## the buildings grow out of the land instead of standing on it.
##
## The planners (plan_city.gd, plan_rural.gd) describe the ground as they lay a place out;
## `build` makes it at the end. Positions are map pixels (as for Settlements._add).
## Kinds of surface: "earth" (trodden earth, a yard), "dirt" (an earth lane), "cobble",
## "flag" (flagstones), "sand", "garden" (dug beds), "grass" (lusher, darker grass).
##
## How it is made. Everything is a thin skin draped on the terrain: each vertex takes the
## height of the very triangle the terrain draws there (so it hugs slopes without sinking in)
## and lies a hair above it. The skins are alpha-blended with feathered, noisy edges
## (shaders/city_ground_paving.gdshader) so the earth fades into the grass; there are no slabs
## and no visible sides. They are merged into one mesh per map tile. Besides what the planners
## describe, `build` lays under every building of `Settlements.placed` a worn apron (wider at
## the door, with a dark contact band at the wall's foot), a trodden path from the door to the
## nearest road, and a plinth of stone or earth that reaches down into the slope, so no corner
## of a house floats.
extends RefCounted

const SHADER := preload("res://shaders/city_ground_paving.gdshader")

## Surface kinds as the shader numbers them.
const SURFACE := {"earth": 0, "dirt": 1, "cobble": 2, "flag": 3, "sand": 4, "garden": 5, "grass": 6,
	"trample": 7, "ao": 8}
## Shapes as the shader numbers them.
const ROAD := 0
const RIM := 1
const BLOB := 2
const APRON := 3

## The local earth by people (everyday sRGB colours, run through the same pipeline as the
## terrain's grass): dusty sand-earth on the Nile and in the Near East, red earth in the
## south, grey-brown in the north, warm ochre round the Mediterranean, mid brown in the east.
const EARTH := {"nile": Color(0.82, 0.70, 0.48), "near_east": Color(0.80, 0.68, 0.47),
	"south_asian": Color(0.74, 0.45, 0.30), "northern": Color(0.52, 0.45, 0.34),
	"classical": Color(0.77, 0.63, 0.42), "east": Color(0.64, 0.50, 0.33),
	"steppe": Color(0.68, 0.62, 0.43)}
## The stone or earth of a building's plinth by people.
const PLINTH := {"nile": Color(0.80, 0.68, 0.48), "near_east": Color(0.78, 0.66, 0.47),
	"south_asian": Color(0.74, 0.54, 0.40), "northern": Color(0.56, 0.54, 0.51),
	"classical": Color(0.82, 0.78, 0.70), "east": Color(0.60, 0.56, 0.51),
	"steppe": Color(0.62, 0.56, 0.44)}

const LIFT := 0.012        ## how far the skins lie above the terrain (world units)
const VERGE := 0.4         ## a road's verge each side, as a share of its width
const CELL := 2.0          ## size of the buckets that find roads near a point
const REACH := 1.5         ## how far a door's path may run to a road (map units)
const MAX_PLINTH := 1.2    ## the deepest a plinth may be sunk (world units)


## One tile of ground mesh under construction. Triangles are kept per layer so that
## later layers (streets over aprons, squares over streets, shadows over all) draw last.
class Tile:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c := PackedColorArray()
	var i0 := PackedInt32Array()
	var i1 := PackedInt32Array()
	var i2 := PackedInt32Array()
	var i3 := PackedInt32Array()

	func tri(layer: int, a: int, b: int, d: int) -> void:
		match layer:
			0:
				i0.append(a)
				i0.append(b)
				i0.append(d)
			1:
				i1.append(a)
				i1.append(b)
				i1.append(d)
			2:
				i2.append(a)
				i2.append(b)
				i2.append(d)
			_:
				i3.append(a)
				i3.append(b)
				i3.append(d)


var s: Settlements   ## the Settlements being built
## Everything described, for others to read (the dressing keeps props off the streets):
var roads: Array = []     ## [points: PackedVector2Array, width: float, kind: String]
var areas: Array = []     ## [points: PackedVector2Array, kind: String]
var patches: Array = []   ## [centre: Vector2, radius: float, kind: String]
var fields: Array = []    ## [centre: Vector2, yaw: float, w: float, d: float] (not streets)

var _jobs: Array = []        ## what the planners described, in order: {t, ..., style}
var _footings: Array = []    ## explicit footings: {pos, yaw, size, kind, style}
var _grid := {}              ## bucket -> road segments [a, b, half width] near it
var _widest := 0.0           ## the widest road half width, for searching the buckets
var _area_boxes: Array = []  ## bounding rect per area, parallel to `areas`
var _heights := {}           ## terrain grid index -> height
var _normals := {}           ## terrain grid index -> normal
var _tiles := {}             ## Vector2i -> Tile
var _site_style := {}        ## site index -> building style


func _init(settlements: Settlements) -> void:
	s = settlements


# --- what the planners describe ----------------------------------------------------------

## A soft, irregular patch of surface `kind` round `centre`, `radius` map units across;
## `strength` (0..1) how worn or complete it is (fades out at its edge).
func patch(centre: Vector2, radius: float, kind: String, strength := 1.0) -> void:
	patches.append([centre, radius, kind])
	_jobs.append({"t": "patch", "c": centre, "r": radius, "kind": kind, "k": strength, "style": s.style})


## A lane, street or road along `points`, `width` map units wide, of surface `kind`.
func road(points: PackedVector2Array, width: float, kind: String) -> void:
	if points.size() < 2:
		return
	roads.append([points, width, kind])
	_jobs.append({"t": "road", "p": points, "w": width, "kind": kind, "style": s.style})
	var half := width * 0.5
	_widest = maxf(_widest, half)
	for i in points.size() - 1:
		_register(points[i], points[i + 1], half)


## A whole area (a square, a court, a yard) inside the polygon `points`, of surface `kind`.
func area(points: PackedVector2Array, kind: String) -> void:
	if points.size() < 3:
		return
	areas.append([points, kind])
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	_area_boxes.append(Rect2(lo, hi - lo))
	_jobs.append({"t": "area", "p": points, "kind": kind, "style": s.style})


## A farm field draped on the terrain: `w` x `d` map units centred on `c`, its long side along
## z when turned by `yaw`, furrows along its length in the `crop` colour, a soft bank round it.
func field(c: Vector2, yaw: float, w: float, d: float, crop: Color) -> void:
	fields.append([c, yaw, w, d])
	_jobs.append({"t": "field", "c": c, "yaw": yaw, "w": w, "d": d, "crop": crop, "style": s.style})


## True when `p` lies on a road or square (within `margin` of its edge).
func on_street(p: Vector2, margin := 0.0) -> bool:
	var reach := _widest + margin
	var lo := _bucket(p - Vector2(reach, reach))
	var hi := _bucket(p + Vector2(reach, reach))
	for bx in range(lo.x, hi.x + 1):
		for by in range(lo.y, hi.y + 1):
			for seg in _grid.get(Vector2i(bx, by), []):
				var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1]))
				if d < float(seg[2]) + margin:
					return true
	for i in areas.size():
		if (_area_boxes[i] as Rect2).grow(margin).has_point(p) and Geometry2D.is_point_in_polygon(p, areas[i][0]):
			return true
	return false


## Where a building stands: `size` (map units, x across its front, y deep) turned by `yaw`
## (as in Settlements._add). Lays its footing into the slope and the worn ground round it.
## (`build` already does this for every building in `Settlements.placed`; a footing described
## here instead replaces the automatic apron for a building standing at `centre`.)
func footing(centre: Vector2, yaw: float, size: Vector2, kind := "earth") -> void:
	_footings.append({"pos": centre, "yaw": yaw, "size": size, "kind": kind, "style": s.style})


func _bucket(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func _register(a: Vector2, b: Vector2, half: float) -> void:
	var lo := _bucket(a.min(b))
	var hi := _bucket(a.max(b))
	for bx in range(lo.x, hi.x + 1):
		for by in range(lo.y, hi.y + 1):
			var key := Vector2i(bx, by)
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append([a, b, half])


## The nearest road point to `p` within `reach`: [point, half width, distance], or [].
func _nearest_road(p: Vector2, reach: float) -> Array:
	var best := []
	var best_d := reach
	var lo := _bucket(p - Vector2(reach, reach))
	var hi := _bucket(p + Vector2(reach, reach))
	for bx in range(lo.x, hi.x + 1):
		for by in range(lo.y, hi.y + 1):
			for seg in _grid.get(Vector2i(bx, by), []):
				var q := Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1])
				var d := p.distance_to(q)
				if d < best_d:
					best_d = d
					best = [q, seg[2], d]
	return best


# --- the terrain, as it is drawn ----------------------------------------------------------

func _cell_height(i: int) -> float:
	if _heights.has(i):
		return _heights[i]
	var h: float = s.earth._cell_height(i)
	_heights[i] = h
	return h


## The terrain's surface height at pixel `p`: the very triangle the mesh draws there (its
## quads are cut along the diagonal from their top-right to their bottom-left corner).
func _h(p: Vector2) -> float:
	var e := s.earth
	var stride := float(EarthBuilder.STRIDE)
	var gx := clampf(p.x / stride, 0.0, e.cols - 1.001)
	var gy := clampf(p.y / stride, 0.0, e.rows - 1.001)
	var q := int(gx)
	var r := int(gy)
	var fx := gx - q
	var fy := gy - r
	var i := r * e.cols + q
	var a := _cell_height(i)
	var b := _cell_height(i + 1)
	var c := _cell_height(i + e.cols)
	if fx + fy <= 1.0:
		return a + fx * (b - a) + fy * (c - a)
	var d := _cell_height(i + e.cols + 1)
	return d + (1.0 - fx) * (c - d) + (1.0 - fy) * (b - d)


func _normal_at_grid(q: int, r: int) -> Vector3:
	var e := s.earth
	var key := r * e.cols + q
	if _normals.has(key):
		return _normals[key]
	var hl := _cell_height(r * e.cols + maxi(q - 1, 0))
	var hr := _cell_height(r * e.cols + mini(q + 1, e.cols - 1))
	var hu := _cell_height(maxi(r - 1, 0) * e.cols + q)
	var hd := _cell_height(mini(r + 1, e.rows - 1) * e.cols + q)
	var n := Vector3(hl - hr, 2.0 * EarthBuilder.STRIDE, hu - hd).normalized()
	_normals[key] = n
	return n


## The terrain's smooth normal at pixel `p` (as the mesh interpolates it).
func _n(p: Vector2) -> Vector3:
	var e := s.earth
	var stride := float(EarthBuilder.STRIDE)
	var gx := clampf(p.x / stride, 0.0, e.cols - 1.001)
	var gy := clampf(p.y / stride, 0.0, e.rows - 1.001)
	var q := int(gx)
	var r := int(gy)
	var fx := gx - q
	var fy := gy - r
	var top := _normal_at_grid(q, r).lerp(_normal_at_grid(q + 1, r), fx)
	var bottom := _normal_at_grid(q, r + 1).lerp(_normal_at_grid(q + 1, r + 1), fx)
	return top.lerp(bottom, fy).normalized()


func _tile(p: Vector2) -> Tile:
	var half := s.earth.size() / 2.0
	var key := Vector2i(floori((p.x - half.x) / s.TILE), floori((p.y - half.y) / s.TILE))
	if not _tiles.has(key):
		_tiles[key] = Tile.new()
	return _tiles[key]


## One vertex on the terrain at `p`; `alpha` is its strength (0 over water).
func _vert(t: Tile, p: Vector2, uv: Vector2, kind: int, shape: int, tint: Color, alpha: float,
		check_water := true) -> int:
	var half := s.earth.size() / 2.0
	var wet := s.earth.is_wet(p) if check_water else s.earth.is_ocean_at(p)
	t.v.append(Vector3(p.x - half.x, _h(p) + LIFT, p.y - half.y))
	t.n.append(_n(p))
	t.uv.append(uv)
	t.uv2.append(Vector2(kind, shape))
	t.c.append(Color(tint.r, tint.g, tint.b, 0.0 if wet else alpha))
	return t.v.size() - 1


func _quad(t: Tile, layer: int, a: int, b: int, c: int, d: int) -> void:
	t.tri(layer, a, b, c)
	t.tri(layer, b, d, c)


## A deterministic value in 0..1 for a lattice point.
func _rand01(x: int, y: int) -> float:
	return float(hash(Vector2i(x, y)) & 0xFFFF) / 65535.0


func _vnoise(p: Vector2) -> float:
	var ix := floori(p.x)
	var iy := floori(p.y)
	var fx := p.x - ix
	var fy := p.y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(_rand01(ix, iy), _rand01(ix + 1, iy), fx),
		lerpf(_rand01(ix, iy + 1), _rand01(ix + 1, iy + 1), fx), fy)


func _earth_tint(style: String) -> Color:
	return EARTH.get(style, EARTH["east"])


## The building style of a province's owner (as Settlements.build sets it while planning).
func _style_of_site(site: int) -> String:
	if site < 0 or site >= s.map.sites.size():
		return s.style
	if not _site_style.has(site):
		var owner: Variant = s.map.sites[site]["owner"]
		_site_style[site] = Settlements.style_of(str(s.map.civ_portraits.get(owner, "")))
	return _site_style[site]


# --- roads --------------------------------------------------------------------------------

## Round the corners of a polyline (Chaikin's corner cutting; the ends stay put).
func _smooth(pts: PackedVector2Array, rounds: int) -> PackedVector2Array:
	var cur := pts
	for r in rounds:
		if cur.size() < 3:
			break
		var out := PackedVector2Array([cur[0]])
		for i in cur.size() - 1:
			out.append(cur[i].lerp(cur[i + 1], 0.25))
			out.append(cur[i].lerp(cur[i + 1], 0.75))
		out.append(cur[cur.size() - 1])
		cur = out
	return cur


## Points along a polyline a fixed step apart (the end is always kept).
func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	var carry := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var length := a.distance_to(b)
		if length < 0.0001:
			continue
		var pos := step - carry
		while pos < length:
			out.append(a.lerp(b, pos / length))
			pos += step
		carry = length - (pos - step)
	if out.size() < 2 or out[out.size() - 1].distance_to(pts[pts.size() - 1]) > step * 0.3:
		out.append(pts[pts.size() - 1])
	else:
		out[out.size() - 1] = pts[pts.size() - 1]
	return out


## A ribbon along `pts`: a surface `width` wide with a verge each side that fades out, rounded
## ends, and smooth corners. Split between tiles where it crosses their borders.
func _ribbon(pts: PackedVector2Array, width: float, kind_name: String, style: String, layer: int,
		wobble := 0.12, strength := 1.0) -> void:
	if pts.size() < 2:
		return
	var kind: int = SURFACE.get(kind_name, 1)
	var tint := _earth_tint(style)
	var line := _resample(_smooth(pts, 2 if pts.size() < 8 else 1), 0.4)
	if line.size() < 2:
		return
	var half := width * 0.5 * (1.0 + 2.0 * VERGE)
	# sections: position, normal, half width, distance along
	var pos: Array[Vector2] = []
	var nrm: Array[Vector2] = []
	var hw: Array[float] = []
	var run: Array[float] = []
	var count := line.size()
	var total := 0.0
	var tangents: Array[Vector2] = []
	for i in count:
		var a := line[maxi(i - 1, 0)]
		var b := line[mini(i + 1, count - 1)]
		var dir := (b - a).normalized()
		if dir.length() < 0.5:
			dir = Vector2.RIGHT
		tangents.append(dir)
	# a rounded cap beyond each end
	var cap_steps := [0.3, 0.6, 0.85, 1.0]
	var ext := width * 0.55
	for k in range(cap_steps.size() - 1, -1, -1):
		var t: float = cap_steps[k]
		pos.append(line[0] - tangents[0] * ext * t)
		nrm.append(tangents[0].orthogonal())
		hw.append(half * sqrt(maxf(1.0 - t * t, 0.0)))
		run.append(-ext * t)
	for i in count:
		if i > 0:
			total += line[i].distance_to(line[i - 1])
		var miter := 1.0
		if i > 0 and i < count - 1:
			var seg := (line[i] - line[i - 1]).normalized().orthogonal()
			miter = clampf(1.0 / maxf(seg.dot(tangents[i].orthogonal()), 0.55), 1.0, 1.8)
		pos.append(line[i])
		nrm.append(tangents[i].orthogonal())
		var w := 1.0 + wobble * (_vnoise(line[i] * 1.7) - 0.5) * 2.0
		hw.append(half * w * miter)
		run.append(total)
	for k in cap_steps.size():
		var t: float = cap_steps[k]
		pos.append(line[count - 1] + tangents[count - 1] * ext * t)
		nrm.append(tangents[count - 1].orthogonal())
		hw.append(half * sqrt(maxf(1.0 - t * t, 0.0)))
		run.append(total + ext * t)
	# emit rows of three vertices (left, middle, right), a new tile mesh where it changes
	var tile: Tile = null
	var prev_row: Array = []
	var prev_tile: Tile = null
	for i in pos.size():
		tile = _tile(pos[i])
		var row := _row(tile, pos[i], nrm[i], hw[i], run[i], kind, tint, strength)
		if prev_tile != null:
			if prev_tile != tile:
				# crossed into another tile: repeat the previous section there to join up
				prev_row = _row(tile, pos[i - 1], nrm[i - 1], hw[i - 1], run[i - 1], kind, tint, strength)
			_quad(tile, layer, prev_row[0], prev_row[1], row[0], row[1])
			_quad(tile, layer, prev_row[1], prev_row[2], row[1], row[2])
		prev_row = row
		prev_tile = tile


func _row(tile: Tile, p: Vector2, normal: Vector2, half: float, along: float, kind: int, tint: Color,
		strength: float) -> Array:
	var row := []
	for side in [-1.0, 0.0, 1.0]:
		row.append(_vert(tile, p + normal * half * side, Vector2(side, along), kind, ROAD, tint, strength))
	return row


# --- polygons -----------------------------------------------------------------------------

## An area filled and feathered at its rim, draped on the terrain.
func _polygon(points: PackedVector2Array, kind_name: String, style: String, layer: int,
		rim := 0.24, strength := 1.0) -> void:
	var kind: int = SURFACE.get(kind_name, 3)
	var tint := _earth_tint(style)
	var ring := PackedVector2Array()
	for p in points:
		if ring.is_empty() or ring[ring.size() - 1].distance_to(p) > 0.01:
			ring.append(p)
	if ring.size() > 1 and ring[0].distance_to(ring[ring.size() - 1]) < 0.01:
		ring.remove_at(ring.size() - 1)
	if ring.size() < 3:
		return
	# edges no longer than 0.5 so the rim follows the ground and can be noisy
	var dense := PackedVector2Array()
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var n := maxi(1, ceili(a.distance_to(b) / 0.5))
		for k in n:
			dense.append(a.lerp(b, float(k) / n))
	var ccw := not Geometry2D.is_polygon_clockwise(dense)
	var centre := Vector2.ZERO
	var lo := dense[0]
	var hi := dense[0]
	for p in dense:
		centre += p
		lo = lo.min(p)
		hi = hi.max(p)
	centre /= dense.size()
	var tile := _tile(centre)
	# interior: Delaunay over the rim and a coarse grid of inner points, keeping what lies inside
	var pts := PackedVector2Array(dense)
	var x := lo.x + 0.35
	while x < hi.x:
		var y := lo.y + 0.35
		while y < hi.y:
			var q := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(q, dense) and _inside_by(q, dense, 0.3):
				pts.append(q)
			y += 0.7
		x += 0.7
	var tris := Geometry2D.triangulate_delaunay(pts)
	var base := tile.v.size()
	for p in pts:
		_vert(tile, p, Vector2.ZERO, kind, RIM, tint, strength)
	for k in range(0, tris.size(), 3):
		var cen := (pts[tris[k]] + pts[tris[k + 1]] + pts[tris[k + 2]]) / 3.0
		if Geometry2D.is_point_in_polygon(cen, dense):
			tile.tri(layer, base + tris[k], base + tris[k + 1], base + tris[k + 2])
	# the rim: from a little inside to the outer edge, with a noisy width
	var count := dense.size()
	var rows: Array = []
	for i in count:
		var a := dense[(i + count - 1) % count]
		var b := dense[(i + 1) % count]
		var out := (b - a).normalized().orthogonal()
		if ccw:
			out = -out
		var width := rim * (0.7 + 0.6 * _vnoise(dense[i] * 2.1))
		var row := []
		row.append(_vert(tile, dense[i] - out * 0.12, Vector2.ZERO, kind, RIM, tint, strength))
		row.append(_vert(tile, dense[i], Vector2.ZERO, kind, RIM, tint, strength))
		row.append(_vert(tile, dense[i] + out * width * 0.5, Vector2(0.5, 0.0), kind, RIM, tint, strength))
		row.append(_vert(tile, dense[i] + out * width, Vector2(1.0, 0.0), kind, RIM, tint, strength))
		rows.append(row)
	for i in count:
		var r0: Array = rows[i]
		var r1: Array = rows[(i + 1) % count]
		for j in 3:
			_quad(tile, layer, r0[j], r0[j + 1], r1[j], r1[j + 1])


## True when `q` is at least `margin` away from every edge of the polygon.
func _inside_by(q: Vector2, poly: PackedVector2Array, margin: float) -> bool:
	for i in poly.size():
		var c := Geometry2D.get_closest_point_to_segment(q, poly[i], poly[(i + 1) % poly.size()])
		if q.distance_to(c) < margin:
			return false
	return true


# --- fields -------------------------------------------------------------------------------

## The mesh of a field: a grid about 0.5 apart, with an outer ring that fades out.
func _field(c: Vector2, yaw: float, w: float, d: float, crop: Color) -> void:
	var tile := _tile(c)
	var fwd := Vector2(sin(yaw), cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var nx := maxi(1, ceili(w / 0.5))
	var nz := maxi(1, ceili(d / 0.5))
	var bank := 0.1
	# grid lines from -bank to w + bank, the outermost two at the bank's edge (alpha 0)
	var xs := [-w / 2.0 - bank]
	for i in nx + 1:
		xs.append(-w / 2.0 + w * i / nx)
	xs.append(w / 2.0 + bank)
	var zs := [-d / 2.0 - bank]
	for j in nz + 1:
		zs.append(-d / 2.0 + d * j / nz)
	zs.append(d / 2.0 + bank)
	var rows: Array = []
	for j in zs.size():
		var line := []
		for i in xs.size():
			var edge := i == 0 or j == 0 or i == xs.size() - 1 or j == zs.size() - 1
			var q: Vector2 = c + right * float(xs[i]) + fwd * float(zs[j])
			line.append(_vert(tile, q, Vector2(xs[i], zs[j]), 9, 4, crop, 0.0 if edge else 1.0))
		rows.append(line)
	for j in zs.size() - 1:
		for i in xs.size() - 1:
			_quad(tile, 0, rows[j][i], rows[j][i + 1], rows[j + 1][i], rows[j + 1][i + 1])


# --- patches ------------------------------------------------------------------------------

## An irregular blob of ground: a fan of rings out to a wobbling edge.
func _blob(centre: Vector2, radius: float, kind_name: String, style: String, layer: int, strength: float) -> void:
	var kind: int = SURFACE.get(kind_name, 0)
	var tint := _earth_tint(style)
	var tile := _tile(centre)
	var seed := _rand01(int(centre.x * 50.0), int(centre.y * 50.0))
	var angle := seed * TAU
	var rays := clampi(int(radius * 16.0), 10, 30)
	var fractions := [0.0, 0.4, 0.75, 1.0, 1.25]
	var rings: Array = []
	var middle := _vert(tile, centre, Vector2(0.0, angle), kind, BLOB, tint, strength)
	for k in rays:
		var th := TAU * k / rays
		# the edge wobbles: a few waves of different lengths, phase from the patch itself
		var wob := 1.0 + 0.16 * sin(2.0 * th + seed * 11.0) + 0.1 * sin(3.0 * th + seed * 23.0) \
			+ 0.06 * sin(5.0 * th + seed * 37.0)
		var ring := []
		for f in fractions:
			var q: Vector2 = centre + Vector2(cos(th), sin(th)) * radius * wob * float(f)
			ring.append(_vert(tile, q, Vector2(float(f) / 1.25, angle), kind, BLOB, tint, strength))
		rings.append(ring)
	for k in rays:
		var r0: Array = rings[k]
		var r1: Array = rings[(k + 1) % rays]
		tile.tri(layer, middle, r0[0], r1[0])
		for j in fractions.size() - 1:
			_quad(tile, layer, r0[j], r0[j + 1], r1[j], r1[j + 1])


# --- buildings ----------------------------------------------------------------------------

## Make everything described, under `parent`: wear round the buildings, then what the
## planners described, then the shadows at the walls' feet; plinths join the other parts.
func build(parent: Node3D) -> void:
	_tiles.clear()
	_register_parts()
	var explicit := {}
	for f in _footings:
		explicit[_key(f["pos"])] = true
	for e in s.placed:
		if not explicit.has(_key(e["pos"])):
			_building(e)
	for f in _footings:
		_explicit_footing(f)
	for job in _jobs:
		match job["t"]:
			"patch":
				_blob(job["c"], job["r"], job["kind"], job["style"], 0, job["k"])
			"road":
				_ribbon(job["p"], job["w"], job["kind"], job["style"], 1)
			"area":
				_polygon(job["p"], job["kind"], job["style"], 2)
			"field":
				_field(job["c"], job["yaw"], job["w"], job["d"], job["crop"])
	# the contact shadow at every wall's foot goes over everything
	for e in s.placed:
		if e["what"] != "tent" and not explicit.has(_key(e["pos"])):
			_contact(e)
	_flush(parent)


func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 10.0), roundi(p.y * 10.0))


## The footprint of a placed building: [centre, half x, half z, round?].
func _footprint(e: Dictionary) -> Array:
	var part: String = e["part"]
	var box: AABB = (s._parts[part]["mesh"] as Mesh).get_aabb()
	var k: float = float(e["r"]) / maxf(s._foot(part), 0.001)
	var yaw: float = e["yaw"]
	var right := Vector2(cos(yaw), -sin(yaw))
	var fwd := Vector2(sin(yaw), cos(yaw))
	var off := box.get_center()
	var centre: Vector2 = e["pos"] + right * off.x * k + fwd * off.z * k
	var round_shape: bool = e["what"] == "tent" or part.contains("round")
	return [centre, box.size.x * 0.5 * k, box.size.z * 0.5 * k, round_shape]


## Apron, path and plinth for one building from `placed`.
func _building(e: Dictionary) -> void:
	var what: String = e["what"]
	var style := _style_of_site(int(e["site"]))
	var fp := _footprint(e)
	var centre: Vector2 = fp[0]
	var hx: float = fp[1]
	var hz: float = fp[2]
	var round_shape: bool = fp[3]
	var yaw: float = e["yaw"]
	var big := maxf(hx, hz)
	var scale_up := clampf(sqrt(big / 0.3), 1.0, 2.2)
	var side := 0.06
	var back := 0.05
	var front := 0.2
	var strength := 0.8
	var kind := "earth"
	match what:
		"tent":
			side = 0.2
			back = 0.2
			front = 0.3
			kind = "trample"
		"wall":
			side = 0.09
			back = 0.09
			front = 0.09
			strength = 0.8
		"tower":
			side = 0.18
			back = 0.18
			front = 0.22
		"gate":
			side = 0.12
			back = 0.45
			front = 0.45
		"palace", "public":
			side = 0.16 * scale_up
			back = 0.13 * scale_up
			front = 0.42 * scale_up
	var subs := 2 if what in ["house", "palace", "public"] else 1
	if big > 0.5:
		subs = 3
	_apron(centre, yaw, hx, hz, round_shape, side, back, front, style, SURFACE[kind], 0, strength,
		[-0.3, 0.0, 0.45, 1.0], subs)
	if what in ["house", "palace", "public"]:
		_door_path(centre, yaw, hz + front * 0.2, style, what)
	if what != "tent":
		_plinth(e, centre, hx, hz, round_shape, style)


func _explicit_footing(f: Dictionary) -> void:
	var size: Vector2 = f["size"]
	var style: String = f["style"]
	var kind: String = f["kind"]
	_apron(f["pos"], f["yaw"], size.x * 0.5, size.y * 0.5, false, 0.1, 0.08, 0.3, style,
		SURFACE.get(kind, 0), 0, 0.95, [-0.3, 0.0, 0.45, 1.0], 2)
	_apron(f["pos"], f["yaw"], size.x * 0.5, size.y * 0.5, false, 0.15, 0.15, 0.15, style, SURFACE["ao"], 3,
		1.0, [-0.3, 0.0, 1.0], 2)


func _contact(e: Dictionary) -> void:
	var fp := _footprint(e)
	var what: String = e["what"]
	var width := 0.09 if what != "wall" else 0.07
	_apron(fp[0], e["yaw"], fp[1], fp[2], fp[3], width, width, width, "east", SURFACE["ao"], 3, 1.0,
		[-0.4, 0.0, 1.0], 2 if what != "wall" else 1)


## The worn ground round a footprint: rows of vertices stepping out from just inside the wall
## to the outer edge (`rows` are shares of the margin), wider at the front (+z, where the door is).
func _apron(c: Vector2, yaw: float, hx: float, hz: float, round_shape: bool, side: float, back: float,
		front: float, style: String, kind: int, layer: int, strength: float, rows: Array, subs: int) -> void:
	var tint := _earth_tint(style)
	var tile := _tile(c)
	var fwd := Vector2(sin(yaw), cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	# the outline: points and outward normals in the building's own frame
	var at: Array[Vector2] = []
	var out: Array[Vector2] = []
	if round_shape:
		var n := 12
		for k in n:
			var a := TAU * k / n
			at.append(Vector2(cos(a) * hx, sin(a) * hz))
			out.append(Vector2(cos(a), sin(a)))
	else:
		var corners: Array[Vector2] = [Vector2(hx, hz), Vector2(-hx, hz), Vector2(-hx, -hz), Vector2(hx, -hz)]
		var normals: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(-1.0, 0.0), Vector2(0.0, -1.0), Vector2(1.0, 0.0)]
		for k in 4:
			var a := corners[k]
			var b := corners[(k + 1) % 4]
			var diag := Vector2(signf(a.x), signf(a.y)).normalized()
			at.append(a)
			out.append(diag)
			for m in range(1, subs):
				at.append(a.lerp(b, float(m) / subs))
				out.append(normals[k])
	var count := at.size()
	var grid: Array = []
	for i in count:
		var nl := out[i]
		var margin := side
		if nl.y > 0.0:
			margin = lerpf(side, front, nl.y)
		else:
			margin = lerpf(side, back, -nl.y)
		margin *= 0.85 + 0.3 * _vnoise((c + right * at[i].x + fwd * at[i].y) * 3.1)
		var line := []
		for r in rows:
			var d: float = float(r) * margin
			var local := at[i] + nl * d
			var q: Vector2 = c + right * local.x + fwd * local.y
			var t := maxf(float(r), 0.0)
			line.append(_vert(tile, q, Vector2(t, maxf(d, 0.0)), kind, APRON, tint, strength, false))
		grid.append(line)
	for i in count:
		var r0: Array = grid[i]
		var r1: Array = grid[(i + 1) % count]
		for j in rows.size() - 1:
			_quad(tile, layer, r0[j], r0[j + 1], r1[j], r1[j + 1])


## A short trodden path from the door to the nearest road, if one is near and ahead.
func _door_path(c: Vector2, yaw: float, depth: float, style: String, what: String) -> void:
	var fwd := Vector2(sin(yaw), cos(yaw))
	var door := c + fwd * depth
	var near := _nearest_road(door, REACH)
	if near.is_empty():
		return
	var q: Vector2 = near[0]
	var gap: float = float(near[2]) - float(near[1])
	if gap < 0.12:
		return   # the door opens on the street itself
	if (q - door).normalized().dot(fwd) < 0.3:
		return   # the road runs behind or beside the house
	var mid := door.lerp(q, 0.5) + (q - door).orthogonal().normalized() * (_vnoise(door * 4.0) - 0.5) * 0.12
	var edge := q + (door - q).normalized() * float(near[1]) * 0.5
	_ribbon(PackedVector2Array([door, mid, edge]), 0.12 if what == "house" else 0.2, "dirt", style, 1, 0.2, 0.85)


## A plinth that reaches down into the ground under a building, so no corner floats.
func _plinth(e: Dictionary, centre: Vector2, hx: float, hz: float, round_shape: bool, style: String) -> void:
	var yaw: float = e["yaw"]
	var fwd := Vector2(sin(yaw), cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var low := INF
	for sx in [-1.0, 0.0, 1.0]:
		for sz in [-1.0, 0.0, 1.0]:
			low = minf(low, _h(centre + right * hx * sx + fwd * hz * sz))
	var model_at := s.earth.ground_at_pixel(e["pos"]).y   # where the building itself stands
	var step := 0.03 if e["what"] in ["house", "wall", "tower"] else 0.05
	var bottom := minf(low, model_at) - 0.05
	var height := minf(model_at + step - bottom, MAX_PLINTH)
	var grow := 0.03
	var shade := 0.94 + 0.12 * _rand01(int(e["pos"].x * 40.0), int(e["pos"].y * 40.0))
	var colour: Color = PLINTH.get(style, PLINTH["east"])
	colour = Color(colour.r * shade, colour.g * shade, colour.b * shade)
	var part := "g_plinth_round" if round_shape else "g_plinth"
	s._add(part, centre, bottom - s.earth.ground_at_pixel(centre).y, yaw,
		Vector3((hx + grow) * 2.0, height, (hz + grow) * 2.0), colour)


# --- the meshes ---------------------------------------------------------------------------

## The plinth parts (a unit box or drum standing on y=0), registered with the Settlements.
func _register_parts() -> void:
	if s._parts.has("g_plinth"):
		return
	s._parts["g_plinth"] = {"mesh": _prism(4, 0.7071), "transforms": [], "colours": []}
	s._parts["g_plinth_round"] = {"mesh": _prism(10, 0.5), "transforms": [], "colours": []}


## An upright prism with `sides` sides, 1 high, standing on y=0, `radius` out to its corners
## (a box that is 1 wide for 4 sides at 0.7071), with a flat top and no bottom.
func _prism(sides: int, radius: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var turn := PI / 4.0 if sides == 4 else 0.0
	var up := Vector3(0.0, 1.0, 0.0)
	for k in sides:
		var a0 := turn + TAU * k / sides
		var a1 := turn + TAU * (k + 1) / sides
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var nl := Vector3(cos((a0 + a1) / 2.0), 0.0, sin((a0 + a1) / 2.0))
		for v in [p0, p1, p1 + up, p0, p1 + up, p0 + up]:
			verts.append(v)
			normals.append(nl)
		for v in [up, p1 + up, p0 + up]:
			verts.append(v)
			normals.append(up)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Turn every tile under construction into a mesh under `parent`.
func _flush(parent: Node3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("fade_near", s.SHOW_WITHIN)
	var keys := _tiles.keys()
	keys.sort()
	for key in keys:
		var t: Tile = _tiles[key]
		var idx := PackedInt32Array()
		idx.append_array(t.i0)
		idx.append_array(t.i1)
		idx.append_array(t.i2)
		idx.append_array(t.i3)
		if idx.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = t.v
		arrays[Mesh.ARRAY_NORMAL] = t.n
		arrays[Mesh.ARRAY_COLOR] = t.c
		arrays[Mesh.ARRAY_TEX_UV] = t.uv
		arrays[Mesh.ARRAY_TEX_UV2] = t.uv2
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.name = "Ground_%d_%d" % [key.x, key.y]
		node.mesh = mesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = s.SHOW_WITHIN * 1.22 + mesh.get_aabb().size.length() / 2.0
		parent.add_child(node)
	_tiles.clear()
