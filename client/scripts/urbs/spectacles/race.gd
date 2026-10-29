## The chariot race in the Circus (U6). Twelve chariots (ten quadrigae, two bigae) in the four
## faction colours start from the carceres when the mappa drops, run seven laps anticlockwise
## round the spina, overtake on the turns, sometimes crash at a meta, and finish while the crowd
## roars; eggs on the spina are turned over one by one as the leader completes each lap
## (Livy 41.27; data/rome/city/spectacles.yaml). The whole race is simulated up front with a
## seeded RNG, so seek(t) is exact and replays are identical. About 90 s (time-compressed:
## real races ran many minutes).
##
## Params (all optional): length (track length x, 580), width (track width z, 90), laps (7),
## seed, duration (90), rows / spacing (crowd), crashes (0..2, default 2), crowd (bool).
## Local frame: spina on the x axis, carceres at the west (-x) end, floor at y = 0; the parent
## scales/places it on the circus monument.
extends "res://scripts/urbs/spectacles/base.gd"

const F := preload("res://scripts/urbs/spectacles/figure.gd")
const Chariot := preload("res://scripts/urbs/spectacles/chariot.gd")
const Crowd := preload("res://scripts/urbs/crowd.gd")

const N := 12
const DT := 0.05
const GATE_T := 4.0
const FACTIONS := [
	["albata", Color(0.93, 0.93, 0.90)], ["russata", Color(0.80, 0.16, 0.14)],
	["prasina", Color(0.20, 0.55, 0.28)], ["veneta", Color(0.20, 0.38, 0.75)],
]

var length := 580.0
var width := 90.0
var laps := 7
var Ls := 250.0          # half the straight: turn centres at x = +-Ls
var r_in := 7.0
var r_out := 43.0
var P0 := 0.0            # lap length on the inner line
var s_fin := 0.0

# simulation tables, one entry per step
var _steps := 0
var _S: Array[PackedFloat32Array] = []    # car progress
var _R: Array[PackedFloat32Array] = []    # car lateral radius
var _TS: Array[PackedFloat32Array] = []   # team progress
var _TR: Array[PackedFloat32Array] = []
var _crash_t: Array[float] = []           # per chariot, -1 if none
var _fin_t: Array[float] = []
var _lap_times: Array[float] = []         # leader's crossing of the line, per lap
var winner := -1
var results: Array[int] = []              # chariot indices in finishing order

var _ch: Array = []
var _gates: Array[Node3D] = []
var _eggs: Array[Node3D] = []
var _mappa: MeshInstance3D
var _crowd: Node3D
var _label: Label3D


func _init(p: Dictionary = {}) -> void:
	params = p


func _ready() -> void:
	length = float(params.get("length", length))
	width = float(params.get("width", width))
	laps = int(params.get("laps", laps))
	duration = float(params.get("duration", 90.0))
	Ls = length / 2.0 - width / 2.0
	r_out = width / 2.0 - 2.0
	P0 = 4.0 * Ls + TAU * r_in
	s_fin = Ls + (laps - 1) * P0
	_simulate(int(params.get("seed", 3)), int(params.get("crashes", 2)))
	_build()
	seek(float(params.get("start_at", 0.0)))


# ---- track geometry -------------------------------------------------------------------

## Position and heading at progress s (metres along the inner line) and lateral radius r.
func track_at(s: float, r: float) -> Array:
	var P := P0
	if s < 0.0:
		return [Vector3(-Ls + s, 0, r), Vector3.RIGHT]
	s = fposmod(s, P) if s > P else s
	var straight := 2.0 * Ls
	var turn := PI * r_in
	if s < straight:
		return [Vector3(-Ls + s, 0, r), Vector3.RIGHT]
	s -= straight
	if s < turn:
		var a := s / r_in
		return [Vector3(Ls + sin(a) * r, 0, cos(a) * r), Vector3(cos(a), 0, -sin(a))]
	s -= turn
	if s < straight:
		return [Vector3(Ls - s, 0, -r), Vector3.LEFT]
	s -= straight
	var a2 := s / r_in
	return [Vector3(-Ls - sin(a2) * r, 0, -cos(a2) * r), Vector3(-cos(a2), 0, sin(a2))]


func _in_turn(s: float) -> bool:
	var m := fposmod(s, P0)
	return (m > 2.0 * Ls and m < 2.0 * Ls + PI * r_in) or m > 4.0 * Ls + PI * r_in


