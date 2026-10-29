## A low-poly articulated Roman (U6): smooth capsule limbs with shoulders, elbows, hips, knees
## and ankles, a head with a painted face, hands and feet, 7.5 heads tall (1.75 m), and clothing
## as geometry: tunic with hem and belt, toga with folds, sinus and border, veil, helmets,
## shields, fasces, wreaths. Faces +Z; the origin is at the feet.
##
## Build with F.person(opts) (see the options below) or the old F.make(...). Skeleton nodes:
##   pelvis > torso > neck/head, shoulder[R,L] (= arms) > elbow > wrist (= hand_r, hand_l),
##   pelvis > hip[R,L] (= legs) > knee > ankle.
## Rotation about x: negative swings a limb FORWARD (+z), positive backward. Poses: walk(),
## pose_arms(), kneel(), sit(), hand_to() (two-bone reach), look_yaw(); equip_*() add kit.
## Options for person(): tunic Color, toga bool, border Color, scale, skin Color, bare bool
## (bare-chested), hair Color, veil bool (capite velato), picta bool (toga picta), palmata bool,
## belt Color, shoes Color, sleeves bool, laticlave bool (broad stripe), limus bool, seed int.
extends Node3D

const M := preload("res://scripts/urbs/spectacles/meshlib.gd")
const SKIN := Color(0.86, 0.66, 0.52)

const SH_X := 0.205
const SH_Y := 0.47
const L_UP := 0.29
const L_FORE := 0.25
const THIGH := 0.43
const SHIN := 0.41
const HIP_X := 0.095
const PELVIS_Y := 0.92
const HEAD_Y := 0.58

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}

var pelvis: Node3D
var torso: Node3D
var neck: Node3D
var head: Node3D
var arms: Array[Node3D] = []      # shoulders [right, left]
var elbows: Array[Node3D] = []
var legs: Array[Node3D] = []      # hips [right, left]
var knees: Array[Node3D] = []
var ankles: Array[Node3D] = []
var hand_r: Node3D
var hand_l: Node3D
var opts: Dictionary = {}
var has_long_robe := false
var shield_node: Node3D
var _head_mesh: MeshInstance3D


# ---- materials ------------------------------------------------------------------------

static func mat(c: Color) -> StandardMaterial3D:
	var key := "m" + c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_mats[key] = m
	return _mats[key]


static func cloth(c: Color) -> StandardMaterial3D:
	var key := "c" + c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func metal(c: Color, shine := 0.55) -> StandardMaterial3D:
	var key := "t%s%.2f" % [c.to_html(), shine]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = shine
		m.roughness = 0.38
		_mats[key] = m
	return _mats[key]


static func _blade_mat() -> StandardMaterial3D:
	if not _mats.has("blade"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.86, 0.87, 0.92)
		m.metallic = 0.8
		m.roughness = 0.3
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats["blade"] = m
	return _mats["blade"]


static func face_mat(skin: Color, seed_value: int) -> StandardMaterial3D:
	var key := "f%s%d" % [skin.to_html(), seed_value]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = M.face_texture(skin, seed_value)
		m.roughness = 0.85
		_mats[key] = m
	return _mats[key]


