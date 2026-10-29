## The Senate in session (U6): the senators take their benches by rank (consulars nearest the
## tribunal), the presiding consul on his curule chair lays the matter before them (relatio),
## speakers rise in order of rank, then the division: those for the proposal walk to one side of
## the hall, those against to the other, and are counted (discessio, "pedibus in sententiam";
## Gellius 14.7, data/rome/city/spectacles.yaml). It plays the engine's REAL vote.
##
## Params: vote {issue: String, yes_bp: int, no_bp: int, passes: bool} (basis points of the
## house for and against, from the engine's view); hall (Vector2: width x, length z, default
## 24 x 40); benches (Array of Vector3 seat positions, nearest the tribunal first; default three
## tiers along both long walls); count (senators shown, default 60: the house is drawn to scale,
## the tallies are scaled to the real size via `house`, default 300); seed.
## Local frame: hall centre at the origin, tribunal at the -z end, door at the +z end, floor y = 0.
extends "res://scripts/urbs/spectacles/base.gd"

const F := preload("res://scripts/urbs/spectacles/figure.gd")

const T_ENTER := 26.0
const T_RELATIO := 36.0
const T_SPEAK_END := 66.0
const T_CALL := 70.0
const T_WALK := 82.0
const T_COUNT := 90.0

var hall := Vector2(24.0, 40.0)
var vote := {"issue": "", "yes_bp": 5000, "no_bp": 5000, "passes": true}
var count := 60
var house := 300
var _sen: Array = []           # figures
var _seat: Array[Vector3] = []
var _enter_at: Array[float] = []
var _yes: Array[bool] = []
var _side_target: Array[Vector3] = []
var _consul: Node3D
var _speakers: Array[int] = []
var _label: Label3D
var _tally_yes: Label3D
var _tally_no: Label3D
var _n_yes := 0


func _init(p: Dictionary = {}) -> void:
	params = p


