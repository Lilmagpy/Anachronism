## Urbs street life (U8, the "people" row of the Rome Reborn gap table): crowds that walk the
## known streets and gather in the Forum, market stalls under awnings, carts and pack mules,
## litters, dogs, kitchen smoke and lamps at night, all scaled by the year's population and the
## hour of the day.
##
## ## The hooks the lead wires in urbs.gd
##   var life := UrbsLife.new()
##   add_child(life)                                   # once, in _ready (it is a Node3D)
##   life.build(self, year, hour, Callable(self, "height_at"))   # in _rebuild, AFTER streets and
##                                                     # monuments are built; call again when the
##                                                     # year changes (it clears itself)
##   life.set_hour(hour)                               # from set_hour: crowds thin, stalls shut,
##                                                     # carts come out, lamps and smoke
##   life.set_events(view["city"]["events"])           # the turn's events: a games event raises the
##                                                     # crowds and gathers one at the venue
##   life.tick(delta, cam.camera.global_position)      # each frame from _process; or leave
##                                                     # `auto_tick` true and it drives itself from
##                                                     # the viewport camera
##   life.visible = false                              # while INSIDE a monument (urbs hides siblings)
## Nothing here touches urbs.gd, fill*.gd, monuments*.gd or the terrain: it only reads
## `urbs.streets` (UrbsStreets, built for the year), `urbs.monuments` (ids/bounds/_placed) and
## the height callable.
##
## ## Performance
## Every person is an instance of ONE MultiMesh per detail level (crowd.gd walker_mesh 1 and 2),
## animated by crowd.gd's WALK_SHADER on the GPU (legs, arms, bob, idle sway); the CPU writes one
## transform per person, near ones every frame, far ones every fourth. Only the nearest
## `near_figures` (default 40) people are skinned figure.gd persons with a per-node rig, plus the
## litters' bearers and the carts' oxen. Stalls, lamps and smoke are MultiMeshes; smoke is
## animated in its own vertex shader. Budget: < 2 ms CPU and < 60 draw calls at street level.
##
## ## Sources (passages read for this pass, Latin at thelatinlibrary.com; see also spectacles.yaml)
##   Placement: nobody is put inside a monument's solids (UrbsMonuments.solid_boxes, D-295).
##   Scale and hours: population.json (city_population, central estimates, log-interpolated by
##     year). Hours of the day: Martial 4.8 (read; Imperial, AD 80s): hours 1-2 the morning
##     callers (salutatio), 3 the lawyers, to the 5th "varios extendit Roma labores", 6th rest,
##     7th the end of work, 8th the exercise grounds, 9th dinner. Used for the activity curve.
##   Where people stand in the Forum: Plautus Curculio 466-485 (read): perjurers in the Comitium,
##     liars at the shrine of Cloacina, rich spendthrifts and prostitutes "sub basilica", the
##     good and rich "in foro infimo", show-offs "in medio propter canalem", the garrulous
##     "supra lacum", lenders and borrowers "sub veteribus", the untrustworthy behind the temple
##     of Castor, in the Vicus Tuscus those who sell themselves, in the Velabrum bakers, butchers
##     and soothsayers. The groups below are placed by those lines.
##   Markets: Varro LL 5.145-146 (read): the forum is where men bring their disputes and what they
##     want to sell; the Forum Boarium and Holitorium, the fish market by the Tiber, and the
##     Macellum where "everything that belongs to food was brought together in one place".
##     Livy 26.27.2-3 (read): the tabernae round the Forum (the seven shops, the argentariae)
##     burned in 210 BC. Stalls with awnings as the market's furniture are the modeller's
##     reading (# unverified: no passage describes a Republican stall). Market days: Varro RR 2
##     praef. (read): the ancestors did city business on the ninth days and farmed the other
##     seven; the engine has no day, so every day is a market day here.
##   Carts: the daytime ban on plaustra in Rome (sunrise to the tenth hour, with exceptions for
##     public works, Vestals, triumphs and games) is the Tabula Heracleensis / Lex Iulia
##     municipalis 56-67, 45 BC (# unverified: the text could not be fetched through the proxy).
##     Juvenal 3.236-238 and 254-261 (read; Imperial): carts passing in the narrow streets at
##     night and the mule-drivers' curses; fir and pine logs and Ligurian marble on the carts.
##     So carts run in the city only before 6 h and after 16 h, and on the roads outside all day.
##   Litters: Cic. Phil. 2.58 (read): Antony's "aperta lectica", an open litter carried in
##     procession before his travelling party; the Republican litter shown is open.
##   Dogs: Varro RR 2.9 (read): two kinds, the hunting dog and the guard dog; white preferred
##     "quod in tenebris facilius agnoscuntur". The street dogs here are mostly pale.
##   Smoke: Horace Odes 3.29.12 (read; 23 BC): "fumum et opes strepitumque Romae", the smoke,
##     wealth and din of Rome. Cooking hours follow Martial 4.8 (read): the ninth hour's dinner.
##   Night: Juvenal 3.268-277 (read; Imperial): the dangers of the night street, with nothing
##     about street lighting; the lamps here are few, at doorways (# unverified reconstruction).
##   Clothing by class and sex:
##     toga for the citizen on public business: Livy 3.26.9 (read): Cincinnatus at work in his
##       field is told to put on his toga, "togatus mandata senatus audiret", and has it brought
##       from the hut; so the toga is worn for business, the tunic for work. Cic. Phil. 2.44
##       (read): the toga virilis.
##     tunic for workers and slaves: Livy 3.26 as above; Juvenal 3.254 "tunicae" of the crowd
##       (read, Imperial).
##     stola and palla for matrons: Horace Sat. 1.2.29 "subsuta talos tegat instita veste",
##       1.2.99 "ad talos stola demissa et circumdata palla" (read, c. 35 BC).
##     pilleus for freedmen: Livy 30.45.5 and 45.44.19 (read), see figure.gd.
##     the purple border (praetexta) of magistrates and the senator's broad stripe: Livy 30.15.11
##       (toga picta of the triumph, read in the U6 pass); praetexta for curule magistrates and
##       boys is # unverified here (Macrobius Sat. 1.6, not read).
##   Colours of cloth: undyed wool (white to brown), with madder red, woad blue and saffron as the
##     cheap dyes, is the modeller's palette (# unverified: Pliny NH 9 and 22 not read).
class_name UrbsLife
extends Node3D

const F := preload("res://scripts/urbs/spectacles/figure.gd")
const A := preload("res://scripts/urbs/spectacles/animals.gd")
const M := preload("res://scripts/urbs/spectacles/meshlib.gd")
const Crowd := preload("res://scripts/urbs/crowd.gd")
const POP_PATH := "res://data/city/population.json"
const REGIONS_PATH := "res://data/city/regions.json"

## Walkers nearer than this get a skinned figure; the pool holds `near_figures` of them.
var near_figures := 40
var near_distance := 42.0
## MultiMesh levels: the detailed walker (with shadows) to near_mm_distance, the middle one to
## mid_distance, the far one to cull_distance, nothing beyond.
var near_mm_distance := 75.0
var mid_distance := 300.0
var cull_distance := 1100.0
const HIDDEN := 9
## One street walker per this many inhabitants at the day's peak; one Forum idler per this many.
var people_per_walker := 230.0
var people_per_idler := 2400.0
var max_walkers := 3600
var auto_tick := true
## Carts and mules (rigs) kept at once; litters near the Forum.
var cart_count := 14
var mule_count := 5
var litter_count := 2

var urbs: Node3D
var year := -50
var hour := 10.0
var height: Callable = func(_x: float, _z: float) -> float: return 10.0
var population := 100000.0
var activity := 1.0
var events: Array = []
var festival_venue := ""
var built := false

var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _frame := 0
var _streets: Array = []           # urbs.streets.streets
var _links: Array = []             # per street: [[end 0|1, other street, d on it], ...]
var _agents: Array[Dictionary] = []
var _move_figs := PackedInt32Array()   # walking agents with a skinned figure: every frame
var _move_near := PackedInt32Array()   # level 1 walkers: every second frame
var _move_mid := PackedInt32Array()    # agents stepped one frame in four (level 2)
var _move_far := PackedInt32Array()    # agents stepped one frame in sixteen (level 3)
var _street_h: Array[PackedFloat32Array] = []   # ground height at each street point
var _mm_mid: MultiMesh   # level 1: near walkers (shadows)
var _mm_far: MultiMesh   # level 2: middle distance
var _mm_vfar: MultiMesh  # level 3: far
var _mm_dog: MultiMesh
var _mi_mid: MultiMeshInstance3D
var _mi_far: MultiMeshInstance3D
var _mi_dog: MultiMeshInstance3D
var _figs: Array = []              # [{node, kind, agent}]
var _fig_free: Array[int] = []
var _cam := Vector3(1e9, 0, 1e9)
var _lod_timer := 0.0
var _lamps: PackedVector3Array = PackedVector3Array()
var _lights: Array[OmniLight3D] = []
var _lamp_node: Node3D
var _smoke: MultiMeshInstance3D
var _smoke_mat: ShaderMaterial
var _smoke_count := 0
var _stalls: Node3D
var _stall_open: Array[MultiMeshInstance3D] = []
var _rigs: Array = []              # {node, kind, agent, animals: Array, extra: Array}
var _venue_crowd: Node3D
var _forum: Dictionary = {}        # {c: Vector2, u: Vector2, v: Vector2, hl, hw, y}
var _blockers: Array = []          # AABBs of monuments' solids people must not stand in
var _block_grid := {}              # Vector2i cell -> indices into _blockers
const BLOCK_CELL := 40.0
var _vcol_mat: StandardMaterial3D
var _counts := {}


# ---- building -----------------------------------------------------------------------------

