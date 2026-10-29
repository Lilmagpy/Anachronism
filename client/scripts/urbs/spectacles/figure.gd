## A small articulated person (and horse) for the spectacles (U6). Built from boxes and a
## sphere, with pivots at the hips and shoulders so it can walk, thrust, raise an arm, kneel.
## Units are metres; the figure stands at its origin and FACES +Z (as the models do, geo.gd).
## Reuse: Figure.make(...) for people, Figure.make_horse(...) for a horse, Figure.face(node, dir).

extends Node3D

const SKIN := Color(0.86, 0.66, 0.52)
static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}

var legs: Array[Node3D] = []
var arms: Array[Node3D] = []     # [right, left] (right is +x)
var torso: Node3D
var head: Node3D
var hips_y := 0.9
var hand_r: Node3D
var hand_l: Node3D


## A person. `tunic` is the cloth colour, `toga` wraps a white toga over it (senators,
## magistrates: `stripe` is the purple/red edge), `scale_` makes them taller or shorter.
static func make(tunic: Color, toga := false, stripe := Color(0.55, 0.1, 0.35), scale_ := 1.0, skin := SKIN) -> Node3D:
	var f = new()
	f.torso = Node3D.new()
	f.torso.position = Vector3(0, 0.9, 0)
	f.add_child(f.torso)
	_box(f.torso, Vector3(0.40, 0.62, 0.24), Vector3(0, 0.31, 0), tunic)
	_box(f, Vector3(0.42, 0.36, 0.27), Vector3(0, 0.72, 0), tunic)   # tunic skirt
	if toga:
		_box(f.torso, Vector3(0.46, 0.5, 0.30), Vector3(0, 0.30, 0.0), Color(0.95, 0.93, 0.86))
		_box(f, Vector3(0.50, 0.55, 0.32), Vector3(0, 0.66, 0), Color(0.95, 0.93, 0.86))
		_box(f.torso, Vector3(0.05, 0.62, 0.32), Vector3(0.08, 0.31, 0.0), stripe)
	f.head = Node3D.new()
	f.head.position = Vector3(0, 0.74, 0)
	f.torso.add_child(f.head)
	_sphere(f.head, 0.12, Vector3(0, 0.05, 0), skin)
	for s in [1.0, -1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.1 * s, 0.9, 0)
		f.add_child(leg)
		_box(leg, Vector3(0.14, 0.9, 0.16), Vector3(0, -0.45, 0), skin.darkened(0.1))
		f.legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(0.27 * s, 0.56, 0)
		f.torso.add_child(arm)
		_box(arm, Vector3(0.10, 0.34, 0.10), Vector3(0, -0.17, 0), tunic)
		_box(arm, Vector3(0.09, 0.30, 0.09), Vector3(0, -0.49, 0), skin)
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.64, 0)
		arm.add_child(hand)
		f.arms.append(arm)
		if s > 0:
			f.hand_r = hand
		else:
			f.hand_l = hand
	f.scale = Vector3.ONE * scale_
	return f


## Walk cycle: `phase` in radians (advance by distance walked / stride), `amp` 0 stands, 1 walks.
func walk(phase: float, amp := 1.0) -> void:
	var sw := sin(phase) * 0.55 * amp
	legs[0].rotation.x = sw
	legs[1].rotation.x = -sw
	arms[0].rotation.x = -sw * 0.8
	arms[1].rotation.x = sw * 0.8
	torso.position.y = 0.9 + absf(cos(phase)) * 0.025 * amp


## Set both arms' pitch (radians; negative lifts forward/up) and sideways spread.
func pose_arms(right: float, left: float, spread_r := 0.0, spread_l := 0.0) -> void:
	arms[0].rotation = Vector3(right, 0, -spread_r)
	arms[1].rotation = Vector3(left, 0, spread_l)


## Kneel (0 standing, 1 on one knee), sink the body.
func kneel(amount: float) -> void:
	torso.position.y = 0.9 - 0.4 * amount
	legs[0].rotation.x = -1.4 * amount
	legs[1].rotation.x = 1.2 * amount
	position.y = 0.0


