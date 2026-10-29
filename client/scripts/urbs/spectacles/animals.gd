## Low-poly horses and oxen for the spectacles (U6): a barrel body, swept-tube neck and head with
## ears, eyes, mane and tail, and four articulated legs (shoulder/hip, knee/hock, fetlock) with
## a gallop and a walk cycle. Faces +Z, hooves on y = 0. Like the people, each animal is baked
## into one skinned mesh per level of detail (rig.gd); the Node3D bones only carry the pose.
extends RefCounted

const M := preload("res://scripts/urbs/spectacles/meshlib.gd")
const F := preload("res://scripts/urbs/spectacles/figure.gd")
const R := preload("res://scripts/urbs/spectacles/rig.gd")

# barrel profiles: Vector4(z, half-width, half-height, centre y)
const HORSE_BARREL := [
	Vector4(-0.92, 0.0, 0.0, 1.26), Vector4(-0.88, 0.12, 0.17, 1.28), Vector4(-0.72, 0.26, 0.30, 1.27),
	Vector4(-0.42, 0.27, 0.31, 1.22), Vector4(0.0, 0.27, 0.33, 1.2), Vector4(0.35, 0.27, 0.34, 1.2),
	Vector4(0.6, 0.24, 0.32, 1.25), Vector4(0.78, 0.17, 0.24, 1.3), Vector4(0.86, 0.0, 0.0, 1.31),
]
const OX_BARREL := [
	Vector4(-0.88, 0.0, 0.0, 1.0), Vector4(-0.84, 0.14, 0.2, 1.04), Vector4(-0.66, 0.3, 0.38, 1.04),
	Vector4(-0.3, 0.33, 0.42, 1.0), Vector4(0.1, 0.35, 0.44, 0.98), Vector4(0.45, 0.34, 0.43, 1.02),
	Vector4(0.7, 0.28, 0.38, 1.06), Vector4(0.86, 0.14, 0.24, 1.08), Vector4(0.92, 0.0, 0.0, 1.08),
]


static func _barrel(profile: Array, key: String) -> Callable:
	return func(lod: int) -> ArrayMesh:
		return F._cached("%s%d" % [key, lod], func():
			var n := profile.size()
			var fn := func(u: float, v: float) -> Vector3:
				var f := v * float(n - 1)
				var i := mini(int(f), n - 2)
				var t := f - float(i)
				var a: Vector4 = profile[i]
				var b: Vector4 = profile[i + 1]
				var z := lerpf(a.x, b.x, t)
				var rx := lerpf(a.y, b.y, t)
				var ry := lerpf(a.z, b.z, t)
				var yc := lerpf(a.w, b.w, t)
				var th := u * TAU
				return Vector3(rx * sin(th), yc + ry * cos(th) - (0.04 * ry if cos(th) < 0.0 else 0.0), z)
			return M.surface(16 if lod == 0 else 8, (n - 1) * (3 if lod == 0 else 1), fn))


static func _tube(key: String, pts: Array, radii: Array, nu := 10) -> Callable:
	return func(lod: int) -> ArrayMesh:
		return F._cached("%s%d" % [key, lod], func(): return M.tube(pts, radii, nu if lod == 0 else 6))


## Add a part to the animal's rig (the animal root is `h`, its rig stored in meta "rig").
static func _p(h: Node3D, bone: int, key: String, fn: Callable, at := Vector3.ZERO, rot := Vector3.ZERO, slot := 5, col := Color.WHITE, metal := 0.0) -> void:
	(h.get_meta("rig") as Node).add_part(bone, key, fn, F._xf(at, rot), slot, col, metal)


