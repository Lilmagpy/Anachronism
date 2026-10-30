## A day's gladiator games, seen from the seats (U6): several pairs in turn. Each bout: the two
## walk in, circle, trade thrusts and parries behind their shields; one goes down on a knee and
## raises a finger to ask for missio; the editor's sign is the ENGINE's decision (`missio`); the
## crowd roars; the pair leaves, or the winner strikes (data/rome/city/spectacles.yaml, munus).
## Armatures shown are the Republican ones: samnis, gallus, thraex.
##
## Params: rx, rz (arena ellipse radii, m; default 28 x 18), pairs (Array of {a, b, loser,
## missio}), missio (bool or Array of bool: the editor's decision for each pair), editor_pos
## (Vector3, default the front of the long axis), seed, crowd (bool), rows.
## Local frame: arena centre at the origin, floor y = 0.
extends "res://scripts/urbs/spectacles/base.gd"

const F := preload("res://scripts/urbs/spectacles/figure.gd")
const Crowd := preload("res://scripts/urbs/crowd.gd")

const BOUT := 34.0
const LEAD_IN := 2.0
const ARMS := {
	"samnis": {"shield": "scutum", "sword": "gladius", "col": Color(0.55, 0.2, 0.15), "helm": Color(0.72, 0.62, 0.3), "crest": Color(0.75, 0.12, 0.1)},
	"gallus": {"shield": "round", "sword": "gladius", "col": Color(0.2, 0.35, 0.55), "helm": Color(0.7, 0.7, 0.72), "crest": Color(0.1, 0.1, 0.5)},
	"thraex": {"shield": "parma", "sword": "sica", "col": Color(0.6, 0.5, 0.2), "helm": Color(0.62, 0.5, 0.25), "crest": Color(0.1, 0.5, 0.2)},
}

var rx := 28.0
var rz := 18.0
var pairs: Array = []
var editor_pos := Vector3.ZERO
var _fighters: Array = []      # per pair: [figA, figB, shieldA, shieldB]
var _editor: Node3D
var _label: Label3D
var _crowd: Node3D
var _rng_seed := 5


func _init(p: Dictionary = {}) -> void:
	params = p


func _ready() -> void:
	rx = float(params.get("rx", rx))
	rz = float(params.get("rz", rz))
	_rng_seed = int(params.get("seed", 5))
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed
	var kinds := ["samnis", "gallus", "thraex"]
	var missios = params.get("missio", true)
	if params.has("pairs"):
		pairs = params["pairs"]
	else:
		for k in 3:
			var a: String = kinds[k % 3]
			var b: String = kinds[(k + 1 + k / 2) % 3] if k > 0 else "thraex"
			if k == 0:
				a = "samnis"
			pairs.append({"a": a, "b": b, "loser": rng.randi() % 2})
	for k in pairs.size():
		if not pairs[k].has("missio"):
			var m: bool = missios[k % missios.size()] if missios is Array else bool(missios)
			pairs[k]["missio"] = m
	duration = LEAD_IN + pairs.size() * BOUT + 2.0
	editor_pos = params.get("editor_pos", Vector3(0, 1.3, rz + 1.8))
	var tones := [Color(0.86, 0.66, 0.52), Color(0.78, 0.58, 0.44), Color(0.9, 0.72, 0.58), Color(0.7, 0.5, 0.38)]
	var hairs := [Color(0.15, 0.1, 0.08), Color(0.3, 0.2, 0.12), Color(0.12, 0.1, 0.1), Color(0.45, 0.32, 0.18)]
	for k in pairs.size():
		var row: Array = []
		for side in 2:
			var key: String = pairs[k]["a" if side == 0 else "b"]
			var f = F.person({"bare": true, "tunic": Color(0.9, 0.86, 0.76), "belt": Color(0.45, 0.3, 0.18),
				"skin": tones[(k * 2 + side) % tones.size()], "hair": hairs[(k + side * 2) % hairs.size()], "seed": k * 2 + side + 1})
			var sh: Node3D = f.equip_kit(key)
			add_child(f)
			f.visible = false
			row.append(f)
			row.append(sh)
		_fighters.append(row)
	_editor = F.person({"tunic": Color(0.9, 0.86, 0.78), "toga": true, "border": Color(0.52, 0.1, 0.32), "scale": 1.04, "seed": 40, "hair": Color(0.3, 0.3, 0.3)})
	_editor.position = editor_pos
	F.face(_editor, Vector3(0, 0, -1))
	add_child(_editor)
	# the lanista, standing at the gate with a staff
	_label = make_label("", 0.9, Color(1, 0.95, 0.8))
	_label.position = editor_pos + Vector3(0, 3.2, 0)
	if bool(params.get("crowd", true)):
		var c = Crowd.new()
		c.add_seats(Crowd.ellipse_seats(rx + 1.5, rz + 1.5, int(params.get("rows", 8)), 1.2, 0.9, 0.5, 0.6))
		c.build()
		add_child(c)
		_crowd = c
	seek(float(params.get("start_at", 0.0)))