## Build the life of `new_year` at `new_hour`. `urbs_node` is the Urbs scene (streets, monuments
## built for the year); `height_fn(x, z) -> y` is the ground.
func build(urbs_node: Node3D, new_year: int, new_hour: float, height_fn: Callable) -> void:
	clear()
	urbs = urbs_node
	year = new_year
	hour = fposmod(new_hour, 24.0)
	height = height_fn
	_rng.seed = hash("life%d" % year)
	population = _population(year)
	activity = activity_at(hour)
	_streets = urbs.streets.streets if urbs.streets != null else []
	_street_h.clear()
	for st in _streets:
		var hs := PackedFloat32Array()
		for q in (st["pts"] as PackedVector2Array):
			hs.append(float(height.call(q.x, q.y)))
		_street_h.append(hs)
	_link_streets()
	_find_forum()
	# what people must not stand in: the monuments' real solids (UrbsMonuments.solid_boxes),
	# not plazas or routes (no bounds), not steps and low platforms (1.3 m or less)
	_blockers.clear()
	_block_grid.clear()
	var mb: Variant = urbs.monuments.get("_bounds")
	for id in urbs.monuments.ids():
		if mb is Dictionary and ((mb as Dictionary).get(id, AABB()) as AABB).size == Vector3.ZERO:
			continue
		var boxes: Array = urbs.monuments.solid_boxes(id) if urbs.monuments.has_method("solid_boxes") else [urbs.monuments.bounds(id)]
		for b in boxes:
			var bb: AABB = b
			if bb.size.y <= 1.3 or bb.size.x > 400.0 or bb.size.z > 400.0:
				continue
			_blockers.append(bb)
			var k := _blockers.size() - 1
			for gx in range(floori((bb.position.x - 1.0) / BLOCK_CELL), floori((bb.end.x + 1.0) / BLOCK_CELL) + 1):
				for gz in range(floori((bb.position.z - 1.0) / BLOCK_CELL), floori((bb.end.z + 1.0) / BLOCK_CELL) + 1):
					var key := Vector2i(gx, gz)
					if not _block_grid.has(key):
						_block_grid[key] = []
					(_block_grid[key] as Array).append(k)
	_vcol_mat = StandardMaterial3D.new()
	_vcol_mat.vertex_color_use_as_albedo = true
	_vcol_mat.roughness = 0.95
	_make_people()
	_make_stalls()
	_make_vehicles()
	_size_multimeshes()
	_prewarm_figures()
	for a in _agents:
		if str(a["mode"]) in ["street", "cart", "mule", "litter"]:
			_step_street(a, 0.0)
	_make_lamps()
	_make_smoke()
	_apply_hour()
	built = true
	_counts = {"people": _agents.size(), "figures": _figs.size(), "rigs": _rigs.size(), "stalls": _stalls.get_meta("count", 0) if _stalls != null else 0, "lamps": _lamps.size(), "smoke": _smoke_count, "population": int(population), "activity": activity}


func clear() -> void:
	for c in get_children():
		c.queue_free()
	_agents.clear()
	_figs.clear()
	_fig_free.clear()
	_rigs.clear()
	_lights.clear()
	_lamps = PackedVector3Array()
	_stall_open.clear()
	_mm_mid = null
	_mm_far = null
	_mm_vfar = null
	_mm_dog = null
	_smoke = null
	_stalls = null
	_lamp_node = null
	_venue_crowd = null
	built = false


## Counts for reports and the preview.
func counts() -> Dictionary:
	return _counts


## Change the hour (0-24) without rebuilding: thins or thickens the crowds, shuts the stalls,
## lets the carts out, lights the lamps.
func set_hour(new_hour: float) -> void:
	hour = fposmod(new_hour, 24.0)
	activity = activity_at(hour)
	if built:
		_apply_hour()


## The turn's events (view["city"]["events"]). A `games` event at a circus brings a festival:
## more people in the streets and a crowd gathered along the venue.
func set_events(list: Array) -> void:
	events = list.duplicate()
	festival_venue = ""
	for e in events:
		if str(e.get("kind", "")) == "games" and str(e.get("ref", "")) != "munus":
			festival_venue = str(e.get("monument", ""))
	if built:
		_apply_hour()
		_make_venue_crowd()


## How busy the city is at `h` (0..1), from Martial 4.8 (read): the morning callers from the
## first hour, business to the fifth, rest at the sixth, work ends at the seventh, then the
## baths and dinner; the streets empty after dark (Juvenal 3.268-277, read).
static func activity_at(h: float) -> float:
	var table := [[4.0, 0.03], [5.5, 0.08], [6.5, 0.35], [7.5, 0.75], [8.5, 0.95], [10.0, 1.0], [11.5, 0.9],
		[12.5, 0.55], [13.5, 0.4], [14.5, 0.55], [16.0, 0.65], [17.5, 0.5], [18.5, 0.3], [19.5, 0.14], [21.0, 0.05], [24.0, 0.03]]
	var hh := fposmod(h, 24.0)
	if hh < 4.0:
		return 0.03
	for i in range(1, table.size()):
		if hh <= float(table[i][0]):
			var a: Array = table[i - 1]
			var b: Array = table[i]
			return lerpf(float(a[1]), float(b[1]), (hh - float(a[0])) / (float(b[0]) - float(a[0])))
	return 0.03


## Markets are open from the first hour to the seventh (Martial 4.8 "septima finis erit", read).
static func market_open(h: float) -> bool:
	return h >= 6.0 and h < 13.5


## The plaustra may enter the city only after the tenth hour and leave before sunrise (Tabula
## Heracleensis 56-67, # unverified; Juvenal 3.236-238, read).
static func carts_allowed(h: float) -> bool:
	return h < 6.0 or h >= 16.0


static func lamps_lit(h: float) -> bool:
	return h < 5.5 or h >= 18.5


static func _population(y: int) -> float:
	var text := FileAccess.get_file_as_string(POP_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return 100000.0
	var pts: Array = []
	for e in parsed.get("city_population", []):
		pts.append([int(e["year"]), float(e["central"])])
	pts.sort_custom(func(a, b): return a[0] < b[0])
	if pts.is_empty():
		return 100000.0
	if y <= pts[0][0]:
		return pts[0][1]
	for i in range(1, pts.size()):
		if y <= pts[i][0]:
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			var f := float(y - a[0]) / float(b[0] - a[0])
			return exp(lerpf(log(a[1]), log(b[1]), f))
	return pts[pts.size() - 1][1]


# ---- streets --------------------------------------------------------------------------------

func _link_streets() -> void:
	_links = []
	for i in _streets.size():
		_links.append([])
	for i in _streets.size():
		var pts_i: PackedVector2Array = _streets[i]["pts"]
		for end in 2:
			var e: Vector2 = pts_i[0] if end == 0 else pts_i[pts_i.size() - 1]
			for j in _streets.size():
				if j == i:
					continue
				var pts_j: PackedVector2Array = _streets[j]["pts"]
				var cum: PackedFloat32Array = _streets[j]["cum"]
				var best := 30.0
				var best_d := -1.0
				for k in range(pts_j.size() - 1):
					var q := Geometry2D.get_closest_point_to_segment(e, pts_j[k], pts_j[k + 1])
					var dist := e.distance_to(q)
					if dist < best:
						best = dist
						best_d = cum[k] + pts_j[k].distance_to(q)
				if best_d >= 0.0:
					(_links[i] as Array).append([end, j, best_d])


func _street_pos(si: int, d: float, lat: float) -> Array:
	var s: Dictionary = _streets[si]
	var dd := clampf(d, 0.0, float(s["len"]))
	var pt: Array = urbs.streets.sample_at(si, dd)
	var p: Vector2 = pt[0]
	var tg: Vector2 = pt[1]
	var n := Vector2(-tg.y, tg.x)
	var q := p + n * lat
	return [Vector3(q.x, float(height.call(q.x, q.y)) + 0.22, q.y), tg]


## Weight of a street for walkers: the Forum's streets and the shopping streets busiest, the roads
## outside the walls quiet; by length.
func _street_weight(s: Dictionary) -> float:
	var id := str(s["id"])
	var w := 1.0
	if s["kind"] == "road":
		w = 0.18
	if id in ["via_sacra", "argiletum", "vicus_tuscus", "subura", "vicus_iugarius", "via_velabrum", "clivus_argentarius", "nova_via"]:
		w = 1.8
	return w * float(s["len"])


# ---- people ---------------------------------------------------------------------------------

## Clothing classes. Each: cloth palette, chance of a long robe, the pilleus, scale; the share of
## each class in the streets and in the Forum (Plautus Curculio 466-485 for the Forum's togate
## business crowd; see the header).
const KINDS := {
	"toga":   {"long": true,  "cap": false, "scale": 1.0,  "street": 0.12, "forum": 0.25},
	"tunic":  {"long": false, "cap": false, "scale": 1.0,  "street": 0.54, "forum": 0.45},
	"stola":  {"long": true,  "cap": false, "scale": 0.94, "street": 0.20, "forum": 0.15},
	"pilleus": {"long": false, "cap": true, "scale": 1.0,  "street": 0.07, "forum": 0.08},
	"child":  {"long": false, "cap": false, "scale": 0.68, "street": 0.07, "forum": 0.05},
}
## The toga of undyed wool: cream to off-white, never paper white (# unverified: the fuller's
## whitening of the toga candida is for candidates only).
const TOGA_COLOURS := [Color(0.88, 0.85, 0.76), Color(0.84, 0.8, 0.7), Color(0.8, 0.77, 0.68), Color(0.9, 0.88, 0.8)]
const TUNIC_COLOURS := [Color(0.76, 0.68, 0.5), Color(0.62, 0.5, 0.36), Color(0.7, 0.62, 0.55), Color(0.55, 0.45, 0.35),
	Color(0.66, 0.3, 0.24), Color(0.5, 0.52, 0.6), Color(0.8, 0.74, 0.6), Color(0.45, 0.38, 0.3), Color(0.72, 0.6, 0.35)]
const STOLA_COLOURS := [Color(0.82, 0.62, 0.3), Color(0.42, 0.5, 0.68), Color(0.6, 0.38, 0.5), Color(0.5, 0.6, 0.42),
	Color(0.85, 0.8, 0.7), Color(0.7, 0.35, 0.3), Color(0.55, 0.42, 0.62)]


func _pick_kind(where: String) -> String:
	var r := _rng.randf()
	var acc := 0.0
	for k in KINDS:
		acc += float(KINDS[k][where])
		if r <= acc:
			return k
	return "tunic"


func _cloth(kind: String) -> Color:
	var c: Color
	match kind:
		"toga": c = TOGA_COLOURS[_rng.randi() % TOGA_COLOURS.size()]
		"stola": c = STOLA_COLOURS[_rng.randi() % STOLA_COLOURS.size()]
		_: c = TUNIC_COLOURS[_rng.randi() % TUNIC_COLOURS.size()]
	return c.lerp(Color(0.5, 0.5, 0.5), _rng.randf() * 0.12)


func _new_agent(kind: String) -> Dictionary:
	var k: Dictionary = KINDS.get(kind, KINDS["tunic"])
	var flags := (1.0 if k["cap"] else 0.0) + (2.0 if k["long"] else 0.0)
	var a := {
		"kind": kind, "col": _cloth(kind), "scale": float(k["scale"]) * _rng.randf_range(0.95, 1.05),
		"custom": Color(_rng.randf(), 1.0, _rng.randf() * 0.7, flags + _rng.randf() * 0.95),
		"si": -1, "d": 0.0, "dir": 1, "lat": 0.0, "speed": _rng.randf_range(1.15, 1.55), "amp": 1.0,
		"pos": Vector3.ZERO, "yaw": 0.0, "lod": HIDDEN, "fig": -1, "phase": _rng.randf() * TAU,
		"mode": "street", "target": Vector2.ZERO, "pause": 0.0, "area": {}, "face": Vector2.ZERO,
		"active": true, "dog": false,
	}
	return a


func _make_people() -> void:
	# how many: the peak counts, then set_hour hides a share
	var n_walk := clampi(int(population / people_per_walker), 120, max_walkers)
	var n_forum := clampi(int(population / people_per_idler), 40, 420)
	var n_dogs := clampi(n_walk / 24, 5, 60)
	# street walkers spread by street weight
	var weights: Array[float] = []
	var total := 0.0
	for s in _streets:
		var w := _street_weight(s)
		weights.append(w)
		total += w
	for i in n_walk:
		var a := _new_agent(_pick_kind("street"))
		if total > 0.0:
			var r := _rng.randf() * total
			var si := 0
			while si < weights.size() - 1 and r > weights[si]:
				r -= weights[si]
				si += 1
			a["si"] = si
			a["d"] = _rng.randf() * float(_streets[si]["len"])
			a["dir"] = 1 if _rng.randf() < 0.5 else -1
			var hw := float(_streets[si]["hw"])
			a["lat"] = (hw * _rng.randf_range(0.25, 0.85)) * (1.0 if _rng.randf() < 0.5 else -1.0)
		else:
			a["active"] = false
		_agents.append(a)
	# the Forum's idlers: groups in conversation at Plautus's places, a few crossing
	if not _forum.is_empty():
		var spots := _forum_spots()
		var made := 0
		var tries := 0
		while made < n_forum and tries < n_forum * 8:
			tries += 1
			var spot: Dictionary = spots[_rng.randi() % spots.size()]
			var group := 1 + _rng.randi() % 4 if _rng.randf() < 0.75 else 1
			var c: Vector2 = spot["p"] + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * float(spot["r"])
			if _blocked(c):
				continue
			var ring := 0.55 + 0.18 * group
			for g in group:
				var a := _new_agent(str(spot["kind"]) if spot["kind"] != "" and _rng.randf() < 0.4 else _pick_kind("forum"))
				var ang := TAU * g / group + _rng.randf() * 0.4
				var p := c + Vector2(cos(ang), sin(ang)) * (ring if group > 1 else 0.0)
				a["mode"] = "stand"
				a["amp"] = 0.0
				a["pos"] = _forum_point(p)
				a["face"] = c if group > 1 else c + Vector2(cos(ang), sin(ang))
				a["yaw"] = _yaw_to(p, a["face"]) if group > 1 else _rng.randf() * TAU
				_agents.append(a)
				made += 1
		# crossing the plaza
		for i in maxi(6, n_forum / 5):
			var a := _new_agent(_pick_kind("forum"))
			a["mode"] = "plaza"
			a["area"] = _forum
			a["pos"] = _forum_point(_forum_random())
			a["target"] = _forum_random()
			a["speed"] = _rng.randf_range(1.0, 1.4)
			_agents.append(a)
	# dogs
	for i in n_dogs:
		var a := _new_agent("tunic")
		a["dog"] = true
		a["col"] = [Color(0.9, 0.88, 0.82), Color(0.85, 0.8, 0.7), Color(0.6, 0.45, 0.3), Color(0.35, 0.3, 0.25)][_rng.randi() % 4] if _rng.randf() < 0.7 else Color(0.92, 0.9, 0.86)
		a["custom"] = Color(_rng.randf(), 1.0, 0.0, 4.0 + _rng.randf() * 0.9)
		a["scale"] = _rng.randf_range(0.8, 1.1)
		a["speed"] = _rng.randf_range(1.0, 1.6)
		if total > 0.0:
			var si := _rng.randi() % _streets.size()
			a["si"] = si
			a["d"] = _rng.randf() * float(_streets[si]["len"])
			a["dir"] = 1 if _rng.randf() < 0.5 else -1
			a["lat"] = float(_streets[si]["hw"]) * _rng.randf_range(0.5, 0.95) * (1.0 if _rng.randf() < 0.5 else -1.0)
		_agents.append(a)
	# the MultiMeshes (sized when everyone is made: _size_multimeshes)
	_mm_mid = _multimesh(Crowd.walker_mesh(1), 1)
	_mm_far = _multimesh(Crowd.walker_mesh(2), 1)
	_mm_vfar = _multimesh(Crowd.walker_mesh(3), 1)
	_mm_dog = _multimesh(Crowd.dog_mesh(), 1)
	var mat := Crowd.walk_material()
	_mi_mid = _mm_instance(_mm_mid, mat, "WalkersNear", false)
	_mi_far = _mm_instance(_mm_far, mat, "WalkersMid", false)
	_mm_instance(_mm_vfar, mat, "WalkersFar", false)
	_mi_dog = _mm_instance(_mm_dog, mat, "Dogs", false)
	# the skinned figures for the nearest people are made on demand, per class (_take_fig)


## Make the skinned figures up front (their first bake is the slow part), hidden, in the
## proportions of the Forum's dress, so walking into a crowd never stalls.
func _prewarm_figures() -> void:
	var share := {"toga": 0.30, "tunic": 0.38, "stola": 0.18, "pilleus": 0.08, "child": 0.06}
	for k in share:
		for i in int(round(float(share[k]) * near_figures)):
			var a := _new_agent(k)
			_figs.append({"node": _make_figure(k, a), "kind": k, "agent": -1})
			(_figs[_figs.size() - 1]["node"] as Node3D).visible = false
			_fig_free.append(_figs.size() - 1)


func _size_multimeshes() -> void:
	for mm in [_mm_mid, _mm_far, _mm_vfar, _mm_dog]:
		if mm != null:
			(mm as MultiMesh).instance_count = maxi(1, _agents.size())
			(mm as MultiMesh).visible_instance_count = 0


func _multimesh(mesh: ArrayMesh, n: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-2600, -50, -2600), Vector3(5200, 300, 5200))
	return mm


