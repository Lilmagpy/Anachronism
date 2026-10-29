## Low-poly horses and oxen for the spectacles (U6): a barrel body, swept-tube neck and head with
## ears, eyes, mane and tail, and four articulated legs (shoulder/hip, knee/hock, fetlock) with
## a gallop and a walk cycle. Faces +Z, hooves on y = 0.
extends RefCounted

const M := preload("res://scripts/urbs/spectacles/meshlib.gd")
const F := preload("res://scripts/urbs/spectacles/figure.gd")

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


static func _barrel(profile: Array, key: String) -> ArrayMesh:
	if F._meshes.has(key):
		return F._meshes[key]
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
		return Vector3(rx * sin(th), yc + ry * cos(th) * 1.0 - (0.04 * ry if cos(th) < 0.0 else 0.0), z)
	var m := M.surface(16, (n - 1) * 3, fn)
	F._meshes[key] = m
	return m


static func _leg(parent: Node3D, pos: Vector3, upper: float, lower: float, pastern: float, r0: float, coat: Color, dark: Color, hock_back := true) -> Array:
	var hip := Node3D.new()
	hip.position = pos
	parent.add_child(hip)
	F._part(hip, M.capsule(r0, r0 * 0.62, upper, 10, 0.012), F.mat(coat))
	var knee := Node3D.new()
	knee.position = Vector3(0, -upper, 0)
	hip.add_child(knee)
	F._part(knee, M.capsule(r0 * 0.56, r0 * 0.4, lower, 8), F.mat(coat.lerp(dark, 0.4)))
	var fet := Node3D.new()
	fet.position = Vector3(0, -lower, 0)
	knee.add_child(fet)
	F._part(fet, M.capsule(r0 * 0.42, r0 * 0.4, pastern, 8), F.mat(coat.lerp(dark, 0.6)))
	F._part(fet, M.capsule(r0 * 0.5, r0 * 0.55, 0.05, 8), F.mat(Color(0.14, 0.11, 0.09)), Vector3(0, -pastern - 0.02, 0.01))   # hoof
	return [hip, knee, fet]


