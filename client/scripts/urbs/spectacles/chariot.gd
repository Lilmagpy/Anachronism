## A racing chariot (U6): the car (two wheels, a rail, the driver in his faction's colour) and
## the team (a pole, a yoke and two or four horses abreast) as two separate nodes, so that in a
## crash the car can tumble while the horses run on. Both face +Z.
extends RefCounted

const F := preload("res://scripts/urbs/spectacles/figure.gd")
const POLE := 3.6

var car: Node3D
var team: Node3D
var driver: Node3D
var wheels: Array[Node3D] = []
var horses: Array[Node3D] = []
var colour := Color.WHITE


static func make(team_colour: Color, n_horses: int, coat_seed: int, white_team := false) -> RefCounted:
	var c = (load("res://scripts/urbs/spectacles/chariot.gd") as GDScript).new()
	c.colour = team_colour
	c.car = Node3D.new()
	F.box(c.car, Vector3(1.0, 0.08, 0.9), Vector3(0, 0.38, 0), Color(0.55, 0.38, 0.2))
	F.box(c.car, Vector3(1.0, 0.5, 0.06), Vector3(0, 0.62, 0.45), team_colour)
	for s in [-0.5, 0.5]:
		F.box(c.car, Vector3(0.06, 0.45, 0.8), Vector3(s, 0.6, 0.0), team_colour.darkened(0.15))
	for s in [-0.62, 0.62]:
		var piv := Node3D.new()
		piv.position = Vector3(s, 0.42, -0.05)
		c.car.add_child(piv)
		var rim := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.42
		cm.bottom_radius = 0.42
		cm.height = 0.07
		cm.radial_segments = 14
		rim.mesh = cm
		rim.material_override = F.mat(Color(0.35, 0.24, 0.12))
		rim.rotation.z = PI / 2.0
		piv.add_child(rim)
		F.box(piv, Vector3(0.09, 0.84, 0.06), Vector3.ZERO, Color(0.8, 0.7, 0.45))
		F.box(piv, Vector3(0.09, 0.06, 0.84), Vector3.ZERO, Color(0.8, 0.7, 0.45))
		c.wheels.append(piv)
	c.driver = F.make(team_colour, false, Color.WHITE, 0.97)
	c.driver.position = Vector3(0, 0.42, -0.1)
	c.driver.pose_arms(-1.1, -1.1)
	c.driver.equip_helmet(Color(0.45, 0.3, 0.15), team_colour.lightened(0.2))
	c.car.add_child(c.driver)
	c.team = Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = coat_seed
	var coats := [Color(0.45, 0.28, 0.16), Color(0.30, 0.2, 0.14), Color(0.62, 0.62, 0.6), Color(0.15, 0.13, 0.12), Color(0.55, 0.35, 0.2)]
	F.box(c.team, Vector3(0.08, 0.08, POLE), Vector3(0, 0.75, -POLE / 2.0 + 0.2), Color(0.5, 0.35, 0.2)).rotation.x = -0.1
	F.box(c.team, Vector3(float(n_horses) * 0.72, 0.07, 0.07), Vector3(0, 1.25, 0.1), Color(0.4, 0.28, 0.15))
	for i in n_horses:
		var h := F.make_horse(Color(0.95, 0.94, 0.9) if white_team else coats[rng.randi() % coats.size()])
		h.position = Vector3((float(i) - (n_horses - 1) * 0.5) * 0.72, 0, 0.75)
		F.box(h, Vector3(0.06, 0.3, 0.06), Vector3(0, 2.0, 0.78), team_colour).rotation.x = 0.0
		c.team.add_child(h)
		c.horses.append(h)
	return c


## Spin the wheels and gallop the team for a total distance run.
func animate(dist: float, team_dist: float, moving := 1.0) -> void:
	for w in wheels:
		w.rotation.x = dist / 0.42
	var i := 0
	for h in horses:
		F.gallop(h, team_dist * 0.8 + i * 0.5, moving)
		i += 1