func _mm_instance(mm: MultiMesh, mat: Material, nm: String, shadow: bool) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A skinned figure for an agent's class (built on first use; meshes are cached in the rig).
func _make_figure(kind: String, a: Dictionary) -> Node3D:
	var o := {"seed": _rng.randi() % 1000, "tunic": a["col"], "skin": Color(0.95, 0.75, 0.6).lerp(Color(0.6, 0.4, 0.3), (a["custom"] as Color).b),
		"hair": Color(0.12, 0.09, 0.07).lerp(Color(0.42, 0.3, 0.2), fmod(float((a["custom"] as Color).a), 1.0))}
	match kind:
		"toga":
			o["toga"] = true
			o["toga_colour"] = a["col"]
			o["tunic"] = Color(0.9, 0.88, 0.82)
			if _rng.randf() < 0.04:
				o["border"] = Color(0.40, 0.07, 0.16)   # a curule magistrate's praetexta (# unverified)
			else:
				o["border"] = a["col"]
		"stola":
			o["stola"] = true
			o["palla"] = STOLA_COLOURS[_rng.randi() % STOLA_COLOURS.size()]
			o["hair"] = Color(0.15, 0.1, 0.08)
		"pilleus":
			o["pilleus"] = true
		"child":
			o["scale"] = 0.68
	var f: Node3D = F.person(o)
	f.rig.lod_distance = 14.0   # the full-detail body (and its shadow) only this close
	f.name = "Fig_" + kind
	add_child(f)
	return f


# ---- the Forum --------------------------------------------------------------------------------

func _find_forum() -> void:
	_forum = {}
	var placed: Dictionary = urbs.monuments.get("_placed") if urbs.monuments.get("_placed") != null else {}
	if not placed.has("forum_romanum"):
		return
	var p: Dictionary = placed["forum_romanum"]
	var yaw: float = p["yaw"]
	_forum = {"c": p["centre"], "u": Vector2(sin(yaw), cos(yaw)), "v": Vector2(cos(yaw), -sin(yaw)),
		"hl": float(p["length"]) * 0.5, "hw": float(p["width"]) * 0.5, "y": float(p["y"])}


func _forum_random() -> Vector2:
	for i in 12:
		var p: Vector2 = _forum["c"] + (_forum["u"] as Vector2) * _rng.randf_range(-float(_forum["hl"]), float(_forum["hl"])) * 0.95 + (_forum["v"] as Vector2) * _rng.randf_range(-float(_forum["hw"]), float(_forum["hw"])) * 0.9
		if not _blocked(p):
			return p
	return _forum["c"]


func _forum_point(p: Vector2) -> Vector3:
	var y := maxf(float(height.call(p.x, p.y)), float(_forum.get("y", 0.0))) + 0.15
	return Vector3(p.x, y, p.y)


## Where the Forum's groups stand, from Plautus Curculio 466-485 (read): {p, r, kind}. The kind
## "" takes the Forum's mix; "toga" for the businessmen's spots.
func _forum_spots() -> Array:
	var c: Vector2 = _forum["c"]
	var u: Vector2 = _forum["u"]
	var v: Vector2 = _forum["v"]
	var hl: float = _forum["hl"]
	var hw: float = _forum["hw"]
	var out: Array = []
	# the Comitium: perjurers and politics (Curc. 470)
	if urbs.monuments.ids().has("comitium"):
		var b: AABB = urbs.monuments.bounds("comitium")
		var cc := b.get_center()
		out.append({"p": Vector2(cc.x, cc.z), "r": 9.0, "kind": "toga"})
		out.append({"p": Vector2(cc.x, cc.z), "r": 9.0, "kind": ""})
	# in medio propter canalem: show-offs (477); the middle of the plaza
	out.append({"p": c, "r": 14.0, "kind": ""})
	out.append({"p": c + u * hl * 0.3, "r": 12.0, "kind": ""})
	out.append({"p": c - u * hl * 0.3, "r": 12.0, "kind": ""})
	# in foro infimo: the good and the rich (476); the lower (east) end
	out.append({"p": c + u * hl * 0.75, "r": 10.0, "kind": "toga"})
	# sub veteribus: lenders and borrowers (481); along the south side (Tabernae Veteres)
	out.append({"p": c + v * hw * 0.8 + u * hl * 0.2, "r": 8.0, "kind": "toga"})
	out.append({"p": c + v * hw * 0.8 - u * hl * 0.3, "r": 8.0, "kind": "toga"})
	# sub basilica: the north side (473-474)
	out.append({"p": c - v * hw * 0.8 - u * hl * 0.2, "r": 9.0, "kind": ""})
	out.append({"p": c - v * hw * 0.8 + u * hl * 0.35, "r": 9.0, "kind": ""})
	# pone aedem Castoris (482)
	if urbs.monuments.ids().has("aedes_castoris"):
		var b2: AABB = urbs.monuments.bounds("aedes_castoris")
		var e := b2.get_center()
		out.append({"p": Vector2(e.x, b2.position.z - 5.0), "r": 6.0, "kind": ""})
	return out