## Turn the figure so its front (+z) points along `dir` (a horizontal vector).
static func face(node: Node3D, dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.0001:
		node.rotation.y = atan2(dir.x, dir.z)


## A horse. Legs swing with `gallop(phase)`.
static func make_horse(coat: Color) -> Node3D:
	var h := Node3D.new()
	var body := Node3D.new()
	h.add_child(body)
	_box(body, Vector3(0.55, 0.62, 1.5), Vector3(0, 1.15, 0), coat)
	var neck := Node3D.new()
	neck.position = Vector3(0, 1.3, 0.65)
	neck.rotation.x = 0.6
	body.add_child(neck)
	_box(neck, Vector3(0.25, 0.7, 0.28), Vector3(0, 0.3, 0), coat)
	var hd := Node3D.new()
	hd.position = Vector3(0, 0.62, 0.0)
	hd.rotation.x = 1.5
	neck.add_child(hd)
	_box(hd, Vector3(0.2, 0.5, 0.22), Vector3(0, 0.2, 0), coat)
	_box(body, Vector3(0.08, 0.5, 0.08), Vector3(0, 0.95, -0.9), coat.darkened(0.35)).rotation.x = -0.3
	h.set_meta("legs", [])
	var legs_a: Array = []
	for z in [0.55, -0.55]:
		for x in [0.17, -0.17]:
			var leg := Node3D.new()
			leg.position = Vector3(x, 0.86, z)
			h.add_child(leg)
			_box(leg, Vector3(0.11, 0.86, 0.12), Vector3(0, -0.43, 0), coat.darkened(0.15))
			legs_a.append(leg)
	h.set_meta("legs", legs_a)
	h.set_meta("body", body)
	return h


## Gallop pose for a horse from make_horse (phase advances with distance run).
static func gallop(h: Node3D, phase: float, amp := 1.0) -> void:
	var legs_a: Array = h.get_meta("legs")
	for i in legs_a.size():
		var front: bool = i < 2
		var off := 0.0 if front else PI * 0.6
		var lr: float = 0.0 if (i % 2 == 0) else 0.5
		(legs_a[i] as Node3D).rotation.x = sin(phase + off + lr) * 0.8 * amp
	var body: Node3D = h.get_meta("body")
	body.position.y = sin(phase * 1.0 + 0.8) * 0.06 * amp
	body.rotation.x = sin(phase) * 0.05 * amp


## Equip a shield held in front of the left side of the body (a child of the torso: animate
## its position and rotation to guard and parry; the left arm is hidden behind it). kind: "scutum" (tall oblong), "round", "parma" (small square).
func equip_shield(kind: String, col := Color(0.62, 0.2, 0.15)) -> Node3D:
	var sh := Node3D.new()
	torso.add_child(sh)
	var size := Vector3(0.7, 0.9, 0.06)
	match kind:
		"round":
			size = Vector3(0.8, 0.8, 0.06)
		"parma":
			size = Vector3(0.5, 0.5, 0.05)
	sh.position = Vector3(-0.22, 0.2, 0.3)
	_box(sh, size, Vector3.ZERO, col)
	_box(sh, size * Vector3(1.0, 1.0, 0.0) + Vector3(-0.1, -0.1, 0.09), Vector3(0, 0, 0.02), Color(0.8, 0.68, 0.3))
	_box(sh, Vector3(0.12, 0.12, 0.1), Vector3(0, 0, 0.06), Color(0.75, 0.7, 0.6))
	return sh


## Equip a sword in the right hand: "gladius" straight or "sica" curved (just a bent blade).
func equip_sword(kind := "gladius") -> Node3D:
	var sw := Node3D.new()
	hand_r.add_child(sw)
	sw.rotation.x = PI / 2.0
	_box(sw, Vector3(0.05, 0.05, 0.14), Vector3(0, 0, 0), Color(0.35, 0.22, 0.1))
	var blade := _box(sw, Vector3(0.05, 0.03, 0.62), Vector3(0, 0, 0.38), Color(0.82, 0.83, 0.86))
	if kind == "sica":
		blade.rotation.y = 0.18
	return sw


## A helmet in the given metal colour with a crest.
func equip_helmet(metal := Color(0.7, 0.62, 0.35), crest := Color(0.7, 0.1, 0.1)) -> void:
	_box(head, Vector3(0.27, 0.12, 0.27), Vector3(0, 0.12, 0), metal)
	_box(head, Vector3(0.05, 0.14, 0.3), Vector3(0, 0.22, 0), crest)


static func mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_mats[key] = m
	return _mats[key]


static func _box(parent: Node3D, size: Vector3, at: Vector3, col: Color) -> MeshInstance3D:
	var key := "b%.2f,%.2f,%.2f" % [size.x, size.y, size.z]
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[key] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.material_override = mat(col)
	mi.position = at
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, r: float, at: Vector3, col: Color) -> MeshInstance3D:
	var key := "s%.3f" % r
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 10
		sm.rings = 5
		_meshes[key] = sm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.material_override = mat(col)
	mi.position = at
	parent.add_child(mi)
	return mi


## Public box helper for the scenes (a coloured box mesh at a position).
static func box(parent: Node3D, size: Vector3, at: Vector3, col: Color) -> MeshInstance3D:
	return _box(parent, size, at, col)
