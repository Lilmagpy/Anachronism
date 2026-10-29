## A racing chariot (U6): the car (curved bronze-trimmed dashboard, spoked iron-tyred wheels,
## the charioteer in his faction's tunic with a leather cap, reins wrapped round his waist and
## a knife at his belt) and the team (a pole, a yoke and two or four harnessed horses abreast)
## as two separate nodes, so that in a crash the car can tumble while the horses run on.
## Both face +Z. The reins are a ribbon redrawn by update_reins() once both are placed.
extends RefCounted

const F := preload("res://scripts/urbs/spectacles/figure.gd")
const M := preload("res://scripts/urbs/spectacles/meshlib.gd")
const A := preload("res://scripts/urbs/spectacles/animals.gd")
const POLE := 3.6
const SPACING := 0.8

var car: Node3D
var team: Node3D
var driver: Node3D
var wheels: Array[Node3D] = []
var horses: Array[Node3D] = []
var colour := Color.WHITE
var reins: MeshInstance3D
var _rein_mesh := ImmediateMesh.new()
var _hands := [Vector3(-0.13, 1.1, 0.32), Vector3(0.13, 1.1, 0.32)]
var driver_visible_reins := true


static func make(team_colour: Color, n_horses: int, coat_seed: int, white_team := false) -> RefCounted:
	var c = (load("res://scripts/urbs/spectacles/chariot.gd") as GDScript).new()
	c.colour = team_colour
	c.car = Node3D.new()
	c._build_car(team_colour)
	c.team = Node3D.new()
	c._build_team(team_colour, n_horses, coat_seed, white_team)
	return c


func _build_car(col: Color) -> void:
	var wood := Color(0.5, 0.36, 0.2)
	var bronze := Color(0.78, 0.6, 0.25)
	# the floor and the curved front and sides (a D-shaped body open at the back)
	F._part(car, F._cached("car_floor", func(): return M.ellipsoid(0.56, 0.035, 0.52, 16, 4)), F.mat(wood), Vector3(0, 0.42, 0.0))
	var shell := F._cached("car_shell", func():
		var fn := func(u: float, v: float) -> Vector3:
			var a := lerpf(-PI * 0.5 - 0.35, PI * 0.5 + 0.35, u)   # from the left rear round the front to the right rear
			var h := lerpf(0.0, 0.62, v)
			var flare := 1.0 + 0.06 * v
			return Vector3(-sin(a) * 0.56 * flare, 0.42 + h, cos(a) * 0.52 * flare * (1.0 if cos(a) > 0.0 else 0.8) * 0.9 + 0.02)
		return M.surface(16, 4, fn, -1))
	F._part(car, shell, F.cloth(col))
	var trim := _tube_arc(0.58, 0.55, 0.012)
	F._part(car, trim, F.metal(bronze, 0.8), Vector3(0, 1.04, 0.02))
	F._part(car, _tube_arc(0.575, 0.52, 0.012), F.metal(bronze, 0.8), Vector3(0, 0.44, 0.02))
	for i in 7:
		var a := lerpf(-1.3, 1.3, float(i) / 6.0)
		F._part(car, M.ellipsoid(0.02, 0.02, 0.012, 6, 4), F.metal(bronze, 0.8), Vector3(-sin(a) * 0.57, 0.88, cos(a) * 0.5 + 0.02), Vector3(0, a, 0))
	# the axle and the wheels
	F._part(car, M.capsule(0.03, 0.03, 1.5, 8), F.mat(wood.darkened(0.3)), Vector3(0.75, 0.42, -0.05), Vector3(0, 0, PI / 2.0))
	for s in [-0.78, 0.78]:
		var piv := Node3D.new()
		piv.position = Vector3(s, 0.42, -0.05)
		car.add_child(piv)
		var rim := F._cached("wheel_rim", func():
			var pts: Array = []
			var rr: Array = []
			for i in 25:
				var a := float(i) / 24.0 * TAU
				pts.append(Vector3(0.0, sin(a) * 0.42, cos(a) * 0.42))
				rr.append(0.032)
			return M.tube(pts, rr, 6))
		F._part(piv, rim, F.mat(Color(0.2, 0.19, 0.18)))
		F._part(piv, M.capsule(0.07, 0.07, 0.1, 8), F.metal(bronze, 0.7), Vector3(0.0, 0.0, 0.0), Vector3(0, 0, PI / 2.0))
		for k in 8:
			var a := float(k) / 8.0 * TAU
			F._part(piv, M.capsule(0.016, 0.012, 0.36, 5), F.mat(wood.lightened(0.1)), Vector3(0, sin(a) * 0.04, cos(a) * 0.04), Vector3(a + PI / 2.0, 0, 0)).rotation = Vector3(-a + PI, 0, 0)
		wheels.append(piv)
	# the charioteer
	driver = F.person({"tunic": col.lerp(Color(0.9, 0.9, 0.85), 0.1), "seed": int(col.r * 7.0) % 5, "hair": Color(0.15, 0.1, 0.08), "sleeves": true, "belt_on": false})
	driver.position = Vector3(0, 0.455, -0.12)
	driver.equip_helmet("leather", Color(0.42, 0.28, 0.14), col.lightened(0.15))
	var wrap := F._cached("rein_wrap", func(): return M.lathe([Vector4(0.06, 0.158, 0.108, 0.0), Vector4(0.06, 0.168, 0.116, 0.0), Vector4(0.2, 0.168, 0.116, 0.0), Vector4(0.2, 0.158, 0.108, 0.0)], 16, 1))
	F._part(driver.torso, wrap, F.cloth(Color(0.42, 0.26, 0.14)))
	F._part(driver.torso, F._cached("falx", func(): return M.ellipsoid(0.01, 0.09, 0.004, 6, 4)), F.metal(Color(0.85, 0.86, 0.9), 0.8), Vector3(-0.17, 0.0, 0.05), Vector3(0.0, 0.0, 0.3))
	car.add_child(driver)
	_pose_driver(0.0)
	reins = MeshInstance3D.new()
	reins.mesh = _rein_mesh
	reins.material_override = F.cloth(Color(0.32, 0.2, 0.12))
	reins.top_level = false
	car.add_child(reins)