func _apply(time: float) -> void:
	var tt := minf(time, duration)
	var bout := int((tt - LEAD_IN) / BOUT) if tt >= LEAD_IN else -1
	var roar := 0.2
	var tb := tt - LEAD_IN - bout * BOUT
	for k in pairs.size():
		var row: Array = _fighters[k]
		(row[0] as Node3D).visible = k == bout
		(row[2] as Node3D).visible = k == bout
		if k == bout:
			roar = _pose_bout(k, tb)
	# the editor
	_editor.pose_arms(0, 0)
	_label.text = ""
	if bout >= 0:
		var pr: Dictionary = pairs[bout]
		if tb > 23.0 and tb < 29.0:
			_editor.pose_arms(-2.6 if tb > 24.5 else -1.2, 0.0)
			_label.text = "Missio: spared" if bool(pr["missio"]) else "No mercy"
		elif tb < 4.0:
			_label.text = "%s against %s" % [pr["a"], pr["b"]]
	if _crowd != null:
		_crowd.set_state(tt, roar, fposmod(tt * 0.08, 1.0), 0.5)


# Returns the crowd's roar for the moment.
func _pose_bout(k: int, tb: float) -> float:
	var pr: Dictionary = pairs[k]
	var row: Array = _fighters[k]
	var fa: Node3D = row[0]
	var fb: Node3D = row[2]
	var sa: Node3D = row[1]
	var sb: Node3D = row[3]
	fa.visible = true
	fb.visible = true
	var loser: int = int(pr["loser"])
	var lane := (k - (pairs.size() - 1) / 2.0) * 3.0
	var centre := Vector3(0, 0, lane * 0.4)
	# base positions: enter from opposite ends of the long axis
	var ang := 0.4 * sin(tb * 0.35 + k)
	var n := Vector3(cos(ang), 0, sin(ang))
	var gap := 2.6
	var roar := 0.25
	var pos_a: Vector3
	var pos_b: Vector3
	var walking := 0.0
	var fight := tb >= 4.0 and tb < 20.5
	if tb < 4.0:
		var u := smoothstep(0.0, 4.0, tb)
		var start := rx - 3.0
		pos_a = centre - n * lerpf(start, gap / 2.0, u)
		pos_b = centre + n * lerpf(start, gap / 2.0, u)
		walking = 1.0 - absf(u - 0.5) * 0.0
	else:
		var cyc := (tb - 4.0) / 1.5
		var c := int(cyc)
		var ph := cyc - c
		var atk := (c + (c / 3)) % 2   # who attacks this round
		var lunge := sin(clampf(ph * 1.6, 0.0, 1.0) * PI)   # in and out
		var d := gap - 0.9 * lunge
		var sway := 0.25 * sin(cyc * 1.7)
		pos_a = centre - n * (d / 2.0) + Vector3(0, 0, sway)
		pos_b = centre + n * (d / 2.0) + Vector3(0, 0, sway)
		if not fight:
			pos_a = centre - n * (gap / 2.0)
			pos_b = centre + n * (gap / 2.0)
		roar = 0.3 + 0.25 * lunge
		_pose_fight(fa, fb, sa, sb, atk, ph, fight)
	fa.position = pos_a
	fb.position = pos_b
	F.face(fa, pos_b - pos_a)
	F.face(fb, pos_a - pos_b)
	if tb < 4.0:
		fa.walk(tb * 5.0, 0.9)
		fb.walk(tb * 5.0 + 1.0, 0.9)
		for pair in [[fa, sa], [fb, sb]]:
			_arms_ready(pair[0], pair[1], 0.0)
			_sword_arm(pair[0], -1.0)
		roar = 0.2 + 0.15 * smoothstep(1.0, 4.0, tb)
	if tb >= 20.5:
		roar = _pose_end(pr, loser, fa, fb, sa, sb, tb, pos_a, pos_b)
	return roar