# ---- the simulation ---------------------------------------------------------------------

func _simulate(seed_value: int, crashes: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_steps = int(duration / DT) + 2
	var s := PackedFloat64Array()
	var r := PackedFloat64Array()
	var ts := PackedFloat64Array()
	var tr := PackedFloat64Array()
	var ability: Array[float] = []
	var ph1: Array[float] = []
	var ph2: Array[float] = []
	var lane_w := (r_out - r_in) / float(N)
	var crash_s: Array[float] = []
	var car_v: Array[float] = []
	var fin: Array[float] = []
	_crash_t = []
	_fin_t = []
	for i in N:
		s.append(-10.0 + i * 0.7)
		r.append(r_in + (i + 0.5) * lane_w)
		ts.append(s[i] + Chariot.POLE)
		tr.append(r[i])
		ability.append(1.0 + rng.randf_range(-0.03, 0.03))
		ph1.append(rng.randf() * TAU)
		ph2.append(rng.randf() * TAU)
		crash_s.append(-1.0)
		car_v.append(0.0)
		fin.append(-1.0)
		_crash_t.append(-1.0)
		_fin_t.append(-1.0)
		_S.append(PackedFloat32Array())
		_R.append(PackedFloat32Array())
		_TS.append(PackedFloat32Array())
		_TR.append(PackedFloat32Array())
	# crashes: a chosen chariot, lap and meta
	var pool: Array[int] = []
	for i in N:
		pool.append(i)
	for k in crashes:
		var pick := rng.randi() % pool.size()
		var who := pool[pick]
		pool.remove_at(pick)
		var lap := 1 + rng.randi() % (laps - 3)
		var east := rng.randf() < 0.5
		crash_s[who] = lap * P0 + (2.0 * Ls + 0.35 * PI * r_in if east else 4.0 * Ls + PI * r_in + 0.35 * PI * r_in)
	var t_run := duration * 0.80 - GATE_T
	var v_nom := (s_fin + 10.0) / t_run * 1.03
	var line_next := 0
	_lap_times = []
	var wreck_v: Array[float] = []
	for i in N:
		wreck_v.append(0.0)
	for step in _steps:
		var t := step * DT
		for i in N:
			_S[i].append(s[i])
			_R[i].append(r[i])
			_TS[i].append(ts[i])
			_TR[i].append(tr[i])
		if t < GATE_T:
			continue
		var ramp := smoothstep(0.0, 1.0, (t - GATE_T) / 5.0)
		var ns := s.duplicate()
		var nr := r.duplicate()
		var nts := ts.duplicate()
		var ntr := tr.duplicate()
		for i in N:
			var v: float = v_nom * ability[i] * (1.0 + 0.035 * sin(0.3 * t + ph1[i]) + 0.025 * sin(0.11 * t + ph2[i]))
			v *= 0.2 + 0.8 * ramp
			if _in_turn(s[i]):
				v *= 0.9
			var wrecked: bool = _crash_t[i] >= 0.0
			# traffic: the nearest car ahead on a similar line
			var blocker := -1
			var gap := 1e9
			for j in N:
				if j == i:
					continue
				var d: float = s[j] - s[i]
				if d > 0.0 and d < 16.0 and absf(r[j] - r[i]) < 3.2 and d < gap:
					gap = d
					blocker = j
			var target: float = r_in
			if blocker >= 0 and not wrecked:
				var jw: bool = _crash_t[blocker] >= 0.0
				var out_r: float = r[blocker] + 3.4
				var in_r: float = r[blocker] - 3.4
				if (_in_turn(s[i]) or jw or gap < 9.0) and out_r <= r_out:
					target = out_r
				elif in_r >= r_in and (_in_turn(s[i]) or jw):
					target = in_r
				elif not jw:
					v = minf(v, v_nom * 0.95)
				if jw:
					v *= 0.85
				elif gap < 8.0 and absf(target - r[blocker]) < 3.0:
					v = minf(v, v_nom * 0.97 * ability[blocker])
			elif not wrecked and gap > 1e8:
				# slipstream and keep the inside line when clear
				target = r_in
			if wrecked:
				# the car skids to a stop; the team runs on and drifts outward
				car_v[i] *= exp(-DT * 2.2)
				ns[i] = s[i] + car_v[i] * DT
			else:
				var vs: float = v * (r_in / maxf(r[i], r_in) if _in_turn(s[i]) else 1.0)
				# a finished chariot slows to the applause
				if fin[i] >= 0.0:
					vs *= 1.0 - 0.6 * smoothstep(0.0, 4.0, t - fin[i])
				car_v[i] = vs
				ns[i] = s[i] + vs * DT
				# lateral move, only into free water
				var want: float = clampf(target, r_in, r_out)
				var step_r: float = clampf(want - r[i], -3.5 * DT, 3.5 * DT)
				var cand: float = r[i] + step_r
				var free := true
				for j in N:
					if j != i and absf(s[j] - s[i]) < 8.0 and absf(r[j] - cand) < 3.1 and absf(r[j] - cand) < absf(r[j] - r[i]) + 0.001:
						free = false
				if free:
					nr[i] = cand
				if crash_s[i] >= 0.0 and s[i] < crash_s[i] and ns[i] >= crash_s[i]:
					_crash_t[i] = t
				if fin[i] < 0.0 and ns[i] >= s_fin:
					fin[i] = t
					_fin_t[i] = t
					results.append(i)
			# team
			if wrecked:
				var vt: float = v_nom * 0.8
				nts[i] = ts[i] + vt * DT
				ntr[i] = minf(tr[i] + 1.2 * DT, r_out)
			else:
				nts[i] = ns[i] + Chariot.POLE
				ntr[i] = nr[i]
		s = ns
		r = nr
		ts = nts
		tr = ntr
		# the leader's lap times
		var lead := -1e9
		for i in N:
			lead = maxf(lead, s[i])
		if line_next < laps and lead >= Ls + line_next * P0:
			_lap_times.append(t)
			line_next += 1
	winner = results[0] if results.size() > 0 else 0


# ---- building -----------------------------------------------------------------------

func _build() -> void:
	var lane_w := (r_out - r_in) / float(N)
	for i in N:
		var fac: Array = FACTIONS[i % 4]
		var ch = Chariot.make(fac[1], 2 if (i == 5 or i == 10) else 4, 100 + i)
		add_child(ch.car)
		add_child(ch.team)
		_ch.append(ch)
		# a gate: two leaves hinged at the lane edges
		var r_i := r_in + (i + 0.5) * lane_w
		var s_i := -10.0 + i * 0.7 + 6.4
		var door := Node3D.new()
		door.position = Vector3(-Ls + s_i, 0, r_i - lane_w / 2.0)
		add_child(door)
		F.box(door, Vector3(0.12, 2.2, lane_w * 0.5), Vector3(0, 1.1, lane_w * 0.25), Color(0.5, 0.36, 0.2))
		_gates.append(door)
		var door2 := Node3D.new()
		door2.position = Vector3(-Ls + s_i, 0, r_i + lane_w / 2.0)
		add_child(door2)
		F.box(door2, Vector3(0.12, 2.2, lane_w * 0.5), Vector3(0, 1.1, -lane_w * 0.25), Color(0.5, 0.36, 0.2))
		_gates.append(door2)
	# the eggs, on a bar on the spina
	var bar := Node3D.new()
	bar.position = Vector3(0, 4.2, 0)
	add_child(bar)
	F.box(bar, Vector3(laps * 4.0 + 2.0, 0.25, 0.25), Vector3.ZERO, Color(0.55, 0.5, 0.4))
	for k in [-1.0, 1.0]:
		F.box(bar, Vector3(0.4, 4.2, 0.4), Vector3(k * (laps * 2.0 + 0.5), -2.1, 0), Color(0.6, 0.56, 0.5))
	for k in laps:
		var egg := Node3D.new()
		egg.position = Vector3((k - (laps - 1) / 2.0) * 4.0, -0.6, 0)
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.6
		sm.height = 1.2
		sm.radial_segments = 12
		sm.rings = 6
		m.mesh = sm
		m.scale = Vector3(0.9, 1.25, 0.9)
		m.material_override = F.mat(Color(0.96, 0.93, 0.82))
		egg.add_child(m)
		bar.add_child(egg)
		_eggs.append(egg)
	# the mappa
	_mappa = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.6, 1.6)
	_mappa.mesh = qm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.97, 0.95, 0.9)
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mappa.material_override = mm
	add_child(_mappa)
	# the crowd
	if bool(params.get("crowd", true)):
		var c = Crowd.new()
		c.fan_colours.assign([FACTIONS[0][1], FACTIONS[1][1], FACTIONS[2][1], FACTIONS[3][1]])
		c.fan_share = 0.35
		c.add_seats(Crowd.stadium_seats(Ls, width / 2.0 + 2.0, int(params.get("rows", 14)), float(params.get("spacing", 1.5)), 0.9, 0.55, 0.0, true))
		c.build()
		add_child(c)
		_crowd = c
	_label = make_label("", 1.0, Color(1, 0.95, 0.8))
	_label.position = Vector3(0, 9.0, 0)


