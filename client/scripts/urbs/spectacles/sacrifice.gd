## A Roman sacrifice before a temple (U6): the procession brings the magistrate, lictors, flute
## player, officiants and the white victim to the altar; wine and incense (praefatio); salted
## meal on the victim (mola salsa); the prayer in Cato's manner (paraphrased in a speech
## bubble); the popa strikes, the cultrarius cuts; smoke rises; the haruspex reads the exta and
## the result follows the ENGINE (`favourable`). Order after data/rome/city/spectacles.yaml
## (sacrifice: Dion. Hal. 7.72, Cato Agr. 132-141; passages unverified there).
##
## Params: favourable (bool, default true), altar_at / yaw are set by the parent through the
## node's transform. crowd (bool, default true): onlookers either side. victim ("ox").
## Local frame: the altar at the origin, the temple's front toward -z (the procession arrives
## from +z), floor y = 0. Length 70 s.
extends "res://scripts/urbs/spectacles/base.gd"

const F := preload("res://scripts/urbs/spectacles/figure.gd")
const Crowd := preload("res://scripts/urbs/crowd.gd")

const T_ARRIVE := 18.0
const T_WINE := 26.0
const T_MOLA := 32.0
const T_PRAYER := 44.0
const T_STRIKE := 47.0
const T_EXTA := 56.0
const T_FEAST := 66.0

var favourable := true
var _cast := {}                 # name -> figure
var _stations := {}             # name -> [Vector3 station, float delay]
var _ox: Node3D
var _ox_legs: Array = []
var _liver: MeshInstance3D
var _smoke: Array[MeshInstance3D] = []
var _label: Label3D
var _speech: Label3D
var _crowd: Node3D
var _hammer: Node3D

var prayer: Array = []
const PRAYER := [
	"Father Mars, keep this household and its flocks safe and well,",
	"and take this offering as is right.",
	"If anything here was amiss, we shall do it again.",
]


func _init(p: Dictionary = {}) -> void:
	params = p


func _ready() -> void:
	prayer = params.get("prayer", PRAYER)
	favourable = bool(params.get("favourable", true))
	duration = 72.0
	_add("tibicen", Color(0.8, 0.75, 0.65), Vector3(-1.4, 0, 3.4), 0.0)
	_add("lictor_a", Color(0.7, 0.12, 0.1), Vector3(1.2, 0, 4.6), 1.0)
	_add("lictor_b", Color(0.7, 0.12, 0.1), Vector3(-1.2, 0, 4.6), 1.0)
	_add("magistrate", Color(0.95, 0.93, 0.86), Vector3(0.0, 0, 2.3), 2.0, true)
	_add("haruspex", Color(0.9, 0.88, 0.8), Vector3(-2.4, 0, 1.2), 3.0, true)
	_add("servant", Color(0.82, 0.76, 0.6), Vector3(-1.4, 0, 1.0), 3.0)
	_add("leader_a", Color(0.75, 0.68, 0.55), Vector3(2.9, 0, 1.6), 4.0)
	_add("leader_b", Color(0.75, 0.68, 0.55), Vector3(2.9, 0, -0.6), 4.0)
	_add("popa", Color(0.72, 0.56, 0.42), Vector3(4.3, 0, 0.5), 5.5)
	_add("cultrarius", Color(0.7, 0.55, 0.4), Vector3(2.0, 0, -1.3), 5.5)
	# the veil over the magistrate's head
	var mag: Node3D = _cast["magistrate"]
	F.box(mag.head, Vector3(0.3, 0.22, 0.32), Vector3(0, 0.09, -0.02), Color(0.95, 0.93, 0.86))
	# lictors' fasces
	for n in ["lictor_a", "lictor_b"]:
		var lf: Node3D = _cast[n]
		F.box(lf.hand_r, Vector3(0.1, 0.1, 0.9), Vector3(0, -0.2, 0.0), Color(0.5, 0.35, 0.2)).rotation.x = PI / 2.0
		lf.pose_arms(-0.3, 0.1)
	# the flute: a pair of pipes
	var tib: Node3D = _cast["tibicen"]
	F.box(tib.head, Vector3(0.05, 0.05, 0.5), Vector3(0.1, -0.05, 0.28), Color(0.35, 0.25, 0.12))
	# the hammer of the popa
	_hammer = Node3D.new()
	(_cast["popa"] as Node3D).hand_r.add_child(_hammer)
	F.box(_hammer, Vector3(0.07, 0.07, 0.6), Vector3(0, 0, 0), Color(0.45, 0.3, 0.15)).rotation.x = PI / 2.0
	F.box(_hammer, Vector3(0.14, 0.14, 0.24), Vector3(0, -0.28, 0), Color(0.4, 0.4, 0.42))
	# the altar's fire and smoke
	var fire := F.box(self, Vector3(0.7, 0.25, 0.7), Vector3(0, 1.4, 0), Color(0.95, 0.5, 0.12))
	fire.name = "Fire"
	for i in 18:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 8
		sm.rings = 4
		m.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.55, 0.55, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat
		add_child(m)
		_smoke.append(m)
	# the victim
	_ox = _make_ox()
	add_child(_ox)
	# the exta
	_liver = F.box(self, Vector3(0.3, 0.12, 0.22), Vector3.ZERO, Color(0.6, 0.15, 0.12))
	F.box(_liver, Vector3(0.1, 0.1, 0.1), Vector3(0.12, 0.05, 0.0), Color(0.3, 0.4, 0.2))
	_label = make_label("", 0.9, Color(1, 0.95, 0.8))
	_label.position = Vector3(0, 5.2, 2.0)
	_speech = make_label("", 0.8, Color(1, 1, 0.9))
	_speech.position = Vector3(0, 3.4, 2.3)
	if bool(params.get("crowd", true)):
		var c = Crowd.new()
		var poly := PackedVector3Array([Vector3(0, 0, 6.0), Vector3(0, 0, 26.0)])
		c.add_seats(Crowd.line_seats(poly, 7.0, 3, 1.3, 1.0, 0.0))
		c.build()
		add_child(c)
		_crowd = c
	seek(float(params.get("start_at", 0.0)))