static func _node(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


static func _leg(h: Node3D, body: Node3D, body_bone: int, pos: Vector3, upper: float, lower: float, pastern: float, r0: float) -> Array:
	var rig: Node = h.get_meta("rig")
	var hip := _node(body, pos)
	var knee := _node(hip, Vector3(0, -upper, 0))
	var fet := _node(knee, Vector3(0, -lower, 0))
	var bh: int = rig.add_bone(hip, body_bone)
	var bk: int = rig.add_bone(knee, bh)
	var bf: int = rig.add_bone(fet, bk)
	_p(h, bh, "hl_up%.3f,%.3f" % [r0, upper], F.fcap(r0, r0 * 0.62, upper, 0.012), Vector3.ZERO, Vector3.ZERO, 0)
	_p(h, bk, "hl_lo%.3f,%.3f" % [r0, lower], F.fcap(r0 * 0.56, r0 * 0.4, lower), Vector3.ZERO, Vector3.ZERO, 4)
	_p(h, bf, "hl_pa%.3f,%.3f" % [r0, pastern], F.fcap(r0 * 0.42, r0 * 0.4, pastern), Vector3.ZERO, Vector3.ZERO, 4)
	_p(h, bf, "hoof%.3f" % r0, F.fcap(r0 * 0.5, r0 * 0.55, 0.05), Vector3(0, -pastern - 0.02, 0.01), Vector3.ZERO, 5, Color(0.14, 0.11, 0.09))
	return [hip, knee, fet]


## A horse. `coat` is the body colour; the mane, tail and lower legs are darker.
static func make_horse(coat: Color, blaze := true) -> Node3D:
	var h := Node3D.new()
	var rig := R.create(h)
	h.set_meta("rig", rig)
	var dark := Color(0.1, 0.075, 0.06) if coat.v < 0.7 else coat.darkened(0.12)
	rig.set_colour("c_skin", coat)
	rig.set_colour("c_hair", dark)
	var body := _node(h, Vector3.ZERO)
	var bb: int = rig.add_bone(body, -1)
	var neck := _node(body, Vector3(0, 1.36, 0.62))
	var bn: int = rig.add_bone(neck, bb)
	var headn := _node(neck, Vector3(0, 0.42, 0.42))
	var bhd: int = rig.add_bone(headn, bn)
	var tail := _node(body, Vector3(0, 1.32, -0.88))
	var bt: int = rig.add_bone(tail, bb)
	_p(h, bb, "h_barrel", _barrel(HORSE_BARREL, "horse_barrel"), Vector3.ZERO, Vector3.ZERO, 0)
	_p(h, bn, "h_neck", _tube("h_neck", [Vector3(0, -0.02, -0.05), Vector3(0, 0.15, 0.17), Vector3(0, 0.33, 0.32), Vector3(0, 0.42, 0.42)], [0.175, 0.14, 0.108, 0.09]), Vector3.ZERO, Vector3.ZERO, 0)
	_p(h, bhd, "h_head", _tube("h_head", [Vector3(0, 0.0, -0.02), Vector3(0, -0.1, 0.12), Vector3(0, -0.22, 0.25), Vector3(0, -0.28, 0.33)], [0.1, 0.085, 0.062, 0.05]), Vector3.ZERO, Vector3.ZERO, 0)
	_p(h, bhd, "h_muzzle", F.fell(0.052, 0.045, 0.075), Vector3(0, -0.3, 0.35), Vector3.ZERO, 4)
	if blaze:
		_p(h, bhd, "h_blaze", F.fell(0.02, 0.1, 0.02), Vector3(0, -0.1, 0.105), Vector3(0.4, 0, 0), 5, Color(0.93, 0.92, 0.88))
	for s in [-1.0, 1.0]:
		_p(h, bhd, "h_ear", F.fell(0.017, 0.055, 0.014, true), Vector3(0.05 * s, 0.06, -0.04), Vector3(-0.2, 0, 0.2 * s), 0)
		_p(h, bhd, "h_eye", F.fell(0.014, 0.014, 0.01, true), Vector3(0.088 * s, -0.055, 0.05), Vector3.ZERO, 5, Color(0.03, 0.02, 0.02))
	for i in 9:
		var t := float(i) / 8.0
		_p(h, bn, "h_mane", F.fell(0.014, 0.07, 0.03), Vector3(0, 0.0 + 0.4 * t + 0.1, -0.03 + 0.38 * t), Vector3.ZERO, 4)
	_p(h, bt, "h_tail", _tube("h_tail", [Vector3(0, 0, 0), Vector3(0, -0.12, -0.12), Vector3(0, -0.4, -0.18), Vector3(0, -0.7, -0.14)], [0.05, 0.05, 0.04, 0.02], 8), Vector3.ZERO, Vector3.ZERO, 4)
	var legs_a: Array = []
	for z in [0.55, -0.62]:
		for x in [0.17, -0.17]:
			var up := 0.42 if z > 0.0 else 0.44
			legs_a.append(_leg(h, body, bb, Vector3(x, 1.12, z), up, 0.42, 0.14, 0.1 if z > 0.0 else 0.115))
	h.set_meta("legs", legs_a)
	h.set_meta("body", body)
	h.set_meta("neck", neck)
	h.set_meta("head", headn)
	h.set_meta("tail", tail)
	h.set_meta("bone_body", bb)
	h.set_meta("bone_neck", bn)
	h.set_meta("bone_head", bhd)
	return h


## Gallop pose: `phase` advances with distance run; amp 0 stands.
static func gallop(h: Node3D, phase: float, amp := 1.0) -> void:
	var legs_a: Array = h.get_meta("legs")
	var offs := [0.0, 0.5, 0.9, 1.4]   # front L, front R, hind L, hind R (a rotary gait)
	for i in legs_a.size():
		var l: Array = legs_a[i]
		var ph: float = phase + float(offs[i])
		var sw := sin(ph)
		var front := i < 2
		var hip_a := sw * (0.85 if front else 0.7) * amp
		(l[0] as Node3D).rotation = Vector3(hip_a, 0, 0)
		var flex := maxf(0.0, -cos(ph))
		(l[1] as Node3D).rotation = Vector3(flex * (1.5 if front else 1.1) * amp + 0.05 * amp, 0, 0)
		(l[2] as Node3D).rotation = Vector3(-flex * 0.5 * amp + 0.2 * maxf(0.0, sw) * amp, 0, 0)
	var body: Node3D = h.get_meta("body")
	body.position.y = (0.035 * sin(2.0 * phase + 0.5)) * amp
	body.rotation.x = 0.05 * sin(phase + 0.3) * amp
	(h.get_meta("neck") as Node3D).rotation.x = -0.12 * sin(phase + 1.2) * amp
	(h.get_meta("head") as Node3D).rotation.x = 0.1 * sin(phase + 2.0) * amp
	(h.get_meta("tail") as Node3D).rotation.x = 0.25 + 0.2 * sin(phase * 1.5) * amp


## Strap harness on a horse: a breast collar with gilt discs, a bridle, a head plume in `plume`.
static func add_harness(h: Node3D, strap := Color(0.5, 0.12, 0.1), plume := Color(0.8, 0.2, 0.2)) -> void:
	var rig: Node = h.get_meta("rig")
	var bb: int = h.get_meta("bone_body")
	var bhd: int = h.get_meta("bone_head")
	rig.set_colour("c_trim", plume)
	_p(h, bb, "h_collar", F.fmesh(func():
		return F._cached("horse_collar2", func():
			var fn := func(u: float, v: float) -> Vector3:
				var th := u * TAU
				return Vector3(0.265 * sin(th) * (1.0 + 0.04 * v), 1.25 + 0.33 * cos(th), 0.56 + 0.06 * v)
			return M.surface(16, 1, fn, -1))), Vector3.ZERO, Vector3.ZERO, 5, strap)
	for i in 3:
		var a := -0.6 + i * 0.6
		_p(h, bb, "h_disc", F.fell(0.03, 0.03, 0.01, true), Vector3(0.265 * sin(a), 1.25 + 0.33 * cos(a) * 0.98 - 0.02, 0.72), Vector3.ZERO, 5, Color(0.9, 0.72, 0.25), 0.8)
	_p(h, bhd, "h_noseband", F.fell(0.06, 0.012, 0.06), Vector3(0, -0.27, 0.3), Vector3.ZERO, 5, strap)
	_p(h, bhd, "h_browband", F.fell(0.095, 0.012, 0.09), Vector3.ZERO, Vector3.ZERO, 5, strap)
	_p(h, bhd, "h_plume", F.fell(0.022, 0.07, 0.022, true), Vector3(0, 0.12, -0.02), Vector3(-0.2, 0, 0), 3)


# ---- the ox ----------------------------------------------------------------------------------

## A sacrificial ox: white, gilt horns, a garland and fillets, a dorsuale cloth.
static func make_ox(white := Color(0.94, 0.93, 0.9), garland := true) -> Node3D:
	var ox := Node3D.new()
	var rig := R.create(ox)
	ox.set_meta("rig", rig)
	rig.set_colour("c_skin", white)
	rig.set_colour("c_hair", white.darkened(0.2))
	var body := _node(ox, Vector3.ZERO)
	var bb: int = rig.add_bone(body, -1)
	var neck := _node(body, Vector3(0, 1.1, 0.7))
	var bn: int = rig.add_bone(neck, bb)
	var headn := _node(neck, Vector3(0, -0.08, 0.35))
	var bhd: int = rig.add_bone(headn, bn)
	var tail := _node(body, Vector3(0, 1.05, -0.86))
	var bt: int = rig.add_bone(tail, bb)
	var gold := Color(0.9, 0.74, 0.28)
	_p(ox, bb, "o_barrel", _barrel(OX_BARREL, "ox_barrel"), Vector3.ZERO, Vector3.ZERO, 0)
	_p(ox, bn, "o_neck", _tube("o_neck", [Vector3(0, 0.0, -0.1), Vector3(0, -0.02, 0.15), Vector3(0, -0.08, 0.35)], [0.28, 0.24, 0.2]), Vector3.ZERO, Vector3.ZERO, 0)
	_p(ox, bn, "o_dewlap", F.fell(0.1, 0.22, 0.2), Vector3(0, -0.26, 0.2), Vector3.ZERO, 0)
	_p(ox, bhd, "o_head", _tube("o_head", [Vector3(0, 0.02, -0.05), Vector3(0, -0.04, 0.15), Vector3(0, -0.1, 0.32)], [0.19, 0.16, 0.12]), Vector3.ZERO, Vector3.ZERO, 0)
	_p(ox, bhd, "o_muzzle", F.fell(0.1, 0.07, 0.1), Vector3(0, -0.12, 0.39), Vector3.ZERO, 5, Color(0.86, 0.66, 0.64))
	for s in [-1.0, 1.0]:
		var horn_pts: Array = []
		var horn_r: Array = []
		for i in 6:
			var t := float(i) / 5.0
			horn_pts.append(Vector3(0.14 * s + 0.2 * s * t, 0.05 + 0.15 * t + 0.1 * t * t, 0.0))
			horn_r.append(0.035 * (1.0 - 0.8 * t))
		_p(ox, bhd, "o_horn%d" % int(s), _tube("o_horn%d" % int(s), horn_pts, horn_r, 6), Vector3(0, 0.06, 0.0), Vector3.ZERO, 5, gold, 0.7)
		_p(ox, bhd, "o_ear", F.fell(0.03, 0.065, 0.025, true), Vector3(0.19 * s, 0.05, -0.04), Vector3(0, 0, 0.9 * s), 0)
		_p(ox, bhd, "o_eye", F.fell(0.017, 0.017, 0.012, true), Vector3(0.14 * s, 0.0, 0.14), Vector3.ZERO, 5, Color(0.03, 0.02, 0.02))
	if garland:
		var pts: Array = []
		var rr: Array = []
		for i in 21:
			var a := float(i) / 20.0 * TAU
			pts.append(Vector3(sin(a) * 0.26, 0.0, cos(a) * 0.22 - 0.05))
			rr.append(0.045 + 0.012 * sin(a * 9.0))
		_p(ox, bn, "o_garland", _tube("o_garland", pts, rr, 7), Vector3(0, -0.02, 0.1), Vector3(0.35, 0, 0), 5, Color(0.26, 0.48, 0.2))
		for s in [-1.0, 1.0]:
			_p(ox, bn, "o_fillet", F.fell(0.012, 0.18, 0.03, true), Vector3(0.16 * s, -0.2, 0.2), Vector3(0.1, 0, 0.0), 5, Color(0.7, 0.1, 0.12))
	_p(ox, bb, "o_cloth", F.fell(0.38, 0.03, 0.42), Vector3(0, 1.45, 0.05), Vector3.ZERO, 5, Color(0.55, 0.1, 0.3))
	_p(ox, bb, "o_cloth_b", F.fell(0.39, 0.012, 0.43), Vector3(0, 1.43, 0.05), Vector3.ZERO, 5, gold, 0.7)
	_p(ox, bt, "o_tail", _tube("o_tail", [Vector3(0, 0, 0), Vector3(0, -0.2, -0.08), Vector3(0, -0.55, -0.08)], [0.03, 0.025, 0.02], 6), Vector3.ZERO, Vector3.ZERO, 0)
	_p(ox, bt, "o_tuft", F.fell(0.04, 0.1, 0.04), Vector3(0, -0.62, -0.08), Vector3.ZERO, 4)
	var legs_a: Array = []
	for z in [0.55, -0.55]:
		for x in [0.24, -0.24]:
			legs_a.append(_leg(ox, body, bb, Vector3(x, 0.78, z), 0.3, 0.3, 0.12, 0.105))
	ox.set_meta("legs", legs_a)
	ox.set_meta("body", body)
	ox.set_meta("neck", neck)
	ox.set_meta("head", headn)
	ox.set_meta("tail", tail)
	return ox


## Walk cycle for an ox (phase advances with distance; amp 0 stands).
static func walk_ox(ox: Node3D, phase: float, amp := 1.0) -> void:
	var legs_a: Array = ox.get_meta("legs")
	var offs := [0.0, PI, PI * 1.5, PI * 0.5]
	for i in legs_a.size():
		var l: Array = legs_a[i]
		var ph: float = phase + float(offs[i])
		(l[0] as Node3D).rotation = Vector3(sin(ph) * 0.38 * amp, 0, 0)
		(l[1] as Node3D).rotation = Vector3(maxf(0.0, -cos(ph)) * 0.7 * amp, 0, 0)
		(l[2] as Node3D).rotation = Vector3(-maxf(0.0, -cos(ph)) * 0.3 * amp, 0, 0)
	var body: Node3D = ox.get_meta("body")
	body.position.y = 0.012 * sin(2.0 * phase) * amp
	(ox.get_meta("neck") as Node3D).rotation.x = 0.04 * sin(phase) * amp
	(ox.get_meta("tail") as Node3D).rotation.z = 0.2 * sin(phase * 0.7) * amp
