## A triumph along a street (U6): from the Campus Martius through the Porta Triumphalis, the
## Circi and the Via Sacra to the Capitol, in the sourced order (data/rome/city/spectacles.yaml,
## triumph.order; Plut. Aem. 32-34, Livy 45.40, Josephus BJ 7.123-157, Appian Pun. 66):
## the Senate and magistrates, trumpeters, the spoils and pictures (named from the engine's
## battle report), white oxen with gilt horns, captives, lictors, the general in the quadriga with
## the slave behind him, then the soldiers singing. Crowds line the street. At the top of the
## Clivus Capitolinus the procession halts and the sacrifice to Jupiter (sacrifice.gd) is played.
##
## Params: route (PackedVector3Array or Array of Vector3: the street, local metres, y the ground
## height; the way the Urbs scene gives from UrbsStreets.along), spoils (Array of String or of
## {name, kind: statue|gold|arms|picture}), general (String), captives (int, 8), soldiers (int, 48),
## march_seconds (time for the head to walk the route, default 110), crowd (bool), rows, seed.
## Everything is a function of time, so seek(t) works. Length = march + 75 s of sacrifice.
extends "res://scripts/urbs/spectacles/base.gd"

const F := preload("res://scripts/urbs/spectacles/figure.gd")
const A := preload("res://scripts/urbs/spectacles/animals.gd")
const M := preload("res://scripts/urbs/spectacles/meshlib.gd")
const R := preload("res://scripts/urbs/spectacles/rig.gd")
const Chariot := preload("res://scripts/urbs/spectacles/chariot.gd")
const Crowd := preload("res://scripts/urbs/crowd.gd")
const Sacrifice := preload("res://scripts/urbs/spectacles/sacrifice.gd")

var route: PackedVector3Array = PackedVector3Array()
var _cum: Array[float] = []
var length := 0.0
var march := 110.0
var speed := 4.0
var _members: Array = []    # {node, along, lat, kind, phase, stop}
var _chariot
var _general: Node3D
var _slave: Node3D
var _tail := 0.0
var _crowd: Node3D
var _sacrifice: Node3D
var _songs: Array[Label3D] = []
var _song_members: Array[int] = []
var _label_head: Label3D
var _spoil_labels: Array = []   # [Label3D, member index]


func _init(p: Dictionary = {}) -> void:
	params = p


func _ready() -> void:
	var r = params.get("route", null)
	if r is PackedVector3Array:
		route = r
	elif r is Array:
		for v in r:
			route.append(v)
	if route.size() < 2:
		route = PackedVector3Array([Vector3(0, 0, 0), Vector3(-300, 0, 0)])
	_cum = [0.0]
	for i in range(1, route.size()):
		_cum.append(_cum[i - 1] + route[i].distance_to(route[i - 1]))
	length = _cum[_cum.size() - 1]
	march = float(params.get("march_seconds", march))
	speed = length / march
	var rng := RandomNumberGenerator.new()
	rng.seed = int(params.get("seed", 21))
	_build_order(rng)
	_label_head = make_label("", 0.55, Color(1, 0.95, 0.8))
	for k in 3:
		var l := make_label("Io triumphe!", 0.9, Color(1, 0.9, 0.5))
		_songs.append(l)
	if bool(params.get("crowd", true)):
		var c = Crowd.new()
		c.toga_rows = 1
		c.standing = true
		c.add_seats(Crowd.line_seats(route, 6.5, int(params.get("rows", 2)), 1.6, 1.0, 0.0))
		c.build()
		add_child(c)
		_crowd = c
	# the sacrifice at the top: its frame is the last stretch of the route
	var d_end := route[route.size() - 1] - route[route.size() - 2]
	d_end.y = 0.0
	_sacrifice = Sacrifice.new({"favourable": true, "crowd": false, "prayer": ["Jupiter, Best and Greatest, keep this city and its people safe,", "and accept this offering from the victorious army,", "as is right."], "label": "The sacrifice to Jupiter"})
	add_child(_sacrifice)
	_sacrifice.playing = false
	_sacrifice.position = route[route.size() - 1] + d_end.normalized() * 6.0
	_sacrifice.transform.basis = Basis.looking_at(d_end.normalized(), Vector3.UP)
	duration = march + 12.0 + 75.0
	seek(float(params.get("start_at", 0.0)))


