## Urbs (U8): the mesh builder of the monuments. Every face is keyed by a surface NAME from
## UrbsMaterials (materials.gd), so the whole city changes together when the material library
## changes; `finish()` gives one ArrayMesh with one surface per name, each carrying its shared
## material, box-mapped UVs in metres, flat normals and tangents (for normal maps).
##
## Units are METRES, y up, the monument's centre at the origin and its front towards +z.
## Faces turn away from `inside` (a point inside the solid) automatically.
##
## Repeated parts (columns) go through `instance(key, mesh, xform)`: UrbsMonuments turns every
## key into one MultiMeshInstance3D. Collision and picking use `solid(...)` boxes; `open(...)`
## marks the footprint of a court or a plaza that is walked on but never picked.
##
## Use: var mm := UrbsMonumentMesh.new(); mm.box(...); var r := mm.finish()
##   r = {mesh: ArrayMesh, instances: {key: {mesh, xforms: Array[Transform3D]}},
##        solids: [{centre, size}], opens: [{centre, size}], tris: int}
class_name UrbsMonumentMesh
extends RefCounted

var _st := {}                                   ## material name -> SurfaceTool
var _frames: Array[Transform3D] = [Transform3D.IDENTITY]
var _tris := 0
var _instances := {}
var _solids: Array = []
var _opens: Array = []


# --- frames -------------------------------------------------------------------------------------


## Enter a local frame (relative to the current one) until `pop()`.
func push(local: Transform3D) -> void:
	_frames.append(_frames[-1] * local)


func pop() -> void:
	if _frames.size() > 1:
		_frames.pop_back()


## A frame turned `yaw` radians about the vertical and moved to `at_pos`.
static func at(at_pos: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at_pos)


func triangles() -> int:
	return _tris


# --- raw faces ----------------------------------------------------------------------------------


func _tool(mat: String) -> SurfaceTool:
	if not _st.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[mat] = st
	return _st[mat]


## Planar UV in metres by the dominant axis of the normal (so slabs, courses and flutes read
## at the right scale whatever the material's texture).
static func _uv(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z)
	if a.x >= a.z:
		return Vector2(p.z, p.y)
	return Vector2(p.x, p.y)


## One triangle in the current frame, facing away from `inside` when given.
func tri(a: Vector3, b: Vector3, c: Vector3, mat: String, inside := Vector3.INF) -> void:
	var f := _frames[-1]
	var wa := f * a
	var wb := f * b
	var wc := f * c
	var n := (wb - wa).cross(wc - wa)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	if inside != Vector3.INF:
		var centre := f * inside
		if n.dot((wa + wb + wc) / 3.0 - centre) < 0.0:
			n = -n
			var t := wb
			wb = wc
			wc = t
	var st := _tool(mat)
	# Godot's front faces wind clockwise seen from outside
	for p in [wa, wc, wb]:
		st.set_normal(n)
		st.set_uv(_uv(p, n))
		st.add_vertex(p)
	_tris += 1


## A quad a-b-c-d in order round its edge.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, mat: String, inside := Vector3.INF) -> void:
	tri(a, b, c, mat, inside)
	tri(a, c, d, mat, inside)


## A convex polygon (points in order) facing away from `inside`.
func polygon(points: Array, mat: String, inside := Vector3.INF) -> void:
	for i in range(1, points.size() - 1):
		tri(points[0], points[i], points[i + 1], mat, inside)


# --- solids -------------------------------------------------------------------------------------