## A horse. `coat` is the body colour; the mane, tail and lower legs are darker.
static func make_horse(coat: Color, blaze := true) -> Node3D:
	var h := Node3D.new()
	var dark := Color(0.1, 0.075, 0.06) if coat.v < 0.7 else coat.darkened(0.12)
	var body := Node3D.new()
	h.add_child(body)
	F._part(body, _barrel(HORSE_BARREL, "horse_barrel"), F.mat(coat))
	# neck and head
	var neck := Node3D.new()
	neck.position = Vector3(0, 1.36, 0.62)
	body.add_child(neck)
	var nm := M.tube([Vector3(0, -0.02, -0.05), Vector3(0, 0.15, 0.17), Vector3(0, 0.33, 0.32), Vector3(0, 0.42, 0.42)], [0.175, 0.14, 0.108, 0.09], 10)
	F._part(neck, nm, F.mat(coat))
	var headn := Node3D.new()
	headn.position = Vector3(0, 0.42, 0.42)
	neck.add_child(headn)
	var hm := M.tube([Vector3(0, 0.0, -0.02), Vector3(0, -0.1, 0.12), Vector3(0, -0.22, 0.25), Vector3(0, -0.28, 0.33)], [0.1, 0.085, 0.062, 0.05], 10)
	F._part(headn, hm, F.mat(coat))
	F._part(headn, M.ellipsoid(0.052, 0.045, 0.075, 8, 5), F.mat(coat.lerp(dark, 0.25)), Vector3(0, -0.3, 0.35))   # muzzle
	if blaze:
		F._part(headn, M.ellipsoid(0.02, 0.1, 0.02, 6, 4), F.mat(Color(0.93, 0.92, 0.88)), Vector3(0, -0.1, 0.105), Vector3(0.4, 0, 0))
	for s in [-1.0, 1.0]:
		F._part(headn, M.ellipsoid(0.017, 0.055, 0.014, 6, 4), F.mat(coat), Vector3(0.05 * s, 0.06, -0.04), Vector3(-0.2, 0, 0.2 * s))   # ears
		F._part(headn, M.ellipsoid(0.014, 0.014, 0.01, 6, 4), F.mat(Color(0.03, 0.02, 0.02)), Vector3(0.088 * s, -0.055, 0.05))   # eyes
	# the mane: a row of dark tufts along the crest
	for i in 9:
		var t := float(i) / 8.0
		F._part(neck, M.ellipsoid(0.014, 0.07, 0.03, 6, 4), F.mat(dark), Vector3(0, 0.0 + 0.4 * t + 0.1, -0.03 + 0.38 * t), Vector3(0.0, 0, 0))
	# the tail
	var tail := Node3D.new()
	tail.position = Vector3(0, 1.32, -0.88)
	body.add_child(tail)
	F._part(tail, M.tube([Vector3(0, 0, 0), Vector3(0, -0.12, -0.12), Vector3(0, -0.4, -0.18), Vector3(0, -0.7, -0.14)], [0.05, 0.05, 0.04, 0.02], 8), F.mat(dark))
	# legs: front pair at the shoulder, hind pair at the haunch
	var legs_a: Array = []
	for z in [0.55, -0.62]:
		for x in [0.17, -0.17]:
			var up := 0.42 if z > 0.0 else 0.44
			legs_a.append(_leg(body, Vector3(x, 1.12, z), up, 0.42, 0.14, 0.1 if z > 0.0 else 0.115, coat, dark))
	h.set_meta("legs", legs_a)
	h.set_meta("body", body)
	h.set_meta("neck", neck)
	h.set_meta("head", headn)
	h.set_meta("tail", tail)
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
	var body: Node3D = h.get_meta("body")
	var collar := F._cached("horse_collar", func(): return M.lathe([Vector4(0.0, 0.282, 0.352, 0.0), Vector4(0.03, 0.285, 0.355, 0.0)], 18, 1))
	var ring := Node3D.new()
	ring.position = Vector3(0, 0, 0.0)
	body.add_child(ring)
	var cm := F._part(ring, F._cached("horse_collar2", func():
		var fn := func(u: float, v: float) -> Vector3:
			var th := u * TAU
			return Vector3(0.265 * sin(th) * (1.0 + 0.04 * v), 1.25 + 0.33 * cos(th), 0.56 + 0.06 * v - 0.12 * abs(sin(th)) * 0.0)
		return M.surface(16, 1, fn, -1)), F.cloth(strap))
	for i in 3:
		var a := -0.6 + i * 0.6
		F._part(body, M.ellipsoid(0.03, 0.03, 0.01, 8, 4), F.metal(Color(0.9, 0.72, 0.25), 0.8), Vector3(0.265 * sin(a), 1.25 + 0.33 * cos(a) * 0.98 - 0.02, 0.6 + 0.12))
	var headn: Node3D = h.get_meta("head")
	F._part(headn, M.ellipsoid(0.06, 0.012, 0.06, 8, 3), F.cloth(strap), Vector3(0, -0.27, 0.3))
	F._part(headn, M.ellipsoid(0.095, 0.012, 0.09, 8, 3), F.cloth(strap), Vector3(0, 0.0, 0.0))
	F._part(headn, M.ellipsoid(0.022, 0.07, 0.022, 6, 4), F.cloth(plume), Vector3(0, 0.12, -0.02), Vector3(-0.2, 0, 0))


# ---- the ox ----------------------------------------------------------------------------------