func _add_member(node: Node3D, along: float, lat: float, kind: String, stop := 0.0) -> int:
	add_child(node)
	_members.append({"node": node, "along": along, "lat": lat, "kind": kind, "phase": float(_members.size()) * 0.7, "stop": stop})
	return _members.size() - 1


func _build_order(rng: RandomNumberGenerator) -> void:
	var cursor := 0.0
	var tones := [Color(0.86, 0.66, 0.52), Color(0.8, 0.6, 0.46), Color(0.9, 0.72, 0.58), Color(0.74, 0.54, 0.42)]
	var hairs := [Color(0.14, 0.1, 0.08), Color(0.3, 0.2, 0.12), Color(0.45, 0.32, 0.18), Color(0.6, 0.58, 0.56)]
	var seed_n := 0
	# 1 the Senate and the magistrates, two by two
	for i in 12:
		seed_n += 1
		var f = F.person({"tunic": Color(0.9, 0.87, 0.8), "toga": true, "border": Color(0.52, 0.1, 0.32) if i < 4 else Color(0.94, 0.92, 0.84),
			"scale": rng.randf_range(0.96, 1.05), "skin": tones[rng.randi() % 4], "hair": hairs[rng.randi() % 4], "seed": seed_n, "belt_on": false})
		_add_member(f, cursor + (i / 2) * 2.2, -0.9 if i % 2 == 0 else 0.9, "walker", 24.0)
	cursor += 6 * 2.2 + 8.0
	# 2 trumpeters
	for i in 6:
		seed_n += 1
		var f = F.person({"tunic": Color(0.82, 0.74, 0.55), "skin": tones[rng.randi() % 4], "hair": hairs[rng.randi() % 4], "seed": seed_n})
		f.equip_tuba()
		_add_member(f, cursor + (i / 2) * 2.0, -0.9 if i % 2 == 0 else 0.9, "trumpeter", 20.0)
	cursor += 3 * 2.0 + 8.0
	# 3 the spoils and pictures, carried on litters by four men each
	var spoils: Array = params.get("spoils", ["spoils of the enemy"])
	if spoils.is_empty():
		spoils = ["spoils of the enemy"]
	var kinds := ["statue", "gold", "arms", "picture"]
	for k in spoils.size():
		var sp = spoils[k]
		var nm: String = sp if sp is String else str(sp.get("name", ""))
		var kd: String = kinds[k % 4] if sp is String else str(sp.get("kind", kinds[k % 4]))
		var litter := _make_litter(kd)
		var idx := _add_member(litter, cursor + 1.5, 0.0, "litter", 18.0 + k * 0.0)
		var lab := make_label(nm, 0.8, Color(1, 0.95, 0.75))
		_spoil_labels.append([lab, idx])
		for q in 4:
			seed_n += 1
			var f = F.person({"tunic": Color(0.74, 0.68, 0.52), "skin": tones[rng.randi() % 4], "hair": hairs[rng.randi() % 4], "seed": seed_n})
			_add_member(f, cursor + (0.0 if q < 2 else 3.0), -1.4 if q % 2 == 0 else 1.4, "bearer", 18.0)
		cursor += 9.0
	cursor += 4.0
	# 4 the white oxen, each with its leader
	for i in 4:
		var ox := A.make_ox()
		_add_member(ox, cursor + (i / 2) * 4.5, -1.4 if i % 2 == 0 else 1.4, "ox", 14.0)
		seed_n += 1
		var lead = F.person({"bare": true, "tunic": Color(0.9, 0.88, 0.8), "laurel": true, "seed": seed_n, "skin": tones[rng.randi() % 4]})
		lead.equip_limus()
		_add_member(lead, cursor + (i / 2) * 4.5 + 1.9, (-1.4 if i % 2 == 0 else 1.4) * 1.7, "walker", 14.0)
	cursor += 2 * 4.5 + 6.0
	# 5 captives in chains, the king first
	var n_cap := int(params.get("captives", 8))
	for i in n_cap:
		seed_n += 1
		var f = F.person({"tunic": Color(0.4, 0.34, 0.28) if i > 0 else Color(0.25, 0.2, 0.35), "skin": tones[rng.randi() % 4], "hair": hairs[rng.randi() % 4], "seed": seed_n, "sleeves": true})
		_add_member(f, cursor + (i / 2) * 1.8, -0.8 if i % 2 == 0 else 0.8, "captive", 12.0)
	cursor += ceil(n_cap / 2.0) * 1.8 + 6.0
	# 6 the lictors: two files, purple tunics, fasces
	for i in 12:
		seed_n += 1
		var f = F.person({"tunic": Color(0.45, 0.12, 0.38), "skin": tones[rng.randi() % 4], "hair": hairs[rng.randi() % 4], "seed": seed_n, "scale": 1.02})
		f.equip_fasces()
		_add_member(f, cursor + (i / 2) * 1.8, -1.0 if i % 2 == 0 else 1.0, "lictor", 9.0)
	cursor += 6 * 1.8 + 6.0
	# 7 the general in the quadriga, the slave behind him
	_chariot = Chariot.make(Color(0.85, 0.7, 0.2), 4, 5, true)
	_chariot.driver.visible = false
	_general = F.person({"tunic": Color(0.42, 0.1, 0.45), "toga": true, "picta": true, "laurel": true, "scale": 1.04,
		"seed": 91, "border": Color(0.9, 0.72, 0.2), "belt_on": false, "hair": Color(0.45, 0.4, 0.35), "hem": Color(0.9, 0.72, 0.2), "hem_band": true})
	_general.paint_face(Color(0.8, 0.3, 0.24))
	_general.equip_branch()
	_general.equip_sceptre()
	_general.position = Vector3(0, 0.455, 0.08)
	_general.pelvis.position.y = 0.8
	for li in 2:
		_general.legs[li].rotation = Vector3(-0.28, 0, 0.07 * (1.0 if li == 0 else -1.0))
		_general.knees[li].rotation = Vector3(0.55, 0, 0)
		_general.ankles[li].rotation = Vector3(-0.27, 0, 0)
	_general.arms[0].rotation = Vector3(-0.6, 0, -0.35)
	_general.elbows[0].rotation = Vector3(-1.2, 0, 0)
	_general.arms[1].rotation = Vector3(-0.35, 0, 0.1)
	_general.elbows[1].rotation = Vector3(-1.0, 0, 0)
	_chariot.car.add_child(_general)
	_slave = F.person({"tunic": Color(0.68, 0.6, 0.46), "scale": 0.95, "seed": 92, "skin": Color(0.74, 0.54, 0.42)})
	_slave.position = Vector3(0, 0.455, -0.5)
	_slave.arms[0].rotation = Vector3(-2.6, 0, -0.3)
	_slave.elbows[0].rotation = Vector3(-0.4, 0, 0)
	_slave.arms[1].rotation = Vector3(0.0, 0, 0.1)
	var crown := F._cached("golden_crown", func():
		var pts: Array = []
		var rr: Array = []
		for i in 17:
			var a := float(i) / 16.0 * TAU
			pts.append(Vector3(sin(a) * 0.11, 0.0, cos(a) * 0.11))
			rr.append(0.012 + 0.006 * (i % 2))
		return M.tube(pts, rr, 6))
	F._part(_slave.hand_r, crown, F.metal(Color(0.92, 0.76, 0.25), 0.8), Vector3(0, 0.09, 0))
	_chariot.car.add_child(_slave)
	var kid = F.person({"tunic": Color(0.9, 0.87, 0.8), "toga": true, "border": Color(0.52, 0.1, 0.32), "scale": 0.52, "seed": 93, "belt_on": false})   # boys and girls rode with him (Appian Pun. 66)
	kid.position = Vector3(0.38, 0.455, 0.2)
	_chariot.car.add_child(kid)
	add_child(_chariot.car)
	add_child(_chariot.team)
	_members.append({"node": _chariot.car, "along": cursor + 6.0, "lat": 0.0, "kind": "chariot", "phase": 0.0, "stop": 6.0})
	cursor += 12.0
	# 8 the soldiers, in files, wreathed, singing
	var n_sol := int(params.get("soldiers", 48))
	for i in n_sol:
		seed_n += 1
		var f = F.person({"tunic": Color(0.66, 0.24, 0.2), "laurel": true, "scale": rng.randf_range(0.97, 1.05), "skin": tones[rng.randi() % 4], "hair": hairs[rng.randi() % 4], "seed": seed_n})
		f.equip_spear()
		var mi := _add_member(f, cursor + (i / 4) * 1.5, (i % 4 - 1.5) * 0.95, "soldier", 2.0 + (i / 4) * 0.5)
		if i % 17 == 8:
			_song_members.append(mi)
	_tail = cursor + ceil(n_sol / 4.0) * 1.5


