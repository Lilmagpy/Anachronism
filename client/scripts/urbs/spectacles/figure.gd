## A low-poly articulated Roman (U6): smooth capsule limbs with shoulders, elbows, hips, knees
## and ankles, a head with a painted face, hands and feet, 7.5 heads tall (1.75 m), and clothing
## as geometry: tunic with hem and belt, toga with folds, sinus and border, veil, helmets,
## shields, fasces, wreaths. Faces +Z; the origin is at the feet.
##
## Performance: the body is baked into ONE skinned mesh per level of detail (rig.gd); the
## Node3D bones below only carry the pose, which is copied to the GPU skeleton each frame.
## Kit that does not bend (shield, sword, fasces ...) is one merged mesh per item.
##
## Build with F.person(opts) or the old F.make(...). Skeleton nodes:
##   pelvis > torso > head, shoulder[R,L] (= arms) > elbow > wrist (= hand_r, hand_l),
##   pelvis > hip[R,L] (= legs) > knee > ankle.
## Rotation about x: negative swings a limb FORWARD (+z), positive backward. Poses: walk(),
## pose_arms(), kneel(), sit(), hand_to() (two-bone reach), look_yaw(); equip_*() add kit.
## Options for person(): tunic Color, toga bool, border Color, toga_colour, scale, skin Color,
## bare bool (bare-chested), hair Color, veil bool (capite velato), picta bool (toga picta),
## belt Color, shoes Color, sleeves bool, laticlave bool, laurel bool, hem Color + hem_band bool,
## belt_on bool, seed int. U8 street life adds: stola bool (a matron: tunic to the ankles with a
## palla wrapped over it, palla Color; Horace Sat. 1.2.29, 99, read), pilleus bool (the freedman's
## felt cap, Livy 30.45.5 and 45.44.19, read), long bool (an ankle-length tunic without palla).
extends Node3D

const M := preload("res://scripts/urbs/spectacles/meshlib.gd")
const R := preload("res://scripts/urbs/spectacles/rig.gd")
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
var rig: Node
# bone indices
var b_pelvis := 0
var b_torso := 1
var b_head := 2
var b_sh: Array[int] = []
var b_el: Array[int] = []
var b_wr: Array[int] = []
var b_hip: Array[int] = []
var b_kn: Array[int] = []
var b_an: Array[int] = []


# ---- materials for scenery props (the people use the rig shader) ------------------------------

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


static func _part(parent: Node3D, mesh: Mesh, material: Material, at := Vector3.ZERO, rot := Vector3.ZERO, _detail := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
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


# ---- part builders for the rig (each returns fn(lod) -> mesh) --------------------------------

static func fcap(r0: float, r1: float, length: float, belly := 0.0, flat := 1.0) -> Callable:
	return func(lod: int) -> ArrayMesh: return M.capsule(r0, r1, length, 10 if lod == 0 else 6, belly, flat)


static func fell(rx: float, ry: float, rz: float, detail := false) -> Callable:
	return func(lod: int) -> ArrayMesh:
		if detail and lod > 0:
			return null
		return M.ellipsoid(rx, ry, rz, 12 if lod == 0 else 7, 7 if lod == 0 else 4)


static func flathe(profile: Array, nu := 18, orient := 0) -> Callable:
	return func(lod: int) -> ArrayMesh: return M.lathe(profile, nu if lod == 0 else maxi(8, nu / 2), orient)


static func fmesh(builder: Callable) -> Callable:
	return func(_lod: int) -> ArrayMesh: return builder.call()


static func _xf(at := Vector3.ZERO, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot), at)


## Add a baked body part on a bone.
func _bp(bone: int, key: String, fn: Callable, at := Vector3.ZERO, rot := Vector3.ZERO, slot := 5, col := Color.WHITE, metal_v := 0.0) -> void:
	rig.add_part(bone, key, fn, _xf(at, rot), slot, col, metal_v)


## A rigid part for R.rigid.
static func rp(key: String, fn: Callable, at := Vector3.ZERO, rot := Vector3.ZERO, slot := 5, col := Color.WHITE, metal_v := 0.0) -> Dictionary:
	return {"key": key, "fn": fn, "xf": _xf(at, rot), "slot": slot, "col": col, "metal": metal_v}


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


