## Urbs F3 (monuments): what the street camera's frame shows. A grid of sight lines through the
## frame (16 x 9 by default, the camera's 70-degree height and 16:9 width) is cast against
## everything drawn round the monument: its own meshes and its neighbours' (their nearest level of
## detail, their columns too), the houses (their lots as boxes), the trees (their crowns) and the
## ground. From what each line meets first:
##   near    the share of the frame filled by something other than the monument within NEAR_M
##           (a wall, a podium, a house or a tree in the camera's face; the floor below the
##           horizon does not count)
##   bank    the share of the frame's upper half (above the horizon) that is ground: a bank or
##           a hillside in front
##   fill    the share of the frame the monument fills (a far line, or nothing in view)
##   facade  the share of points spread over the monument's front that are seen
## `faults(score)` turns these into the reasons a view fails ([] when it passes).
## Use: var fr := UrbsMonumentFrame.new(view); fr.prepare(centre, radius); fr.score(...)
class_name UrbsMonumentFrame
extends RefCounted

const VFOV := 70.0           ## UrbsCamera.FOV_STREET (vertical)
const ASPECT := 16.0 / 9.0
const NEAR_M := 6.0
const CELL := 4.0
const NEAR_MAX := 0.25       ## more of the frame than this filled by something within NEAR_M fails
const BANK_MAX := 0.45       ## more of the upper half than this ground fails
const FILL_MIN := 0.04       ## less of the frame than this the monument fails (FILL_THIN for a column)
const FILL_THIN := 0.02
const FACADE_MIN := 0.6      ## fewer of the front's points than this seen fails
const PAVINGS := ["plaza", "road_paved", "lacus_curtius", "comitium"]

var view: UrbsMonumentView
var mons: UrbsMonuments
var _v := PackedVector3Array()        # triangle corners, 3 each
var _who := PackedStringArray()       # per triangle: the monument
var _pave := PackedByteArray()        # per triangle: 1 for a paving (walked on: it reads as ground)
var _grid := {}                       # Vector2i cell -> PackedInt32Array of triangle indices
var _at := Vector2(INF, INF)
var _r := 0.0


func _init(v: UrbsMonumentView) -> void:
	view = v
	mons = v.mons


## Gather what is drawn within `r` of `c` (the monuments' triangles, binned by CELL on the plan).
func prepare(c: Vector2, r: float) -> void:
	if c.distance_to(_at) < 1.0 and r <= _r:
		return
	_at = c
	_r = r
	_v = PackedVector3Array()
	_who = PackedStringArray()
	_pave = PackedByteArray()
	_grid = {}
	var area := Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0)
	for mid in mons._nodes:
		var node: Node3D = mons._nodes[mid]
		var paving := str(mons._placed.get(mid, {}).get("model", "")) in PAVINGS
		for ch in node.get_children():
			var meshes: Array = []
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
				var bx: AABB = xf * mesh.get_aabb()
				if not Rect2(bx.position.x, bx.position.z, bx.size.x, bx.size.z).grow(0.1).intersects(area):
					continue
				var f := mesh.get_faces()
				for i in range(0, f.size(), 3):
					var a: Vector3 = xf * f[i]
					var b: Vector3 = xf * f[i + 1]
					var d: Vector3 = xf * f[i + 2]
					var lo := a.min(b).min(d)
					var hi := a.max(b).max(d)
					if hi.x < area.position.x or lo.x > area.end.x or hi.z < area.position.y or lo.z > area.end.y:
						continue
					var k := _who.size()
					_v.append(a)
					_v.append(b)
					_v.append(d)
					_who.append(str(mid))
					_pave.append(1 if paving else 0)
					for gx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
						for gz in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
							var key := Vector2i(gx, gz)
							if not _grid.has(key):
								_grid[key] = PackedInt32Array()
							var arr: PackedInt32Array = _grid[key]
							arr.append(k)
							_grid[key] = arr


## The first thing the line from `o` along unit `d` meets within `maxd`: [distance, kind, id];
## kind "mon" (id: the monument), "ground" (the ground, or a paving: id its monument), "house",
## "tree" or "".
func cast(o: Vector3, d: Vector3, maxd: float) -> Array:
	var best := maxd
	var kind := ""
	var who := ""
	# the monuments' triangles, cell by cell along the line's plan
	var flat := Vector2(d.x, d.z)
	var fl := flat.length()
	var seen := {}
	var step := CELL * 0.5
	var s := 0.0
	while true:
		var p := o + d * (s / fl if fl > 0.001 else 0.0)
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		for dk in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var kk: Vector2i = key + dk
			if seen.has(kk) or not _grid.has(kk):
				continue
			seen[kk] = true
			for i: int in _grid[kk]:
				var hit: Variant = Geometry3D.ray_intersects_triangle(o, d, _v[i * 3], _v[i * 3 + 1], _v[i * 3 + 2])
				if hit != null:
					var t := o.distance_to(hit)
					if t < best:
						best = t
						who = _who[i]
						kind = "ground" if _pave[i] == 1 else "mon"
		if fl <= 0.001 or s / fl > best or s / fl > maxd:
			break
		s += step
	# the houses (their lots as boxes) and the trees (their crowns)
	for lot in view._lots:
		var t := _lot_hit(o, d, lot)
		if t < best:
			best = t
			kind = "house"
			who = ""
	for tr in view._trees:
		var oc: Vector3 = o - (tr.c as Vector3)
		var b := oc.dot(d)
		var c := oc.length_squared() - float(tr.r) * float(tr.r)
		var disc := b * b - c
		if disc >= 0.0:
			var t := -b - sqrt(disc)
			if t > 0.0 and t < best:
				best = t
				kind = "tree"
				who = ""
	# the ground, marched (finer near the eye)
	var g := 0.3
	while g < best:
		var q := o + d * g
		if q.y < view._ground(q.x, q.z):
			best = g
			kind = "ground"
			who = ""
			break
		g += maxf(0.3, g * 0.04)
	return [best, kind, who]


