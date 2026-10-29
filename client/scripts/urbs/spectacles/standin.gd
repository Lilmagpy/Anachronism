## Simple stand-in geometry for the spectacle previews (U6): ground, circus track and tiers,
## arena, curia hall, temple front with altar, a street with house blocks. The real monuments
## and interiors replace these; the spectacles only need the numbers (track size, arena radii,
## bench positions, altar position, street polyline).
extends RefCounted

const F := preload("res://scripts/urbs/spectacles/figure.gd")
const Crowd := preload("res://scripts/urbs/crowd.gd")


static func ground(parent: Node3D, size: float, col := Color(0.52, 0.5, 0.4)) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	m.mesh = pm
	m.material_override = F.mat(col)
	m.position.y = -0.05
	parent.add_child(m)
	return m


## A strip of treads and risers along a path function: `pts` is the array of (x, y, z) for
## the front edge, going round; each row k is offset by `out` metres outward from `centre`.
static func tier_mesh(parent: Node3D, rows: Array, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rows:
		var a: PackedVector3Array = row[0]   # front edge of the tread
		var b: PackedVector3Array = row[1]   # back edge
		var y0: float = row[2]
		for i in range(a.size() - 1):
			var q := [a[i], b[i], b[i + 1], a[i + 1]]
			st.add_vertex(q[0])
			st.add_vertex(q[1])
			st.add_vertex(q[2])
			st.add_vertex(q[0])
			st.add_vertex(q[2])
			st.add_vertex(q[3])
			# riser, down to the previous level
			var d0: Vector3 = a[i] - Vector3(0, a[i].y - y0, 0)
			var d1: Vector3 = a[i + 1] - Vector3(0, a[i + 1].y - y0, 0)
			st.add_vertex(d0)
			st.add_vertex(a[i])
			st.add_vertex(a[i + 1])
			st.add_vertex(d0)
			st.add_vertex(a[i + 1])
			st.add_vertex(d1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	mi.material_override = m
	parent.add_child(mi)


## A circus: sand track, spina with metae and statues, tiers round, the carceres block.
static func circus(parent: Node3D, length: float, width: float, rows := 14) -> void:
	var Ls := length / 2.0 - width / 2.0
	var sand := F.box(parent, Vector3(length, 0.1, width), Vector3(0, -0.06, 0), Color(0.82, 0.72, 0.5))
	sand.name = "track"
	F.box(parent, Vector3(2.0 * Ls, 1.0, 5.0), Vector3(0, 0.45, 0), Color(0.7, 0.66, 0.58))
	for sx in [-1.0, 1.0]:
		for k in 3:
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.2
			cm.bottom_radius = 1.0
			cm.height = 4.5
			cm.radial_segments = 8
			cone.mesh = cm
			cone.material_override = F.mat(Color(0.8, 0.74, 0.55))
			cone.position = Vector3(sx * (Ls + 1.5), 2.5, (k - 1) * 2.2)
			parent.add_child(cone)
	for k in 9:
		F.box(parent, Vector3(1.6, 3.0, 1.6), Vector3(-Ls * 0.8 + k * Ls * 0.2, 2.2, 0), Color(0.85, 0.82, 0.76))
	var rr: Array = []
	var r0 := width / 2.0 + 1.0
	for k in rows:
		var r := r0 + k * 0.9
		var y := k * 0.55
		var a := PackedVector3Array()
		var b := PackedVector3Array()
		var n := 160
		var straight := 2.0 * Ls
		var turn := PI * r
		var total := 2.0 * straight + 2.0 * turn
		for i in n + 1:
			var d := total * float(i) / n
			var p := Crowd._stadium_point(Ls, r, d)
			var q := Crowd._stadium_point(Ls, r + 0.9, d * (2.0 * straight + 2.0 * PI * (r + 0.9)) / total)
			if p.x < -Ls - 1.0 and not (i == 0 or i == n):
				p.x = -Ls - 1.0
			a.append(Vector3(p.x, y, p.z))
			b.append(Vector3(q.x, y, q.z))
		rr.append([a, b, y - 0.55])
	tier_mesh(parent, rr, Color(0.72, 0.68, 0.6))
	# carceres block at the west end
	F.box(parent, Vector3(12.0, 5.0, width + 10.0), Vector3(-Ls - 16.0, 2.5, 0), Color(0.68, 0.6, 0.5))
	# a pulvinar on the north side
	F.box(parent, Vector3(10.0, 1.5, 4.0), Vector3(0, 8.0, -width / 2.0 - 10.0), Color(0.55, 0.2, 0.2))


static func arena(parent: Node3D, rx: float, rz: float, rows := 8) -> void:
	var floor_m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.1
	cm.radial_segments = 48
	floor_m.mesh = cm
	floor_m.scale = Vector3(rx, 1.0, rz)
	floor_m.position.y = -0.06
	floor_m.material_override = F.mat(Color(0.84, 0.74, 0.52))
	parent.add_child(floor_m)
	var rr: Array = []
	for k in rows:
		var a := PackedVector3Array()
		var b := PackedVector3Array()
		var ra := rx + k * 0.9
		var rb := rz + k * 0.9
		for i in 97:
			var t := TAU * float(i) / 96.0
			a.append(Vector3(cos(t) * ra, k * 0.5, sin(t) * rb))
			b.append(Vector3(cos(t) * (ra + 0.9), k * 0.5, sin(t) * (rb + 0.9)))
		rr.append([a, b, k * 0.5 - 0.5])
	tier_mesh(parent, rr, Color(0.72, 0.68, 0.6))
	# the editor's box
	F.box(parent, Vector3(5.0, 0.5, 3.0), Vector3(0, 1.0, rz + 1.6), Color(0.55, 0.2, 0.2))


## The hall of the Curia: a floor, three-tier benches along both long walls, the tribunal.
## Returns nothing; seat positions come from `curia_benches`.
static func curia(parent: Node3D, hall: Vector2) -> void:
	F.box(parent, Vector3(hall.x, 0.2, hall.y), Vector3(0, -0.1, 0), Color(0.78, 0.74, 0.66))
	for sx in [-1.0, 1.0]:
		for k in 3:
			var w := 1.2
			F.box(parent, Vector3(w, 0.35 + 0.35 * k, hall.y - 8.0), Vector3(sx * (hall.x / 2.0 - w / 2.0 - k * w), (0.35 + 0.35 * k) / 2.0, 1.5), Color(0.62, 0.55, 0.45))
	F.box(parent, Vector3(hall.x - 3.0, 0.9, 4.0), Vector3(0, 0.45, -hall.y / 2.0 + 2.5), Color(0.55, 0.45, 0.35))
	# walls
	F.box(parent, Vector3(0.6, 12.0, hall.y), Vector3(-hall.x / 2.0 - 0.3, 6.0, 0), Color(0.88, 0.8, 0.68))
	F.box(parent, Vector3(0.6, 12.0, hall.y), Vector3(hall.x / 2.0 + 0.3, 6.0, 0), Color(0.88, 0.8, 0.68))
	F.box(parent, Vector3(hall.x + 1.2, 12.0, 0.6), Vector3(0, 6.0, -hall.y / 2.0 - 0.3), Color(0.88, 0.8, 0.68))


## Bench seat positions for the Curia: three tiers per side, `per_row` seats, nearest the tribunal first.
static func curia_benches(hall: Vector2, per_row := 12) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var spacing := (hall.y - 10.0) / float(per_row)
	for i in per_row:
		for k in 3:
			for sx in [-1.0, 1.0]:
				var x: float = sx * (hall.x / 2.0 - 0.6 - k * 1.2)
				out.append(Vector3(x, 0.35 + 0.35 * k, -hall.y / 2.0 + 7.0 + i * spacing))
	return out


## A temple front with steps and columns at z = -12 facing +z, an altar at the origin.
static func temple(parent: Node3D) -> void:
	F.box(parent, Vector3(30.0, 3.0, 20.0), Vector3(0, 1.5, -22.0), Color(0.8, 0.76, 0.68))
	for i in 6:
		F.box(parent, Vector3(2.0, 9.0, 2.0), Vector3(-10.0 + i * 4.0, 7.5, -13.0), Color(0.9, 0.86, 0.78))
	F.box(parent, Vector3(28.0, 2.5, 6.0), Vector3(0, 13.2, -14.0), Color(0.75, 0.4, 0.3))
	F.box(parent, Vector3(24.0, 14.0, 12.0), Vector3(0, 10.0, -26.0), Color(0.88, 0.82, 0.7))
	F.box(parent, Vector3(2.6, 1.3, 1.6), Vector3(0, 0.65, 0), Color(0.82, 0.8, 0.74))   # altar
	F.box(parent, Vector3(3.0, 0.2, 2.0), Vector3(0, 0.1, 0), Color(0.7, 0.68, 0.62))


## A street along a polyline with blocks of houses on both sides.
static func street(parent: Node3D, poly: PackedVector3Array, half_width := 5.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(poly.size() - 1):
		var d := (poly[i + 1] - poly[i])
		d.y = 0
		d = d.normalized()
		var side := Vector3(-d.z, 0, d.x) * half_width
		var a := poly[i]
		var b := poly[i + 1]
		for p in [a - side, a + side, b + side, a - side, b + side, b - side]:
			st.add_vertex(p + Vector3(0, 0.02, 0))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.58, 0.5)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	parent.add_child(mi)
	for i in range(poly.size() - 1):
		var d := (poly[i + 1] - poly[i])
		var len_ := d.length()
		d.y = 0
		d = d.normalized()
		var side := Vector3(-d.z, 0, d.x)
		var n := int(len_ / 10.0)
		for j in n:
			for sgn in [-1.0, 1.0]:
				var p: Vector3 = poly[i].lerp(poly[i + 1], (j + 0.5) / n) + side * sgn * (half_width + 10.0)
				var h := rng.randf_range(7.0, 14.0)
				var bx := F.box(parent, Vector3(9.0, h, 8.0), p + Vector3(0, h / 2.0, 0), Color(0.78, 0.6, 0.45).lerp(Color(0.85, 0.8, 0.7), rng.randf()))
				bx.rotation.y = atan2(d.x, d.z)