## A box standing on `foot` (the middle of its base), `size` = (x, y, z), turned `yaw`. Its underside
## is drawn (ceilings, beams and soffits are seen from below).
func box(foot: Vector3, size: Vector3, mat: String, yaw := 0.0, bottom := true) -> void:
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return
	push(at(foot, yaw))
	var h := size / 2.0
	var c := Vector3(0, h.y, 0)
	var p := [Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, size.y, -h.z), Vector3(-h.x, size.y, -h.z),
		Vector3(-h.x, 0, h.z), Vector3(h.x, 0, h.z), Vector3(h.x, size.y, h.z), Vector3(-h.x, size.y, h.z)]
	quad(p[4], p[5], p[6], p[7], mat, c)
	quad(p[0], p[1], p[2], p[3], mat, c)
	quad(p[1], p[5], p[6], p[2], mat, c)
	quad(p[0], p[4], p[7], p[3], mat, c)
	quad(p[3], p[2], p[6], p[7], mat, c)
	if bottom:
		quad(p[0], p[1], p[5], p[4], mat, c)
	pop()


## A box from corner extents x0..x1, y0..y1, z0..z1.
func ext(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, mat: String, bottom := true) -> void:
	box(Vector3((x0 + x1) * 0.5, minf(y0, y1), (z0 + z1) * 0.5), Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)), mat, 0.0, bottom)


## Four walls of thickness t round a rectangle of half-sizes hx, hz centred on (cx, cz).
func ring(cx: float, cz: float, hx: float, hz: float, t: float, y0: float, y1: float, mat: String) -> void:
	ext(cx - hx, y0, cz + hz - t, cx + hx, y1, cz + hz, mat)
	ext(cx - hx, y0, cz - hz, cx + hx, y1, cz - hz + t, mat)
	ext(cx - hx, y0, cz - hz + t, cx - hx + t, y1, cz + hz - t, mat)
	ext(cx + hx - t, y0, cz - hz + t, cx + hx, y1, cz + hz - t, mat)


## An upright cone frustum on `foot`: radius r0 at the base, r1 at the top.
func frustum(foot: Vector3, r0: float, r1: float, height: float, mat: String, sides := 12, cap := true, bottom := false) -> void:
	push(at(foot))
	var c := Vector3(0, height * 0.5, 0)
	for k in sides:
		var a0 := k * TAU / sides
		var a1 := (k + 1) * TAU / sides
		var b0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var t0 := Vector3(cos(a0) * r1, height, sin(a0) * r1)
		var t1 := Vector3(cos(a1) * r1, height, sin(a1) * r1)
		if r1 > 0.0001:
			quad(b0, b1, t1, t0, mat, c)
			if cap:
				tri(Vector3(0, height, 0), t0, t1, mat, c)
		else:
			tri(b0, b1, t0, mat, c)
		if bottom and r0 > 0.0001:
			tri(Vector3.ZERO, b1, b0, mat, c)
	pop()


func cylinder(foot: Vector3, r: float, height: float, mat: String, sides := 12, cap := true) -> void:
	frustum(foot, r, r, height, mat, sides, cap)


## A surface of revolution about the vertical through `foot`: `profile` is a list of (radius,
## height) pairs from the bottom up. The ends are closed when `caps` is true. Mouldings
## (torus, scotia, cavetto, cyma) are drawn this way.
func lathe(foot: Vector3, profile: PackedVector2Array, mat: String, sides := 12, caps := true) -> void:
	if profile.size() < 2:
		return
	push(at(foot))
	var hmax := 0.0
	for p in profile:
		hmax = maxf(hmax, p.y)
	var c := Vector3(0, hmax * 0.5, 0)
	for i in range(1, profile.size()):
		var p0 := profile[i - 1]
		var p1 := profile[i]
		for k in sides:
			var a0 := k * TAU / sides
			var a1 := (k + 1) * TAU / sides
			var b0 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var b1 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var t0 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var t1 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			var out := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
			var mid := (b0 + b1 + t0 + t1) * 0.25
			# the face turns outward from the axis: use a point on the axis at its height
			var axis_pt := Vector3(0, mid.y, 0)
			if p0.x < 0.0005 and p1.x < 0.0005:
				continue
			elif p1.x < 0.0005:
				tri(b0, b1, t0, mat, axis_pt - out)
			elif p0.x < 0.0005:
				tri(b0, t1, t0, mat, axis_pt - out)
			else:
				quad(b0, b1, t1, t0, mat, axis_pt - out)
	if caps:
		var top := profile[profile.size() - 1]
		if top.x > 0.0005:
			for k in sides:
				var a0 := k * TAU / sides
				var a1 := (k + 1) * TAU / sides
				tri(Vector3(0, top.y, 0), Vector3(cos(a0) * top.x, top.y, sin(a0) * top.x), Vector3(cos(a1) * top.x, top.y, sin(a1) * top.x), mat, c)
	pop()


