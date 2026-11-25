## Urbs F3 (monuments): the checks that see a monument as the player sees it, by geometry. Run
## by audit.gd (`# F3 monuments`) after it has built the year's monuments; the findings go into
## its URBS_AUDIT line and from there into city_audit.py's report.
##
## The PARTS of a monument are its real mesh pieces at the nearest level of detail: every
## connected run of triangles of one material in its meshes (a step, a wall, a column drum, a
## roof plane), and every instanced part (a column) as its mesh's box under its transform. Each
## part is a box in the monument's own frame (turned only about the vertical), so in the world
## it is an oriented box: these are the "real mesh AABBs" the checks use, not one box per
## monument.
##
## Findings (lists of strings "<id> ..." so the report can quote them):
##   part_overlaps    parts of one standing monument inside another's (deeper than PART_M), not
##                    hidden in the ground; one line per pair with the deepest and the count
##   parts_floating   parts (or clusters of touching parts) of a monument resting on nothing:
##                    neither the ground nor another of its parts
##   parts_sunk       columns (instanced parts) whose foot is below the top of what they stand
##                    on by more than SUNK_M (a column sunk into its podium or stylobate)
##   coplanar         faces of two different materials in the same plane and overlapping:
##                    they flicker (z-fighting), within one monument or between two
##   view_inside      the `--at=<id>` street camera inside a solid (any monument's part)
##   view_misses      the `--at=<id>` camera not looking at its monument's front: standing
##                    behind or beside it, turned away from it, or with another monument between
## and `parts`: the number of parts checked.
class_name UrbsMonumentAudit
extends RefCounted

const PART_M := 0.10       ## overlaps shallower than this are parts touching, not through
const TOUCH_M := 0.03      ## gap within which two parts touch (support)
const GROUND_M := 0.15     ## a part whose foot is this close to the ground stands on it
const SUNK_M := 0.10
const REST_M := 0.15       ## parts overlapping less than this in height rest one on the other
const FLAT_M := 0.5        ## a part this thin and wide is a floor: standing on it is not through it
const CELL := 4.0          ## grid cell for the part searches (metres)
const QUANT := 100.0       ## vertex welding for the connected runs: 1 cm
const COPLANAR_MIN_AREA := 0.05   ## m²: smaller faces flicker too little to see
## Monuments whose parts are open ground (pavings): standing on them is not an overlap.
const PAVINGS := ["plaza", "road_paved", "lacus_curtius", "comitium"]
## Routes whose parts run through the city by design (their meeting with a gate is the gate's).
const ROUTES := ["wall", "aqueduct", "sewer"]
## Models with no `--at` street view of a front (routes, pavings, the river works).
const NO_VIEW := ["wall", "aqueduct", "sewer", "road_paved", "bridge_stone", "bridge_timber", "quay"]

var mon: UrbsMonuments
var height := Callable()
var fill: UrbsFill = null   ## the houses, for the camera checks (optional)
var parts := {}            ## id -> Array of part dictionaries (see _part)
var _grid := {}            ## Vector2i -> Array of [id, index]: every part, by world cell


func _init(monuments: UrbsMonuments, ground: Callable, houses: UrbsFill = null) -> void:
	mon = monuments
	height = ground
	fill = houses


## Every check: {part_overlaps, parts_floating, parts_sunk, coplanar, view_inside, view_misses, parts}.
func run(with_coplanar := true) -> Dictionary:
	var ids: Array = mon.ids()
	ids.sort()
	var n := 0
	for id in ids:
		parts[id] = _parts_of(id)
		n += (parts[id] as Array).size()
	_index(ids)
	var out := {"parts": n, "part_overlaps": _part_overlaps(ids), "parts_floating": [], "parts_sunk": [],
		"coplanar": [], "view_inside": [], "view_misses": []}
	for id in ids:
		var fl := _floating(id)
		if fl != "":
			out.parts_floating.append(fl)
		var sk := _sunk(id)
		if sk != "":
			out.parts_sunk.append(sk)
	if with_coplanar:
		out.coplanar = _coplanar(ids)
	var views := _views(ids)
	out.view_inside = views[0]
	out.view_misses = views[1]
	return out


# ---------------------------------------------------------------------------------------------
# Parts
# ---------------------------------------------------------------------------------------------


## A part: lo/hi its box in the monument's frame; c, ax, az, hx, hz its oriented rectangle on
## the ground (world); y0, y1 its height range (world); mat the material's id; inst true for an
## instanced part; area its horizontal top's area.
## tv: its triangles (3 vertices each, the monument's frame; for an instance built on demand
## from `mesh` under `t`); comp: the triangles of the whole connected run it was cut from (a
## closed solid, for the inside test); wb: its world box; xf: the monument's frame.
func _part(xf: Transform3D, lo: Vector3, hi: Vector3, mat: int, inst: bool, tv := PackedVector3Array(),
		comp := PackedVector3Array()) -> Dictionary:
	var c3 := xf * ((lo + hi) * 0.5)
	var ax3 := xf.basis * Vector3(1, 0, 0)
	var az3 := xf.basis * Vector3(0, 0, 1)
	var wb := AABB(xf * lo, Vector3.ZERO)
	for i in 8:
		wb = wb.expand(xf * AABB(lo, hi - lo).get_endpoint(i))
	return {"lo": lo, "hi": hi, "c": Vector2(c3.x, c3.z), "ax": Vector2(ax3.x, ax3.z).normalized(),
		"az": Vector2(az3.x, az3.z).normalized(), "hx": (hi.x - lo.x) * 0.5, "hz": (hi.z - lo.z) * 0.5,
		"y0": xf.origin.y + lo.y, "y1": xf.origin.y + hi.y, "mat": mat, "inst": inst, "tv": tv, "comp": comp,
		"wb": wb, "xf": xf}