func _make_litter(kind: String) -> Node3D:
	var n := Node3D.new()
	var plist: Array = []
	var bx := func(key: String, size: Vector3, at: Vector3, col: Color, metal := 0.0) -> void:
		plist.append(F.rp(key, F.fmesh(func(): return M.box(size)), at, Vector3.ZERO, 5, col, metal))
	bx.call("l_deck", Vector3(2.4, 0.15, 1.5), Vector3(0, 1.15, 0), Color(0.5, 0.36, 0.2))
	match kind:
		"statue":
			bx.call("l_body", Vector3(0.6, 0.9, 0.5), Vector3(0, 1.7, 0), Color(0.85, 0.82, 0.76))
			bx.call("l_head", Vector3(0.35, 0.35, 0.35), Vector3(0, 2.35, 0), Color(0.85, 0.82, 0.76))
		"gold":
			for i in 5:
				bx.call("l_ingot", Vector3(0.6, 0.3, 0.4), Vector3(-0.8 + i * 0.4, 1.4 + (i % 2) * 0.3, 0), Color(0.9, 0.75, 0.2), 0.8)
		"arms":
			for i in 4:
				bx.call("l_spear", Vector3(0.08, 1.3, 0.5), Vector3(-0.9 + i * 0.6, 1.9, 0), Color(0.6, 0.62, 0.66), 0.5)
			bx.call("l_shield", Vector3(0.7, 0.9, 0.05), Vector3(0, 1.8, 0.3), Color(0.3, 0.45, 0.6))
		_:
			bx.call("l_frame", Vector3(1.8, 1.3, 0.06), Vector3(0, 1.95, 0), Color(0.7, 0.5, 0.3))
			bx.call("l_pic", Vector3(1.5, 1.0, 0.07), Vector3(0, 1.95, 0), Color(0.35, 0.5, 0.65))
	R.rigid(n, "litter_" + kind, plist)
	return n