static func _part(parent: Node3D, mesh: Mesh, material: Material, at := Vector3.ZERO, rot := Vector3.ZERO, detail := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if detail:
		mi.visibility_range_end = 28.0   # small parts vanish at a distance (fewer draw calls)
		mi.visibility_range_end_margin = 4.0
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cached(key: String, builder: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = builder.call()
	return _meshes[key]


# ---- the body -------------------------------------------------------------------------

const HEAD_PROFILE := [
	Vector4(0.0, 0.0, 0.0, 0.0), Vector4(0.008, 0.030, 0.034, 0.022), Vector4(0.035, 0.055, 0.068, 0.008),
	Vector4(0.075, 0.072, 0.090, 0.0), Vector4(0.12, 0.078, 0.098, -0.003), Vector4(0.17, 0.079, 0.100, -0.005),
	Vector4(0.21, 0.070, 0.090, -0.005), Vector4(0.235, 0.040, 0.052, -0.004), Vector4(0.2375, 0.0, 0.0, -0.004),
]
const TORSO_PROFILE := [
	Vector4(-0.085, 0.0, 0.0, 0.0), Vector4(-0.07, 0.125, 0.09, 0.0), Vector4(0.0, 0.172, 0.112, 0.0),
	Vector4(0.08, 0.160, 0.105, 0.0), Vector4(0.15, 0.143, 0.096, 0.0), Vector4(0.26, 0.164, 0.106, 0.004),
	Vector4(0.37, 0.178, 0.116, 0.006), Vector4(0.44, 0.19, 0.106, 0.0), Vector4(0.49, 0.14, 0.084, 0.0),
	Vector4(0.53, 0.075, 0.064, 0.0), Vector4(0.56, 0.0, 0.0, 0.0),
]


static func _profile_at(profile: Array, y: float) -> Vector4:
	for i in range(profile.size() - 1):
		var a: Vector4 = profile[i]
		var b: Vector4 = profile[i + 1]
		if y >= a.x and y <= b.x:
			return a.lerp(b, (y - a.x) / maxf(b.x - a.x, 0.0001))
	return profile[profile.size() - 1]


## A person. See the file header for the options.
static func person(o: Dictionary = {}) -> Node3D:
	var f = new()
	f.opts = o
	f._build()
	var sc: float = float(o.get("scale", 1.0))
	f.scale = Vector3.ONE * sc
	return f


## The old constructor: tunic colour, toga, toga border colour, scale, skin.
static func make(tunic: Color, toga := false, stripe := Color(0.55, 0.1, 0.35), scale_ := 1.0, skin := SKIN) -> Node3D:
	return person({"tunic": tunic, "toga": toga, "border": stripe, "scale": scale_, "skin": skin})


func _build() -> void:
	var skin: Color = opts.get("skin", SKIN)
	var tunic: Color = opts.get("tunic", Color(0.8, 0.75, 0.65))
	var bare: bool = opts.get("bare", false)
	var toga: bool = opts.get("toga", false)
	var border: Color = opts.get("border", Color(0.52, 0.1, 0.32))
	var skin_m := mat(skin)
	var seed_v: int = int(opts.get("seed", 0))
	pelvis = Node3D.new()
	pelvis.position = Vector3(0, PELVIS_Y, 0)
	add_child(pelvis)
	torso = Node3D.new()
	pelvis.add_child(torso)
	# torso (skin if bare, else the tunic body)
	var tmesh := _cached("torso", func(): return M.lathe(TORSO_PROFILE, 18))
	_part(torso, tmesh, skin_m if bare else cloth(tunic))
	# neck and head
	neck = Node3D.new()
	neck.position = Vector3(0, 0.50, 0)
	torso.add_child(neck)
	_part(neck, M.capsule(0.048, 0.05, 0.11, 10), skin_m, Vector3(0, 0.12, 0))
	head = Node3D.new()
	head.position = Vector3(0, HEAD_Y, 0)
	torso.add_child(head)
	var hm := _cached("head", func(): return M.lathe_y(HEAD_PROFILE, 24, 30))
	_head_mesh = _part(head, hm, face_mat(skin, seed_v), Vector3(0, 0.03, 0))
	_part(head, M.ellipsoid(0.013, 0.024, 0.02, 8, 5), skin_m, Vector3(0, 0.122, 0.106), Vector3(0.25, 0, 0), true)   # nose
	for s in [-1.0, 1.0]:
		_part(head, M.ellipsoid(0.009, 0.03, 0.02, 8, 5), skin_m, Vector3(0.079 * s, 0.16, -0.005), Vector3.ZERO, true)   # ears
	if not bool(opts.get("veil", false)):
		_part(head, _hair_mesh(), cloth(opts.get("hair", Color(0.17, 0.12, 0.09))), Vector3(0, 0.03, 0))
	# arms
	for si in 2:
		var s := -1.0 if si == 0 else 1.0   # the figure faces +z, so its right side is -x
		var sh := Node3D.new()
		sh.position = Vector3(SH_X * s, SH_Y, 0)
		torso.add_child(sh)
		arms.append(sh)
		_part(sh, M.capsule(0.056, 0.043, L_UP, 10, 0.006), skin_m)
		if not bare and not toga and opts.get("sleeves", true):
			_part(sh, M.capsule(0.059, 0.055, 0.12, 10), cloth(tunic))
		var el := Node3D.new()
		el.position = Vector3(0, -L_UP, 0)
		sh.add_child(el)
		elbows.append(el)
		_part(el, M.capsule(0.041, 0.031, L_FORE, 10, 0.004), skin_m)
		var wr := Node3D.new()
		wr.position = Vector3(0, -L_FORE, 0)
		el.add_child(wr)
		_part(wr, M.ellipsoid(0.038, 0.058, 0.02, 10, 6), skin_m, Vector3(0, -0.055, 0))   # palm
		_part(wr, M.capsule(0.012, 0.01, 0.04, 6), skin_m, Vector3(0.03 * s, -0.045, 0.012), Vector3(0, 0, 0.5 * s), true)   # thumb
		if si == 0:
			hand_r = wr
		else:
			hand_l = wr
	# legs
	var shoe: Color = opts.get("shoes", Color(0.36, 0.24, 0.15))
	for si in 2:
		var s := -1.0 if si == 0 else 1.0
		var hp := Node3D.new()
		hp.position = Vector3(HIP_X * s, 0.0, 0.0)
		pelvis.add_child(hp)
		legs.append(hp)
		_part(hp, M.capsule(0.085, 0.060, THIGH, 12, 0.008), skin_m)
		var kn := Node3D.new()
		kn.position = Vector3(0, -THIGH, 0)
		hp.add_child(kn)
		knees.append(kn)
		_part(kn, M.capsule(0.058, 0.04, SHIN, 12, 0.012), skin_m)
		var an := Node3D.new()
		an.position = Vector3(0, -SHIN, 0)
		kn.add_child(an)
		ankles.append(an)
		_part(an, M.ellipsoid(0.046, 0.034, 0.118, 10, 6), mat(shoe), Vector3(0, -0.02, 0.05))
	# clothes
	if not bare and not toga:
		_tunic_skirt(tunic, opts.get("hem", border.lightened(0.0) if opts.get("hem_band", false) else Color(0, 0, 0, 0)))
	elif bare:
		_loincloth(opts.get("belt", Color(0.5, 0.35, 0.2)), tunic)
	if toga:
		_tunic_skirt(tunic, Color(0, 0, 0, 0), 0.30)
		_toga(opts.get("toga_colour", Color(0.94, 0.92, 0.84)), border, bool(opts.get("picta", false)))
	if opts.get("laticlave", false):
		var sm := _cached("stripe", func(): return _stripe_mesh())
		_part(torso, sm, cloth(border), Vector3(0.0, 0.0, 0.0))
	if not bare and opts.get("belt_on", not toga):
		var bm := _cached("belt", func(): return M.lathe([Vector4(0.115, 0.152, 0.104, 0.0), Vector4(0.115, 0.158, 0.108, 0.0), Vector4(0.15, 0.158, 0.108, 0.0), Vector4(0.15, 0.152, 0.104, 0.0)], 18, 1))
		_part(torso, bm, cloth(opts.get("belt", Color(0.30, 0.2, 0.12))))
	if opts.get("veil", false):
		_veil(opts.get("toga_colour", Color(0.94, 0.92, 0.84)), border)
	if opts.get("laurel", false):
		equip_laurel()
	has_long_robe = toga
	walk(0.0, 0.0)


static func _hair_mesh() -> ArrayMesh:
	return _cached("hair", func():
		var fn := func(u: float, v: float) -> Vector3:
			var th := (u - 0.5) * TAU
			# lower edge: a hairline at the front, the temples, and low at the nape
			var low := lerpf(0.178, 0.07, smoothstep(0.55, 2.7, absf(th)))
			var y := lerpf(low, 0.2375, v)
			var pr := _profile_at(HEAD_PROFILE, minf(y, 0.2374))
			var k := 1.05 + 0.03 * sin(v * PI)
			return Vector3(pr.y * k * sin(th), y + 0.004 * v, pr.z * k * cos(th) + pr.w - 0.003)
		return M.surface(24, 8, fn, -1))


func _stripe_mesh() -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var y := lerpf(0.5, -0.08, v)
		var pr := _profile_at(TORSO_PROFILE, clampf(y, -0.07, 0.55))
		var x := lerpf(-0.022, 0.022, u)
		return Vector3(x, y, pr.z * 1.04 + pr.w)
	return M.surface(2, 6, fn, 1)


func _tunic_skirt(col: Color, hem: Color, length := 0.34) -> void:
	var prof := [Vector4(0.06, 0.0, 0.0, 0.0), Vector4(0.06, 0.168, 0.118, 0.0), Vector4(-0.05, 0.19, 0.13, 0.0),
		Vector4(-length * 0.6, 0.215, 0.155, 0.0), Vector4(-length, 0.235, 0.175, 0.0)]
	var key := "skirt%.2f" % length
	var sm := _cached(key, func(): return M.lathe(prof, 20, 1))
	_part(pelvis, sm, cloth(col))
	if hem.a > 0.0:
		var hm := _cached("hem%.2f" % length, func(): return M.lathe([Vector4(-length + 0.045, 0.2285, 0.1685, 0.0), Vector4(-length, 0.236, 0.176, 0.0)], 20, 1))
		_part(pelvis, hm, cloth(hem))


func _loincloth(belt: Color, cloth_col: Color) -> void:
	var prof := [Vector4(0.05, 0.172, 0.122, 0.0), Vector4(-0.05, 0.2, 0.145, 0.0), Vector4(-0.2, 0.225, 0.16, 0.0)]
	_part(pelvis, _cached("loin", func(): return M.lathe(prof, 18, 1)), cloth(cloth_col))
	var bm := _cached("belt2", func(): return M.lathe([Vector4(0.1, 0.172, 0.118, 0.0), Vector4(0.15, 0.172, 0.118, 0.0)], 18, 1))
	_part(torso, bm, cloth(belt))


func _toga(col: Color, border: Color, picta: bool) -> void:
	var body := col
	var trim := border
	if picta:
		body = Color(0.42, 0.1, 0.45)
		trim = Color(0.9, 0.72, 0.2)
	# the skirt, with long folds
	var sk := _cached("toga_skirt", func():
		var fn := func(u: float, v: float) -> Vector3:
			var th := (u - 0.5) * TAU
			var y := lerpf(0.03, -0.80, v)
			var rb := lerpf(0.20, 0.285, v)
			var fold := 1.0 + 0.06 * sin(9.0 * th + v * 2.5) * (0.25 + 0.75 * v)
			return Vector3(rb * 1.05 * fold * sin(th), y, rb * 0.9 * fold * cos(th) + 0.01)
		return M.surface(28, 10, fn, 1))
	_part(pelvis, sk, cloth(body))
	var skb := _cached("toga_skirt_b", func():
		var fn := func(u: float, v: float) -> Vector3:
			var th := (u - 0.5) * TAU
			var vv := lerpf(0.93, 1.0, v)
			var y := lerpf(0.03, -0.80, vv)
			var rb := lerpf(0.20, 0.285, vv)
			var fold := 1.0 + 0.06 * sin(9.0 * th + vv * 2.5) * (0.25 + 0.75 * vv)
			return Vector3(rb * 1.055 * fold * sin(th), y, rb * 0.905 * fold * cos(th) + 0.01)
		return M.surface(28, 2, fn, 1))
	_part(pelvis, skb, cloth(trim))
	# the chest: a diagonal wrap from the right hip over the left shoulder
	var chest := _cached("toga_chest", func():
		var fn := func(u: float, v: float) -> Vector3:
			var th := (u - 0.5) * TAU
			var top := 0.31 - 0.20 * sin(th)
			var y := lerpf(-0.02, top, v)
			var pr := _profile_at(TORSO_PROFILE, clampf(y, -0.07, 0.54))
			var rip := 1.0 + 0.05 * sin(6.0 * th + y * 11.0)
			return Vector3((pr.y * 1.07 + 0.012) * rip * sin(th), y, (pr.z * 1.07 + 0.012) * rip * cos(th) + pr.w)
		return M.surface(28, 8, fn, 1))
	_part(torso, chest, cloth(body))
	var edge := _cached("toga_edge", func():
		var fn := func(u: float, v: float) -> Vector3:
			var th := (u - 0.5) * TAU
			var top := 0.31 - 0.20 * sin(th)
			var y := lerpf(top - 0.045, top, v)
			var pr := _profile_at(TORSO_PROFILE, clampf(y, -0.07, 0.54))
			var rip := 1.0 + 0.05 * sin(6.0 * th + y * 11.0)
			return Vector3((pr.y * 1.075 + 0.013) * rip * sin(th), y, (pr.z * 1.075 + 0.013) * rip * cos(th) + pr.w)
		return M.surface(28, 2, fn, 1))
	_part(torso, edge, cloth(trim))
	# the left shoulder and arm covered
	_part(arms[1], M.capsule(0.066, 0.062, 0.22, 10), cloth(body))
	# the sinus: a hanging fold across the front
	var sinus := _cached("toga_sinus", func():
		var fn := func(u: float, v: float) -> Vector3:
			var x := lerpf(-0.21, 0.10, u)
			var yb := 0.02 - 0.12 * sin(u * PI * 0.9)
			var y := lerpf(0.40 - 0.18 * u, yb, v)
			var z := 0.128 + 0.035 * sin(u * 9.0 + v * 2.0) * v + 0.03 * (1.0 - v)
			return Vector3(x, y, z)
		return M.surface(10, 6, fn, -1))
	_part(torso, sinus, cloth(body))
	var sinus_b := _cached("toga_sinus_b", func():
		var fn := func(u: float, v: float) -> Vector3:
			var x := lerpf(-0.21, 0.10, u)
			var yb := 0.02 - 0.12 * sin(u * PI * 0.9)
			var yt := 0.40 - 0.18 * u
			var y := lerpf(yb + 0.04, yb, v)
			var z := 0.128 + 0.035 * sin(u * 9.0 + 1.0 * 2.0)
			return Vector3(x, y, z + 0.004)
		return M.surface(10, 1, fn, -1))
	_part(torso, sinus_b, cloth(trim))


func _veil(col: Color, border: Color) -> void:
	# the toga drawn over the head (capite velato): from the crown down over the shoulders
	var vm := _cached("veil", func():
		var fn := func(u: float, v: float) -> Vector3:
			var th := (u - 0.5) * TAU
			var front := cos(th) * 0.5 + 0.5   # 1 at the face
			var low := lerpf(-0.17, 0.17, front * front)
			low = lerpf(low, 0.06, smoothstep(0.0, 0.45, front) * 0.0)
			var y := lerpf(low, 0.255, v)
			var pr := _profile_at(HEAD_PROFILE, clampf(y, 0.0, 0.236))
			var drop := clampf((0.1 - y) / 0.27, 0.0, 1.0)
			var k := 1.07 + 0.9 * drop * (1.0 - front * 0.6)
			var rx := maxf(pr.y, 0.06) * k
			var rz := maxf(pr.z, 0.07) * k
			return Vector3(rx * sin(th), y, rz * cos(th) + pr.w * 0.5)
		return M.surface(26, 10, fn, 1))
	_part(head, vm, cloth(col), Vector3(0, 0.03, 0))


# ---- poses ------------------------------------------------------------------------------

## Walk (and run) cycle. `phase` in radians, advance by distance walked / stride. amp 0 stands.
func walk(phase: float, amp := 1.0, run := 0.0) -> void:
	var a := amp * (1.0 + run * 0.8)
	if has_long_robe:
		a *= 0.6
	var s := sin(phase)
	var c := cos(phase)
	var swing := 0.5 * a
	for i in 2:
		var ph := phase + (PI if i == 1 else 0.0)
		var sw := sin(ph) * swing
		legs[i].rotation = Vector3(sw, 0.0, 0.0)
		# the knee bends while the leg swings forward
		var kb := maxf(0.0, -cos(ph)) * (0.75 + 0.5 * run) * a + 0.06 * a
		knees[i].rotation = Vector3(kb, 0, 0)
		ankles[i].rotation = Vector3(-(sw + kb) * 0.8 + 0.15 * maxf(0.0, sin(ph)) * a, 0, 0)
		var sg := -1.0 if i == 0 else 1.0   # arms swing opposite the same-side leg
		var armr := -sin(ph) * 0.45 * a * (1.0 if i == 0 else 1.0)
		arms[i].rotation = Vector3(armr, 0.0, 0.05 * (1.0 if i == 0 else -1.0))
		elbows[i].rotation = Vector3(-(0.22 + 0.45 * maxf(0.0, -armr) + run * 0.8) * clampf(a, 0.0, 1.5), 0, 0)
	pelvis.position.y = PELVIS_Y - 0.03 * a * (0.5 - 0.5 * cos(2.0 * phase))
	pelvis.rotation = Vector3(0, -0.10 * s * amp, 0.025 * c * amp)
	torso.rotation = Vector3(0.12 * run * amp, 0.14 * s * amp, -0.02 * c * amp)
	head.rotation = Vector3(-0.03 * a, -0.14 * s * amp, 0)


## Both arms by shoulder pitch (negative = forward/up), optional spread (out to the side) and
## elbow bend (default follows the pitch).
func pose_arms(right: float, left: float, spread_r := 0.0, spread_l := 0.0, bend_r := -1.0, bend_l := -1.0) -> void:
	var pitches := [right, left]
	var spreads := [spread_r, spread_l]
	var bends := [bend_r, bend_l]
	for i in 2:
		var p: float = pitches[i]
		var sgn := -1.0 if i == 0 else 1.0
		arms[i].rotation = Vector3(p, 0.0, spreads[i] * sgn)
		var b: float = bends[i]
		if b < 0.0:
			b = 0.12 + 0.55 * sin(clampf(absf(p), 0.0, PI)) * 0.85
		elbows[i].rotation = Vector3(-b, 0, 0)


## Kneel on one knee (amount 0..1).
func kneel(a: float, right_front := true) -> void:
	var f := 0 if right_front else 1
	var r := 1 - f
	pelvis.position.y = lerpf(PELVIS_Y, SHIN + 0.075, a)
	legs[f].rotation = Vector3(-1.5 * a, 0, 0)
	knees[f].rotation = Vector3(1.5 * a, 0, 0)
	ankles[f].rotation = Vector3(0.0, 0, 0)
	legs[r].rotation = Vector3(0.12 * a, 0, 0)
	knees[r].rotation = Vector3(1.6 * a, 0, 0)
	ankles[r].rotation = Vector3(0.6 * a, 0, 0)
	torso.rotation = Vector3(0.12 * a, 0, 0)
	pelvis.rotation = Vector3.ZERO


## Sit on a bench (amount 0..1): the feet origin stays on the floor; raise the figure by the
## bench height yourself.
func sit(a: float) -> void:
	pelvis.position.y = lerpf(PELVIS_Y, SHIN + 0.075, a)
	for i in 2:
		legs[i].rotation = Vector3(-1.52 * a, 0, 0.04 * a * (1.0 if i == 0 else -1.0))
		knees[i].rotation = Vector3(1.5 * a, 0, 0)
		ankles[i].rotation = Vector3(0.0, 0, 0)
	if a > 0.01:
		arms[0].rotation = Vector3(-0.35 * a, 0, 0)
		arms[1].rotation = Vector3(-0.35 * a, 0, 0)
		elbows[0].rotation = Vector3(-0.9 * a, 0, 0)
		elbows[1].rotation = Vector3(-0.9 * a, 0, 0)
	pelvis.rotation = Vector3.ZERO
	torso.rotation = Vector3.ZERO


## Turn the head (radians) and nod.
func look_yaw(yaw: float, pitch := 0.0) -> void:
	head.rotation = Vector3(pitch, yaw, 0)


## Two-bone reach: put the hand (side 0 right, 1 left) at `target` (in the torso's frame) with
## the elbow bent outward and down. Overrides the shoulder and elbow rotations.
func hand_to(side: int, target: Vector3) -> void:
	var sgn := -1.0 if side == 0 else 1.0
	var sh_pos := Vector3(SH_X * (-1.0 if side == 0 else 1.0), SH_Y, 0.0)
	var d := target - sh_pos
	var dist := clampf(d.length(), 0.12, L_UP + L_FORE - 0.01)
	var dir := d.normalized()
	var cos_e := clampf((L_UP * L_UP + L_FORE * L_FORE - dist * dist) / (2.0 * L_UP * L_FORE), -1.0, 1.0)
	var bend := PI - acos(cos_e)
	var alpha := acos(clampf((L_UP * L_UP + dist * dist - L_FORE * L_FORE) / (2.0 * L_UP * dist), -1.0, 1.0))
	var pole := Vector3(0.6 * (-1.0 if side == 0 else 1.0), -0.7, -0.3).normalized()
	var axis := dir.cross(pole)
	if axis.length() < 0.001:
		axis = Vector3.RIGHT
	axis = axis.normalized()
	var up_a := dir.rotated(axis, alpha)
	var up_b := dir.rotated(axis, -alpha)
	var upper := up_a if up_a.dot(pole) > up_b.dot(pole) else up_b
	var ang := alpha if up_a.dot(pole) > up_b.dot(pole) else -alpha
	# the upper arm hangs along local -y; local x = axis (perpendicular to the arm's plane)
	var y_axis := -upper
	var x_axis := axis
	var z_axis := x_axis.cross(y_axis).normalized()
	x_axis = y_axis.cross(z_axis).normalized()
	arms[side].basis = Basis(x_axis, y_axis, z_axis)
	# the forearm bends about local x: pick the sign that brings the wrist to the target
	var f1 := upper.rotated(axis, bend)
	var f2 := upper.rotated(axis, -bend)
	var w1 := sh_pos + upper * L_UP + f1 * L_FORE
	var w2 := sh_pos + upper * L_UP + f2 * L_FORE
	var e := bend if w1.distance_to(target) < w2.distance_to(target) else -bend
	elbows[side].rotation = Vector3(e, 0, 0)


# ---- kit ------------------------------------------------------------------------------

## A laurel wreath on the head.
func equip_laurel(col := Color(0.28, 0.5, 0.2)) -> void:
	var wm := _cached("laurel", func():
		var pts: Array = []
		var radii: Array = []
		for i in 25:
			var a := float(i) / 24.0 * TAU * 0.92 + 0.2
			pts.append(Vector3(sin(a) * 0.088, 0.0 + 0.012 * sin(a * 6.0), cos(a) * 0.1 - 0.004))
			radii.append(0.011 + 0.005 * sin(a * 12.0))
		return M.tube(pts, radii, 6))
	_part(head, wm, cloth(col), Vector3(0, 0.195, 0))


## A helmet. kind: "samnis" (crested, visored), "thraex" (broad-brimmed, griffin crest),
## "gallus" (cheek-plated), "leather" (a charioteer's cap).
func equip_helmet(kind := "samnis", metal_col := Color(0.72, 0.6, 0.3), crest_col := Color(0.72, 0.1, 0.1)) -> void:
	var mm := metal(metal_col)
	if kind == "leather":
		_part(head, M.ellipsoid(0.092, 0.07, 0.105, 12, 6), mat(metal_col), Vector3(0, 0.205, 0.0))
		_part(head, M.ellipsoid(0.02, 0.03, 0.02, 6, 4), cloth(crest_col), Vector3(0, 0.272, 0.0))
		return
	var dome := _cached("helm_dome", func():
		var prof := [Vector4(0.0, 0.098, 0.112, 0.0), Vector4(0.03, 0.094, 0.108, 0.0), Vector4(0.07, 0.080, 0.094, 0.0), Vector4(0.1, 0.048, 0.056, 0.0), Vector4(0.115, 0.0, 0.0, 0.0)]
		return M.lathe(prof, 20))
	_part(head, dome, mm, Vector3(0, 0.185, -0.004))
	_part(head, M.lathe([Vector4(0.0, 0.1, 0.118, 0.0), Vector4(0.012, 0.1, 0.118, 0.0)], 20, 1), mm, Vector3(0, 0.182, -0.004))   # rim
	# neck guard at the back
	var guard := _cached("helm_guard", func():
		var fn := func(u: float, v: float) -> Vector3:
			var th := lerpf(PI * 0.35, PI * 1.65, u) + PI
			return Vector3(0.11 * sin(th), lerpf(0.0, -0.06, v), 0.13 * cos(th) * 0.9 - 0.005 + 0.03 * v * -cos(th))
		return M.surface(10, 2, fn, -1))
	_part(head, guard, mm, Vector3(0, 0.19, 0))
	var crest := _cached("crest_" + kind, func():
		var fn := func(u: float, v: float) -> Vector3:
			# a comb along the head, front to back; v is the height
			var z := lerpf(0.1, -0.12, u)
			var h := (0.06 + 0.07 * sin(u * PI)) * (1.0 if kind != "gallus" else 0.6)
			if kind == "thraex":
				h = 0.05 + 0.16 * pow(sin(u * PI), 0.8)
			return Vector3(lerpf(-0.012, 0.012, v), v * h, z)
		return M.surface(10, 3, fn, -1))
	_part(head, crest, cloth(crest_col), Vector3(0, 0.285, 0))
	_part(head, crest, cloth(crest_col), Vector3(0, 0.285, 0), Vector3(0, 0, 0))
	if kind == "samnis" or kind == "thraex":
		# a visor: a plate over the face with two eye slits
		var visor := _cached("visor_" + kind, func():
			var fn := func(u: float, v: float) -> Vector3:
				var th := lerpf(-0.9, 0.9, u)
				var y := lerpf(-0.02, 0.1, v)
				return Vector3(0.108 * sin(th), y, 0.122 * cos(th) + 0.012)
			return M.surface(10, 4, fn, -1))
		_part(head, visor, mm, Vector3(0, 0.13, 0.0))
		for s in [-1.0, 1.0]:
			_part(head, M.ellipsoid(0.017, 0.006, 0.006, 6, 4), mat(Color(0.04, 0.03, 0.03)), Vector3(0.04 * s, 0.158, 0.142))
	else:
		# cheek plates
		for s in [-1.0, 1.0]:
			_part(head, M.ellipsoid(0.008, 0.055, 0.045, 6, 5), mm, Vector3(0.085 * s, 0.1, 0.045), Vector3(0, 0.0, 0.0))
	if kind == "thraex":
		_part(head, M.ellipsoid(0.13, 0.008, 0.14, 14, 3), mm, Vector3(0, 0.195, 0.0))   # broad brim


## A shield held in front of the left side of the body, following the left hand (hand_to).
## kind: "scutum" (tall curved oblong), "long" (the Gallus's tall oval), "parma" (small square),
## "round". Returns the shield node, a child of the torso; move it and call hand_to().
func equip_shield(kind := "scutum", col := Color(0.62, 0.2, 0.15)) -> Node3D:
	var sh := Node3D.new()
	torso.add_child(sh)
	sh.position = Vector3(0.17, 0.2, 0.25)
	shield_node = sh
	var w := 0.46
	var h := 0.80
	var curve := 0.14
	match kind:
		"long":
			w = 0.42
			h = 0.95
			curve = 0.09
		"parma":
			w = 0.36
			h = 0.36
			curve = 0.03
		"round":
			w = 0.62
			h = 0.62
			curve = 0.05
	var key := "shield_%s_%.2f" % [kind, w]
	var body := _cached(key, func():
		var fn := func(u: float, v: float) -> Vector3:
			var x := lerpf(-w / 2.0, w / 2.0, u)
			var y := lerpf(-h / 2.0, h / 2.0, v)
			var xx := x
			var yy := y
			if kind == "long" or kind == "round":
				# an oval outline: scale the corners in
				var e := sqrt(pow(2.0 * u - 1.0, 2.0) + pow(2.0 * v - 1.0, 2.0))
				var k := 1.0 / maxf(1.0, e) if kind == "round" else 1.0 / maxf(1.0, e * 0.75)
				xx = x * lerpf(1.0, k, 0.5)
				yy = y * lerpf(1.0, k, 0.5)
			var z := curve * (1.0 - pow(2.0 * u - 1.0, 2.0)) * -1.0 + curve
			return Vector3(xx, yy, z * 0.8)
		return M.surface(10, 8, fn, -1))
	_part(sh, body, cloth(col))
	# the rim, boss and spine
	_part(sh, M.ellipsoid(0.07, 0.07, 0.04, 10, 6), metal(Color(0.8, 0.68, 0.32)), Vector3(0, 0, curve * 0.8 + 0.02))
	if kind == "scutum" or kind == "long":
		_part(sh, M.ellipsoid(0.014, h * 0.5, 0.02, 6, 6), metal(Color(0.78, 0.66, 0.3)), Vector3(0, 0, curve * 0.8 + 0.01))
		for sy in [-1.0, 1.0]:
			_part(sh, M.ellipsoid(w * 0.46, 0.014, 0.014, 8, 4), metal(Color(0.78, 0.66, 0.3)), Vector3(0, sy * (h / 2.0 - 0.02), curve * 0.4))
	else:
		_part(sh, M.ellipsoid(w * 0.5, 0.016, 0.014, 8, 4), metal(Color(0.78, 0.66, 0.3)), Vector3(0, h / 2.0, curve * 0.3))
	return sh


## A sword in the right hand: "gladius" straight, "sica" curved. The blade continues the arm.
func equip_sword(kind := "gladius") -> Node3D:
	var sw := Node3D.new()
	hand_r.add_child(sw)
	sw.position = Vector3(0, -0.06, 0)
	_part(sw, M.capsule(0.014, 0.012, 0.09, 6), mat(Color(0.3, 0.2, 0.12)), Vector3(0, 0.04, 0))   # grip
	_part(sw, M.ellipsoid(0.014, 0.01, 0.035, 6, 4), metal(Color(0.8, 0.68, 0.3)), Vector3(0, -0.06, 0))   # pommel
	_part(sw, M.ellipsoid(0.07, 0.008, 0.014, 8, 3), metal(Color(0.8, 0.68, 0.3)), Vector3(0, -0.095, 0))   # guard
	var bm := _cached("blade_" + kind, func():
		var fn := func(u: float, v: float) -> Vector3:
			var y := -0.1 - v * (0.55 if kind == "gladius" else 0.5)
			var w := 0.036 * (1.0 - 0.75 * pow(v, 3.0))
			var x := lerpf(-w, w, u)
			var curve := 0.0 if kind == "gladius" else 0.14 * v * v
			var thick := 0.012 * (1.0 - absf(2.0 * u - 1.0))
			return Vector3(x, y, curve + thick)
		return M.surface(4, 8, fn, -1))
	_part(sw, bm, _blade_mat())
	return sw


## A knife for the victimarius (or a charioteer's falx).
func equip_knife() -> Node3D:
	var k := Node3D.new()
	hand_r.add_child(k)
	k.position = Vector3(0, -0.06, 0)
	_part(k, M.capsule(0.014, 0.012, 0.08, 6), mat(Color(0.3, 0.2, 0.12)), Vector3(0, 0.03, 0))
	_part(k, M.ellipsoid(0.016, 0.13, 0.006, 6, 5), metal(Color(0.85, 0.86, 0.9), 0.8), Vector3(0, -0.2, 0.0))
	return k


## A greave on the shin (side 0 right, 1 left), `high` reaches over the knee.
func equip_greave(side: int, high := false, col := Color(0.72, 0.6, 0.3)) -> void:
	var ln := SHIN * (0.95 if high else 0.78)
	_part(knees[side], M.capsule(0.064, 0.05, ln, 12, 0.003), metal(col), Vector3(0, 0.02 if high else -0.04, 0.0))


## An armoured sleeve (manica) on the right arm: segmented rings.
func equip_manica(col := Color(0.7, 0.62, 0.35)) -> void:
	for i in 4:
		_part(arms[0], M.capsule(0.06, 0.059, 0.05, 10), metal(col), Vector3(0, -0.04 - i * 0.065, 0))
	for i in 3:
		_part(elbows[0], M.capsule(0.048, 0.046, 0.05, 10), metal(col), Vector3(0, -0.02 - i * 0.07, 0))


## Gladiator kit by armature: "samnis", "thraex", "gallus". Returns the shield.
func equip_kit(armature: String) -> Node3D:
	var sh: Node3D
	match armature:
		"samnis":
			equip_helmet("samnis", Color(0.74, 0.62, 0.3), Color(0.72, 0.1, 0.1))
			sh = equip_shield("scutum", Color(0.55, 0.18, 0.12))
			equip_greave(1, false)
			equip_manica()
			equip_sword("gladius")
		"thraex":
			equip_helmet("thraex", Color(0.66, 0.56, 0.3), Color(0.1, 0.5, 0.2))
			sh = equip_shield("parma", Color(0.6, 0.48, 0.18))
			equip_greave(0, true)
			equip_greave(1, true)
			equip_sword("sica")
		_:
			equip_helmet("gallus", Color(0.72, 0.72, 0.75), Color(0.15, 0.2, 0.6))
			sh = equip_shield("long", Color(0.2, 0.34, 0.55))
			equip_sword("gladius")
	return sh


## Fasces: a bundle of rods bound with red straps and an axe, held in the right hand.
func equip_fasces() -> Node3D:
	var fs := Node3D.new()
	hand_r.add_child(fs)
	fs.position = Vector3(0, -0.05, 0)
	var rods := _cached("fasces_rods", func():
		var prof: Array = []
		prof.append(Vector4(-0.62, 0.0, 0.0, 0.0))
		prof.append(Vector4(-0.6, 0.038, 0.038, 0.0))
		for i in 8:
			var y := -0.6 + float(i) / 7.0 * 1.2
			prof.append(Vector4(y, 0.046 + 0.004 * sin(i * 2.0), 0.046 + 0.004 * sin(i * 2.0), 0.0))
		prof.append(Vector4(0.6, 0.038, 0.038, 0.0))
		prof.append(Vector4(0.62, 0.0, 0.0, 0.0))
		return M.lathe(prof, 12))
	_part(fs, rods, mat(Color(0.62, 0.5, 0.3)), Vector3(0, 0.15, 0))
	var strap := _cached("fasces_strap", func(): return M.lathe([Vector4(-0.012, 0.05, 0.05, 0.0), Vector4(0.012, 0.05, 0.05, 0.0)], 12, 1))
	for i in 4:
		_part(fs, strap, cloth(Color(0.7, 0.1, 0.1)), Vector3(0, -0.3 + i * 0.28, 0))
	var axe := _cached("fasces_axe", func():
		var fn := func(u: float, v: float) -> Vector3:
			var x := lerpf(0.0, 0.17, u) * (0.6 + 0.4 * sin(v * PI * 0.5 + 0.8) )
			var y := lerpf(-0.1, 0.1, v) * (1.0 + 0.9 * u)
			return Vector3(x, y, lerpf(-0.004, 0.004, 0.5))
		return M.surface(4, 6, fn, -1))
	_part(fs, axe, metal(Color(0.8, 0.82, 0.86), 0.8), Vector3(0.04, 0.5, 0.0))
	fs.rotation = Vector3(0.0, 0.0, 0.0)
	return fs


## A tuba (a long straight trumpet) held at the mouth in the right hand.
func equip_tuba() -> Node3D:
	var t := Node3D.new()
	hand_r.add_child(t)
	var tm := _cached("tuba", func():
		var prof: Array = [Vector4(0.0, 0.0, 0.0, 0.0)]
		for i in 11:
			var y := float(i) / 10.0 * 1.35
			var r := 0.012 + (0.012 if i < 8 else 0.012 + (float(i) - 7.0) * 0.045)
			prof.append(Vector4(y, r, r, 0.0))
		prof.append(Vector4(1.36, 0.0, 0.0, 0.0))
		return M.lathe(prof, 10))
	_part(t, tm, metal(Color(0.85, 0.66, 0.2), 0.8), Vector3(0, 0.1, 0.0), Vector3(-PI / 2.0, 0, 0))
	t.position = Vector3(0, -0.04, 0)
	return t


## A staff-like ivory sceptre with an eagle (the general's), in the left hand.
func equip_sceptre() -> Node3D:
	var s := Node3D.new()
	hand_l.add_child(s)
	_part(s, M.capsule(0.014, 0.014, 0.9, 6), mat(Color(0.92, 0.88, 0.76)), Vector3(0, 0.45, 0))
	_part(s, M.ellipsoid(0.04, 0.045, 0.06, 8, 6), metal(Color(0.9, 0.75, 0.25), 0.8), Vector3(0, 0.98, 0))
	_part(s, M.ellipsoid(0.1, 0.012, 0.035, 8, 3), metal(Color(0.9, 0.75, 0.25), 0.8), Vector3(0, 0.975, 0))
	return s


## A laurel branch in the right hand.
func equip_branch() -> Node3D:
	var b := Node3D.new()
	hand_r.add_child(b)
	_part(b, M.capsule(0.012, 0.01, 0.5, 6), mat(Color(0.4, 0.3, 0.18)), Vector3(0, 0.1, 0))
	for i in 7:
		_part(b, M.ellipsoid(0.02, 0.05, 0.008, 6, 4), cloth(Color(0.26, 0.5, 0.2)), Vector3(0.02 * (1.0 if i % 2 == 0 else -1.0), 0.15 + i * 0.065, 0.0), Vector3(0, 0, 0.7 * (1.0 if i % 2 == 0 else -1.0)))
	return b


## A pilum or spear in the right hand.
func equip_spear() -> Node3D:
	var s := Node3D.new()
	hand_r.add_child(s)
	_part(s, M.capsule(0.012, 0.012, 1.7, 6), mat(Color(0.5, 0.36, 0.2)), Vector3(0, 0.6, 0))
	_part(s, M.ellipsoid(0.02, 0.1, 0.006, 6, 4), metal(Color(0.8, 0.82, 0.86), 0.8), Vector3(0, 1.4, 0))
	return s


## The sacrificial mallet or axe (popa).
func equip_mallet() -> Node3D:
	var m := Node3D.new()
	hand_r.add_child(m)
	_part(m, M.capsule(0.016, 0.016, 0.6, 6), mat(Color(0.45, 0.3, 0.15)), Vector3(0, 0.12, 0))
	_part(m, M.ellipsoid(0.07, 0.07, 0.07, 8, 6), metal(Color(0.45, 0.45, 0.48), 0.5), Vector3(0, -0.5, 0))
	return m


## Two pipes (tibiae) held at the mouth.
func equip_pipes() -> Node3D:
	var p := Node3D.new()
	head.add_child(p)
	for s in [-1.0, 1.0]:
		_part(p, M.capsule(0.01, 0.011, 0.5, 6), mat(Color(0.35, 0.25, 0.12)), Vector3(0.025 * s, 0.07, 0.25), Vector3(-PI / 2.0 - 0.15, 0.0, 0.12 * s))
	return p


## The limus: a linen apron with a purple border worn by the victimarius.
func equip_limus() -> void:
	var lm := _cached("limus", func():
		var fn := func(u: float, v: float) -> Vector3:
			var th := lerpf(-1.0, 1.0, u)
			var y := lerpf(0.1, -0.34, v)
			return Vector3(0.2 * sin(th) * (1.0 + 0.2 * v), y, 0.145 * cos(th) * (1.0 + 0.2 * v) + 0.02 + 0.015 * sin(v * 9.0))
		return M.surface(10, 6, fn, -1))
	_part(pelvis, lm, cloth(Color(0.94, 0.92, 0.86)))
	var lb := _cached("limus_b", func():
		var fn := func(u: float, v: float) -> Vector3:
			var th := lerpf(-1.0, 1.0, u)
			var y := lerpf(-0.31, -0.34, v)
			return Vector3(0.24 * sin(th), y, 0.174 * cos(th) + 0.035)
		return M.surface(10, 1, fn, -1))
	_part(pelvis, lb, cloth(Color(0.52, 0.1, 0.32)))


## Tint the face (the general's red-painted face).
func paint_face(c: Color) -> void:
	_head_mesh.material_override = face_mat(c, int(opts.get("seed", 0)))


## A coloured box mesh (for stand-ins and simple props).
static func box(parent: Node3D, size: Vector3, at: Vector3, col: Color) -> MeshInstance3D:
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


## Turn the figure so its front (+z) points along `dir` (a horizontal vector).
static func face(node: Node3D, dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.0001:
		node.rotation.y = atan2(dir.x, dir.z)