func _blocked(p: Vector2) -> bool:
	var key := Vector2i(floori(p.x / BLOCK_CELL), floori(p.y / BLOCK_CELL))
	if not _block_grid.has(key):
		return false
	for k in _block_grid[key]:
		var bb: AABB = _blockers[k]
		if p.x > bb.position.x - 0.8 and p.x < bb.end.x + 0.8 and p.y > bb.position.z - 0.8 and p.y < bb.end.z + 0.8:
			return true
	return false


static func _yaw_to(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(d.x, d.y)


# ---- stalls -------------------------------------------------------------------------------------

## A market stall: a trestle table, four poles and a sloping awning, goods on the table. Three
## kinds of goods: produce (greens, fruit, grain sacks), pottery (amphorae, jars), bread and
## cloth. The frame and the awning are UrbsMaterials surfaces; the goods are vertex colours.
func _make_stalls() -> void:
	_stalls = Node3D.new()
	_stalls.name = "Stalls"
	add_child(_stalls)
	var places: Array = []   # {p: Vector2, yaw: float, goods: int}
	var placed: Dictionary = urbs.monuments.get("_placed") if urbs.monuments.get("_placed") != null else {}
	# the Forum Boarium and Holitorium (Varro LL 5.146): rows of stalls across the plaza
	for id in ["forum_boarium", "forum_holitorium"]:
		if not placed.has(id):
			continue
		var p: Dictionary = placed[id]
		var yaw: float = p["yaw"]
		var u := Vector2(sin(yaw), cos(yaw))
		var v := Vector2(cos(yaw), -sin(yaw))
		var hl: float = float(p["length"]) * 0.5 - 6.0
		var hw: float = float(p["width"]) * 0.5 - 5.0
		var rows := maxi(1, int(hw * 2.0 / 11.0))
		for r in rows:
			var off := -hw + 5.5 + r * 11.0
			var n := int(hl * 2.0 / 4.2)
			for i in n:
				if _rng.randf() < 0.18:
					continue
				var c: Vector2 = p["centre"] + u * (-hl + 2.1 + i * 4.2) + v * off
				if _blocked(c):
					continue
				c += Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6))
				places.append({"p": c, "yaw": yaw + PI / 2.0 + (PI if r % 2 == 1 else 0.0) + _rng.randf_range(-0.12, 0.12), "goods": _rng.randi() % 3})
	# the Macellum (Livy 40.51.5; Varro LL 5.146): stalls round the market hall
	if placed.has("macellum"):
		var p: Dictionary = placed["macellum"]
		var yaw: float = p["yaw"]
		var u := Vector2(sin(yaw), cos(yaw))
		var v := Vector2(cos(yaw), -sin(yaw))
		var hl: float = float(p["length"]) * 0.5 + 3.5
		var hw: float = float(p["width"]) * 0.5 + 3.5
		var n := int(hl * 2.0 / 4.5)
		for i in n:
			for side in [-1.0, 1.0]:
				var c: Vector2 = p["centre"] + u * (-hl + 2.0 + i * 4.5) + v * hw * side
				places.append({"p": c, "yaw": yaw + (0.0 if side > 0 else PI), "goods": _rng.randi() % 3})
	# the Argiletum and the Vicus Tuscus: stalls on the footpaths (Plautus Curc. 483; the
	# Argiletum's shops: Martial 1.3, # unverified)
	for sid in ["argiletum", "vicus_tuscus"]:
		for si in _streets.size():
			var s: Dictionary = _streets[si]
			if str(s["id"]) != sid:
				continue
			var hw: float = s["hw"]
			var n := int(float(s["len"]) / 9.0)
			for i in n:
				var side := 1.0 if i % 2 == 0 else -1.0
				var pt: Array = urbs.streets.sample_at(si, 4.0 + i * 9.0 + _rng.randf_range(-1.5, 1.5))
				var tg: Vector2 = pt[1]
				var nrm := Vector2(-tg.y, tg.x)
				# against the house fronts (the kerb and the footpath are 1.3 m: fill.gd), table
				# back to the wall, the awning reaching to the street's edge
				var c: Vector2 = pt[0] + nrm * (hw + 1.05) * side
				if _blocked(c):
					continue
				places.append({"p": c, "yaw": atan2(-nrm.x * side, -nrm.y * side), "goods": _rng.randi() % 3, "wall": true})
	if places.is_empty():
		_stalls.set_meta("count", 0)
		return
	# meshes: free-standing stalls (four poles) and wall stalls (two poles, the awning fixed to
	# the house front)
	var goods: Array = [_goods_mesh(0), _goods_mesh(1), _goods_mesh(2)]
	var n_all := places.size()
	var mm_frame: Array = [_plain_mm(_stall_frame_mesh(false), n_all), _plain_mm(_stall_frame_mesh(true), n_all)]
	var mm_canvas: Array = [_plain_mm(_stall_awning_mesh(false), n_all), _plain_mm(_stall_awning_mesh(true), n_all)]
	var mm_striped: Array = [_plain_mm(_stall_awning_mesh(false), n_all), _plain_mm(_stall_awning_mesh(true), n_all)]
	var mm_goods: Array = [_plain_mm(goods[0], n_all), _plain_mm(goods[1], n_all), _plain_mm(goods[2], n_all)]
	var k_frame := [0, 0]
	var k_canvas := [0, 0]
	var k_striped := [0, 0]
	var k_goods := [0, 0, 0]
	for i in n_all:
		var pl: Dictionary = places[i]
		var c: Vector2 = pl["p"]
		var y := float(height.call(c.x, c.y)) + 0.2
		var xf := Transform3D(Basis(Vector3.UP, float(pl["yaw"])), Vector3(c.x, y, c.y))
		var w := 1 if pl.get("wall", false) else 0
		(mm_frame[w] as MultiMesh).set_instance_transform(k_frame[w], xf)
		k_frame[w] += 1
		if _rng.randf() < 0.55:
			(mm_canvas[w] as MultiMesh).set_instance_transform(k_canvas[w], xf)
			k_canvas[w] += 1
		else:
			(mm_striped[w] as MultiMesh).set_instance_transform(k_striped[w], xf)
			k_striped[w] += 1
		var g: int = pl["goods"]
		(mm_goods[g] as MultiMesh).set_instance_transform(k_goods[g], xf)
		k_goods[g] += 1
		# the stallholder behind the table and a shopper or two in front
		var back := Vector2(sin(float(pl["yaw"])), cos(float(pl["yaw"])))
		var v := _new_agent("tunic" if _rng.randf() < 0.75 else "stola")
		v["mode"] = "stand"
		v["amp"] = 0.0
		var vp := c - back * 1.1 if w == 0 else c + Vector2(back.y, -back.x) * 1.35 + back * 0.3
		v["pos"] = Vector3(vp.x, y - 0.07, vp.y)
		v["yaw"] = atan2(back.x, back.y)
		v["market"] = true
		_agents.append(v)
		for s in (_rng.randi() % 3):
			var sh := _new_agent(_pick_kind("street"))
			sh["mode"] = "stand"
			sh["amp"] = 0.0
			var side := Vector2(back.y, -back.x)
			var sp := c + back * _rng.randf_range(0.9, 1.5) + side * _rng.randf_range(-0.9, 0.9)
			sh["pos"] = Vector3(sp.x, y - 0.07, sp.y)
			sh["yaw"] = atan2(-back.x, -back.y) + _rng.randf_range(-0.3, 0.3)
			sh["market"] = true
			_agents.append(sh)
	for w in 2:
		(mm_frame[w] as MultiMesh).visible_instance_count = k_frame[w]
		(mm_canvas[w] as MultiMesh).visible_instance_count = k_canvas[w]
		(mm_striped[w] as MultiMesh).visible_instance_count = k_striped[w]
		_add_mm(_stalls, mm_frame[w], UrbsMaterials.get_material("timber_oak"), "StallFrames%d" % w)
		_stall_open.append(_add_mm(_stalls, mm_canvas[w], UrbsMaterials.get_material("awning_canvas"), "AwningsCanvas%d" % w))
		_stall_open.append(_add_mm(_stalls, mm_striped[w], UrbsMaterials.get_material("awning_striped"), "AwningsStriped%d" % w))
	for g in 3:
		(mm_goods[g] as MultiMesh).visible_instance_count = k_goods[g]
	for g in 3:
		_stall_open.append(_add_mm(_stalls, mm_goods[g], _vcol_mat, "Goods%d" % g))
	_stalls.set_meta("count", n_all)


func _plain_mm(mesh: Mesh, n: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# white instance colours: the compatibility renderer multiplies the vertex colour by the
	# instance colour, which is zero when a MultiMesh has none (lead's note, U8)
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = n
	for i in n:
		mm.set_instance_color(i, Color.WHITE)
	return mm


func _add_mm(parent: Node3D, mm: MultiMesh, mat: Material, nm: String) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## The frame: a 1.9 x 0.8 m trestle table at 0.85 m, the front poles 2.4 m; a free stall has two
## back poles of 2.0 m, a wall stall a beam into the house front instead. Faces +z (the customers).
static func _stall_frame_mesh(wall: bool) -> ArrayMesh:
	var parts: Array = []
	parts.append([M.box(Vector3(1.9, 0.05, 0.8)), Transform3D(Basis(), Vector3(0, 0.85, 0.15)), 5.0])
	for sx in [-0.8, 0.8]:
		for sz in [-0.15, 0.45]:
			parts.append([M.box(Vector3(0.06, 0.83, 0.06)), Transform3D(Basis(), Vector3(sx, 0.42, sz)), 5.0])
	for sx in [-1.05, 1.05]:
		parts.append([M.box(Vector3(0.08, 2.4, 0.08)), Transform3D(Basis(), Vector3(sx, 1.2, 1.0)), 5.0])
		if wall:
			parts.append([M.box(Vector3(0.06, 0.06, 1.3)), Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(sx, 2.32, 0.37)), 5.0])
		else:
			parts.append([M.box(Vector3(0.08, 2.0, 0.08)), Transform3D(Basis(), Vector3(sx, 1.0, -0.9)), 5.0])
	parts.append([M.box(Vector3(2.2, 0.06, 0.06)), Transform3D(Basis(), Vector3(0, 2.38, 1.0)), 5.0])
	if not wall:
		parts.append([M.box(Vector3(2.2, 0.06, 0.06)), Transform3D(Basis(), Vector3(0, 1.98, -0.9)), 5.0])
	return M.merge(parts)


## The awning: a cloth from the front bar (2.4 m) back to the back bar (2.0 m) or to the wall
## (2.55 m), sagging a little.
static func _stall_awning_mesh(wall: bool) -> ArrayMesh:
	var z_back := -0.27 if wall else -0.98
	var y_back := 2.55 if wall else 2.02
	var fn := func(u: float, v: float) -> Vector3:
		var x := lerpf(-1.15, 1.15, u)
		var z := lerpf(1.08, z_back, v)
		var y := lerpf(2.42, y_back, v) - 0.08 * sin(v * PI) - 0.03 * sin(u * PI)
		return Vector3(x, y, z)
	# both faces: the cloth is seen from the street below and from the hills above
	return M.merge([[M.surface(6, 4, fn, 1), Transform3D(), 0.0], [M.surface(6, 4, fn, -1), Transform3D(), 0.0]])