# ---- drawing a moment -------------------------------------------------------------------

func _sample(arr: PackedFloat32Array, t: float) -> float:
	var x := clampf(t / DT, 0.0, float(_steps - 2))
	var i := int(x)
	return lerpf(arr[i], arr[i + 1], x - float(i))


func laps_done(time: float) -> int:
	var n := 0
	for lt in _lap_times:
		if time >= lt:
			n += 1
	return n


## The roar of the crowd, 0..1: grows from the start, jumps at a crash, peaks at the finish.
func roar_at(time: float) -> float:
	var r := 0.12
	if time > GATE_T:
		r += 0.3 * smoothstep(GATE_T, GATE_T + 6.0, time) + 0.012 * laps_done(time) * 4.0
	for ct in _crash_t:
		if ct >= 0.0 and time >= ct:
			r += 0.5 * exp(-(time - ct) / 3.0)
	if winner >= 0 and _fin_t[winner] >= 0.0 and time >= _fin_t[winner]:
		r = 0.7 + 0.3 * smoothstep(0.0, 3.0, time - _fin_t[winner])
	return minf(r, 1.0)


func _apply(time: float) -> void:
	var tt := minf(time, duration)
	var lead_s := 0.0
	for i in N:
		var ch = _ch[i]
		var s := _sample(_S[i], tt)
		var r := _sample(_R[i], tt)
		var pc := track_at(s, r)
		var car: Node3D = ch.car
		car.position = pc[0]
		F.face(car, pc[1])
		var ts := _sample(_TS[i], tt)
		var tr := _sample(_TR[i], tt)
		var pt := track_at(ts, tr)
		ch.team.position = pt[0]
		F.face(ch.team, pt[1])
		var moving := 1.0 if (_fin_t[i] < 0.0 or tt - _fin_t[i] < 4.0) else 0.5
		var started := tt >= GATE_T
		ch.animate(s, ts, moving if started else 0.0)
		lead_s = maxf(lead_s, s)
		# crash: the car tips, the driver is thrown
		var ct: float = _crash_t[i]
		ch.driver.visible = true
		car.visible = true
		car.rotation.z = 0.0
		if ct >= 0.0 and tt >= ct:
			var tau := tt - ct
			car.rotation.z = minf(tau * 2.2, 1.45)
			car.position.y = 0.3 * minf(tau, 1.0)
			ch.driver.position = Vector3(0, 0.455 + maxf(0.0, 2.6 * tau - 4.0 * tau * tau), -0.12 + 7.0 * (1.0 - exp(-tau * 1.6)))
			ch.driver.rotation.x = minf(tau * 3.0, 1.5)
			ch.driver.rotation.z = minf(tau * 4.0, 1.2)
			# flailing in the air, then limp
			var fl := exp(-tau * 0.7)
			ch.driver.pose_arms(-2.4 * fl - 0.2, -2.0 * fl - 0.3, 0.8 * fl, 0.8 * fl)
			ch.driver.legs[0].rotation = Vector3(-0.8 * fl, 0, 0.3)
			ch.driver.legs[1].rotation = Vector3(0.5 * fl, 0, -0.3)
			ch.reins.visible = false
			if tau > 14.0:
				car.visible = false
				ch.driver.visible = false
		else:
			ch.driver.position = Vector3(0, 0.455, -0.12)
			ch.driver.rotation = Vector3.ZERO
			ch.reins.visible = true
		ch.update_reins()
	# gates
	var open := smoothstep(GATE_T, GATE_T + 0.8, tt)
	for g in _gates.size():
		var side := 1.0 if g % 2 == 0 else -1.0
		_gates[g].rotation.y = -side * open * 1.55
	# the mappa falls from the editor's hand
	var fall := clampf((tt - (GATE_T - 1.6)) / 1.6, 0.0, 1.0)
	_mappa.visible = tt > GATE_T - 2.6 and tt < GATE_T + 1.5
	_mappa.position = Vector3(-30.0 * fall - 10.0, 12.0 * (1.0 - fall) + 0.6, -width / 2.0 + 20.0 * fall)
	_mappa.rotation = Vector3(0.6 * sin(fall * 14.0), fall * 5.0, 0.4 * cos(fall * 11.0))
	# the eggs: one turned over per lap the leader finishes
	var done := laps_done(tt)
	for k in _eggs.size():
		var e: Node3D = _eggs[k]
		var tilt := 1.0 if k < done else 0.0
		e.rotation.z = tilt * 2.4
		(e.get_child(0) as MeshInstance3D).material_override = F.mat(Color(0.35, 0.26, 0.16) if k < done else Color(0.96, 0.93, 0.82))
	if _crowd != null:
		_crowd.set_state(tt, roar_at(tt), fposmod(lead_s / P0, 1.0))
	if winner >= 0 and _fin_t[winner] >= 0.0 and tt >= _fin_t[winner]:
		_label.text = "%s wins" % FACTIONS[winner % 4][0]
		_label.visible = true
	else:
		_label.text = "Lap %d / %d" % [mini(done + 1, laps), laps] if tt >= GATE_T else ""
		_label.visible = tt >= GATE_T