func _ready() -> void:
	hall = params.get("hall", hall)
	vote = params.get("vote", vote)
	count = int(params.get("count", count))
	house = int(params.get("house", house))
	duration = T_COUNT + 10.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(params.get("seed", 9))
	var benches: Array = params.get("benches", _default_benches())
	count = mini(count, benches.size())
	# who votes yes: the engine's split, shuffled
	var yes_share := float(vote["yes_bp"]) / maxf(float(vote["yes_bp"]) + float(vote["no_bp"]), 1.0)
	_n_yes = roundi(count * yes_share)
	var flags: Array[bool] = []
	for i in count:
		flags.append(i < _n_yes)
	for i in range(count - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := flags[i]
		flags[i] = flags[j]
		flags[j] = tmp
	_yes = flags
	var z_top := -hall.y / 2.0 + 7.0
	var yes_i := 0
	var no_i := 0
	for i in count:
		var consular := i < 6
		var tones := [Color(0.86, 0.66, 0.52), Color(0.8, 0.6, 0.46), Color(0.9, 0.72, 0.58), Color(0.74, 0.54, 0.42)]
		var grey := rng.randf() < (0.55 if consular else 0.3)
		var f = F.person({"tunic": Color(0.9, 0.87, 0.8), "toga": true, "border": Color(0.94, 0.92, 0.84), "scale": rng.randf_range(0.95, 1.05),
			"skin": tones[rng.randi() % tones.size()], "seed": i + 1, "belt_on": false,
			"hair": Color(0.62, 0.6, 0.58) if grey else Color(0.14, 0.1, 0.08).lerp(Color(0.4, 0.28, 0.16), rng.randf())})
		add_child(f)
		_sen.append(f)
		_seat.append(benches[i])
		_enter_at.append(i * 0.2)
		# the division: a column each side of the hall floor
		var idx := yes_i if _yes[i] else no_i
		if _yes[i]:
			yes_i += 1
		else:
			no_i += 1
		var col := idx % 3
		var row := idx / 3
		var sx := 2.0 + col * 1.4
		_side_target.append(Vector3(sx if _yes[i] else -sx, 0, z_top + 3.0 + row * 1.3))
	_consul = F.person({"tunic": Color(0.9, 0.87, 0.8), "toga": true, "border": Color(0.52, 0.1, 0.32), "scale": 1.05, "seed": 77, "hair": Color(0.5, 0.48, 0.46), "belt_on": false})
	_consul.position = Vector3(0, 0.9, -hall.y / 2.0 + 2.4)
	add_child(_consul)
	_curule_chair(_consul)
	_speakers = [0, 1, 7, 15]
	_label = make_label("", 0.9, Color(1, 0.95, 0.8))
	_label.position = Vector3(0, 5.5, -hall.y / 2.0 + 3.0)
	_tally_yes = make_label("", 1.0, Color(0.7, 1.0, 0.7))
	_tally_yes.position = Vector3(4.0, 4.0, 0.0)
	_tally_no = make_label("", 1.0, Color(1.0, 0.7, 0.7))
	_tally_no.position = Vector3(-4.0, 4.0, 0.0)
	seek(float(params.get("start_at", 0.0)))


func _default_benches() -> Array:
	var out: Array = []
	var per_row := 12
	var spacing := (hall.y - 10.0) / float(per_row)
	for i in per_row:
		for k in 3:
			for sx in [1.0, -1.0]:
				var x: float = sx * (hall.x / 2.0 - 0.6 - k * 1.2)
				out.append(Vector3(x, 0.35 + 0.35 * k, -hall.y / 2.0 + 7.0 + i * spacing))
	return out


# Position along a polyline after walking `d` metres, and the heading there.
func _along(pts: Array, d: float) -> Array:
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var l := a.distance_to(b)
		if d <= l or i == pts.size() - 2:
			var u := clampf(d / maxf(l, 0.001), 0.0, 1.0)
			return [a.lerp(b, u), b - a, u >= 1.0]
		d -= l
	return [pts[pts.size() - 1], Vector3.FORWARD, true]


func _apply(time: float) -> void:
	var tt := minf(time, duration)
	var door := Vector3(0, 0, hall.y / 2.0 - 1.5)
	var speaker_now := -1
	if tt >= T_RELATIO and tt < T_SPEAK_END:
		speaker_now = int((tt - T_RELATIO) / ((T_SPEAK_END - T_RELATIO) / _speakers.size()))
	var yes_now := 0
	var no_now := 0
	for i in count:
		var f: Node3D = _sen[i]
		var seat: Vector3 = _seat[i]
		var enter_path := [door + Vector3(0, 0, 0), Vector3(0, 0, seat.z), Vector3(seat.x, 0, seat.z)]
		var path_len := 0.0
		for k in range(enter_path.size() - 1):
			path_len += (enter_path[k] as Vector3).distance_to(enter_path[k + 1])
		var te := tt - _enter_at[i]
		var walk_speed := 2.2
		f.visible = te >= 0.0
		f.sit(0.0)
		f.pose_arms(0, 0)
		f.rotation = Vector3.ZERO
		if te < 0.0:
			continue
		var face_in := Vector3(-signf(seat.x), 0, 0)
		if te * walk_speed < path_len and tt < T_ENTER + 6.0:
			var r := _along(enter_path, te * walk_speed)
			f.position = r[0]
			F.face(f, r[1])
			f.walk(te * walk_speed * 2.6)
		elif tt < T_CALL:
			# seated; the speaker rises
			f.position = seat + Vector3(0, 0, 0)
			var spk: bool = speaker_now >= 0 and _speakers[speaker_now] == i
			F.face(f, face_in)
			if spk:
				var up := smoothstep(0.0, 0.8, (tt - T_RELATIO) - speaker_now * ((T_SPEAK_END - T_RELATIO) / _speakers.size()))
				f.sit(1.0 - up)
				f.position = seat
				F.face(f, Vector3(0, 0, -1))
				f.pose_arms(-0.6 + 0.5 * sin(tt * 2.5), -1.2 + 0.4 * sin(tt * 3.1 + 1.0), 0.2, 0.2)
			else:
				f.sit(1.0)
				f.position = seat
				# the house listens; heads turn toward the speaker or the chair
				if speaker_now >= 0:
					var sp: Vector3 = _seat[_speakers[speaker_now]]
					F.face(f, Vector3(sp.x - seat.x, 0, sp.z - seat.z))
				else:
					F.face(f, Vector3(face_in.x, 0, -0.4))
		else:
			# the division
			var target: Vector3 = _side_target[i]
			var go := [seat, Vector3(0, 0, seat.z), Vector3(0, 0, target.z), target]
			var dlen := 0.0
			for k in range(go.size() - 1):
				dlen += (go[k] as Vector3).distance_to(go[k + 1])
			var u := clampf((tt - T_CALL - (i % 13) * 0.35) / (T_WALK - T_CALL), 0.0, 1.0)
			var r := _along(go, u * dlen)
			f.position = r[0]
			if u <= 0.0:
				f.sit(1.0)
				F.face(f, face_in)
			elif r[2]:
				F.face(f, Vector3(0, 0, -1))
				f.pose_arms(-0.2, -0.2)
				if _yes[i]:
					yes_now += 1 if tt >= T_WALK + (i % 7) * 0.3 else 0
					f.pose_arms(-0.2, -0.2 - 0.0)
				else:
					no_now += 1 if tt >= T_WALK + (i % 7) * 0.3 else 0
			else:
				F.face(f, r[1])
				f.walk(u * dlen * 2.6)
	# the presiding consul
	_consul.pose_arms(0, 0)
	if tt >= T_ENTER - 4.0 and tt < T_RELATIO:
		_consul.pose_arms(-0.5, -0.2)
	if tt >= T_RELATIO and tt < T_RELATIO + 7.0:
		_consul.pose_arms(-1.0 + 0.4 * sin(tt * 3.0), -0.3)
	if tt >= T_SPEAK_END and tt < T_CALL + 4.0:
		_consul.pose_arms(-2.6, 0.0)
	# the words on the chair
	_label.text = ""
	if tt >= T_RELATIO and tt < T_RELATIO + 7.0:
		_label.text = "Relatio: " + str(vote.get("issue", ""))
	elif speaker_now >= 0:
		_label.text = ["A consular speaks first", "Another consular", "A praetorian", "A senator of lower rank"][speaker_now]
	elif tt >= T_SPEAK_END and tt < T_WALK:
		_label.text = "Division: those who agree, to this side; the others to that"
	elif tt >= T_COUNT:
		_label.text = ("Passed" if bool(vote.get("passes", false)) else "Not passed") + ("  %.1f%% for, %.1f%% against" % [float(vote["yes_bp"]) / 100.0, float(vote["no_bp"]) / 100.0])
	# the count
	var show := tt >= T_WALK
	var scale_ := float(house) / float(maxi(count, 1))
	_tally_yes.text = "For\n%d" % roundi(yes_now * scale_) if show else ""
	_tally_no.text = "Against\n%d" % roundi(no_now * scale_) if show else ""


func view_names() -> PackedStringArray:
	return PackedStringArray(["from the door", "the chair", "a bench"])


func seat_views() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.append(look(Vector3(0, 3.5, hall.y / 2.0 - 1.0), Vector3(0, 1.5, -hall.y / 2.0 + 5.0)))
	out.append(look(Vector3(0, 3.0, -hall.y / 2.0 + 1.0), Vector3(0, 1.0, 8.0)))
	out.append(look(Vector3(-hall.x / 2.0 + 1.5, 2.6, -2.0), Vector3(hall.x / 2.0 - 3.0, 1.2, 6.0)))
	return out


## The curule chair: an ivory X-frame with a leather seat, under the consul's feet origin.
func _curule_chair(parent: Node3D) -> void:
	const M := preload("res://scripts/urbs/spectacles/meshlib.gd")
	var ivory := Color(0.93, 0.89, 0.76)
	for sx in [-1.0, 1.0]:
		for sg in [-1.0, 1.0]:
			var piv := Node3D.new()
			piv.position = Vector3(sx * 0.24, 0.46, -0.15 + sg * 0.2)
			piv.rotation.x = sg * asin(0.4 / 0.62)
			parent.add_child(piv)
			F._part(piv, M.capsule(0.022, 0.022, 0.6, 6), F.mat(ivory))
	F._part(parent, M.ellipsoid(0.3, 0.03, 0.27, 12, 4), F.cloth(Color(0.55, 0.12, 0.12)), Vector3(0, 0.48, -0.15))


func cine_view(time: float) -> Transform3D:
	var tt := minf(time, duration)
	var tgt := Vector3(0, 1.4, -hall.y / 2.0 + 2.6)
	if tt >= T_RELATIO and tt < T_SPEAK_END and _speakers.size() > 0:
		var k := clampi(int((tt - T_RELATIO) / ((T_SPEAK_END - T_RELATIO) / _speakers.size())), 0, _speakers.size() - 1)
		if _speakers[k] < _seat.size():
			var sp: Vector3 = _seat[_speakers[k]]
			tgt = sp + Vector3(0, 1.5, 0)
	elif tt >= T_CALL:
		tgt = Vector3(0, 1.3, -hall.y / 2.0 + 10.0)
	return look(Vector3(-hall.x / 2.0 + 2.6, 2.3, 4.0) if tt < T_CALL else Vector3(0, 2.4, 2.0), tgt)