## Goods on the table. 0 produce, 1 pottery, 2 bread and cloth. Vertex colours.
static func _goods_mesh(kind: int) -> ArrayMesh:
	var parts: Array = []
	var cols: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + kind
	match kind:
		0:
			for i in 6:
				var x := -0.75 + i * 0.3
				var c: Color = [Color(0.35, 0.55, 0.25), Color(0.75, 0.55, 0.2), Color(0.6, 0.2, 0.15), Color(0.8, 0.7, 0.3), Color(0.45, 0.6, 0.3), Color(0.7, 0.3, 0.2)][i]
				parts.append([M.ellipsoid(0.14, 0.11, 0.17, 5, 3), Transform3D(Basis(), Vector3(x, 0.96, 0.15)), 0.0])
				cols.append(c)
			# a basket at each end and a sack under the table
			for sx in [-0.95, 0.95]:
				parts.append([M.lathe([Vector4(0.0, 0.14, 0.14, 0.0), Vector4(0.3, 0.2, 0.2, 0.0), Vector4(0.32, 0.17, 0.17, 0.0)], 6, 0, 1), Transform3D(Basis(), Vector3(sx, 0.0, 0.5)), 0.0])
				cols.append(Color(0.7, 0.58, 0.35))
			parts.append([M.ellipsoid(0.3, 0.26, 0.24, 5, 3), Transform3D(Basis(), Vector3(0.3, 0.26, 0.0)), 0.0])
			cols.append(Color(0.72, 0.66, 0.5))
		1:
			for i in 4:
				var x := -0.65 + i * 0.43
				parts.append([M.lathe([Vector4(0.0, 0.08, 0.08, 0.0), Vector4(0.1, 0.17, 0.17, 0.0), Vector4(0.3, 0.14, 0.14, 0.0), Vector4(0.36, 0.08, 0.08, 0.0), Vector4(0.4, 0.09, 0.09, 0.0)], 7, 0, 1), Transform3D(Basis(), Vector3(x, 0.88, 0.1)), 0.0])
				cols.append(Color(0.7, 0.44, 0.3).lerp(Color(0.5, 0.3, 0.2), rng.randf() * 0.5))
			for sx in [-1.0, -0.6, 0.6, 1.0]:
				parts.append([M.lathe([Vector4(0.0, 0.06, 0.06, 0.0), Vector4(0.25, 0.2, 0.2, 0.0), Vector4(0.7, 0.16, 0.16, 0.0), Vector4(0.85, 0.07, 0.07, 0.0), Vector4(0.92, 0.09, 0.09, 0.0)], 7, 0, 1), Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(sx, 0.0, 0.55)), 0.0])
				cols.append(Color(0.7, 0.44, 0.3))
		_:
			for i in 5:
				var x := -0.7 + i * 0.35
				parts.append([M.ellipsoid(0.13, 0.06, 0.13, 5, 2), Transform3D(Basis(), Vector3(x, 0.93, -0.05)), 0.0])
				cols.append(Color(0.72, 0.52, 0.28))
			for i in 3:
				var x := -0.55 + i * 0.55
				parts.append([M.box(Vector3(0.42, 0.12, 0.3)), Transform3D(Basis(), Vector3(x, 0.94, 0.3)), 0.0])
				cols.append([Color(0.55, 0.25, 0.3), Color(0.3, 0.4, 0.6), Color(0.85, 0.8, 0.65)][i])
	return _merge_coloured(parts, cols)


static func _merge_coloured(parts: Array, cols: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var colors := PackedColorArray()
	for i in parts.size():
		var p: Array = parts[i]
		var arr := (p[0] as ArrayMesh).surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ix: Variant = arr[Mesh.ARRAY_INDEX]
		var xf: Transform3D = p[1]
		var c: Color = cols[i]
		if ix != null and (ix as PackedInt32Array).size() > 0:
			for k in (ix as PackedInt32Array):
				verts.append(xf * v[k])
				norms.append((xf.basis * n[k]).normalized())
				colors.append(c)
		else:
			for k in v.size():
				verts.append(xf * v[k])
				norms.append((xf.basis * n[k]).normalized())
				colors.append(c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = colors
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# ---- carts, mules, litters ------------------------------------------------------------------------

func _make_vehicles() -> void:
	if _streets.is_empty():
		return
	# ox carts (plaustra) on the streets; which streets depends on the hour (see _apply_hour)
	for i in cart_count:
		var a := _new_agent("tunic")
		a["mode"] = "cart"
		a["rig"] = true
		a["speed"] = _rng.randf_range(0.8, 1.0)
		a["lat"] = 0.0
		var root := Node3D.new()
		root.name = "Cart%d" % i
		add_child(root)
		var cargo := _rng.randi() % 3
		_cart_mesh(root, cargo)
		var oxen: Array = []
		for sx in [-0.6, 0.6]:
			var ox: Node3D = A.make_ox([Color(0.55, 0.4, 0.28), Color(0.72, 0.62, 0.5), Color(0.35, 0.28, 0.22)][_rng.randi() % 3], false)
			ox.position = Vector3(sx, 0.0, 2.6)
			root.add_child(ox)
			oxen.append(ox)
		# the driver walks at the near ox's head with a goad
		var driver: Node3D = F.person({"tunic": TUNIC_COLOURS[_rng.randi() % TUNIC_COLOURS.size()], "seed": i})
		driver.position = Vector3(-1.25, 0.0, 3.0)
		root.add_child(driver)
		var rig := {"node": root, "kind": "cart", "agent": _agents.size(), "animals": oxen, "extra": [driver], "phase": _rng.randf() * TAU}
		_agents.append(a)
		_rigs.append(rig)
		_place_vehicle(a, true)
	# pack mules with a muleteer (no ban on pack animals; Juvenal 3.237 "mandrae", read)
	for i in mule_count:
		var a := _new_agent("tunic")
		a["mode"] = "mule"
		a["rig"] = true
		a["speed"] = _rng.randf_range(1.0, 1.25)
		var root := Node3D.new()
		root.name = "Mule%d" % i
		add_child(root)
		var mule: Node3D = A.make_horse([Color(0.45, 0.4, 0.36), Color(0.38, 0.3, 0.24), Color(0.6, 0.55, 0.5)][_rng.randi() % 3], false)
		mule.scale = Vector3(0.82, 0.82, 0.82)
		root.add_child(mule)
		# the packs
		var body: Node3D = mule.get_meta("body")
		for sx in [-0.34, 0.34]:
			F.box(body, Vector3(0.28, 0.45, 0.6), Vector3(sx, 1.35, 0.0), Color(0.62, 0.5, 0.34))
		F.box(body, Vector3(0.5, 0.2, 0.7), Vector3(0.0, 1.68, 0.0), Color(0.55, 0.42, 0.3))
		var man: Node3D = F.person({"tunic": TUNIC_COLOURS[_rng.randi() % TUNIC_COLOURS.size()], "seed": 50 + i})
		man.position = Vector3(0.9, 0.0, 0.9)
		root.add_child(man)
		var rig := {"node": root, "kind": "mule", "agent": _agents.size(), "animals": [mule], "extra": [man], "phase": _rng.randf() * TAU}
		_agents.append(a)
		_rigs.append(rig)
		_place_vehicle(a, false)
	# litters near the Forum (Cic. Phil. 2.58, read: an open litter)
	for i in litter_count:
		var a := _new_agent("toga")
		a["mode"] = "litter"
		a["rig"] = true
		a["speed"] = _rng.randf_range(0.95, 1.1)
		var root := Node3D.new()
		root.name = "Litter%d" % i
		add_child(root)
		_litter_mesh(root)
		var bearers: Array = []
		for sx in [-0.45, 0.45]:
			for sz in [1.35, -1.35]:
				var b: Node3D = F.person({"tunic": Color(0.72, 0.62, 0.5).lerp(Color(0.5, 0.45, 0.4), _rng.randf() * 0.5), "seed": 70 + i * 4 + bearers.size(), "sleeves": false})
				b.position = Vector3(sx, 0.0, sz)
				root.add_child(b)
				b.pose_arms(-1.5, -1.5, 0.15, 0.15, 1.25, 1.25)
				bearers.append(b)
		var rider: Node3D = F.person({"toga": true, "seed": 90 + i, "tunic": Color(0.92, 0.9, 0.84)})
		rider.position = Vector3(0, 1.38 - (F.SHIN + 0.075), 0.1)
		rider.sit(1.0)
		rider.look_yaw(0.4)
		root.add_child(rider)
		var rig := {"node": root, "kind": "litter", "agent": _agents.size(), "animals": [], "extra": bearers, "rider": rider, "phase": _rng.randf() * TAU}
		_agents.append(a)
		_rigs.append(rig)
		# start on a Forum street
		var pick := _street_index(["via_sacra", "argiletum", "vicus_tuscus", "nova_via", "clivus_argentarius"])
		a["si"] = pick
		a["d"] = _rng.randf() * float(_streets[pick]["len"])
		a["dir"] = 1 if _rng.randf() < 0.5 else -1
		a["lat"] = float(_streets[pick]["hw"]) * 0.3 * (1.0 if _rng.randf() < 0.5 else -1.0)


func _street_index(prefer: Array) -> int:
	var options: Array[int] = []
	for si in _streets.size():
		if prefer.has(str(_streets[si]["id"])):
			options.append(si)
	if options.is_empty():
		return _rng.randi() % _streets.size()
	return options[_rng.randi() % options.size()]


## Put a cart or mule on a street: carts on the roads outside by day, anywhere when allowed.
func _place_vehicle(a: Dictionary, cart: bool) -> void:
	var roads_only := cart and not carts_allowed(hour)
	var options: Array[int] = []
	for si in _streets.size():
		if roads_only and _streets[si]["kind"] != "road":
			continue
		if not roads_only and cart and _streets[si]["kind"] == "road" and _rng.randf() < 0.5:
			continue
		options.append(si)
	if options.is_empty():
		for si in _streets.size():
			options.append(si)
	var si := options[_rng.randi() % options.size()]
	a["si"] = si
	a["d"] = _rng.randf() * float(_streets[si]["len"])
	a["dir"] = 1 if _rng.randf() < 0.5 else -1
	a["lat"] = (0.0 if cart else float(_streets[si]["hw"]) * 0.35) * (1.0 if _rng.randf() < 0.5 else -1.0)
	a["roads_only"] = roads_only


## A plaustrum: a bed on an axle with two solid wheels, side boards, a pole to the yoke.
## Loads: 0 amphorae, 1 logs (Juvenal 3.254-256, read), 2 sacks.
func _cart_mesh(root: Node3D, cargo: int) -> void:
	var parts: Array = []
	var cols: Array = []
	var timber := Color(0.5, 0.38, 0.24)
	parts.append([M.box(Vector3(1.4, 0.08, 2.2)), Transform3D(Basis(), Vector3(0, 0.95, 0.0)), 0.0])
	cols.append(timber)
	for sx in [-0.7, 0.7]:
		parts.append([M.box(Vector3(0.05, 0.4, 2.2)), Transform3D(Basis(), Vector3(sx, 1.18, 0.0)), 0.0])
		cols.append(timber.darkened(0.1))
	parts.append([M.box(Vector3(1.4, 0.4, 0.05)), Transform3D(Basis(), Vector3(0, 1.18, -1.1)), 0.0])
	cols.append(timber.darkened(0.1))
	parts.append([M.box(Vector3(1.9, 0.1, 0.1)), Transform3D(Basis(), Vector3(0, 0.75, 0.0)), 0.0])
	cols.append(timber.darkened(0.2))
	# solid wheels
	for sx in [-0.88, 0.88]:
		parts.append([M.lathe([Vector4(-0.06, 0.0, 0.0, 0.0), Vector4(-0.06, 0.72, 0.72, 0.0), Vector4(0.06, 0.72, 0.72, 0.0), Vector4(0.06, 0.0, 0.0, 0.0)], 18), Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(sx, 0.75, 0.0)), 0.0])
		cols.append(Color(0.42, 0.32, 0.2))
	# the pole and the yoke
	parts.append([M.box(Vector3(0.1, 0.1, 3.0)), Transform3D(Basis(Vector3.RIGHT, 0.08), Vector3(0, 0.95, 1.4)), 0.0])
	cols.append(timber)
	parts.append([M.box(Vector3(1.7, 0.1, 0.12)), Transform3D(Basis(), Vector3(0, 1.3, 2.85)), 0.0])
	cols.append(timber)
	match cargo:
		0:
			for i in 3:
				for j in 2:
					parts.append([M.lathe([Vector4(0.0, 0.08, 0.08, 0.0), Vector4(0.2, 0.22, 0.22, 0.0), Vector4(0.6, 0.18, 0.18, 0.0), Vector4(0.8, 0.09, 0.09, 0.0), Vector4(0.86, 0.11, 0.11, 0.0)], 10), Transform3D(Basis(Vector3.RIGHT, PI / 2.0 - 0.1), Vector3(-0.45 + j * 0.9 - 0.0, 1.22 + (0.0 if i < 2 else 0.3), -0.7 + i * 0.7)), 0.0])
					cols.append(Color(0.7, 0.44, 0.3))
		1:
			for i in 4:
				parts.append([M.capsule(0.13, 0.11, 3.4, 8), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(-0.45 + i * 0.3, 1.14 + (0.0 if i % 2 == 0 else 0.2), 1.6)), 0.0])
				cols.append(Color(0.45, 0.32, 0.18))
		_:
			for i in 4:
				parts.append([M.ellipsoid(0.36, 0.3, 0.42, 8, 5), Transform3D(Basis(), Vector3(-0.35 + (i % 2) * 0.7, 1.28, -0.5 + (i / 2) * 0.9)), 0.0])
				cols.append(Color(0.74, 0.68, 0.52))
	var mi := MeshInstance3D.new()
	mi.mesh = _merge_coloured(parts, cols)
	mi.material_override = _vcol_mat
	root.add_child(mi)