func _node(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


func _build() -> void:
	var skin: Color = opts.get("skin", SKIN)
	var tunic: Color = opts.get("tunic", Color(0.8, 0.75, 0.65))
	var bare: bool = opts.get("bare", false)
	var toga: bool = opts.get("toga", false)
	var border: Color = opts.get("border", Color(0.52, 0.1, 0.32))
	var picta: bool = opts.get("picta", false)
	rig = R.create(self)
	pelvis = _node(self, Vector3(0, PELVIS_Y, 0))
	torso = _node(pelvis, Vector3.ZERO)
	head = _node(torso, Vector3(0, HEAD_Y, 0))
	b_pelvis = rig.add_bone(pelvis, -1)
	b_torso = rig.add_bone(torso, b_pelvis)
	b_head = rig.add_bone(head, b_torso)
	for si in 2:
		var s := -1.0 if si == 0 else 1.0   # the figure faces +z, so its right side is -x
		var sh := _node(torso, Vector3(SH_X * s, SH_Y, 0))
		arms.append(sh)
		var el := _node(sh, Vector3(0, -L_UP, 0))
		elbows.append(el)
		var wr := _node(el, Vector3(0, -L_FORE, 0))
		if si == 0:
			hand_r = wr
		else:
			hand_l = wr
		var bs: int = rig.add_bone(sh, b_torso)
		var be: int = rig.add_bone(el, bs)
		var bw: int = rig.add_bone(wr, be)
		b_sh.append(bs)
		b_el.append(be)
		b_wr.append(bw)
	for si in 2:
		var s := -1.0 if si == 0 else 1.0
		var hp := _node(pelvis, Vector3(HIP_X * s, 0.0, 0.0))
		legs.append(hp)
		var kn := _node(hp, Vector3(0, -THIGH, 0))
		knees.append(kn)
		var an := _node(kn, Vector3(0, -SHIN, 0))
		ankles.append(an)
		var bh: int = rig.add_bone(hp, b_pelvis)
		var bk: int = rig.add_bone(kn, bh)
		var ba: int = rig.add_bone(an, bk)
		b_hip.append(bh)
		b_kn.append(bk)
		b_an.append(ba)
	# colours (per-instance uniforms of the shared shader)
	rig.set_colour("c_skin", skin)
	rig.set_colour("c_face", skin)
	rig.set_colour("c_tunic", tunic)
	rig.set_colour("c_toga", opts.get("toga_colour", Color(0.94, 0.92, 0.84)))
	rig.set_colour("c_trim", border)
	rig.set_colour("c_hair", opts.get("hair", Color(0.17, 0.12, 0.09)))
	if picta:
		rig.set_colour("c_toga", Color(0.42, 0.1, 0.45))
		rig.set_colour("c_trim", Color(0.9, 0.72, 0.2))
	if opts.get("hem_band", false):
		rig.set_colour("c_trim", opts.get("hem", border))
	# torso, neck, head
	_bp(b_torso, "torso", func(lod: int) -> ArrayMesh: return M.lathe(TORSO_PROFILE, 18 if lod == 0 else 10), Vector3.ZERO, Vector3.ZERO, 0 if bare else 1)
	_bp(b_torso, "neck", fcap(0.048, 0.05, 0.11), Vector3(0, 0.62, 0), Vector3.ZERO, 0)
	_bp(b_head, "head", func(lod: int) -> ArrayMesh: return M.lathe_y(HEAD_PROFILE, 20 if lod == 0 else 10, 24 if lod == 0 else 10), Vector3(0, 0.03, 0), Vector3.ZERO, 6)
	_bp(b_head, "nose", fell(0.013, 0.024, 0.02, true), Vector3(0, 0.122, 0.106), Vector3(0.25, 0, 0), 0)
	for s in [-1.0, 1.0]:
		_bp(b_head, "ear", fell(0.009, 0.03, 0.02, true), Vector3(0.079 * s, 0.16, -0.005), Vector3.ZERO, 0)
	if not bool(opts.get("veil", false)):
		_bp(b_head, "hair", fmesh(_hair_mesh), Vector3(0, 0.03, 0), Vector3.ZERO, 4)
	# arms
	for si in 2:
		var s := -1.0 if si == 0 else 1.0
		_bp(b_sh[si], "uparm", fcap(0.056, 0.043, L_UP, 0.006), Vector3.ZERO, Vector3.ZERO, 0)
		if not bare and not toga and opts.get("sleeves", true):
			_bp(b_sh[si], "sleeve", fcap(0.059, 0.055, 0.12), Vector3.ZERO, Vector3.ZERO, 1)
		_bp(b_el[si], "forearm", fcap(0.041, 0.031, L_FORE, 0.004), Vector3.ZERO, Vector3.ZERO, 0)
		_bp(b_wr[si], "palm", fell(0.038, 0.058, 0.02), Vector3(0, -0.055, 0), Vector3.ZERO, 0)
		_bp(b_wr[si], "thumb%d" % int(s), func(lod: int) -> ArrayMesh: return null if lod > 0 else M.capsule(0.012, 0.01, 0.04, 6), Vector3(0.03 * s, -0.045, 0.012), Vector3(0, 0, 0.5 * s), 0)
	# legs
	var shoe: Color = opts.get("shoes", Color(0.36, 0.24, 0.15))
	for si in 2:
		_bp(b_hip[si], "thigh", fcap(0.085, 0.060, THIGH, 0.008), Vector3.ZERO, Vector3.ZERO, 0)
		_bp(b_kn[si], "shin", fcap(0.058, 0.04, SHIN, 0.012), Vector3.ZERO, Vector3.ZERO, 0)
		_bp(b_an[si], "shoe", fell(0.046, 0.034, 0.118), Vector3(0, -0.02, 0.05), Vector3.ZERO, 5, shoe)
	# clothes
	var stola: bool = opts.get("stola", false)
	if not bare and not toga:
		_tunic_skirt(opts.get("hem_band", false), 0.80 if (stola or opts.get("long", false)) else 0.34)
		if stola:
			rig.set_colour("c_toga", opts.get("palla", Color(0.55, 0.45, 0.6)))
			_palla()
	elif bare:
		_loincloth(opts.get("belt", Color(0.5, 0.35, 0.2)))
	if toga:
		_tunic_skirt(false, 0.30)
		_toga()
	if opts.get("laticlave", false):
		_bp(b_torso, "stripe", fmesh(_stripe_mesh), Vector3.ZERO, Vector3.ZERO, 3)
	if not bare and opts.get("belt_on", not toga):
		_bp(b_torso, "belt", fmesh(func(): return M.lathe([Vector4(0.115, 0.152, 0.104, 0.0), Vector4(0.115, 0.158, 0.108, 0.0), Vector4(0.15, 0.158, 0.108, 0.0), Vector4(0.15, 0.152, 0.104, 0.0)], 18, 1)), Vector3.ZERO, Vector3.ZERO, 5, opts.get("belt", Color(0.30, 0.2, 0.12)))
	if opts.get("veil", false):
		_veil()
	if opts.get("laurel", false):
		equip_laurel()
	if opts.get("pilleus", false):
		equip_pilleus()
	has_long_robe = toga or stola or bool(opts.get("long", false))
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


static func _stripe_mesh() -> ArrayMesh:
	return _cached("stripe", func():
		var fn := func(u: float, v: float) -> Vector3:
			var y := lerpf(0.5, -0.08, v)
			var pr := _profile_at(TORSO_PROFILE, clampf(y, -0.07, 0.55))
			var x := lerpf(-0.022, 0.022, u)
			return Vector3(x, y, pr.z * 1.04 + pr.w)
		return M.surface(2, 6, fn, 1))


func _tunic_skirt(hem_band: bool, length := 0.34) -> void:
	var prof := [Vector4(0.06, 0.0, 0.0, 0.0), Vector4(0.06, 0.168, 0.118, 0.0), Vector4(-0.05, 0.19, 0.13, 0.0),
		Vector4(-length * 0.6, 0.215, 0.155, 0.0), Vector4(-length, 0.235, 0.175, 0.0)]
	_bp(b_pelvis, "skirt%.2f" % length, flathe(prof, 20, 1), Vector3.ZERO, Vector3.ZERO, 1)
	if hem_band:
		_bp(b_pelvis, "hem%.2f" % length, flathe([Vector4(-length + 0.045, 0.2285, 0.1685, 0.0), Vector4(-length, 0.236, 0.176, 0.0)], 20, 1), Vector3.ZERO, Vector3.ZERO, 3)


func _loincloth(belt: Color) -> void:
	var prof := [Vector4(0.05, 0.172, 0.122, 0.0), Vector4(-0.05, 0.2, 0.145, 0.0), Vector4(-0.2, 0.225, 0.16, 0.0)]
	_bp(b_pelvis, "loin", flathe(prof, 18, 1), Vector3.ZERO, Vector3.ZERO, 1)
	_bp(b_torso, "belt2", flathe([Vector4(0.1, 0.172, 0.118, 0.0), Vector4(0.15, 0.172, 0.118, 0.0)], 18, 1), Vector3.ZERO, Vector3.ZERO, 5, belt)


func _toga() -> void:
	# the skirt, with long folds
	_bp(b_pelvis, "toga_skirt", func(lod: int) -> ArrayMesh:
		return _cached("toga_skirt%d" % lod, func():
			var fn := func(u: float, v: float) -> Vector3:
				var th := (u - 0.5) * TAU
				var y := lerpf(0.03, -0.80, v)
				var rb := lerpf(0.20, 0.285, v)
				var fold := 1.0 + 0.06 * sin(9.0 * th + v * 2.5) * (0.25 + 0.75 * v)
				return Vector3(rb * 1.05 * fold * sin(th), y, rb * 0.9 * fold * cos(th) + 0.01)
			return M.surface(28 if lod == 0 else 14, 10 if lod == 0 else 5, fn, 1)), Vector3.ZERO, Vector3.ZERO, 2)
	_bp(b_pelvis, "toga_skirt_b", fmesh(func():
		return _cached("toga_skirt_b", func():
			var fn := func(u: float, v: float) -> Vector3:
				var th := (u - 0.5) * TAU
				var vv := lerpf(0.93, 1.0, v)
				var y := lerpf(0.03, -0.80, vv)
				var rb := lerpf(0.20, 0.285, vv)
				var fold := 1.0 + 0.06 * sin(9.0 * th + vv * 2.5) * (0.25 + 0.75 * vv)
				return Vector3(rb * 1.055 * fold * sin(th), y, rb * 0.905 * fold * cos(th) + 0.01)
			return M.surface(28, 2, fn, 1))), Vector3.ZERO, Vector3.ZERO, 3)
	# the chest: a diagonal wrap from the right hip over the left shoulder
	_bp(b_torso, "toga_chest", func(lod: int) -> ArrayMesh:
		return _cached("toga_chest%d" % lod, func():
			var fn := func(u: float, v: float) -> Vector3:
				var th := (u - 0.5) * TAU
				var top := 0.31 - 0.20 * sin(th)
				var y := lerpf(-0.02, top, v)
				var pr := _profile_at(TORSO_PROFILE, clampf(y, -0.07, 0.54))
				var rip := 1.0 + 0.05 * sin(6.0 * th + y * 11.0)
				return Vector3((pr.y * 1.07 + 0.012) * rip * sin(th), y, (pr.z * 1.07 + 0.012) * rip * cos(th) + pr.w)
			return M.surface(28 if lod == 0 else 14, 8 if lod == 0 else 4, fn, 1)), Vector3.ZERO, Vector3.ZERO, 2)
	_bp(b_torso, "toga_edge", fmesh(func():
		return _cached("toga_edge", func():
			var fn := func(u: float, v: float) -> Vector3:
				var th := (u - 0.5) * TAU
				var top := 0.31 - 0.20 * sin(th)
				var y := lerpf(top - 0.045, top, v)
				var pr := _profile_at(TORSO_PROFILE, clampf(y, -0.07, 0.54))
				var rip := 1.0 + 0.05 * sin(6.0 * th + y * 11.0)
				return Vector3((pr.y * 1.075 + 0.013) * rip * sin(th), y, (pr.z * 1.075 + 0.013) * rip * cos(th) + pr.w)
			return M.surface(28, 2, fn, 1))), Vector3.ZERO, Vector3.ZERO, 3)
	# the left shoulder and arm covered
	_bp(b_sh[1], "toga_arm", fcap(0.066, 0.062, 0.22), Vector3.ZERO, Vector3.ZERO, 2)
	# the sinus: a hanging fold across the front
	_bp(b_torso, "toga_sinus", fmesh(func():
		return _cached("toga_sinus", func():
			var fn := func(u: float, v: float) -> Vector3:
				var x := lerpf(-0.21, 0.10, u)
				var yb := 0.02 - 0.12 * sin(u * PI * 0.9)
				var y := lerpf(0.40 - 0.18 * u, yb, v)
				var z := 0.128 + 0.035 * sin(u * 9.0 + v * 2.0) * v + 0.03 * (1.0 - v)
				return Vector3(x, y, z)
			return M.surface(10, 6, fn, -1))), Vector3.ZERO, Vector3.ZERO, 2)
	_bp(b_torso, "toga_sinus_b", fmesh(func():
		return _cached("toga_sinus_b", func():
			var fn := func(u: float, v: float) -> Vector3:
				var x := lerpf(-0.21, 0.10, u)
				var yb := 0.02 - 0.12 * sin(u * PI * 0.9)
				var y := lerpf(yb + 0.04, yb, v)
				var z := 0.128 + 0.035 * sin(u * 9.0 + 2.0)
				return Vector3(x, y, z + 0.004)
			return M.surface(10, 1, fn, -1))), Vector3.ZERO, Vector3.ZERO, 3)


func _veil() -> void:
	# the toga drawn over the head (capite velato): from the crown down over the shoulders
	_bp(b_head, "veil", fmesh(func():
		return _cached("veil", func():
			var fn := func(u: float, v: float) -> Vector3:
				var th := (u - 0.5) * TAU
				var front := cos(th) * 0.5 + 0.5   # 1 at the face
				var low := lerpf(-0.17, 0.17, front * front)
				var y := lerpf(low, 0.255, v)
				var pr := _profile_at(HEAD_PROFILE, clampf(y, 0.0, 0.236))
				var drop := clampf((0.1 - y) / 0.27, 0.0, 1.0)
				var k := 1.07 + 0.9 * drop * (1.0 - front * 0.6)
				var rx := maxf(pr.y, 0.06) * k
				var rz := maxf(pr.z, 0.07) * k
				return Vector3(rx * sin(th), y, rz * cos(th) + pr.w * 0.5)
			return M.surface(26, 10, fn, 1))), Vector3(0, 0.03, 0), Vector3.ZERO, 2)


## The palla: a matron's mantle wrapped over the stola, the same way the toga crosses the chest
## (Horace Sat. 1.2.99 "ad talos stola demissa et circumdata palla", read). Colour slot 2.
func _palla() -> void:
	_bp(b_torso, "palla_chest", func(lod: int) -> ArrayMesh:
		return _cached("palla_chest%d" % lod, func():
			var fn := func(u: float, v: float) -> Vector3:
				var th := (u - 0.5) * TAU
				var top := 0.33 - 0.17 * sin(th)
				var y := lerpf(-0.30, top, v)
				var pr := _profile_at(TORSO_PROFILE, clampf(y, -0.07, 0.54))
				var rip := 1.0 + 0.04 * sin(7.0 * th + y * 9.0)
				var widen := 1.0 + 0.75 * clampf(-y / 0.3, 0.0, 1.0)   # clears the stola's skirt below the hips
				return Vector3((pr.y * 1.08 + 0.014) * rip * widen * sin(th), y, (pr.z * 1.08 + 0.014) * rip * widen * cos(th) + pr.w)
			return M.surface(24 if lod == 0 else 12, 8 if lod == 0 else 4, fn, 1)), Vector3.ZERO, Vector3.ZERO, 2)
	_bp(b_sh[1], "palla_arm", fcap(0.066, 0.062, 0.24), Vector3.ZERO, Vector3.ZERO, 2)


## The pilleus: the close felt cap of the freedman (Livy 30.45.5: Q. Terentius Culleo followed
## Scipio's chariot "pilleo capiti imposito"; Livy 45.44.19: Prusias "pilleatum, capite raso",
## both read). Its exact shape is a modern reconstruction (# unverified).
func equip_pilleus(col := Color(0.78, 0.72, 0.6)) -> void:
	_bp(b_head, "pilleus", fmesh(func():
		return _cached("pilleus", func():
			return M.lathe([Vector4(0.0, 0.088, 0.1, -0.004), Vector4(0.05, 0.08, 0.09, -0.004), Vector4(0.11, 0.045, 0.05, -0.004), Vector4(0.135, 0.0, 0.0, -0.004)], 14))), Vector3(0, 0.2, 0), Vector3.ZERO, 5, col)


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
	_bp(b_head, "laurel", fmesh(func():
		return _cached("laurel", func():
			var pts: Array = []
			var radii: Array = []
			for i in 25:
				var a := float(i) / 24.0 * TAU * 0.92 + 0.2
				pts.append(Vector3(sin(a) * 0.088, 0.0 + 0.012 * sin(a * 6.0), cos(a) * 0.1 - 0.004))
				radii.append(0.011 + 0.005 * sin(a * 12.0))
			return M.tube(pts, radii, 6))), Vector3(0, 0.195, 0), Vector3.ZERO, 5, col)


## A helmet. kind: "samnis" (crested, visored), "thraex" (broad-brimmed, griffin crest),
## "gallus" (cheek-plated), "leather" (a charioteer's cap).
func equip_helmet(kind := "samnis", metal_col := Color(0.72, 0.6, 0.3), crest_col := Color(0.72, 0.1, 0.1)) -> void:
	if kind == "leather":
		_bp(b_head, "cap", fell(0.092, 0.07, 0.105), Vector3(0, 0.205, 0.0), Vector3.ZERO, 5, metal_col)
		_bp(b_head, "capknob", fell(0.02, 0.03, 0.02), Vector3(0, 0.272, 0.0), Vector3.ZERO, 5, crest_col)
		return
	_bp(b_head, "helm_dome", fmesh(func():
		return _cached("helm_dome", func():
			var prof := [Vector4(0.0, 0.098, 0.112, 0.0), Vector4(0.03, 0.094, 0.108, 0.0), Vector4(0.07, 0.080, 0.094, 0.0), Vector4(0.1, 0.048, 0.056, 0.0), Vector4(0.115, 0.0, 0.0, 0.0)]
			return M.lathe(prof, 20))), Vector3(0, 0.185, -0.004), Vector3.ZERO, 5, metal_col, 0.55)
	_bp(b_head, "helm_rim", flathe([Vector4(0.0, 0.1, 0.118, 0.0), Vector4(0.012, 0.1, 0.118, 0.0)], 20, 1), Vector3(0, 0.182, -0.004), Vector3.ZERO, 5, metal_col, 0.55)
	_bp(b_head, "helm_guard", fmesh(func():
		return _cached("helm_guard", func():
			var fn := func(u: float, v: float) -> Vector3:
				var th := lerpf(PI * 0.35, PI * 1.65, u) + PI
				return Vector3(0.11 * sin(th), lerpf(0.0, -0.06, v), 0.13 * cos(th) * 0.9 - 0.005 + 0.03 * v * -cos(th))
			return M.surface(10, 2, fn, -1))), Vector3(0, 0.19, 0), Vector3.ZERO, 5, metal_col, 0.55)
	_bp(b_head, "crest_" + kind, fmesh(func():
		return _cached("crest_" + kind, func():
			var fn := func(u: float, v: float) -> Vector3:
				var z := lerpf(0.1, -0.12, u)
				var h := (0.06 + 0.07 * sin(u * PI)) * (1.0 if kind != "gallus" else 0.6)
				if kind == "thraex":
					h = 0.05 + 0.16 * pow(sin(u * PI), 0.8)
				return Vector3(lerpf(-0.012, 0.012, v), v * h, z)
			return M.surface(10, 3, fn, -1))), Vector3(0, 0.285, 0), Vector3.ZERO, 5, crest_col)
	if kind == "samnis" or kind == "thraex":
		_bp(b_head, "visor_" + kind, fmesh(func():
			return _cached("visor_" + kind, func():
				var fn := func(u: float, v: float) -> Vector3:
					var th := lerpf(-0.9, 0.9, u)
					var y := lerpf(-0.02, 0.1, v)
					return Vector3(0.108 * sin(th), y, 0.122 * cos(th) + 0.012)
				return M.surface(10, 4, fn, -1))), Vector3(0, 0.13, 0.0), Vector3.ZERO, 5, metal_col, 0.55)
		for s in [-1.0, 1.0]:
			_bp(b_head, "eyeslit", fell(0.017, 0.006, 0.006), Vector3(0.04 * s, 0.158, 0.142), Vector3.ZERO, 5, Color(0.04, 0.03, 0.03))
	else:
		for s in [-1.0, 1.0]:
			_bp(b_head, "cheek", fell(0.008, 0.055, 0.045), Vector3(0.085 * s, 0.1, 0.045), Vector3.ZERO, 5, metal_col, 0.55)
	if kind == "thraex":
		_bp(b_head, "brim", fell(0.13, 0.008, 0.14), Vector3(0, 0.195, 0.0), Vector3.ZERO, 5, metal_col, 0.55)


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
	var gold := Color(0.8, 0.68, 0.32)
	var plist: Array = []
	plist.append(rp("sbody_%s_%s" % [kind, col.to_html()], fmesh(func():
		return _cached("shield_%s_%.2f" % [kind, w], func():
			var fn := func(u: float, v: float) -> Vector3:
				var x := lerpf(-w / 2.0, w / 2.0, u)
				var y := lerpf(-h / 2.0, h / 2.0, v)
				var xx := x
				var yy := y
				if kind == "long" or kind == "round":
					var e := sqrt(pow(2.0 * u - 1.0, 2.0) + pow(2.0 * v - 1.0, 2.0))
					var k := 1.0 / maxf(1.0, e) if kind == "round" else 1.0 / maxf(1.0, e * 0.75)
					xx = x * lerpf(1.0, k, 0.5)
					yy = y * lerpf(1.0, k, 0.5)
				var z := curve * (1.0 - pow(2.0 * u - 1.0, 2.0)) * -1.0 + curve
				return Vector3(xx, yy, z * 0.8)
			return M.surface(10, 8, fn, -1))), Vector3.ZERO, Vector3.ZERO, 5, col))
	plist.append(rp("sboss", fell(0.07, 0.07, 0.04), Vector3(0, 0, curve * 0.8 + 0.02), Vector3.ZERO, 5, gold, 0.6))
	if kind == "scutum" or kind == "long":
		plist.append(rp("sspine%.2f" % h, fell(0.014, h * 0.5, 0.02), Vector3(0, 0, curve * 0.8 + 0.01), Vector3.ZERO, 5, gold, 0.6))
		for sy in [-1.0, 1.0]:
			plist.append(rp("srim%.2f" % w, fell(w * 0.46, 0.014, 0.014), Vector3(0, sy * (h / 2.0 - 0.02), curve * 0.4), Vector3.ZERO, 5, gold, 0.6))
	else:
		plist.append(rp("srimp%.2f" % w, fell(w * 0.5, 0.016, 0.014), Vector3(0, h / 2.0, curve * 0.3), Vector3.ZERO, 5, gold, 0.6))
	R.rigid(sh, "shield_%s_%s" % [kind, col.to_html()], plist)
	return sh


## A sword in the right hand: "gladius" straight, "sica" curved. The blade continues the arm.
func equip_sword(kind := "gladius") -> Node3D:
	var sw := Node3D.new()
	hand_r.add_child(sw)
	sw.position = Vector3(0, -0.06, 0)
	var gold := Color(0.8, 0.68, 0.3)
	var plist: Array = [
		rp("sgrip", fcap(0.014, 0.012, 0.09), Vector3(0, 0.04, 0), Vector3.ZERO, 5, Color(0.3, 0.2, 0.12)),
		rp("spommel", fell(0.014, 0.01, 0.035), Vector3(0, -0.06, 0), Vector3.ZERO, 5, gold, 0.6),
		rp("sguard", fell(0.07, 0.008, 0.014), Vector3(0, -0.095, 0), Vector3.ZERO, 5, gold, 0.6),
		rp("blade_" + kind, fmesh(func():
			return _cached("blade_" + kind, func():
				var fn := func(u: float, v: float) -> Vector3:
					var y := -0.1 - v * (0.55 if kind == "gladius" else 0.5)
					var w := 0.036 * (1.0 - 0.75 * pow(v, 3.0))
					var x := lerpf(-w, w, u)
					var curve := 0.0 if kind == "gladius" else 0.14 * v * v
					var thick := 0.012 * (1.0 - absf(2.0 * u - 1.0))
					return Vector3(x, y, curve + thick)
				return M.surface(4, 8, fn, -1))), Vector3.ZERO, Vector3.ZERO, 5, Color(0.86, 0.87, 0.92), 0.8),
	]
	R.rigid(sw, "sword_" + kind, plist)
	return sw


## A knife for the victimarius (or a charioteer's falx).
func equip_knife() -> Node3D:
	var k := Node3D.new()
	hand_r.add_child(k)
	k.position = Vector3(0, -0.06, 0)
	R.rigid(k, "knife", [rp("kgrip", fcap(0.014, 0.012, 0.08), Vector3(0, 0.03, 0), Vector3.ZERO, 5, Color(0.3, 0.2, 0.12)),
		rp("kblade", fell(0.016, 0.13, 0.006), Vector3(0, -0.2, 0.0), Vector3.ZERO, 5, Color(0.85, 0.86, 0.9), 0.8)])
	return k


## A greave on the shin (side 0 right, 1 left), `high` reaches over the knee.
func equip_greave(side: int, high := false, col := Color(0.72, 0.6, 0.3)) -> void:
	var ln := SHIN * (0.95 if high else 0.78)
	_bp(b_kn[side], "greave%.2f" % ln, fcap(0.064, 0.05, ln, 0.003), Vector3(0, 0.02 if high else -0.04, 0.0), Vector3.ZERO, 5, col, 0.55)


## An armoured sleeve (manica) on the right arm: segmented rings.
func equip_manica(col := Color(0.7, 0.62, 0.35)) -> void:
	for i in 4:
		_bp(b_sh[0], "manica1", fcap(0.06, 0.059, 0.05), Vector3(0, -0.04 - i * 0.065, 0), Vector3.ZERO, 5, col, 0.55)
	for i in 3:
		_bp(b_el[0], "manica2", fcap(0.048, 0.046, 0.05), Vector3(0, -0.02 - i * 0.07, 0), Vector3.ZERO, 5, col, 0.55)


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
	var plist: Array = [
		rp("f_rods", fmesh(func():
			return _cached("fasces_rods", func():
				var prof: Array = []
				prof.append(Vector4(-0.62, 0.0, 0.0, 0.0))
				prof.append(Vector4(-0.6, 0.038, 0.038, 0.0))
				for i in 8:
					var y := -0.6 + float(i) / 7.0 * 1.2
					prof.append(Vector4(y, 0.046 + 0.004 * sin(i * 2.0), 0.046 + 0.004 * sin(i * 2.0), 0.0))
				prof.append(Vector4(0.6, 0.038, 0.038, 0.0))
				prof.append(Vector4(0.62, 0.0, 0.0, 0.0))
				return M.lathe(prof, 12))), Vector3(0, 0.15, 0), Vector3.ZERO, 5, Color(0.62, 0.5, 0.3)),
		rp("f_axe", fmesh(func():
			return _cached("fasces_axe", func():
				var fn := func(u: float, v: float) -> Vector3:
					var x := lerpf(0.0, 0.17, u) * (0.6 + 0.4 * sin(v * PI * 0.5 + 0.8))
					var y := lerpf(-0.1, 0.1, v) * (1.0 + 0.9 * u)
					return Vector3(x, y, 0.0)
				return M.surface(4, 6, fn, -1))), Vector3(0.04, 0.5, 0.0), Vector3.ZERO, 5, Color(0.8, 0.82, 0.86), 0.8),
	]
	for i in 4:
		plist.append(rp("f_strap", flathe([Vector4(-0.012, 0.05, 0.05, 0.0), Vector4(0.012, 0.05, 0.05, 0.0)], 12, 1), Vector3(0, -0.3 + i * 0.28, 0), Vector3.ZERO, 5, Color(0.7, 0.1, 0.1)))
	R.rigid(fs, "fasces", plist)
	fs.rotation = Vector3(1.57, 0.0, 0.0)   # upright when the right forearm is held level (pitch -0.35, elbow 1.2)
	return fs


## A tuba (a long straight trumpet) held at the mouth in the right hand.
func equip_tuba() -> Node3D:
	var t := Node3D.new()
	hand_r.add_child(t)
	R.rigid(t, "tuba", [rp("tuba", fmesh(func():
		return _cached("tuba", func():
			var prof: Array = [Vector4(0.0, 0.0, 0.0, 0.0)]
			for i in 11:
				var y := float(i) / 10.0 * 1.35
				var r := 0.012 + (0.012 if i < 8 else 0.012 + (float(i) - 7.0) * 0.045)
				prof.append(Vector4(y, r, r, 0.0))
			prof.append(Vector4(1.36, 0.0, 0.0, 0.0))
			return M.lathe(prof, 10))), Vector3(0, 0.1, 0.0), Vector3(-PI / 2.0, 0, 0), 5, Color(0.85, 0.66, 0.2), 0.8)])
	t.position = Vector3(0, -0.04, 0)
	return t


## A staff-like ivory sceptre with an eagle (the general's), in the left hand.
func equip_sceptre() -> Node3D:
	var s := Node3D.new()
	hand_l.add_child(s)
	var gold := Color(0.9, 0.75, 0.25)
	R.rigid(s, "sceptre", [rp("scp", fcap(0.014, 0.014, 0.9), Vector3(0, 0.45, 0), Vector3.ZERO, 5, Color(0.92, 0.88, 0.76)),
		rp("eagle", fell(0.04, 0.045, 0.06), Vector3(0, 0.98, 0), Vector3.ZERO, 5, gold, 0.8),
		rp("wings", fell(0.1, 0.012, 0.035), Vector3(0, 0.975, 0), Vector3.ZERO, 5, gold, 0.8)])
	return s


## A laurel branch in the right hand.
func equip_branch() -> Node3D:
	var b := Node3D.new()
	hand_r.add_child(b)
	var plist: Array = [rp("brstem", fcap(0.012, 0.01, 0.5), Vector3(0, 0.1, 0), Vector3.ZERO, 5, Color(0.4, 0.3, 0.18))]
	for i in 7:
		plist.append(rp("brleaf", fell(0.02, 0.05, 0.008), Vector3(0.02 * (1.0 if i % 2 == 0 else -1.0), 0.15 + i * 0.065, 0.0), Vector3(0, 0, 0.7 * (1.0 if i % 2 == 0 else -1.0)), 5, Color(0.26, 0.5, 0.2)))
	R.rigid(b, "branch", plist)
	return b


## A pilum or spear in the right hand.
func equip_spear() -> Node3D:
	var s := Node3D.new()
	hand_r.add_child(s)
	R.rigid(s, "spear", [rp("shaft", fcap(0.012, 0.012, 1.7), Vector3(0, 0.6, 0), Vector3.ZERO, 5, Color(0.5, 0.36, 0.2)),
		rp("head", fell(0.02, 0.1, 0.006), Vector3(0, 1.4, 0), Vector3.ZERO, 5, Color(0.8, 0.82, 0.86), 0.8)])
	return s


## The sacrificial mallet or axe (popa).
func equip_mallet() -> Node3D:
	var m := Node3D.new()
	hand_r.add_child(m)
	R.rigid(m, "mallet", [rp("mhandle", fcap(0.016, 0.016, 0.6), Vector3(0, 0.12, 0), Vector3.ZERO, 5, Color(0.45, 0.3, 0.15)),
		rp("mhead", fell(0.07, 0.07, 0.07), Vector3(0, -0.5, 0), Vector3.ZERO, 5, Color(0.45, 0.45, 0.48), 0.5)])
	return m


## Two pipes (tibiae) held at the mouth.
func equip_pipes() -> Node3D:
	var p := Node3D.new()
	head.add_child(p)
	var plist: Array = []
	for s in [-1.0, 1.0]:
		plist.append(rp("pipe", fcap(0.01, 0.011, 0.5), Vector3(0.025 * s, 0.07, 0.25), Vector3(-PI / 2.0 - 0.15, 0.0, 0.12 * s), 5, Color(0.35, 0.25, 0.12)))
	R.rigid(p, "pipes", plist)
	return p


## The limus: a linen apron with a purple border worn by the victimarius.
func equip_limus() -> void:
	_bp(b_pelvis, "limus", fmesh(func():
		return _cached("limus", func():
			var fn := func(u: float, v: float) -> Vector3:
				var th := lerpf(-1.0, 1.0, u)
				var y := lerpf(0.1, -0.34, v)
				return Vector3(0.2 * sin(th) * (1.0 + 0.2 * v), y, 0.145 * cos(th) * (1.0 + 0.2 * v) + 0.02 + 0.015 * sin(v * 9.0))
			return M.surface(10, 6, fn, -1))), Vector3.ZERO, Vector3.ZERO, 5, Color(0.94, 0.92, 0.86))
	_bp(b_pelvis, "limus_b", fmesh(func():
		return _cached("limus_b", func():
			var fn := func(u: float, v: float) -> Vector3:
				var th := lerpf(-1.0, 1.0, u)
				var y := lerpf(-0.31, -0.34, v)
				return Vector3(0.24 * sin(th), y, 0.174 * cos(th) + 0.035)
			return M.surface(10, 1, fn, -1))), Vector3.ZERO, Vector3.ZERO, 5, Color(0.52, 0.1, 0.32))


## Tint the face (the general's red-painted face).
func paint_face(c: Color) -> void:
	rig.set_colour("c_face", c)


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