## A cylinder lying along z, centred on `c` (volutes, rams).
func disc_z(c: Vector3, r: float, len: float, mat: String, sides := 10) -> void:
	push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), c + Vector3(0, 0, -len * 0.5)))
	frustum(Vector3.ZERO, r, r, len, mat, sides, true, true)
	pop()


## A cylinder lying along x, centred on `c`.
func tube_x(c: Vector3, r: float, len: float, mat: String, sides := 10) -> void:
	push(Transform3D(Basis(Vector3(0, 0, 1), -PI / 2.0), c + Vector3(-len * 0.5, 0, 0)))
	frustum(Vector3.ZERO, r, r, len, mat, sides, true, true)
	pop()


## A triangular prism along x on `foot` (a gable end, a buttress), ridge at height h.
func wedge(foot: Vector3, length: float, depth: float, h: float, mat: String, yaw := 0.0) -> void:
	push(at(foot, yaw))
	var c := Vector3(0, h * 0.3, 0)
	var l := length / 2.0
	var d := depth / 2.0
	quad(Vector3(-l, 0, -d), Vector3(l, 0, -d), Vector3(l, h, 0), Vector3(-l, h, 0), mat, c)
	quad(Vector3(-l, 0, d), Vector3(l, 0, d), Vector3(l, h, 0), Vector3(-l, h, 0), mat, c)
	tri(Vector3(-l, 0, -d), Vector3(-l, 0, d), Vector3(-l, h, 0), mat, c)
	tri(Vector3(l, 0, -d), Vector3(l, 0, d), Vector3(l, h, 0), mat, c)
	pop()


## A tilted slab: `p` = four corners of the top surface, `thick` hanging below it.
func slab(p: Array, thick: float, mat: String, under_mat := "") -> void:
	var dn := Vector3(0, -thick, 0)
	var c: Vector3 = (p[0] + p[1] + p[2] + p[3]) / 4.0 + dn * 0.5
	quad(p[0], p[1], p[2], p[3], mat, c)
	var q: Array = [p[0] + dn, p[1] + dn, p[2] + dn, p[3] + dn]
	quad(q[0], q[1], q[2], q[3], under_mat if under_mat != "" else mat, c)
	for i in 4:
		var j := (i + 1) % 4
		quad(p[i], p[j], q[j], q[i], mat, c)


## A thin square rod from a to b (railings, poles, beams at an angle).
func rod(a: Vector3, b: Vector3, r: float, mat: String) -> void:
	var d := b - a
	if d.length() < 1e-5:
		return
	var axis := d.normalized()
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.01:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized() * r
	var up := side.cross(axis).normalized() * r
	var c := (a + b) / 2.0
	var ringp := [side + up, -side + up, -side - up, side - up]
	for i in 4:
		var j := (i + 1) % 4
		quad(a + ringp[i], b + ringp[i], b + ringp[j], a + ringp[j], mat, c)