## An open lectica: two poles on the bearers' shoulders, a frame and a mattress with cushions.
func _litter_mesh(root: Node3D) -> void:
	var parts: Array = []
	var cols: Array = []
	for sx in [-0.42, 0.42]:
		parts.append([M.capsule(0.035, 0.035, 3.6, 8), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(sx, 1.42, 1.8)), 0.0])
		cols.append(Color(0.5, 0.36, 0.22))
	parts.append([M.box(Vector3(0.9, 0.1, 2.0)), Transform3D(Basis(), Vector3(0, 1.42, 0.0)), 0.0])
	cols.append(Color(0.45, 0.32, 0.2))
	parts.append([M.box(Vector3(0.84, 0.16, 1.9)), Transform3D(Basis(), Vector3(0, 1.55, 0.0)), 0.0])
	cols.append(Color(0.6, 0.2, 0.22))
	parts.append([M.ellipsoid(0.36, 0.1, 0.22, 8, 4), Transform3D(Basis(), Vector3(0, 1.66, -0.75)), 0.0])
	cols.append(Color(0.75, 0.6, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = _merge_coloured(parts, cols)
	mi.material_override = _vcol_mat
	root.add_child(mi)


# ---- lamps and smoke ----------------------------------------------------------------------------

## Lamps at doorways along the streets inside the city, every ~45 m, with a light at the nearest
## eight. Few on purpose: Juvenal 3.268-277 (read) knows no street lighting (# unverified).
func _make_lamps() -> void:
	_lamp_node = Node3D.new()
	_lamp_node.name = "Lamps"
	add_child(_lamp_node)
	_lamps = PackedVector3Array()
	for si in _streets.size():
		var s: Dictionary = _streets[si]
		if s["kind"] == "road":
			continue
		var n := int(float(s["len"]) / 45.0)
		for i in n:
			var pt: Array = urbs.streets.sample_at(si, 20.0 + i * 45.0)
			var p: Vector2 = pt[0]
			if p.length() > 1300.0:
				continue
			var tg: Vector2 = pt[1]
			var side := 1.0 if i % 2 == 0 else -1.0
			var q: Vector2 = p + Vector2(-tg.y, tg.x) * (float(s["hw"]) + 1.0) * side
			_lamps.append(Vector3(q.x, float(height.call(q.x, q.y)) + 2.5, q.y))
	# a few more round the Comitium and the Rostra
	if urbs.monuments.ids().has("comitium"):
		var b: AABB = urbs.monuments.bounds("comitium")
		var c := b.get_center()
		for k in 4:
			var ang := TAU * k / 4.0
			var q := Vector2(c.x + cos(ang) * (b.size.x * 0.5 + 2.0), c.z + sin(ang) * (b.size.z * 0.5 + 2.0))
			_lamps.append(Vector3(q.x, float(height.call(q.x, q.y)) + 2.3, q.y))
	if _lamps.is_empty():
		return
	var lamp_mesh := M.merge([[M.box(Vector3(0.18, 0.26, 0.18)), Transform3D(), 0.0], [M.box(Vector3(0.05, 0.05, 0.5)), Transform3D(Basis(), Vector3(0, 0.16, -0.25)), 0.0]])
	var glass := _plain_mm(M.box(Vector3(0.16, 0.22, 0.16)), _lamps.size())
	var brackets := _plain_mm(lamp_mesh, _lamps.size())
	for i in _lamps.size():
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), _lamps[i])
		glass.set_instance_transform(i, xf)
		brackets.set_instance_transform(i, xf)
	_add_mm(_lamp_node, brackets, UrbsMaterials.get_material("iron"), "LampBrackets")
	_add_mm(_lamp_node, glass, UrbsMaterials.get_material("glass_lamp"), "LampGlass")
	for i in 8:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.5)
		l.light_energy = 2.4
		l.omni_range = 14.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		l.visible = false
		_lamp_node.add_child(l)
		_lights.append(l)