const GUARD := Vector3(0.17, 0.2, 0.25)


## The shield on its guard (g 0 low .. 1 raised to parry) and the left hand behind it.
func _arms_ready(f: Node3D, sh: Node3D, g: float) -> void:
	sh.position = GUARD + Vector3(-0.07 * g, 0.13 * g, 0.1 * g)
	sh.rotation = Vector3(-0.15 * g, -0.25 * g, 0.0)
	f.hand_to(1, sh.position + Vector3(-0.0, -0.13, -0.07))


## The sword arm through a thrust, t 0..1: wind-up (eased), a fast strike, a recovery.
## t < 0 holds the guard.
func _sword_arm(f: Node3D, t: float) -> void:
	var pitch := -0.9
	var elbow := 1.25
	if t >= 0.0:
		var wind := smoothstep(0.0, 0.3, t)
		var strike := 1.0 - pow(1.0 - clampf((t - 0.3) / 0.14, 0.0, 1.0), 3.0)
		var back := smoothstep(0.58, 1.0, t)
		var w := wind * (1.0 - strike)
		var st := strike * (1.0 - back)
		pitch = -0.9 + 0.75 * w - 0.7 * st
		elbow = 1.25 + 0.45 * w - 1.05 * st
		f.torso.rotation.x += 0.22 * st
		f.torso.rotation.y += 0.5 * st - 0.2 * w
	f.arms[0].rotation = Vector3(pitch, 0.0, -0.12)
	f.elbows[0].rotation = Vector3(-elbow, 0, 0)


## A fighting crouch, the shield foot forward and the hips turned side-on.
func _stance(f: Node3D, sway: float) -> void:
	f.pelvis.position.y = 0.86
	f.legs[1].rotation = Vector3(-0.42, 0, 0.1)
	f.knees[1].rotation = Vector3(0.55, 0, 0)
	f.ankles[1].rotation = Vector3(-0.12, 0, 0)
	f.legs[0].rotation = Vector3(0.32 + 0.05 * sway, 0, -0.12)
	f.knees[0].rotation = Vector3(0.45, 0, 0)
	f.ankles[0].rotation = Vector3(0.12, 0, 0)
	f.pelvis.rotation = Vector3(0, -0.5, 0)
	f.torso.rotation = Vector3(0.1, -0.2, 0)
	f.head.rotation = Vector3(0, 0.55, 0)


func _pose_fight(fa: Node3D, fb: Node3D, sa: Node3D, sb: Node3D, atk: int, ph: float, fight: bool) -> void:
	var figs := [fa, fb]
	var shs := [sa, sb]
	for who in 2:
		var f: Node3D = figs[who]
		var sh: Node3D = shs[who]
		f.walk(0.0, 0.0)
		f.rotation.x = 0.0
		_stance(f, sin(ph * TAU + who))
		if who == atk:
			_arms_ready(f, sh, 0.0)
			_sword_arm(f, ph)
		else:
			# the defender raises his shield to meet the thrust and rocks back at the hit
			var g := smoothstep(0.15, 0.4, ph) * (1.0 - smoothstep(0.62, 0.95, ph))
			_arms_ready(f, sh, g)
			_sword_arm(f, -1.0)
			f.torso.rotation.x += 0.1 * g