static func _tube_arc(rx: float, rz: float, r: float) -> ArrayMesh:
	var key := "arc%.2f,%.2f,%.3f" % [rx, rz, r]
	if F._meshes.has(key):
		return F._meshes[key]
	var pts: Array = []
	var rr: Array = []
	for i in 17:
		var a := lerpf(-PI * 0.5 - 0.35, PI * 0.5 + 0.35, float(i) / 16.0)
		pts.append(Vector3(-sin(a) * rx, 0.0, cos(a) * rz * (1.0 if cos(a) > 0.0 else 0.8) * 0.9))
		rr.append(r)
	var m := M.tube(pts, rr, 6)
	F._meshes[key] = m
	return m


func _pose_driver(sway: float) -> void:
	var d = driver
	d.walk(0.0, 0.0)
	d.pelvis.position.y = 0.78 + 0.0
	for i in 2:
		d.legs[i].rotation = Vector3(-0.32 + 0.0 * sway, 0, 0.08 * (1.0 if i == 0 else -1.0))
		d.knees[i].rotation = Vector3(0.62, 0, 0)
		d.ankles[i].rotation = Vector3(-0.3, 0, 0)
	d.torso.rotation = Vector3(0.28 + 0.04 * sway, 0.05 * sway, 0)
	d.head.rotation = Vector3(-0.2, 0, 0)
	d.hand_to(0, Vector3(-0.1, 0.38, 0.3) + Vector3(0, 0.02 * sway, 0))
	d.hand_to(1, Vector3(0.1, 0.38, 0.3) + Vector3(0, -0.02 * sway, 0))


func _build_team(col: Color, n: int, coat_seed: int, white_team: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = coat_seed
	var coats := [Color(0.45, 0.28, 0.16), Color(0.32, 0.21, 0.14), Color(0.66, 0.65, 0.62), Color(0.16, 0.14, 0.13), Color(0.55, 0.36, 0.2), Color(0.38, 0.24, 0.14)]
	var wood := Color(0.5, 0.36, 0.2)
	var pole := F._cached("pole", func(): return M.tube([Vector3(0, 0.55, -POLE + 0.1), Vector3(0, 0.9, -POLE * 0.6), Vector3(0, 1.25, -0.9), Vector3(0, 1.42, 0.0)], [0.04, 0.04, 0.038, 0.036], 8))
	F._part(team, pole, F.mat(wood))
	var width := float(n) * SPACING
	F._part(team, M.capsule(0.03, 0.03, width + 0.3, 8), F.mat(wood.darkened(0.2)), Vector3(width / 2.0 + 0.15, 1.45, 0.0), Vector3(0, 0, PI / 2.0))
	for i in n:
		var h := A.make_horse(Color(0.95, 0.94, 0.9) if white_team else coats[rng.randi() % coats.size()], rng.randf() < 0.5)
		h.position = Vector3((float(i) - (n - 1) * 0.5) * SPACING, 0, -0.55)
		A.add_harness(h, Color(0.52, 0.12, 0.1), col)
		team.add_child(h)
		horses.append(h)


## Spin the wheels and gallop the team for a total distance run.
func animate(dist: float, team_dist: float, moving := 1.0) -> void:
	for w in wheels:
		w.rotation.x = dist / 0.42
	var i := 0
	for h in horses:
		A.gallop(h, team_dist * 0.75 + i * 0.7, moving)
		i += 1
	if moving > 0.01:
		_pose_driver(sin(dist * 0.5))


## Redraw the reins from the charioteer's hands to the horses' bits (call after both nodes are
## positioned; they must share a parent).
func update_reins() -> void:
	_rein_mesh.clear_surfaces()
	if not reins.visible or horses.is_empty() or car.get_parent() == null:
		return
	var rel: Transform3D = car.transform.affine_inverse() * team.transform
	_rein_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := horses.size()
	for i in n:
		var h := horses[i]
		var bit: Vector3 = rel * (h.position + Vector3(0, 1.5, 1.38))
		var hand: Vector3 = _hands[0] if i < n / 2 else _hands[1]
		hand = hand + Vector3(0, 0.06, 0)
		var prev := hand
		for k in range(1, 7):
			var t := float(k) / 6.0
			var p := hand.lerp(bit, t)
			p.y -= 0.12 * sin(t * PI) * 0.5
			_ribbon(prev, p, 0.012)
			prev = p
	_rein_mesh.surface_end()


func _ribbon(a: Vector3, b: Vector3, w: float) -> void:
	var up := Vector3(0, w, 0)
	var side := Vector3(w, 0, 0)
	for off in [up, side]:
		_rein_mesh.surface_add_vertex(a - off)
		_rein_mesh.surface_add_vertex(a + off)
		_rein_mesh.surface_add_vertex(b + off)
		_rein_mesh.surface_add_vertex(a - off)
		_rein_mesh.surface_add_vertex(b + off)
		_rein_mesh.surface_add_vertex(b - off)