func _add(name_: String, col: Color, station: Vector3, delay: float, toga := false) -> void:
	var f = F.make(col, toga, Color(0.55, 0.08, 0.3), 1.0)
	add_child(f)
	_cast[name_] = f
	_stations[name_] = [station, delay]


func _make_ox() -> Node3D:
	var ox := F.make_ox()
	_ox_legs = ox.get_meta("legs")
	return ox


func _apply(time: float) -> void:
	var tt := minf(time, duration)
	# the walkers: each comes in from +z to its station
	for n in _cast:
		var f: Node3D = _cast[n]
		var st: Vector3 = _stations[n][0]
		var delay: float = _stations[n][1]
		var dist_left := maxf(0.0, 28.0 + delay * 1.0 - 1.55 * tt)
		var arrived := dist_left <= 0.0
		f.position = st + Vector3(0, 0, dist_left)
		f.sit(0.0)
		f.torso.rotation.x = 0.0
		if arrived:
			f.walk(0.0, 0.0)
			F.face(f, Vector3(0, 0, -1) if n != "popa" and n != "leader_a" and n != "leader_b" else Vector3(-1, 0, 0))
			if n == "cultrarius":
				F.face(f, Vector3(-1, 0, 0.3))
			if n == "tibicen":
				F.face(f, Vector3(0, 0, -1))
		else:
			F.face(f, Vector3(0, 0, -1))
			f.walk(tt * 5.0 + delay)
	# the ox walks with its leaders, then stands
	var ox_left := maxf(0.0, 27.0 - 1.45 * tt)
	_ox.position = Vector3(2.9, 0, 0.5 + ox_left)
	_ox.rotation = Vector3(0, -PI / 2.0 * (1.0 if ox_left <= 0.0 else 0.0) + (PI if ox_left > 0.0 else 0.0), 0)
	if ox_left > 0.0:
		_ox.rotation.y = PI    # walking toward -z: its front is +z, so turn it
		_ox.rotation.y = 0.0
	else:
		_ox.rotation.y = PI / 2.0   # standing broadside, its head toward +x? face the altar (-x)
		_ox.rotation.y = -PI / 2.0
	for i in _ox_legs.size():
		(_ox_legs[i] as Node3D).rotation.x = sin(tt * 5.0 + i * 1.6) * 0.4 if ox_left > 0.0 else 0.0
	# the strike
	var fall := smoothstep(T_STRIKE + 0.6, T_STRIKE + 2.8, tt)
	_ox.rotation.z = 1.45 * fall
	_ox.position.y = -0.0 * fall
	_ox.position.x = 2.9 + 0.35 * fall
	var popa: Node3D = _cast["popa"]
	var cultr: Node3D = _cast["cultrarius"]
	var mag: Node3D = _cast["magistrate"]
	var har: Node3D = _cast["haruspex"]
	var serv: Node3D = _cast["servant"]
	mag.pose_arms(0, 0)
	har.pose_arms(0, 0)
	serv.pose_arms(-0.4, -0.4)
	popa.pose_arms(-0.4, 0.0)
	cultr.pose_arms(-0.3, -0.3)
	var wine := tt >= T_WINE - 6.0 and tt < T_MOLA
	var smoke_k := 0.0
	_label.text = ""
	_speech.text = ""
	if tt < T_ARRIVE:
		_label.text = "The procession comes to the altar"
	if tt >= T_ARRIVE and tt < T_WINE:
		_label.text = "Praefatio: wine and incense"
		mag.pose_arms(-0.9 - 0.3 * sin(tt * 3.0), -0.2)
		smoke_k = smoothstep(T_ARRIVE, T_WINE, tt) * 0.4
	elif tt >= T_WINE and tt < T_MOLA:
		_label.text = "Mola salsa: salted meal on the victim"
		mag.pose_arms(-1.1, -0.2)
		smoke_k = 0.4
	elif tt >= T_MOLA and tt < T_PRAYER:
		smoke_k = 0.4
		mag.pose_arms(-1.4, -1.4, 0.5, 0.5)
		var k := int((tt - T_MOLA) / ((T_PRAYER - T_MOLA) / 3.0))
		_label.text = str(params.get("label", "The prayer"))
		var lines := ""
		for j in range(mini(k + 1, 3)):
			lines += str(prayer[j]) + "\n"
		_speech.text = lines
	elif tt >= T_PRAYER and tt < T_STRIKE + 3.0:
		smoke_k = 0.4
		_label.text = "The victim is struck"
		var raise := smoothstep(T_STRIKE - 2.0, T_STRIKE - 0.2, tt)
		var blow := smoothstep(T_STRIKE, T_STRIKE + 0.5, tt)
		popa.pose_arms(-0.4 - 2.4 * raise + 2.4 * blow, 0.0)
		popa.torso.rotation.x = 0.35 * blow
		mag.pose_arms(-0.6, -0.6)
	elif tt >= T_STRIKE + 3.0 and tt < T_EXTA:
		_label.text = "The cultrarius cuts; the smoke rises"
		smoke_k = 0.4 + 0.6 * smoothstep(T_STRIKE, T_STRIKE + 8.0, tt)
		cultr.kneel(smoothstep(T_STRIKE + 3.0, T_STRIKE + 4.0, tt))
		cultr.pose_arms(-0.8, -0.8)
	elif tt >= T_EXTA:
		smoke_k = 1.0
		cultr.kneel(1.0)
		_label.text = "The exta are read"
	# the haruspex with the liver
	var reading := tt >= T_EXTA and tt < T_FEAST + 2.0
	_liver.visible = reading
	if reading:
		var up := smoothstep(T_EXTA, T_EXTA + 2.0, tt)
		har.position = Vector3(-1.6, 0, 1.0).lerp(Vector3(-1.2, 0, 0.9), up)
		har.pose_arms(-1.6 * up, -0.3)
		_liver.position = har.position + Vector3(0.25, 1.65 * up + 0.4 * (1.0 - up), 0.3)
		var mat := F.mat(Color(0.7, 0.18, 0.14) if favourable else Color(0.28, 0.22, 0.16))
		_liver.material_override = mat
		if tt >= T_EXTA + 3.0:
			if favourable:
				_label.text = "The exta are sound: the god accepts (litatio)"
				mag.pose_arms(-2.4, -2.4, 0.4, 0.4)
				har.pose_arms(-2.0 + 0.2 * sin(tt * 4.0), -0.3)
			else:
				_label.text = "A defect in the liver: the sacrifice must be repeated"
				har.pose_arms(-1.6, -0.3)
				har.rotation.y += 0.5 * sin(tt * 3.0)
				mag.pose_arms(0.0, 0.0)
	if tt >= T_FEAST:
		_label.text = "The feast" if favourable else "A fresh victim is called for"
	# the smoke
	for i in _smoke.size():
		var age := fposmod(tt * 0.12 + float(i) / _smoke.size(), 1.0)
		var m: MeshInstance3D = _smoke[i]
		m.visible = smoke_k > 0.02
		m.position = Vector3(sin(age * 7.0 + i) * 0.5 * age + 0.6 * age, 1.5 + age * 11.0, cos(age * 5.0 + i) * 0.4 * age)
		m.scale = Vector3.ONE * (0.3 + age * 2.2) * (0.4 + 0.6 * smoke_k)
		(m.material_override as StandardMaterial3D).albedo_color.a = 0.45 * (1.0 - age) * smoke_k
	if _crowd != null:
		var roar := 0.15
		if tt >= T_EXTA + 3.0:
			roar = 0.8 if favourable else 0.12
		_crowd.set_state(tt, roar, 0.0, 0.0)


func view_names() -> PackedStringArray:
	return PackedStringArray(["the altar", "from the crowd", "the temple steps"])


func seat_views() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.append(look(Vector3(8.0, 2.2, 8.0), Vector3(0.5, 1.2, 0.5)))
	out.append(look(Vector3(-7.0, 1.8, 14.0), Vector3(0, 1.4, 1.0)))
	out.append(look(Vector3(0, 4.0, -9.0), Vector3(0.5, 1.2, 3.0)))
	return out