func _pose_end(pr: Dictionary, loser: int, fa: Node3D, fb: Node3D, sa: Node3D, sb: Node3D, tb: float, pos_a: Vector3, pos_b: Vector3) -> float:
	var figs := [fa, fb]
	var shs := [sa, sb]
	var lf: Node3D = figs[loser]
	var wf: Node3D = figs[1 - loser]
	var lsh: Node3D = shs[loser]
	var wsh: Node3D = shs[1 - loser]
	var ploser: Vector3 = pos_a if loser == 0 else pos_b
	var pwin: Vector3 = pos_b if loser == 0 else pos_a
	var ldir := (pwin - ploser).normalized()
	var roar := 0.5
	# 20.5-23: the loser is hit and goes down on a knee
	var down := smoothstep(20.5, 22.5, tb)
	lf.walk(0.0, 0.0)
	lf.rotation.x = 0.0
	lf.kneel(down, false)
	lf.torso.rotation.x += 0.2 * down
	# the shield dropped, the sword arm limp
	lsh.position = GUARD.lerp(Vector3(0.28, -0.42, 0.42), down)
	lsh.rotation = Vector3(-1.2 * down, 0, 0)
	lf.arms[0].rotation = Vector3(0.1, 0, -0.15)
	lf.elbows[0].rotation = Vector3(-0.3, 0, 0)
	lf.hand_to(1, lsh.position + Vector3(0, 0.05, -0.1))
	wf.walk(0.0, 0.0)
	wf.rotation.x = 0.0
	_stance(wf, 0.0)
	_arms_ready(wf, wsh, 0.0)
	_sword_arm(wf, -1.0)
	wf.torso.rotation.x = 0.0
	if tb >= 23.0 and tb < 29.0:
		# raises a finger: the left arm up (the shield stays on the sand)
		var up := smoothstep(23.0, 24.0, tb)
		lf.arms[1].rotation = Vector3(lerpf(-0.3, -2.85, up), 0, 0.25 * up)
		lf.elbows[1].rotation = Vector3(-lerpf(0.4, 0.25, up), 0, 0)
		roar = 0.85
	# keep the winner a step back from the kneeling man
	wf.position = ploser + ldir * 1.9
	var pr_missio: bool = bool(pr["missio"])
	if tb >= 29.0:
		if pr_missio:
			# both leave toward the gate; the loser rises, the winner salutes
			var u := smoothstep(29.0, 34.0, tb)
			lf.kneel(1.0 - smoothstep(29.0, 30.5, tb), false)
			lf.position = ploser + Vector3(-signf(ploser.x + 0.001) * 20.0 * u, 0, 0)
			wf.position = wf.position + Vector3(signf(wf.position.x + 0.001) * 20.0 * u, 0, 0)
			F.face(lf, Vector3(-signf(ploser.x + 0.001), 0, 0))
			F.face(wf, Vector3(signf(wf.position.x + 0.001), 0, 0))
			var wk := smoothstep(30.0, 31.0, tb)
			if wk > 0.01:
				lf.walk(tb * 5.0, wk)
				wf.walk(tb * 5.0, wk)
			wf.arms[0].rotation = Vector3(-2.7, 0, -0.2)
			wf.elbows[0].rotation = Vector3(-0.35, 0, 0)
			roar = 0.9 - 0.4 * u
		else:
			# the winner strikes; the loser falls back and lies still
			var hit := smoothstep(29.0, 30.0, tb)
			_sword_arm(wf, 0.3 + 0.2 * hit)
			wf.torso.rotation.x = 0.35 * hit
			lf.kneel(1.0, false)
			lf.rotation.x = -1.4 * smoothstep(30.0, 31.5, tb)
			lf.position.y = 0.2 * smoothstep(30.0, 31.5, tb)
			lf.arms[1].rotation = Vector3(0.2, 0, 0.3)
			roar = 0.6
	return roar


## A close view for the cinematic camera: over the shoulder of one gladiator at the other.
func cine_view(time: float) -> Transform3D:
	var tt := minf(time, duration)
	var bout := int((tt - LEAD_IN) / BOUT) if tt >= LEAD_IN else 0
	bout = clampi(bout, 0, pairs.size() - 1)
	var a: Node3D = _fighters[bout][0]
	var b: Node3D = _fighters[bout][2]
	var pa := a.position
	var pb := b.position
	var dir := (pb - pa)
	dir.y = 0.0
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var mid := (pa + pb) * 0.5
	var from := pa - dir * 1.5 + side * 0.65 + Vector3(0, 1.75, 0)
	return look(from, mid + dir * 0.6 + Vector3(0, 1.15, 0))


func view_names() -> PackedStringArray:
	return PackedStringArray(["editor's seat", "arena rail", "high seat"])


func seat_views() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.append(look(Vector3(0, 4.0, rz + 5.0), Vector3(0, 1.0, 0)))
	out.append(look(Vector3(-rx - 2.0, 2.2, 6.0), Vector3(0, 1.0, 0)))
	out.append(look(Vector3(rx * 0.5, 11.0, -rz - 8.0), Vector3(0, 0.5, 0)))
	return out