## Position and heading at distance `s` along the street (before the start it runs backwards
## along the first segment).
func sample(s: float) -> Array:
	if s <= 0.0:
		var d0 := (route[1] - route[0])
		var dn := d0.normalized()
		return [route[0] + dn * s, dn]
	if s >= length:
		var dl := (route[route.size() - 1] - route[route.size() - 2]).normalized()
		return [route[route.size() - 1] + dl * (s - length), dl]
	var i := 0
	while i < _cum.size() - 2 and _cum[i + 1] < s:
		i += 1
	var u: float = (s - _cum[i]) / maxf(_cum[i + 1] - _cum[i], 0.001)
	return [route[i].lerp(route[i + 1], u), (route[i + 1] - route[i]).normalized()]


func _apply(time: float) -> void:
	var tt := minf(time, duration)
	var head := speed * tt
	var halted := tt >= march
	for m in _members:
		var node: Node3D = m["node"]
		var s: float = head - float(m["along"])
		var stop: float = m["stop"]
		var limit: float = length - stop
		var moving := s < limit
		s = minf(s, limit)
		var r := sample(s)
		var dir: Vector3 = r[1]
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var pos: Vector3 = r[0] + side * float(m["lat"])
		if not halted and s > limit - 0.1:
			moving = false
		node.position = pos
		F.face(node, r[1] if m["kind"] != "chariot" else r[1])
		var phase: float = s * 2.3 + float(m["phase"])
		match m["kind"]:
			"walker":
				node.walk(phase, 1.0 if moving else 0.0)
			"trumpeter":
				node.walk(phase, 1.0 if moving else 0.0)
				node.arms[0].rotation = Vector3(-1.1, 0, -0.1)
				node.elbows[0].rotation = Vector3(-1.9, 0, 0)
				node.arms[1].rotation = Vector3(-0.3, 0, 0.1)
				node.elbows[1].rotation = Vector3(-0.6, 0, 0)
				node.head.rotation.x = -0.1
			"bearer":
				node.walk(phase, 1.0 if moving else 0.0)
				node.arms[0].rotation = Vector3(-0.7, 0, -0.25)
				node.arms[1].rotation = Vector3(-0.7, 0, 0.25)
				node.elbows[0].rotation = Vector3(-0.9, 0, 0)
				node.elbows[1].rotation = Vector3(-0.9, 0, 0)
			"lictor":
				node.walk(phase, 1.0 if moving else 0.0)
				node.arms[0].rotation = Vector3(-0.35, 0, -0.15)
				node.elbows[0].rotation = Vector3(-1.25, 0, 0)
			"soldier":
				node.walk(phase, 1.0 if moving else 0.0, 0.0)
				node.arms[0].rotation = Vector3(-0.5 + 0.05 * sin(tt * 3.0 + float(m["phase"])), 0, -0.15)
				node.elbows[0].rotation = Vector3(-1.2, 0, 0)
				node.head.rotation.x = -0.12 + 0.06 * sin(tt * 6.0 + float(m["phase"]))   # singing, chin up
			"captive":
				node.walk(phase * 0.8, 0.8 if moving else 0.0)
				node.arms[0].rotation = Vector3(-0.8, 0, 0.35)
				node.arms[1].rotation = Vector3(-0.8, 0, -0.35)
				node.elbows[0].rotation = Vector3(-1.1, 0, 0)
				node.elbows[1].rotation = Vector3(-1.1, 0, 0)
				node.head.rotation.x = 0.25
			"ox":
				A.walk_ox(node, phase * 1.2, 1.0 if moving else 0.0)
			"litter":
				node.position.y += 0.0
			"chariot":
				var ts := minf(head - float(m["along"]) + Chariot.POLE, length - stop + Chariot.POLE)
				var rt := sample(ts)
				_chariot.team.position = rt[0]
				F.face(_chariot.team, rt[1])
				_chariot.animate(s, s * 0.55, 0.4 if moving else 0.0)
				_chariot.update_reins()
	# litter bearers: raise the litter to their shoulders by following the lead
	for sl in _spoil_labels:
		var idx: int = sl[1]
		var lab: Label3D = sl[0]
		var n: Node3D = _members[idx]["node"]
		lab.position = n.position + Vector3(0, 3.3, 0)
	# the soldiers' song
	for k in _songs.size():
		var vis := _song_members.size() > 0 and fposmod(tt / 5.0 + k / 3.0, 1.0) < 0.3
		_songs[k].visible = vis
		if _song_members.size() > 0:
			var mem: Dictionary = _members[_song_members[k % _song_members.size()]]
			_songs[k].position = (mem["node"] as Node3D).position + Vector3(0, 2.6, 0)
	# the general's name rides above the quadriga
	var gen: String = str(params.get("general", ""))
	_label_head.text = gen if tt < march else ""
	_label_head.position = _chariot.car.position + Vector3(0, 3.4, 0)
	_label_head.visible = gen != "" and tt < march
	if _crowd != null:
		_crowd.set_state(tt, 0.55 if not halted else 0.35, clampf(head / length, 0.0, 1.0), 0.9)
	# the sacrifice to Jupiter once the head has reached the top
	var ts0 := march + 8.0
	_sacrifice.visible = tt >= ts0
	if tt >= ts0:
		_sacrifice.seek(tt - ts0)