## A part's triangles in world coordinates (cached).
func _world_tris(p: Dictionary, key := "tv") -> PackedVector3Array:
	var wk := "w_" + key
	if p.has(wk):
		return p[wk]
	var src: PackedVector3Array = p[key]
	if src.is_empty() and p.has("mesh"):
		src = _mesh_tris(p.mesh, p.t)
		p["tv"] = src
		p["comp"] = src
	var xf: Transform3D = p.xf
	var out := PackedVector3Array()
	out.resize(src.size())
	for i in src.size():
		out[i] = xf * src[i]
	p[wk] = out
	return out


## Every triangle of a mesh under `t`, 3 vertices each.
static func _mesh_tris(mesh: Mesh, t: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.size() > 0:
			for i in idx.size():
				out.append(t * verts[idx[i]])
		else:
			for v in verts:
				out.append(t * v)
	return out


## The box round `b` under `t` (corners transformed), as [lo, hi].
static func _box_under(t: Transform3D, b: AABB) -> Array:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in 8:
		var p := t * b.get_endpoint(i)
		lo = lo.min(p)
		hi = hi.max(p)
	return [lo, hi]


## The nearest level of detail's meshes and instances of a monument, as parts.
func _parts_of(id: String) -> Array:
	var out: Array = []
	var node: Node3D = mon._nodes.get(id)
	if node == null:
		return out
	var xf: Transform3D = mon._xf.get(id, Transform3D.IDENTITY)
	# the frame audit.gd and push_out use: yaw and position of the node (routes: identity)
	for ch in node.get_children():
		if ch is MeshInstance3D:
			var mi: MeshInstance3D = ch
			if mi.visibility_range_begin > 0.0 or mi.mesh == null:
				continue   # a farther level of detail
			_mesh_parts(out, xf, mi.transform, mi.mesh)
		elif ch is MultiMeshInstance3D:
			var mmi: MultiMeshInstance3D = ch
			if mmi.visibility_range_begin > 0.0 or mmi.multimesh == null or mmi.multimesh.mesh == null:
				continue
			var mm := mmi.multimesh
			var mb := mm.mesh.get_aabb()
			var mat := mm.mesh.get_instance_id()
			for itv in UrbsMonumentClip.instance_xforms(mmi):
				var it: Transform3D = mmi.transform * (itv as Transform3D)
				var bx := _box_under(it, mb)
				var ip := _part(xf, bx[0], bx[1], mat, true)
				ip["mesh"] = mm.mesh
				ip["t"] = it
				out.append(ip)
	return out


## Connected runs of triangles, one material at a time (vertices welded at 1 cm).
func _mesh_parts(out: Array, xf: Transform3D, local: Transform3D, mesh: Mesh) -> void:
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var nv := idx.size() if idx.size() > 0 else verts.size()
		var ntri := nv / 3
		if ntri == 0:
			continue
		var m: Material = mesh.surface_get_material(s)
		var mat := m.get_instance_id() if m != null else s
		# welding by position: one id per distinct (rounded) vertex
		var vid := PackedInt32Array()
		vid.resize(verts.size())
		var seen := {}
		for v in verts.size():
			var p := verts[v]
			var key := Vector3i(roundi(p.x * QUANT), roundi(p.y * QUANT), roundi(p.z * QUANT))
			var got: Variant = seen.get(key)
			if got == null:
				seen[key] = v
				vid[v] = v
			else:
				vid[v] = int(got)
		var parent := PackedInt32Array()
		parent.resize(verts.size())
		for v in verts.size():
			parent[v] = v
		for t in ntri:
			var a := vid[idx[t * 3] if idx.size() > 0 else t * 3]
			for k in [1, 2]:
				var b := vid[idx[t * 3 + k] if idx.size() > 0 else t * 3 + k]
				var ra := _find(parent, a)
				var rb := _find(parent, b)
				if ra != rb:
					parent[rb] = ra
		var groups := {}   # root -> PackedVector3Array of its triangles (monument frame)
		for t in ntri:
			var r := _find(parent, vid[idx[t * 3] if idx.size() > 0 else t * 3])
			if not groups.has(r):
				groups[r] = PackedVector3Array()
			var g: PackedVector3Array = groups[r]
			for k in 3:
				g.append(local * verts[idx[t * 3 + k] if idx.size() > 0 else t * 3 + k])
			groups[r] = g
		for r in groups:
			_add_component(out, xf, groups[r], mat)


## One connected run as parts: whole when small; cut by CELL squares (each triangle by its
## centre) when it spans more, so a ring (a portico round its court) or an L is not one box
## over everything inside it.
func _add_component(out: Array, xf: Transform3D, g: PackedVector3Array, mat: int) -> void:
	var lo := g[0]
	var hi := g[0]
	for v in g:
		lo = lo.min(v)
		hi = hi.max(v)
	if (hi.x - lo.x <= 2.0 * CELL and hi.z - lo.z <= 2.0 * CELL) or g.size() <= 6:
		out.append(_part(xf, lo, hi, mat, false, g, g))
		return
	var cells := {}
	for i in range(0, g.size(), 3):
		var c := (g[i] + g[i + 1] + g[i + 2]) / 3.0
		var key := Vector2i(floori(c.x / CELL), floori(c.z / CELL))
		if not cells.has(key):
			cells[key] = PackedVector3Array()
		var arr: PackedVector3Array = cells[key]
		arr.append(g[i])
		arr.append(g[i + 1])
		arr.append(g[i + 2])
		cells[key] = arr
	for key in cells:
		var arr: PackedVector3Array = cells[key]
		var l2 := arr[0]
		var h2 := arr[0]
		for v in arr:
			l2 = l2.min(v)
			h2 = h2.max(v)
		out.append(_part(xf, l2, h2, mat, false, arr, g))


static func _find(parent: PackedInt32Array, i: int) -> int:
	var r := i
	while parent[r] != r:
		r = parent[r]
	while parent[i] != r:   # path compression
		var nx := parent[i]
		parent[i] = r
		i = nx
	return r


## The world cells a part's rectangle covers.
static func _cells(p: Dictionary) -> Array:
	var c: Vector2 = p.c
	var ex := absf((p.ax as Vector2).x) * float(p.hx) + absf((p.az as Vector2).x) * float(p.hz)
	var ez := absf((p.ax as Vector2).y) * float(p.hx) + absf((p.az as Vector2).y) * float(p.hz)
	var out: Array = []
	var x0 := floori((c.x - ex) / CELL)
	var x1 := floori((c.x + ex) / CELL)
	var z0 := floori((c.y - ez) / CELL)
	var z1 := floori((c.y + ez) / CELL)
	if (x1 - x0 + 1) * (z1 - z0 + 1) > 250000:
		return out   # a route's whole-city run: checked by its own segments
	var thin := (x1 - x0 + 1) * (z1 - z0 + 1) > 16
	var reach := CELL * 0.71
	for i in range(x0, x1 + 1):
		for j in range(z0, z1 + 1):
			if thin:   # a long part on the diagonal: only the cells its rectangle crosses
				var d := Vector2((i + 0.5) * CELL, (j + 0.5) * CELL) - c
				if absf(d.dot(p.ax)) > float(p.hx) + reach or absf(d.dot(p.az)) > float(p.hz) + reach:
					continue
			out.append(Vector2i(i, j))
	return out


func _index(ids: Array) -> void:
	_grid.clear()
	for id in ids:
		var ps: Array = parts[id]
		for k in ps.size():
			for cell in _cells(ps[k]):
				if not _grid.has(cell):
					_grid[cell] = []
				(_grid[cell] as Array).append([id, k])


## Overlap depth of two oriented rectangles along the axis of least overlap (<= 0: apart).
static func _depth(a: Dictionary, b: Dictionary) -> float:
	var dc: Vector2 = (b.c as Vector2) - (a.c as Vector2)
	var best := INF
	for ax in [a.ax, a.az, b.ax, b.az]:
		var axis: Vector2 = ax
		var ra := absf(axis.dot(a.ax)) * float(a.hx) + absf(axis.dot(a.az)) * float(a.hz)
		var rb := absf(axis.dot(b.ax)) * float(b.hx) + absf(axis.dot(b.az)) * float(b.hz)
		best = minf(best, ra + rb - absf(dc.dot(axis)))
	return best


func _model(id: String) -> String:
	return str(mon._placed.get(id, {}).get("model", ""))


static func _fmt(p: Dictionary) -> String:
	return "%.1fx%.1fx%.1f m at (%.0f, %.0f) y %.1f-%.1f" % [float(p.hx) * 2.0, float(p.y1) - float(p.y0),
		float(p.hz) * 2.0, (p.c as Vector2).x, (p.c as Vector2).y, float(p.y0), float(p.y1)]


# ---------------------------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------------------------


## Parts of one monument through another's: pairs of parts whose boxes overlap by more than
## PART_M and whose surfaces cross above the ground (an edge of one through a face of the
## other), one line per pair of monuments; a monument standing on a paving is not counted
## unless the paving covers its part.
func _part_overlaps(_ids: Array) -> Array:
	var pairs := {}   # "a|b" -> {depth, n, pa, pb, at, seen}
	for cell in _grid:
		var lst: Array = _grid[cell]
		if lst.size() < 2:
			continue
		for i in lst.size():
			var ia: String = lst[i][0]
			for j in range(i + 1, lst.size()):
				var ib: String = lst[j][0]
				if ia == ib:
					continue
				var a := ia
				var b := ib
				var ka: int = lst[i][1]
				var kb: int = lst[j][1]
				if a > b:
					a = ib
					b = ia
					ka = lst[j][1]
					kb = lst[i][1]
				var key := a + "|" + b
				var pk := Vector2i(ka, kb)
				var rec: Dictionary = pairs.get(key, {})
				if not rec.is_empty() and (rec.seen as Dictionary).has(pk):
					continue
				var pa: Dictionary = parts[a][ka]
				var pb: Dictionary = parts[b][kb]
				var ma := _model(a)
				var mb := _model(b)
				if ma in ROUTES and mb in ROUTES:
					continue
				var y0 := maxf(float(pa.y0), float(pb.y0))
				var y1 := minf(float(pa.y1), float(pb.y1))
				if y1 - y0 <= 0.0:
					continue
				if y1 - y0 <= REST_M:
					continue   # one rests on the other (set into it a few centimetres)
				var d := _depth(pa, pb)
				if d <= PART_M:
					continue
				# a paving, or any flat part (a court's floor, a platform's top): what stands on it
				# meets it at its foot
				var pave_a := ma in PAVINGS or float(pa.y1) - float(pa.y0) <= FLAT_M
				var pave_b := mb in PAVINGS or float(pb.y1) - float(pb.y0) <= FLAT_M
				if (pave_a and float(pb.y1) > float(pa.y1) + 0.02) or (pave_b and float(pa.y1) > float(pb.y1) + 0.02):
					continue   # it stands on (or through) the paving: the paving meets its foot
				if rec.is_empty():
					rec = {"depth": 0.0, "n": 0, "pa": pa, "pb": pb, "at": Vector3.ZERO, "seen": {}}
					pairs[key] = rec
				rec.seen[pk] = true
				var hit: Variant = _cross(pa, pb)
				if hit == null:
					continue
				rec.n = int(rec.n) + 1
				var depth := maxf(minf(d, y1 - y0), 0.0)
				if depth >= float(rec.depth):
					rec.depth = depth
					rec.pa = pa
					rec.pb = pb
					rec.at = hit
	var keys: Array = pairs.keys()
	keys.sort()
	var out: Array = []
	for key in keys:
		var r: Dictionary = pairs[key]
		if int(r.n) == 0:
			continue
		var ab: PackedStringArray = (key as String).split("|")
		var at: Vector3 = r.at
		out.append("%s parts through %s: %d, deepest %.2f m, at (%.0f, %.0f) y %.1f (%s / %s)" % [ab[0], ab[1],
			int(r.n), float(r.depth), at.x, at.z, at.y, _fmt(r.pa), _fmt(r.pb)])
	return out


## Where a surface of `pa` crosses one of `pb` above the ground (an edge of a triangle of one
## through a triangle of the other), null if nowhere.
func _cross(pa: Dictionary, pb: Dictionary) -> Variant:
	var box: AABB = (pa.wb as AABB).intersection(pb.wb as AABB).grow(0.01)
	var ta := _near(_world_tris(pa), box)
	if ta.is_empty():
		return null
	var tb := _near(_world_tris(pb), box)
	if tb.is_empty():
		return null
	for pass_ in 2:
		var e: PackedVector3Array = ta if pass_ == 0 else tb
		var f: PackedVector3Array = tb if pass_ == 0 else ta
		for i in range(0, e.size(), 3):
			for k in 3:
				var p0 := e[i + k]
				var p1 := e[i + (k + 1) % 3]
				for j in range(0, f.size(), 3):
					var hit: Variant = Geometry3D.segment_intersects_triangle(p0, p1, f[j], f[j + 1], f[j + 2])
					if hit == null:
						continue
					var h: Vector3 = hit
					# an edge ending on the face (a part standing on another) is touching
					if h.distance_to(p0) < 0.02 or h.distance_to(p1) < 0.02:
						continue
					if h.y <= float(height.call(h.x, h.z)) + 0.05:
						continue   # hidden in the ground
					return h
	return null


## The triangles (3 vertices each) whose box meets `box`.
static func _near(t: PackedVector3Array, box: AABB) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(0, t.size(), 3):
		var lo := t[i].min(t[i + 1]).min(t[i + 2])
		var hi := t[i].max(t[i + 1]).max(t[i + 2])
		if hi.x < box.position.x or lo.x > box.end.x or hi.y < box.position.y or lo.y > box.end.y \
				or hi.z < box.position.z or lo.z > box.end.z:
			continue
		out.append(t[i])
		out.append(t[i + 1])
		out.append(t[i + 2])
	return out


## Parts resting on nothing: those not reached from the ground through touching parts.
func _floating(id: String) -> String:
	var ps: Array = parts.get(id, [])
	if ps.is_empty() or _model(id) in ROUTES:
		return ""
	var n := ps.size()
	# a local grid in the monument's frame
	var grid := {}
	for k in n:
		var p: Dictionary = ps[k]
		var lo: Vector3 = p.lo
		var hi: Vector3 = p.hi
		for i in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			for j in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
				var cell := Vector2i(i, j)
				if not grid.has(cell):
					grid[cell] = []
				(grid[cell] as Array).append(k)
	var held := PackedByteArray()
	held.resize(n)
	var queue: Array = []
	for k in n:
		var p: Dictionary = ps[k]
		var c: Vector2 = p.c
		var g := INF
		# the lowest ground under its rectangle (centre and corners)
		for s in [Vector2.ZERO, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var q: Vector2 = c + (p.ax as Vector2) * float(p.hx) * s.x + (p.az as Vector2) * float(p.hz) * s.y
			g = minf(g, float(height.call(q.x, q.y)))
		if float(p.y0) <= g + GROUND_M:
			held[k] = 1
			queue.append(k)
	while not queue.is_empty():
		var k: int = queue.pop_back()
		var p: Dictionary = ps[k]
		var lo: Vector3 = (p.lo as Vector3) - Vector3.ONE * TOUCH_M
		var hi: Vector3 = (p.hi as Vector3) + Vector3.ONE * TOUCH_M
		for i in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			for j in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
				for q in grid.get(Vector2i(i, j), []):
					if held[q] == 1:
						continue
					var o: Dictionary = ps[q]
					var olo: Vector3 = o.lo
					var ohi: Vector3 = o.hi
					if olo.x <= hi.x and ohi.x >= lo.x and olo.y <= hi.y and ohi.y >= lo.y and olo.z <= hi.z and ohi.z >= lo.z:
						held[q] = 1
						queue.append(q)
	var free := 0
	var worst: Dictionary = {}
	var vol := 0.0
	for k in n:
		if held[k] == 0:
			free += 1
			var p: Dictionary = ps[k]
			var v := float(p.hx) * float(p.hz) * (float(p.y1) - float(p.y0))
			if worst.is_empty() or v > vol:
				worst = p
				vol = v
	if free == 0:
		return ""
	return "%s %d of %d parts rest on nothing, largest %s (its own frame %s to %s)" % [id, free, n, _fmt(worst),
		str((worst.lo as Vector3).snapped(Vector3.ONE * 0.1)), str((worst.hi as Vector3).snapped(Vector3.ONE * 0.1))]


## Columns sunk into what they stand on: the top of the highest part under the column's foot.
func _sunk(id: String) -> String:
	var ps: Array = parts.get(id, [])
	var worst := 0.0
	var count := 0
	var at: Dictionary = {}
	var at_seat: Dictionary = {}
	var seat_part: Dictionary = {}
	for k in ps.size():
		var p: Dictionary = ps[k]
		if not bool(p.inst):
			continue
		var plo: Vector3 = p.lo
		var phi: Vector3 = p.hi
		var foot := Vector2((plo.x + phi.x) * 0.5, (plo.z + phi.z) * 0.5)
		var h := phi.y - plo.y
		var seat := -INF
		for q in ps.size():
			if q == k:
				continue
			var o: Dictionary = ps[q]
			if bool(o.inst):
				continue
			var olo: Vector3 = o.lo
			var ohi: Vector3 = o.hi
			if foot.x < olo.x or foot.x > ohi.x or foot.y < olo.z or foot.y > ohi.z:
				continue
			if olo.y < plo.y and ohi.y <= plo.y + h * 0.5 and ohi.y > seat:
				seat = ohi.y
				seat_part = o
		if seat > -INF and seat - plo.y > SUNK_M:
			count += 1
			if seat - plo.y > worst:
				worst = seat - plo.y
				at = p
				at_seat = seat_part
	if count == 0:
		return ""
	return "%s %d columns sunk into what they stand on, deepest %.2f m (%s, in %s)" % [id, count, worst, _fmt(at), _fmt(at_seat)]


## Faces of two materials in one plane, overlapping (they flicker). Faces of at least
## COPLANAR_MIN_AREA, the nearest level of detail, in world coordinates.
func _coplanar(ids: Array) -> Array:
	var planes := {}   # [normal key, offset key] -> Array of [id, mat, Rect2 in the plane, dir]
	for id in ids:
		var node: Node3D = mon._nodes.get(id)
		if node == null:
			continue
		for ch in node.get_children():
			if not ch is MeshInstance3D:
				continue
			var mi: MeshInstance3D = ch
			if mi.visibility_range_begin > 0.0 or mi.mesh == null:
				continue
			var t: Transform3D = node.transform * mi.transform
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var m: Material = mi.mesh.surface_get_material(s)
				var mat := m.get_instance_id() if m != null else -1 - s
				var nv := idx.size() if idx.size() > 0 else verts.size()
				for i in range(0, nv - 2, 3):
					var a := t * verts[idx[i] if idx.size() > 0 else i]
					var b := t * verts[idx[i + 1] if idx.size() > 0 else i + 1]
					var c := t * verts[idx[i + 2] if idx.size() > 0 else i + 2]
					var nrm := (c - a).cross(b - a)   # the faces are wound clockwise (Godot front faces)
					var area := nrm.length() * 0.5
					if area < COPLANAR_MIN_AREA:
						continue
					nrm = nrm / (area * 2.0)
					# only the axis planes (floors, walls along the frame): most z-fighting is there
					var axis := -1
					if absf(nrm.y) > 0.999:
						axis = 1
					elif absf(nrm.x) > 0.999:
						axis = 0
					elif absf(nrm.z) > 0.999:
						axis = 2
					if axis < 0:
						continue
					var off := a[axis]
					var key := Vector3i(axis, signi(roundi(nrm[axis])), roundi(off * 200.0))
					var u := 0 if axis != 0 else 2
					var v := 2 if axis == 1 else 1
					var lo := Vector2(minf(minf(a[u], b[u]), c[u]), minf(minf(a[v], b[v]), c[v]))
					var hi := Vector2(maxf(maxf(a[u], b[u]), c[u]), maxf(maxf(a[v], b[v]), c[v]))
					if not planes.has(key):
						planes[key] = []
					(planes[key] as Array).append([id, mat, Rect2(lo, hi - lo),
						PackedVector2Array([Vector2(a[u], a[v]), Vector2(b[u], b[v]), Vector2(c[u], c[v])])])
	var found := {}
	for key in planes:
		var lst: Array = planes[key]
		if lst.size() < 2 or lst.size() > 4000:
			continue
		for i in lst.size():
			for j in range(i + 1, lst.size()):
				if lst[i][1] == lst[j][1]:
					continue
				var ra: Rect2 = lst[i][2]
				var rb: Rect2 = lst[j][2]
				var x := ra.intersection(rb)
				if x.size.x < 0.05 or x.size.y < 0.05:
					continue
				var ar := 0.0
				var k0: Vector3i = key
				var back: Array = planes.get(Vector3i(k0.x, -k0.y, k0.z), [])
				for poly in Geometry2D.intersect_polygons(lst[i][3], lst[j][3]):
					# covered by a face turned the other way in the same plane (something set on it,
					# a cornice on a frieze's top): enclosed, never seen
					var cen := Vector2.ZERO
					for q in poly:
						cen += q
					cen /= maxf(poly.size(), 1)
					var covered := false
					for t in back:
						if (t[2] as Rect2).grow(0.01).has_point(cen) and Geometry2D.is_point_in_polygon(cen, t[3]):
							covered = true
							break
					if not covered:
						# or facing into a solid of its own monument (the inside of a closed cella)
						var off0 := k0.z / 200.0
						var p3 := Vector3(off0, cen.y, cen.x) if k0.x == 0 else (Vector3(cen.x, off0, cen.y) if k0.x == 1 else Vector3(cen.x, cen.y, off0))
						p3[k0.x] += 0.03 * float(k0.y)
						if _in_solid(str(lst[i][0]), p3) and _in_solid(str(lst[j][0]), p3):
							covered = true
						# or in the ground (a floor's underside on the earth, a top under it)
						if k0.x == 1 and off0 <= float(height.call(p3.x, p3.z)) + 0.05 and (k0.y < 0 or off0 < float(height.call(p3.x, p3.z)) - 0.05):
							covered = true
					if not covered:
						ar += absf(_area(poly))
				if ar < 0.02:
					continue
				var a: String = lst[i][0]
				var b: String = lst[j][0]
				var pk := (a + "|" + b) if a <= b else (b + "|" + a)
				var k3: Vector3i = key
				var rec: Dictionary = found.get(pk, {"n": 0, "area": 0.0, "at": Vector3.ZERO, "mats": "", "axis": 1})
				rec.n = int(rec.n) + 1
				if ar > float(rec.area):
					rec.area = ar
					rec.mats = "%s/%s" % [_mat_name(lst[i][1]), _mat_name(lst[j][1])]
					var off := k3.z / 200.0
					var cu := x.get_center()
					rec.at = Vector3(off, cu.y, cu.x) if k3.x == 0 else (Vector3(cu.x, off, cu.y) if k3.x == 1 else Vector3(cu.x, cu.y, off))
					rec.axis = k3.x
				found[pk] = rec
	var keys: Array = found.keys()
	keys.sort()
	var out: Array = []
	for pk in keys:
		var r: Dictionary = found[pk]
		var ab: PackedStringArray = (pk as String).split("|")
		var who := ab[0] if ab[0] == ab[1] else "%s and %s" % [ab[0], ab[1]]
		out.append("%s: %d coplanar face pairs, largest %.1f m² (%s, %s) at (%.1f, %.1f) y %.1f" % [who, int(r.n), float(r.area),
			r.mats, ["facing x", "level", "facing z"][int(r.axis)], (r.at as Vector3).x, (r.at as Vector3).z, (r.at as Vector3).y])
	return out


## Whether world point `p` stands inside one of monument `id`'s solids.
func _in_solid(id: String, p: Vector3) -> bool:
	var xf: Transform3D = mon._xf.get(id, Transform3D.IDENTITY)
	var lp := xf.affine_inverse() * p
	for b in mon._solids.get(id, []):
		if (b as AABB).has_point(lp):
			return true
	return false


static func _mat_name(mat: int) -> String:
	return str(UrbsMaterials._library.get(mat, mat))


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## The `--at` street camera of every monument (monument_view.gd): inside a solid or a house, or
## not seeing the front (fewer than 3 of the 5 façade points in sight, or a monument, a house or
## the ground across the line to the door, or standing more than 60° off the front axis).
func _views(ids: Array) -> Array:
	var inside: Array = []
	var misses: Array = []
	var mv := UrbsMonumentView.new(mon, height, fill)
	for id in ids:
		if _model(id) in NO_VIEW or bool(mon._placed.get(id, {}).get("world", false)):
			continue
		var v: Dictionary = mv.pick(id)
		var eye: Vector3 = v.eye
		# inside a solid? (the parts round the eye whose closed run holds it), or a house
		var cell := Vector2i(floori(eye.x / CELL), floori(eye.z / CELL))
		for ref in _grid.get(cell, []):
			var p: Dictionary = parts[ref[0]][ref[1]]
			if not (p.wb as AABB).grow(0.25).has_point(eye):
				continue
			if _holds(p, eye):
				inside.append("%s camera at (%.0f, %.0f) inside %s (%s)" % [id, eye.x, eye.z, ref[0], _fmt(p)])
				break
		if not mv.house_at(eye, 0.2).is_empty():
			inside.append("%s camera at (%.0f, %.0f) inside a house" % [id, eye.x, eye.z])
		if bool(v.open_air):
			continue   # it looks in from the entrance: the front is behind it
		var door: Transform3D = mon.entrance(id)
		var outward := door.basis.z
		outward.y = 0.0
		outward = outward.normalized()
		var target := door.origin
		var to := Vector3(target.x - eye.x, 0, target.z - eye.z)
		var why: Array = []
		if int(v.seen) < 3:
			why.append("sees %d of 5 façade points" % int(v.seen))
		if to.length() > 0.5:
			var off := rad_to_deg(acos(clampf((-to.normalized()).dot(outward), -1.0, 1.0)))
			if off > 60.0:
				why.append("stands %.0f° off the front axis" % off)
		var block := _blocked(eye, target, id)
		if block != "":
			why.append("%s across the line to the door" % block)
		elif not mv.is_clear(eye, target, id):
			why.append("a house or the ground across the line to the door")
		if not why.is_empty():
			misses.append("%s view from (%.0f, %.0f): %s" % [id, eye.x, eye.z, ", ".join(why)])
	return [inside, misses]


## Whether the closed run of triangles a part was cut from holds `p`: an odd number of
## crossings straight up and along x and z (each of the three).
func _holds(part: Dictionary, p: Vector3) -> bool:
	var t := _world_tris(part, "comp")
	for dir in [Vector3(0, 1000, 0), Vector3(1000, 0.0013, 0.0007), Vector3(0.0011, 0.0009, 1000)]:
		var n := 0
		for i in range(0, t.size(), 3):
			if Geometry3D.segment_intersects_triangle(p, p + dir, t[i], t[i + 1], t[i + 2]) != null:
				n += 1
		if n % 2 == 0:
			return false
	return true


## The first other monument a sight line from `a` to `b` passes through ("" if none): its parts
## near the line, triangle by triangle.
func _blocked(a: Vector3, b: Vector3, own: String) -> String:
	var len := a.distance_to(b)
	var steps := maxi(int(len / CELL) * 2, 1)
	var seen := {}
	var end := a.lerp(b, maxf(0.0, 1.0 - 2.0 / maxf(len, 0.01)))   # stop 2 m short of the door
	for s in range(0, steps + 1):
		var p := a.lerp(b, float(s) / float(steps))
		var cell := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		for ref in _grid.get(cell, []):
			var id: String = ref[0]
			if id == own or _model(id) in PAVINGS:
				continue
			var key := "%s:%d" % [id, ref[1]]
			if seen.has(key):
				continue
			seen[key] = true
			var q: Dictionary = parts[id][ref[1]]
			if (q.wb as AABB).intersects_segment(a, end) != null:
				var t := _world_tris(q)
				for i in range(0, t.size(), 3):
					if Geometry3D.segment_intersects_triangle(a, end, t[i], t[i + 1], t[i + 2]) != null:
						return id
	return ""


# ---------------------------------------------------------------------------------------------
# Interiors
# ---------------------------------------------------------------------------------------------


## Stands in for the Urbs scene when an interior is built for the audit (interior.gd asks the
## scene for its monuments and its ground).
class AuditUrbs extends Node3D:
	var monuments: UrbsMonuments
	var ground := Callable()

	func height_at(x: float, z: float) -> float:
		return float(ground.call(x, z))


const RAY_M := 500.0
const ICELL := 4.0


## Every enterable monument standing, entered: {interior_voids, interior_figures, interior_missing}.
##   interior_voids    sight lines from where the visitor stands that meet nothing (the scene
##                     hides the city inside: they show the black background), for a roofed
##                     interior any, under the open sky those below the horizon
##   interior_figures  statues and figures whose body a wall or floor passes through
##   interior_missing  enterable monuments with no interior (entering does nothing)
func interiors(year: int) -> Dictionary:
	var out := {"interior_voids": [], "interior_figures": [], "interior_missing": []}
	var fake := AuditUrbs.new()
	fake.monuments = mon
	fake.ground = height
	var ib := UrbsInterior.new()
	var ids: Array = mon.ids()
	ids.sort()
	for id in ids:
		if not bool(mon.info(id).get("enterable", false)):
			continue
		var node: Node3D = ib.build(fake, id, year)
		if node == null:
			out.interior_missing.append("%s (%s) has no interior" % [id, str(mon.entry(id).get("type", ""))])
			continue
		var tris := PackedVector3Array()
		for nm in ["Body", "Cover", "Ground", "Backdrop", "BackdropGround"]:
			if node.has_node(nm):
				var mi: MeshInstance3D = node.get_node(nm)
				if mi.mesh == null:
					continue
				var xf := node.transform * mi.transform
				for v in mi.mesh.get_faces():
					tris.append(xf * v)
		var grid := _tri_grid(tris)
		var res: Dictionary = node.get("result")
		var open_sky := bool(res.get("open_sky", false))
		var ground_y := node.transform.origin.y - 0.03 if bool(res.get("ground", false)) else -INF
		var spawn: Transform3D = node.call("spawn")
		var eye := spawn.origin
		var escaped: Array = []
		var n := 0
		for pitch in [-10.0, 0.0, 25.0, 60.0]:
			for yaw in range(0, 360, 20):
				if pitch >= 60.0 and yaw % 90 != 0:
					continue
				var dir := Vector3(-sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), -cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
				dir = spawn.basis * Vector3(dir.x, 0, dir.z) + Vector3(0, dir.y, 0)
				n += 1
				var t := _first_hit(tris, grid, eye, dir.normalized())
				if t < INF:
					continue
				if dir.y < 0.0 and ground_y > -INF:
					continue   # the ground plane under it
				if open_sky and dir.y >= 0.0:
					continue   # the sky
				escaped.append("%d/%d" % [yaw, int(pitch)])
		if not escaped.is_empty():
			out.interior_voids.append("%s: %d of %d sight lines from the door meet nothing (yaw/pitch %s)" % [id, escaped.size(), n,
				", ".join(escaped.slice(0, 8))])
		# figures: a wall through the body (the body's box: a third of its height across)
		var bad := 0
		var where := ""
		for spec in res.get("statues", []):
			var h := float(spec["h"])
			# a seated figure sits on its stool or throne: only its upper body is tested
			var seated := str(spec.get("pose", "")) == "seated"
			var c: Vector3 = node.transform * ((spec["foot"] as Vector3) + Vector3(0, h * (0.75 if seated else 0.55), 0))
			var r := h * 0.1
			for ax in [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(0, h * (0.2 if seated else 0.4), 0)]:
				var a3: Vector3 = c - (ax as Vector3)
				var b3: Vector3 = c + (ax as Vector3)
				if _segment_hits(tris, grid, a3, b3):
					bad += 1
					where = "%s %.1f m at (%.0f, %.0f) y %.1f" % [str(spec.get("style", "")), h, c.x, c.z, c.y]
					break
		if bad > 0:
			out.interior_figures.append("%s: %d figures through a wall or floor, e.g. %s" % [id, bad, where])
		node.free()
	fake.free()
	return out


## Triangles (3 vertices each) by the ICELL cubes their boxes cover.
static func _tri_grid(t: PackedVector3Array) -> Dictionary:
	var g := {}
	for i in range(0, t.size(), 3):
		var lo := t[i].min(t[i + 1]).min(t[i + 2])
		var hi := t[i].max(t[i + 1]).max(t[i + 2])
		var a := Vector3i(floori(lo.x / ICELL), floori(lo.y / ICELL), floori(lo.z / ICELL))
		var b := Vector3i(floori(hi.x / ICELL), floori(hi.y / ICELL), floori(hi.z / ICELL))
		if (b.x - a.x + 1) * (b.y - a.y + 1) * (b.z - a.z + 1) > 64:
			if not g.has("big"):
				g["big"] = PackedInt32Array()
			var bg: PackedInt32Array = g["big"]
			bg.append(i)
			g["big"] = bg   # a big triangle (a floor, the sky dome): tested by every ray
			continue
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				for z in range(a.z, b.z + 1):
					var k := Vector3i(x, y, z)
					if not g.has(k):
						g[k] = PackedInt32Array()
					var arr: PackedInt32Array = g[k]
					arr.append(i)
					g[k] = arr
	return g


## The distance to the first triangle along a ray (INF: none within RAY_M).
static func _first_hit(t: PackedVector3Array, g: Dictionary, o: Vector3, d: Vector3) -> float:
	var best := INF
	var seen := {}
	for i in g.get("big", PackedInt32Array()):
		var hb: Variant = Geometry3D.ray_intersects_triangle(o, d, t[i], t[i + 1], t[i + 2])
		if hb != null:
			best = minf(best, o.distance_to(hb))
	var s := 0.0
	while s < RAY_M and s < best:
		var p := o + d * s
		var k := Vector3i(floori(p.x / ICELL), floori(p.y / ICELL), floori(p.z / ICELL))
		if g.has(k) and not seen.has(k):
			seen[k] = true
			for i in g[k]:
				var hit: Variant = Geometry3D.ray_intersects_triangle(o, d, t[i], t[i + 1], t[i + 2])
				if hit != null:
					best = minf(best, o.distance_to(hit))
		s += ICELL * 0.5
	return best


static func _segment_hits(t: PackedVector3Array, g: Dictionary, a: Vector3, b: Vector3) -> bool:
	var len := a.distance_to(b)
	var seen := {}
	for j in g.get("big", PackedInt32Array()):
		if Geometry3D.segment_intersects_triangle(a, b, t[j], t[j + 1], t[j + 2]) != null:
			return true
	var steps := maxi(1, int(len / (ICELL * 0.5)) + 1)
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var k := Vector3i(floori(p.x / ICELL), floori(p.y / ICELL), floori(p.z / ICELL))
		if not g.has(k) or seen.has(k):
			continue
		seen[k] = true
		for j in g[k]:
			if Geometry3D.segment_intersects_triangle(a, b, t[j], t[j + 1], t[j + 2]) != null:
				return true
	return false