## A sacrificial ox: white, gilt horns, a garland and fillets, a dorsuale cloth.
static func make_ox(white := Color(0.94, 0.93, 0.9), garland := true) -> Node3D:
	var ox := Node3D.new()
	var body := Node3D.new()
	ox.add_child(body)
	F._part(body, _barrel(OX_BARREL, "ox_barrel"), F.mat(white))
	var neck := Node3D.new()
	neck.position = Vector3(0, 1.1, 0.7)
	body.add_child(neck)
	F._part(neck, M.tube([Vector3(0, 0.0, -0.1), Vector3(0, -0.02, 0.15), Vector3(0, -0.08, 0.35)], [0.28, 0.24, 0.2], 10), F.mat(white))
	F._part(neck, M.ellipsoid(0.1, 0.22, 0.2, 8, 6), F.mat(white.darkened(0.04)), Vector3(0, -0.26, 0.2))   # dewlap
	var headn := Node3D.new()
	headn.position = Vector3(0, -0.08, 0.35)
	neck.add_child(headn)
	F._part(headn, M.tube([Vector3(0, 0.02, -0.05), Vector3(0, -0.04, 0.15), Vector3(0, -0.1, 0.32)], [0.19, 0.16, 0.12], 10), F.mat(white))
	F._part(headn, M.ellipsoid(0.1, 0.07, 0.1, 8, 5), F.mat(Color(0.86, 0.66, 0.64)), Vector3(0, -0.12, 0.39))   # muzzle
	for s in [-1.0, 1.0]:
		var horn_pts: Array = []
		var horn_r: Array = []
		for i in 6:
			var t := float(i) / 5.0
			horn_pts.append(Vector3(0.14 * s + 0.2 * s * t, 0.05 + 0.15 * t + 0.1 * t * t, 0.0 + 0.0 * t))
			horn_r.append(0.035 * (1.0 - 0.8 * t))
		F._part(headn, F._cached("ox_horn_%d" % int(s), func(): return M.tube(horn_pts, horn_r, 6)), F.metal(Color(0.9, 0.74, 0.28), 0.7), Vector3(0, 0.06, 0.0))
		F._part(headn, M.ellipsoid(0.03, 0.065, 0.025, 6, 4), F.mat(white), Vector3(0.19 * s, 0.05, -0.04), Vector3(0, 0, 0.9 * s))   # ears
		F._part(headn, M.ellipsoid(0.017, 0.017, 0.012, 6, 4), F.mat(Color(0.03, 0.02, 0.02)), Vector3(0.14 * s, 0.0, 0.14))   # eyes
	if garland:
		var pts: Array = []
		var rr: Array = []
		for i in 21:
			var a := float(i) / 20.0 * TAU
			pts.append(Vector3(sin(a) * 0.26, 0.0, cos(a) * 0.22 - 0.05))
			rr.append(0.045 + 0.012 * sin(a * 9.0))
		F._part(neck, F._cached("ox_garland", func(): return M.tube(pts, rr, 7)), F.cloth(Color(0.26, 0.48, 0.2)), Vector3(0, -0.02, 0.1), Vector3(0.35, 0, 0))
		for s in [-1.0, 1.0]:
			F._part(neck, M.ellipsoid(0.012, 0.18, 0.03, 4, 4), F.cloth(Color(0.7, 0.1, 0.12)), Vector3(0.16 * s, -0.2, 0.2), Vector3(0.1, 0, 0.0))
	# the dorsuale cloth
	F._part(body, M.ellipsoid(0.38, 0.03, 0.42), F.cloth(Color(0.55, 0.1, 0.3)), Vector3(0, 1.45, 0.05))
	F._part(body, M.ellipsoid(0.39, 0.012, 0.43), F.metal(Color(0.9, 0.74, 0.28), 0.7), Vector3(0, 1.43, 0.05))
	var tail := Node3D.new()
	tail.position = Vector3(0, 1.05, -0.86)
	body.add_child(tail)
	F._part(tail, M.tube([Vector3(0, 0, 0), Vector3(0, -0.2, -0.08), Vector3(0, -0.55, -0.08)], [0.03, 0.025, 0.02], 6), F.mat(white.darkened(0.08)))
	F._part(tail, M.ellipsoid(0.04, 0.1, 0.04, 6, 4), F.mat(white.darkened(0.15)), Vector3(0, -0.62, -0.08))
	var legs_a: Array = []
	for z in [0.55, -0.55]:
		for x in [0.24, -0.24]:
			legs_a.append(_leg(body, Vector3(x, 0.78, z), 0.3, 0.3, 0.12, 0.105, white, white.darkened(0.25)))
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