## The cameras: at a stand a third of the way, by the Forum end, and at the foot of the ascent
## looking up; plus one at the sacrifice.
func view_names() -> PackedStringArray:
	return PackedStringArray(["the street", "the quadriga", "the Clivus", "the sacrifice"])


func seat_views() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for f in [0.18, 0.55, 0.9]:
		var s: float = length * f
		var r := sample(s)
		var dir: Vector3 = r[1]
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var from: Vector3 = (r[0] as Vector3) + side * 9.0 + Vector3(0, 5.0, 0) - dir * 4.0
		out.append(look(from, (r[0] as Vector3) + dir * 10.0 + Vector3(0, 1.5, 0)))
	out.append(_sacrifice.transform * look(Vector3(8.0, 2.4, 9.0), Vector3(0.5, 1.2, 0.5)))
	return out


## Where the head of the procession is at time `time` (for a camera that follows the general).
func general_at(time: float) -> Vector3:
	for m in _members:
		if m["kind"] == "chariot":
			return sample(minf(speed * time - float(m["along"]), length - float(m["stop"])))[0]
	return sample(minf(speed * time, length))[0]


## A close view of the general in his quadriga, from the front and a little below.
func cine_view(time: float) -> Transform3D:
	var tt := minf(time, march)
	var g := Vector3.ZERO
	var d := Vector3(1, 0, 0)
	for m in _members:
		if m["kind"] == "chariot":
			var s := clampf(speed * tt - float(m["along"]), -50.0, length - float(m["stop"]))
			var r := sample(s)
			g = r[0]
			d = r[1]
			d.y = 0.0
			d = d.normalized()
	var side := Vector3(-d.z, 0, d.x)
	return look(g + d * 1.2 + side * 5.2 + Vector3(0, 1.5, 0), g + Vector3(0, 1.55, 0) + d * 0.2)