const SMOKE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
uniform float clock = 0.0;
uniform float amount = 1.0;      // share of columns smoking (0..1)
uniform vec3 wind = vec3(0.6, 0.0, 0.2);
uniform vec4 tint : source_color = vec4(0.62, 0.6, 0.58, 0.4);
varying float alpha;
void vertex() {
	float idx = INSTANCE_CUSTOM.x;      // puff 0..1 along the column
	float seed = INSTANCE_CUSTOM.y;
	float on = step(seed, amount);
	float life = 14.0 + 4.0 * seed;
	float t = fract(clock / life + idx + seed * 3.7);
	float rise = t * (22.0 + 14.0 * seed);
	float size = 2.0 + 7.0 * t + 1.5 * seed;
	alpha = tint.a * (1.0 - t) * smoothstep(0.0, 0.08, t) * on;
	vec3 world_base = MODEL_MATRIX[3].xyz;
	vec3 centre = world_base + vec3(0.0, rise, 0.0) + wind * rise * (0.6 + 0.4 * seed) + vec3(sin(t * 9.0 + seed * 20.0), 0.0, cos(t * 7.0 + seed * 11.0)) * 0.6 * t;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world_pos = centre + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = alpha * smoothstep(1.0, 0.25, d);
	ALBEDO = tint.rgb;
	ALPHA = a;
}
"""


## Kitchen smoke over the houses: columns at positions weighted by the districts' density
## (regions.json), a few metres above the roofs. Horace Odes 3.29.12 (read).
func _make_smoke() -> void:
	var text := FileAccess.get_file_as_string(REGIONS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var districts: Array = parsed.get("districts", [])
	if districts.is_empty():
		return
	var n_col := clampi(int(population / 3500.0), 24, 240)
	var pos: PackedVector3Array = PackedVector3Array()
	var tries := 0
	while pos.size() < n_col and tries < n_col * 20:
		tries += 1
		var d: Dictionary = districts[_rng.randi() % districts.size()]
		var dens := float(d.get("max_density", 0.5)) * pow(clampf(population / float(d.get("saturates_at", 100000.0)), 0.0, 1.0), 0.7)
		if _rng.randf() > dens or str(d.get("id", "")) in ["forum", "capitol"]:
			continue
		var c := UrbsGeo.to_local(float(d["lat"]), float(d["lon"]))
		var r := float(d.get("radius_m", 200.0)) * sqrt(_rng.randf())
		var ang := _rng.randf() * TAU
		var p := c + Vector2(cos(ang), sin(ang)) * r
		if _blocked(p) or UrbsTerrain.in_river(p.x, p.y):
			continue
		pos.append(Vector3(p.x, float(height.call(p.x, p.y)) + _rng.randf_range(6.0, 13.0), p.y))
	if pos.is_empty():
		return
	var puffs := 9
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = pos.size() * puffs
	mm.visible_instance_count = mm.instance_count
	mm.custom_aabb = AABB(Vector3(-2600, -50, -2600), Vector3(5200, 300, 5200))
	for i in pos.size():
		var seed_v := _rng.randf()
		for k in puffs:
			var idx := i * puffs + k
			mm.set_instance_transform(idx, Transform3D(Basis(), pos[i]))
			mm.set_instance_custom_data(idx, Color(float(k) / puffs, seed_v, 0.0, 0.0))
			mm.set_instance_color(idx, Color.WHITE)
	var sh := Shader.new()
	sh.code = SMOKE_SHADER
	_smoke_mat = ShaderMaterial.new()
	_smoke_mat.shader = sh
	var smoke_col: Color = UrbsMaterials.COLOURS.get("smoke", Color(0.6, 0.6, 0.6, 0.4))
	_smoke_mat.set_shader_parameter("tint", Color(smoke_col.r, smoke_col.g, smoke_col.b, 0.42))
	_smoke = MultiMeshInstance3D.new()
	_smoke.name = "Smoke"
	_smoke.multimesh = mm
	_smoke.material_override = _smoke_mat
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_smoke)
	_smoke_count = pos.size()


## Share of kitchens smoking by the hour: bakers before dawn, the prandium about the sixth hour,
## the cena from the ninth (Martial 4.8, read).
static func smoke_at(h: float) -> float:
	var hh := fposmod(h, 24.0)
	var v := 0.12
	v = maxf(v, 0.45 * exp(-pow((hh - 5.5) / 1.6, 2.0)))
	v = maxf(v, 0.5 * exp(-pow((hh - 11.5) / 1.4, 2.0)))
	v = maxf(v, 1.0 * exp(-pow((hh - 16.0) / 2.2, 2.0)))
	return clampf(v, 0.0, 1.0)


# ---- the festival's crowd at the venue ------------------------------------------------------------

## A standing crowd along the long sides of the venue of a `games` event (the Ludi Romani in the
## Circus Maximus each September: republic_rules.yaml city.ludi), waiting to go in. The seats
## inside are the race's own (race.gd fills the Circus in faction colours).
func _make_venue_crowd() -> void:
	if _venue_crowd != null:
		_venue_crowd.queue_free()
		_venue_crowd = null
	if festival_venue == "" or not urbs.monuments.ids().has(festival_venue):
		return
	var placed: Dictionary = urbs.monuments.get("_placed") if urbs.monuments.get("_placed") != null else {}
	if not placed.has(festival_venue):
		return
	var p: Dictionary = placed[festival_venue]
	var yaw: float = p["yaw"]
	var u := Vector2(sin(yaw), cos(yaw))
	var v := Vector2(cos(yaw), -sin(yaw))
	var hl: float = float(p["length"]) * 0.5
	var hw: float = float(p["width"]) * 0.5 + 4.0
	var c: Vector2 = p["centre"]
	var crowd = Crowd.new()
	crowd.standing = true
	crowd.toga_rows = 0
	crowd.fan_colours.assign([Color(0.93, 0.93, 0.90), Color(0.80, 0.16, 0.14), Color(0.20, 0.55, 0.28), Color(0.20, 0.38, 0.75)])
	crowd.fan_share = 0.3
	for side in [-1.0, 1.0]:
		var poly := PackedVector3Array()
		for i in 9:
			var q: Vector2 = c + u * lerpf(-hl * 0.8, hl * 0.8, float(i) / 8.0) + v * hw * side
			poly.append(Vector3(q.x, float(height.call(q.x, q.y)) + 0.2, q.y))
		crowd.add_seats(Crowd.line_seats(poly, 1.0, 3, 1.3, 0.9, 0.0))
	crowd.build()
	crowd.name = "VenueCrowd"
	add_child(crowd)
	crowd.set_state(0.0, 0.25, 0.0, 0.0)
	_venue_crowd = crowd


# ---- the hour ---------------------------------------------------------------------------------------

func _apply_hour() -> void:
	var share := activity * (1.3 if festival_venue != "" else 1.0)
	var open := market_open(hour)
	var carts_ok := carts_allowed(hour)
	for i in _agents.size():
		var a := _agents[i]
		var on := true
		match str(a["mode"]):
			"street", "plaza", "stand":
				if a.get("market", false):
					on = open
				else:
					# each person has a fixed threshold, so the same people stay as the day thins
					on = fmod(float((a["custom"] as Color).r) * 7.31 + float(i) * 0.137, 1.0) < share
				if a["dog"]:
					on = fmod(float(i) * 0.37, 1.0) < 0.35 + 0.65 * share
			"cart":
				if bool(a.get("roads_only", false)) != (not carts_ok):
					_place_vehicle(a, true)
			"mule", "litter":
				on = activity > 0.2
		a["active"] = on
	for mi in _stall_open:
		mi.visible = open
	var lit := lamps_lit(hour)
	if _lamp_node != null:
		_lamp_node.visible = lit
	if _smoke_mat != null:
		_smoke_mat.set_shader_parameter("amount", smoke_at(hour))
	for r in _rigs:
		var a := _agents[r["agent"]]
		(r["node"] as Node3D).visible = a["active"]
	_cam = Vector3(1e9, 0, 1e9)   # force a LOD pass


# ---- each frame -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not built or not auto_tick or not is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		tick(delta, cam.global_position)


## Advance the life by `delta` seconds as seen from `cam_pos` (world metres).
func tick(delta: float, cam_pos: Vector3) -> void:
	if not built:
		return
	_clock += delta
	_frame += 1
	Crowd.walk_material().set_shader_parameter("clock", _clock)
	if _smoke_mat != null:
		_smoke_mat.set_shader_parameter("clock", _clock)
	_lod_timer += delta
	if _lod_phase >= 0:
		_lod_step()
	elif _lod_timer > 1.2 or cam_pos.distance_to(_cam) > 12.0:
		_lod_timer = 0.0
		_cam = cam_pos
		_lod_begin(cam_pos)
		_lod_step()
	# skinned figures every frame, level 1 one frame in two, level 2 one in six, level 3 one in 16
	for i in _move_figs:
		_step(i, delta, true)
	var k := _frame % 2
	while k < _move_near.size():
		_step(_move_near[k], delta * 2.0, true)
		k += 2
	k = _frame % 6
	while k < _move_mid.size():
		_step(_move_mid[k], delta * 6.0, false)
		k += 6
	k = _frame % 16
	while k < _move_far.size():
		_step(_move_far[k], delta * 16.0, false)
		k += 16
	_update_rigs(delta)
	if _lamp_node != null and _lamp_node.visible:
		_update_lights(cam_pos)


func _step(i: int, dt: float, exact := true) -> void:
	var a := _agents[i]
	match str(a["mode"]):
		"street", "cart", "mule", "litter":
			_step_street(a, dt, exact)
		"plaza":
			_step_plaza(a, dt)
		_:
			if int(a["lod"]) != 0:
				return
	_write(i, a)


func _step_street(a: Dictionary, dt: float, exact := true) -> void:
	var si: int = a["si"]
	if si < 0 or si >= _streets.size():
		return
	var s: Dictionary = _streets[si]
	var d: float = a["d"] + float(a["speed"]) * float(a["dir"]) * dt
	var len_s := float(s["len"])
	if d < 0.0 or d > len_s:
		var end := 0 if d < 0.0 else 1
		var links: Array = _links[si]
		var choices: Array = []
		for l in links:
			if int(l[0]) == end:
				if bool(a.get("roads_only", false)) and _streets[int(l[1])]["kind"] != "road":
					continue
				choices.append(l)
		if choices.is_empty() or _rng.randf() < 0.15:
			a["dir"] = -int(a["dir"])
			d = clampf(d, 0.0, len_s)
			a["lat"] = -float(a["lat"])
		else:
			var l: Array = choices[_rng.randi() % choices.size()]
			si = int(l[1])
			a["si"] = si
			a["seg"] = 0
			s = _streets[si]
			d = float(l[2])
			a["dir"] = 1 if _rng.randf() < 0.5 else -1
			var hw := float(s["hw"])
			a["lat"] = signf(a["lat"]) * hw * (0.0 if str(a["mode"]) == "cart" else _rng.randf_range(0.25, 0.85))
	a["d"] = d
	# walk the street's own polyline from the agent's last segment (no search from the start)
	var cum: PackedFloat32Array = s["cum"]
	var pts: PackedVector2Array = s["pts"]
	var k: int = clampi(int(a.get("seg", 0)), 0, cum.size() - 2)
	while k < cum.size() - 2 and cum[k + 1] < d:
		k += 1
	while k > 0 and cum[k] > d:
		k -= 1
	a["seg"] = k
	var seg_len := maxf(cum[k + 1] - cum[k], 0.0001)
	var q := pts[k].lerp(pts[k + 1], clampf((d - cum[k]) / seg_len, 0.0, 1.0))
	var tg := (pts[k + 1] - pts[k]) / seg_len
	q += Vector2(-tg.y, tg.x) * float(a["lat"])
	var gy: float
	if exact:
		gy = float(height.call(q.x, q.y))
	else:
		var hs: PackedFloat32Array = _street_h[si]
		gy = lerpf(hs[k], hs[k + 1], clampf((d - cum[k]) / seg_len, 0.0, 1.0))
	var p := Vector3(q.x, gy + 0.22, q.y)
	var dir := float(a["dir"])
	a["pos"] = p
	a["yaw"] = atan2(tg.x * dir, tg.y * dir)
	a["phase"] = float(a["phase"]) + float(a["speed"]) * dt / 1.45 * TAU


func _step_plaza(a: Dictionary, dt: float) -> void:
	if float(a["pause"]) > 0.0:
		a["pause"] = float(a["pause"]) - dt
		a["amp"] = 0.0
		return
	var p: Vector3 = a["pos"]
	var here := Vector2(p.x, p.z)
	var t: Vector2 = a["target"]
	var to := t - here
	if to.length() < 0.6:
		a["pause"] = _rng.randf_range(2.0, 14.0)
		a["target"] = _forum_random()
		return
	a["amp"] = 1.0
	var step := to.normalized() * float(a["speed"]) * dt
	var q := here + step
	a["pos"] = _forum_point(q)
	a["yaw"] = atan2(to.x, to.y)
	a["phase"] = float(a["phase"]) + float(a["speed"]) * dt / 1.45 * TAU


## Write an agent's transform into its MultiMesh slot (or move its figure).
func _write(i: int, a: Dictionary) -> void:
	var lod: int = a["lod"]
	var p: Vector3 = a["pos"]
	if lod == 0 and int(a["fig"]) >= 0:
		var f: Dictionary = _figs[int(a["fig"])]
		var node: Node3D = f["node"]
		if node != null:
			node.position = p
			node.rotation.y = float(a["yaw"])
			if str(a["mode"]) == "stand" or float(a["amp"]) < 0.01:
				node.walk(0.0, 0.0)
				var ph: float = a["phase"]
				match int(ph * 7.0) % 4:   # a fixed stance per person
					0: node.pose_arms(0.05, 0.05, 0.06, 0.06, 0.15, 0.15)              # arms at rest
					1: node.pose_arms(0.25, 0.25, 0.08, 0.08, 1.9, 1.7)                # hands joined
					2: node.pose_arms(-0.85, 0.1, 0.3, 0.05, 0.6, 0.2)                 # speaking, the right hand out
					_: node.pose_arms(0.1, 0.0, 0.05, 0.75, 0.2, 2.2)                  # a hand on the hip
				node.look_yaw(sin(ph * 13.0) * 0.4, 0.05)
			else:
				node.walk(float(a["phase"]), float(a["amp"]))
		return
	var slot: int = a.get("slot", -1)
	if slot < 0 or lod == HIDDEN:
		return
	var mm: MultiMesh = _mm_dog if a["dog"] else [_mm_mid, _mm_mid, _mm_far, _mm_vfar][lod]
	var sc: float = a["scale"]
	mm.set_instance_transform(slot, Transform3D(Basis(Vector3.UP, float(a["yaw"])).scaled(Vector3.ONE * sc), p))
	var cd: Color = a["custom"]
	if absf(cd.g - float(a["amp"])) > 0.01:
		cd.g = float(a["amp"])
		a["custom"] = cd
		mm.set_instance_custom_data(slot, cd)


## Sort the people into detail levels by distance, pack each level's MultiMesh with only its own
## people (so the GPU draws no hidden instances), and hand the skinned figures to the nearest.
## The pass is spread over LOD_PHASES frames (_lod_step): eight slices of classification, then
## the near figures, then one MultiMesh per frame. _update_lod runs all of it at once.
const LOD_SLICES := 8
const LOD_PHASES := LOD_SLICES + 6
var _lod_phase := -1
var _lod_cam := Vector3.ZERO
var _lod_near: Array = []
var _lod_lists: Array = []


func _update_lod(cam_pos: Vector3) -> void:
	_lod_begin(cam_pos)
	while _lod_phase >= 0:
		_lod_step()


func _lod_begin(cam_pos: Vector3) -> void:
	_lod_cam = cam_pos
	_lod_near = []
	_lod_lists = [[], [], [], []]   # level 1, 2, 3, dogs
	_lod_phase = 0


func _lod_step() -> void:
	if _lod_phase < 0:
		return
	if _lod_phase < LOD_SLICES:
		_lod_classify(_lod_phase)
	elif _lod_phase == LOD_SLICES:
		_lod_apply_levels()
	elif _lod_phase == LOD_SLICES + 1:
		_lod_apply_figures()
	elif _lod_phase == LOD_SLICES + 2:
		_lod_apply_lists()
	else:
		_lod_fill(_lod_phase - LOD_SLICES - 3)
	_lod_phase += 1
	if _lod_phase >= LOD_PHASES:
		_lod_phase = -1


# Slice k of the agents: the new level goes in "nlod" (applied together in _lod_apply).
func _lod_classify(k: int) -> void:
	var d0 := near_distance * near_distance
	var d1 := near_mm_distance * near_mm_distance
	var d2 := mid_distance * mid_distance
	var d3 := cull_distance * cull_distance
	var n := _agents.size()
	for i in range(n * k / LOD_SLICES, n * (k + 1) / LOD_SLICES):
		var a := _agents[i]
		var lod := HIDDEN
		if a["active"]:
			var dd := (a["pos"] as Vector3).distance_squared_to(_lod_cam)
			if a.get("rig", false):
				lod = 1 if dd < 160.0 * 160.0 else HIDDEN
			elif a["dog"]:
				lod = 1 if dd < d1 * 1.5 else HIDDEN
			elif dd < d0:
				lod = 0
				_lod_near.append([dd, i])
			elif dd < d1:
				lod = 1
			elif dd < d2:
				lod = 2
			elif dd < d3:
				lod = 3
		a["nlod"] = lod


# Apply the new levels (then the skinned figures to the nearest, then the stepping lists).
func _lod_apply_levels() -> void:
	for i in _agents.size():
		var a := _agents[i]
		var lod: int = a.get("nlod", HIDDEN)
		a["lod"] = lod
		a["slot"] = -1
		if lod != 0 and int(a["fig"]) >= 0:
			_release_fig(i)


func _lod_apply_figures() -> void:
	_lod_near.sort_custom(func(x, y): return x[0] < y[0])
	var given := 0
	for item in _lod_near:
		var i: int = item[1]
		var a := _agents[i]
		if given >= near_figures:
			if int(a["fig"]) >= 0:
				_release_fig(i)
			a["lod"] = 1
			continue
		if int(a["fig"]) < 0:
			var fi := _take_fig(str(a["kind"]), a)
			if fi < 0:
				a["lod"] = 1
				continue
			a["fig"] = fi
			_figs[fi]["agent"] = i
		given += 1
	_counts["near"] = given


func _lod_apply_lists() -> void:
	_move_figs = PackedInt32Array()
	_move_near = PackedInt32Array()
	_move_mid = PackedInt32Array()
	_move_far = PackedInt32Array()
	for i in _agents.size():
		var a := _agents[i]
		var lod: int = a["lod"]
		if lod == HIDDEN:
			continue
		var moving := str(a["mode"]) != "stand"
		if lod == 0:
			_write(i, a)
			if moving:
				_move_figs.append(i)
			continue
		if not a.get("rig", false):
			(_lod_lists[3] if a["dog"] else _lod_lists[lod - 1]).append(i)
		if not moving:
			continue
		if lod == 1:
			_move_near.append(i)
		elif lod == 2:
			_move_mid.append(i)
		else:
			_move_far.append(i)
	for r in _rigs:
		var a := _agents[r["agent"]]
		(r["node"] as Node3D).visible = a["active"] and int(a["lod"]) != HIDDEN
	_counts["level1"] = (_lod_lists[0] as Array).size()
	_counts["level2"] = (_lod_lists[1] as Array).size()
	_counts["level3"] = (_lod_lists[2] as Array).size()
	_counts["dogs_shown"] = (_lod_lists[3] as Array).size()


# Rewrite one level's MultiMesh in one bulk buffer: per instance 12 floats of transform (by
# rows), 4 of colour, 4 of custom data. k: 0 level 1 and the dogs, 1 level 2, 2 level 3.
func _lod_fill(k: int) -> void:
	var todo: Array = [[_mm_mid, _lod_lists[0]], [_mm_dog, _lod_lists[3]]] if k == 0 else ([[_mm_far, _lod_lists[1]]] if k == 1 else [[_mm_vfar, _lod_lists[2]]])
	for pair in todo:
		var mm: MultiMesh = pair[0]
		var lst: Array = pair[1]
		var buf := PackedFloat32Array()
		buf.resize(mm.instance_count * 20)
		var o := 0
		for slot in lst.size():
			var i: int = lst[slot]
			var a := _agents[i]
			a["slot"] = slot
			var yaw: float = a["yaw"]
			var sc: float = a["scale"]
			var cs := cos(yaw) * sc
			var sn := sin(yaw) * sc
			var p: Vector3 = a["pos"]
			var c: Color = a["col"]
			var cd: Color = a["custom"]
			cd.g = float(a["amp"])
			a["custom"] = cd
			buf[o] = cs; buf[o + 1] = 0.0; buf[o + 2] = sn; buf[o + 3] = p.x
			buf[o + 4] = 0.0; buf[o + 5] = sc; buf[o + 6] = 0.0; buf[o + 7] = p.y
			buf[o + 8] = -sn; buf[o + 9] = 0.0; buf[o + 10] = cs; buf[o + 11] = p.z
			buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = 1.0
			buf[o + 16] = cd.r; buf[o + 17] = cd.g; buf[o + 18] = cd.b; buf[o + 19] = cd.a
			o += 20
		mm.buffer = buf
		mm.visible_instance_count = lst.size()


func _take_fig(kind: String, a: Dictionary) -> int:
	var pick := -1
	for k in _fig_free:
		if _figs[k]["kind"] == kind:
			pick = k
			break
	if pick < 0:
		if _figs.size() < near_figures + 24:
			_figs.append({"node": null, "kind": kind, "agent": -1})
			pick = _figs.size() - 1
		else:
			# reuse a free figure of another class: rebuild it as this class
			if _fig_free.is_empty():
				return -1
			pick = _fig_free[0]
			var old: Node3D = _figs[pick]["node"]
			if old != null:
				old.queue_free()
			_figs[pick]["node"] = null
			_figs[pick]["kind"] = kind
	_fig_free.erase(pick)
	var f: Dictionary = _figs[pick]
	if f["node"] == null:
		f["node"] = _make_figure(kind, a)
	var node: Node3D = f["node"]
	node.visible = true
	# recolour to the agent (the class shape is the figure's)
	var rig: Node = node.rig
	if kind == "toga":
		rig.set_colour("c_toga", a["col"])
	else:
		rig.set_colour("c_tunic", a["col"])
	var skin := Color(0.95, 0.75, 0.6).lerp(Color(0.6, 0.4, 0.3), (a["custom"] as Color).b)
	rig.set_colour("c_skin", skin)
	rig.set_colour("c_face", skin)
	node.scale = Vector3.ONE * float(a["scale"])
	return pick


func _release_fig(i: int) -> void:
	var a := _agents[i]
	var fi: int = a["fig"]
	if fi < 0:
		return
	var f: Dictionary = _figs[fi]
	if f["node"] != null:
		(f["node"] as Node3D).visible = false
	f["agent"] = -1
	a["fig"] = -1
	_fig_free.append(fi)


## Move the carts, mules and litters with their agents and pose the animals and bearers.
func _update_rigs(delta: float) -> void:
	for r in _rigs:
		var a := _agents[r["agent"]]
		var node: Node3D = r["node"]
		if not node.visible:
			continue
		var p: Vector3 = a["pos"]
		node.position = Vector3(p.x, p.y - 0.1, p.z)
		node.rotation.y = float(a["yaw"])
		var ph := float(a["phase"])
		match str(r["kind"]):
			"cart":
				for ox in r["animals"]:
					A.walk_ox(ox, ph * 0.8, 1.0)
				(r["extra"][0] as Node3D).walk(ph, 0.75)
			"mule":
				A.walk_ox(r["animals"][0], ph, 0.9)
				(r["extra"][0] as Node3D).walk(ph, 0.85)
			"litter":
				var k := 0
				for b in r["extra"]:
					(b as Node3D).walk(ph + (0.0 if k % 2 == 0 else 0.0), 0.7)
					(b as Node3D).pose_arms(-1.5, -1.5, 0.15, 0.15, 1.25, 1.25)
					k += 1


## Give the eight lights to the lamps nearest the camera.
func _update_lights(cam_pos: Vector3) -> void:
	if _lamps.is_empty():
		return
	var best: Array = []
	for i in _lamps.size():
		var dd := _lamps[i].distance_squared_to(cam_pos)
		if dd < 120.0 * 120.0:
			best.append([dd, i])
	best.sort_custom(func(x, y): return x[0] < y[0])
	for k in _lights.size():
		var l := _lights[k]
		if k < best.size():
			l.visible = true
			l.position = _lamps[int(best[k][1])] + Vector3(0, -0.2, 0)
		else:
			l.visible = false