func view_names() -> PackedStringArray:
	return PackedStringArray(["pulvinar", "turn", "carceres", "finish"])


func seat_views() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.append(look(Vector3(0, 13.0, -(width / 2.0 + 7.0)), Vector3(-30.0, 0.5, 14.0)))
	out.append(look(Vector3(Ls - 40.0, 10.0, -(width / 2.0 + 5.0)), Vector3(Ls + 12.0, 0.5, 8.0)))
	out.append(look(Vector3(-Ls + 38.0, 8.0, -24.0), Vector3(-Ls - 2.0, 1.0, 18.0)))
	out.append(look(Vector3(-14.0, 6.0, width / 2.0 + 4.0), Vector3(14.0, 0.5, r_in + 12.0)))
	return out


## A camera beside the leading chariot at time `time`, `dist` metres out on the south side
## of the line (a chase view for previews and for the player's "follow the leader").
func leader_view(time: float, dist := 16.0, who := -1) -> Transform3D:
	var tt := minf(time, duration)
	var best := 0
	var bs := -1e9
	for i in (range(N) if who < 0 else [who]):
		var sv := _sample(_S[i], tt)
		if sv > bs:
			bs = sv
			best = i
	var pc := track_at(bs, _sample(_R[best], tt))
	var pos: Vector3 = pc[0]
	var dir: Vector3 = pc[1]
	var out := Vector3(-dir.z, 0, dir.x).normalized()
	var centre := Vector3(clampf(pos.x, -Ls, Ls), 0, 0)
	if (pos - centre).dot(out) < 0.0:
		out = -out
	return look(pos + out * dist + Vector3(0, 3.5, 0) + dir * -4.0, pos + dir * 3.0 + Vector3(0, 1.0, 0))


## Facts about the simulated race for tests and previews.
func debug_info() -> String:
	return "winner=%d finish_times=%s crashes=%s laps=%s" % [winner, _fin_t, _crash_t, _lap_times]


## A close view beside the leading pack, low and just ahead of the leader, on the outside of the
## track (the turns are the best of it).
func cine_view(time: float) -> Transform3D:
	var tt := clampf(time, GATE_T + 1.0, duration)
	var best := 0
	var bs := -1e9
	for i in N:
		var sv := _sample(_S[i], tt)
		if sv > bs:
			bs = sv
			best = i
	var pc := track_at(bs, _sample(_R[best], tt))
	var pos: Vector3 = pc[0]
	var dir: Vector3 = pc[1]
	var out := Vector3(-dir.z, 0, dir.x).normalized()
	var centre := Vector3(clampf(pos.x, -Ls, Ls), 0, 0)
	if (pos - centre).dot(out) < 0.0:
		out = -out
	# beside the pack on the inside of the turn if there is room, else outside
	var from := pos + out * 7.5 + dir * 8.0 + Vector3(0, 2.6, 0)
	return look(from, pos - dir * 1.0 + Vector3(0, 0.8, 0))