## Where the line meets a house lot (an upright box on the plan), INF if it does not.
static func _lot_hit(o: Vector3, d: Vector3, lot: Dictionary) -> float:
	var c: Vector2 = lot.c
	var ax: Vector2 = lot.ax
	var az: Vector2 = lot.az
	var ro := Vector2(o.x, o.z) - c
	var rd := Vector2(d.x, d.z)
	var t0 := 0.0
	var t1 := INF
	for k in 3:
		var org: float
		var dir: float
		var lo: float
		var hi: float
		if k == 0:
			org = ro.dot(ax)
			dir = rd.dot(ax)
			lo = -float(lot.hx)
			hi = float(lot.hx)
		elif k == 1:
			org = ro.dot(az)
			dir = rd.dot(az)
			lo = -float(lot.hz)
			hi = float(lot.hz)
		else:
			org = o.y
			dir = d.y
			lo = float(lot.y0)
			hi = float(lot.y1)
		if absf(dir) < 1e-6:
			if org < lo or org > hi:
				return INF
			continue
		var ta := (lo - org) / dir
		var tb := (hi - org) / dir
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 > t1:
			return INF
	return t0 if t0 > 0.0 else INF


## The frame from `eye` turned `yaw` (the camera's: it looks along -sin, -cos) and tilted
## `pitch_deg` (up +), for monument `id` whose front points are `facade`:
## {near, bank, fill, facade, rays}.
func score(id: String, eye: Vector3, yaw: float, pitch_deg: float, facade: Array, cols := 16, rows := 9) -> Dictionary:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(pitch_deg))
	var ty := tan(deg_to_rad(VFOV * 0.5))
	var tx := ty * ASPECT
	var maxd := 400.0
	var n := 0
	var near := 0
	var upper := 0
	var bank := 0
	var mine := 0
	for j in rows:
		for i in cols:
			var u := ((i + 0.5) / cols) * 2.0 - 1.0
			var w := 1.0 - ((j + 0.5) / rows) * 2.0
			var d := (basis * Vector3(u * tx, w * ty, -1.0)).normalized()
			var hit := cast(eye, d, maxd)
			n += 1
			var t := float(hit[0])
			var kind := str(hit[1])
			var who := str(hit[2])
			if who == id:
				mine += 1
			elif kind != "" and t < NEAR_M and not (kind == "ground" and d.y < 0.0):
				near += 1
			if d.y > 0.0:
				upper += 1
				if kind == "ground":
					bank += 1
	var seen := 0
	for p: Vector3 in facade:
		var to := p - eye
		var dist := to.length()
		if dist < 0.5:
			seen += 1
			continue
		var hit := cast(eye, to / dist, dist + 1.0)
		if str(hit[2]) == id or float(hit[0]) >= dist - 1.0:
			seen += 1
	return {"near": float(near) / n, "bank": float(bank) / maxi(upper, 1), "fill": float(mine) / n,
		"facade": float(seen) / facade.size() if not facade.is_empty() else 1.0, "rays": n}


## Points spread over a front ([face at the ground, base y, top y, width, outward]): 5 across at
## a fifth, a half and four fifths of its height, half a metre out from the face.
static func facade_points(front: Array) -> Array:
	var face: Vector3 = front[0]
	var out: Vector3 = front[4] if front.size() > 4 else Vector3.ZERO
	var right := Vector3(out.z, 0, -out.x)
	var pts: Array = []
	for fy in [0.2, 0.5, 0.8]:
		for fx in [-0.4, -0.2, 0.0, 0.2, 0.4]:
			pts.append(face + out * 0.5 + right * float(front[3]) * fx + Vector3(0, float(front[1]) + (float(front[2]) - float(front[1])) * fy, 0))
	return pts


## The reasons a frame `sc` fails ([] when it passes); `thin` for a column or a statue.
static func faults(sc: Dictionary, thin := false) -> Array:
	var out: Array = []
	if float(sc.near) > NEAR_MAX:
		out.append("%.0f%% of the frame within %.0f m (not the monument)" % [float(sc.near) * 100.0, NEAR_M])
	if float(sc.bank) > BANK_MAX:
		out.append("%.0f%% of the sky half is ground or bank" % [float(sc.bank) * 100.0])
	if float(sc.fill) < (FILL_THIN if thin else FILL_MIN):
		out.append("the monument fills %.0f%% of the frame" % [float(sc.fill) * 100.0])
	if float(sc.facade) < FACADE_MIN:
		out.append("%.0f%% of its front seen" % [float(sc.facade) * 100.0])
	return out


## How good a frame is for the picker (higher is better): the monument big and its front seen,
## little in the camera's face, no bank before it.
static func merit(sc: Dictionary, thin := false) -> float:
	var m := minf(float(sc.fill), 0.45) * 2.0 + float(sc.facade) - float(sc.near) * 2.0 - float(sc.bank)
	return m - 2.0 * faults(sc, thin).size()