## An opening in a wall plane (front +z) between x0 and x1, springing at ys, wall above to yt,
## thickness z0..z1: the arch's intrados and the spandrel wall faces. Piers are separate.
func arch(x0: float, x1: float, ys: float, yt: float, z0: float, z1: float, mat: String, segs := 8,
		front := true, back := true, ratio := 1.0, intrados_mat := "") -> void:
	var rx := (x1 - x0) * 0.5
	var ry := rx * ratio
	var xc := (x0 + x1) * 0.5
	var zm := (z0 + z1) * 0.5
	var o := Vector3(xc, ys + ry * 0.4, zm)
	var imat := intrados_mat if intrados_mat != "" else mat
	for i in segs:
		var a0 := PI * i / segs
		var a1 := PI * (i + 1) / segs
		var p0x := xc + rx * cos(a0)
		var p1x := xc + rx * cos(a1)
		var p0y := ys + ry * sin(a0)
		var p1y := ys + ry * sin(a1)
		if front and yt > maxf(p0y, p1y) + 0.001:
			quad(Vector3(p0x, p0y, z1), Vector3(p1x, p1y, z1), Vector3(p1x, yt, z1), Vector3(p0x, yt, z1), mat, Vector3((p0x + p1x) / 2, yt, zm))
		if back and yt > maxf(p0y, p1y) + 0.001:
			quad(Vector3(p0x, p0y, z0), Vector3(p1x, p1y, z0), Vector3(p1x, yt, z0), Vector3(p0x, yt, z0), mat, Vector3((p0x + p1x) / 2, yt, zm))
		var cen := Vector3((p0x + p1x) / 2, (p0y + p1y) / 2, zm)
		quad(Vector3(p0x, p0y, z0), Vector3(p1x, p1y, z0), Vector3(p1x, p1y, z1), Vector3(p0x, p0y, z1), imat, cen + (cen - o))


## A flight of steps across the front (+z) of a platform `top` high, the lowest step at
## z_edge + n * tread, rising to the platform at z_edge. Risers between 0.23 and 0.25 m and
## treads 0.45 to 0.6 m, an odd number of steps (Vitruvius 3.4.4: risers not more than ten
## nor less than nine inches, treads not less than a foot and a half nor more than two feet,
## always an odd number). Returns the depth the flight takes.
func stair(cx: float, w: float, z_edge: float, top: float, mat: String, tread := 0.5, riser_target := 0.24, n_override := 0) -> float:
	var n := n_override if n_override > 0 else maxi(1, int(round(top / riser_target)))
	if n_override <= 0 and n % 2 == 0:
		n += 1
	var riser := top / n
	for j in n:
		var y1 := (j + 1) * riser
		# step j (from the bottom) reaches from the platform edge out to (n - j) treads
		ext(cx - w / 2, 0.0, z_edge, cx + w / 2, y1, z_edge + (n - j) * tread, mat)
	return n * tread


# --- instancing and collision -------------------------------------------------------------------


## A repeated part: `mesh` placed at `xform` (in the current frame), batched by `key` into one
## MultiMesh by UrbsMonuments. The mesh is built in metres with its own materials.
func instance(key: String, mesh: ArrayMesh, xform: Transform3D) -> void:
	if not _instances.has(key):
		_instances[key] = {"mesh": mesh, "xforms": []}
	(_instances[key].xforms as Array).append(_frames[-1] * xform)


## A solid box (collision and picking) in the current frame: `foot` = the middle of its base.
func solid(foot: Vector3, size: Vector3) -> void:
	var f := _frames[-1]
	_solids.append({"centre": f * (foot + Vector3(0, size.y * 0.5, 0)), "size": size})


## An open footprint (a court, a plaza): walked on, never picked.
func open(foot: Vector3, size: Vector3) -> void:
	var f := _frames[-1]
	_opens.append({"centre": f * (foot + Vector3(0, size.y * 0.5, 0)), "size": size})


# --- output -------------------------------------------------------------------------------------


## The mesh with one surface per material, plus the instanced parts and the collision boxes.
func finish() -> Dictionary:
	var mesh := ArrayMesh.new()
	var names: Array = _st.keys()
	names.sort()
	for name in names:
		var st: SurfaceTool = _st[name]
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, UrbsMaterials.get_material(name))
	return {"mesh": mesh, "instances": _instances, "solids": _solids, "opens": _opens, "tris": _tris}


## Only the mesh (for cached parts such as a column).
func finish_mesh() -> ArrayMesh:
	return finish().mesh
