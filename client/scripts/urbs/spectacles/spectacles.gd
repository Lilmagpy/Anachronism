## Entry point of the spectacles (U6): UrbsSpectacles.play(kind, params, parent) -> Node3D.
## kind is "race", "munus", "senate", "sacrifice" or "triumph"; params are the engine's view of
## the event plus the venue's geometry (see each script's header). The returned node is a
## spectacle (base.gd): it plays by itself in _process, can be seeked (seek(t)), exposes
## seat_views() camera presets and emits `finished`. stop() frees the current one.
##
## ## Engine events -> spectacles (U8)
## The engine's `city` view (docs/ARCHITECTURE.md section 10; tools/city_view.py) lists the turn's
## events as {kind, year, ref, monument, person, value, other}. `from_event(e)` maps one to a
## spectacle and `play_event(e, urbs)` places and plays it on its monument:
##
##   engine kind / ref                 spectacle   placed on            params from the event
##   games / ludi_* of kind circus     race        e.monument (circus_maximus for the Ludi
##     (ludi_romani, ludi_apollinares,             Romani and Apollinares, circus_flaminius for
##      ludi_plebeii)                              the Plebeii: republic_rules.yaml city.ludi)
##                                                                      festival = ref; the Ludi
##                                                 Romani fill the Circus: 22 rows, 55% of the
##                                                 crowd in faction colours (see below)
##   games / munus                     munus       e.monument (forum_boarium: Livy Per. 16,
##                                                 # unverified; the Forum Romanum from 216 BC,
##                                                 Livy 23.30.15, read)     person = the dead man
##   games / ludi_megalenses (scaenic) none        (no theatre spectacle yet; the Urbs street
##                                                 life still shows the festival crowd)
##   senate / <issue>                  senate      e.monument (the senate house in use)
##                                                 vote {issue: ref, yes_bp: value, no_bp: other,
##                                                 passes: value > other}
##   sacrifice / vow | dedication      sacrifice   e.monument (the temple); favourable = true
##                                                 (the engine records only the vow kept)
##   triumph / battle | capital        triumph     the triumphal way (triumph_route): Villa
##                                                 Publica - Circus Flaminius - Porta Carmentalis -
##                                                 Velabrum - Circus Maximus - round the Palatine -
##                                                 Sacra Via - Clivus Capitolinus - Area Capitolina
##                                                 general = person, spoils by ref (the
##                                                 engine's value, its wealth, is not shown)
##   fire, flood                       none        (the monuments show the burnt state; no
##                                                 spectacle)
##
## The Ludi Romani each September (month 9, republic_rules.yaml): the race runs with the Circus
## full, the front rows the senators and knights in white togas (Livy 1.35.8, read: "loca divisa
## patribus equitibusque", places marked out for the senators and the knights), the rest in
## tunics with a large share wearing their faction's colour (Tertullian De spect. 9.5, read; the
## four colours are attested for the Empire, spectacles.yaml factions_note). The pompa circensis
## that opened them (Dion. Hal. 7.72, read) is triumph.gd's procession order; it is not played
## before the race (# not built).
class_name UrbsSpectacles
extends RefCounted

const PATHS := {
	"race": "res://scripts/urbs/spectacles/race.gd",
	"munus": "res://scripts/urbs/spectacles/munus.gd",
	"senate": "res://scripts/urbs/spectacles/senate.gd",
	"sacrifice": "res://scripts/urbs/spectacles/sacrifice.gd",
	"triumph": "res://scripts/urbs/spectacles/triumph.gd",
}

static var _current: Node3D


static func kinds() -> PackedStringArray:
	return PackedStringArray(PATHS.keys())


## Start a spectacle under `parent` (placed by the caller: set .transform / .position on the result).
static func play(kind: String, params: Dictionary, parent: Node) -> Node3D:
	stop()
	if not PATHS.has(kind):
		push_error("UrbsSpectacles: unknown kind %s" % kind)
		return null
	var script: GDScript = load(PATHS[kind])
	var node: Node3D = script.new(params)
	node.name = "Spectacle_" + kind
	parent.add_child(node)
	_current = node
	return node


## Remove the spectacle that is playing.
static func stop() -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = null


const DEFAULT_MONUMENT := {
	"race": "circus_maximus", "munus": "forum_romanum", "senate": "curia_hostilia",
	"sacrifice": "aedes_iovis_capitolini", "triumph": "campus_martius",
}


## The spectacle for one engine event (see the header): {kind, monument, params}, or {} when the
## event has none. Pure: no scene needed (tests and the HUD can ask what an event will show).
static func from_event(e: Dictionary) -> Dictionary:
	var ek := str(e.get("kind", ""))
	var ref := str(e.get("ref", ""))
	var mon := str(e.get("monument", "")) if e.get("monument") != null else ""
	var person := str(e.get("person", "")) if e.get("person") != null else ""
	var value := int(e.get("value", 0)) if e.get("value") != null else 0
	var other := int(e.get("other", 0)) if e.get("other") != null else 0
	match ek:
		"games":
			if ref == "munus":
				return {"kind": "munus", "monument": mon if mon != "" else "forum_boarium", "params": {"person": person}}
			if ref == "ludi_megalenses":
				return {}
			var p := {"festival": ref}
			if ref == "ludi_romani":
				p["rows"] = 22
				p["fan_share"] = 0.55
			return {"kind": "race", "monument": mon if mon != "" else "circus_maximus", "params": p}
		"senate":
			return {"kind": "senate", "monument": mon if mon != "" else "curia_hostilia",
				"params": {"vote": {"issue": ref.replace("_", " "), "yes_bp": value, "no_bp": other, "passes": value > other}}}
		"sacrifice":
			return {"kind": "sacrifice", "monument": mon if mon != "" else "aedes_iovis_capitolini",
				"params": {"favourable": true, "label": "The vow kept" if ref == "dedication" else "The vow"}}
		"triumph":
			var spoils: Array = ["captured arms", "pictures of the war"]
			if ref == "capital":
				spoils = ["statues of the taken city", "silver and gold of the taken city", "captured arms", "pictures of the taken city"]
			return {"kind": "triumph", "monument": "", "params": {"general": person, "spoils": spoils}}
	return {}


## Play an engine event on the city (see the header); null if it has no spectacle.
static func play_event(e: Dictionary, urbs: Node3D, extra: Dictionary = {}) -> Node3D:
	var sp := from_event(e)
	if sp.is_empty():
		return null
	var params: Dictionary = (sp["params"] as Dictionary).duplicate()
	params.merge(extra, true)
	return place(str(sp["kind"]), str(sp["monument"]), urbs, params)


## The handler for `--spectacle=race|munus|senate|sacrifice|triumph [--t=seconds] [--at=<monument>]`
## (flags as main.gd passes them to Urbs.open). Places the spectacle on the monument (its bounds
## and entrance from `urbs.monuments`, ground from `urbs.terrain`), plays it, and with --t holds
## it still at that second. Returns the spectacle, or null if the flag is absent.
static func handle_flags(flags: Dictionary, urbs: Node3D) -> Node3D:
	var sp: Node3D
	var extra := {}
	if flags.has("seed"):
		extra["seed"] = int(flags["seed"])
	if flags.has("route-line"):   # F2 play: --route-line draws the triumph's way (renders)
		extra["show_route"] = true
	if flags.has("event"):
		# --event=kind:ref[:monument]: play an engine event as the city would (U8)
		var f := str(flags["event"]).split(":")
		var e := {"kind": f[0], "ref": f[1] if f.size() > 1 else "", "monument": f[2] if f.size() > 2 else null,
			"value": 6400, "other": 3600, "person": "the consul"}
		sp = play_event(e, urbs, extra)
	elif flags.has("spectacle"):
		var kind := str(flags["spectacle"])
		sp = place(kind, str(flags.get("at", DEFAULT_MONUMENT.get(kind, ""))), urbs, extra)
	if sp == null:
		return null
	if flags.has("t"):
		sp.playing = false
		sp.seek(float(flags["t"]))
	return sp


## Place a spectacle of `kind` on monument `id` (its bounds and entrance from `urbs.monuments`,
## ground from `urbs.terrain`) with `params`, and play it. Returns the spectacle.
const FALLBACKS := {
	"senate": ["curia_iulia", "curia_hostilia", "curia_pompeia"],
	"race": ["circus_maximus", "circus_flaminius"],
	"munus": ["forum_boarium", "forum_romanum"],
	"sacrifice": ["aedes_iovis_capitolini"],
}


static func place(kind: String, id: String, urbs: Node3D, params: Dictionary = {}) -> Node3D:
	if not urbs.monuments.ids().has(id):
		# the venue is not standing in this year: the next one of its kind that is
		id = ""
		for alt in FALLBACKS.get(kind, []):
			if urbs.monuments.ids().has(alt):
				id = alt
				break
	var xf := Transform3D()
	var height := func(x: float, z: float) -> float: return urbs.terrain.height_at(x, z)
	if id != "" and urbs.monuments.ids().has(id):
		var box: AABB = urbs.monuments.bounds(id)
		var c := box.get_center()
		var y: float = height.call(c.x, c.z)
		xf = Transform3D(Basis(), Vector3(c.x, y, c.z))
		match kind:
			"race":
				# the track's long axis follows the monument's own bearing when it is known
				var placed: Variant = urbs.monuments.get("_placed")
				if placed is Dictionary and (placed as Dictionary).has(id) and str((placed as Dictionary)[id].get("model", "")) == "circus_maximus":
					# fit the race to the Circus model (monument_forms.gd _circus): a 79 m track
					# between the banks, the metae at z = -163 and +183 from the model's centre
					# (carceres at -L/2, the curved end from L/2 - W/2), so the race's spina is
					# centred 10 m towards the curved end and its turns sit on the metae
					var pl: Dictionary = placed[id]
					var L := float(pl["length"])
					var W := float(pl["width"])
					var yaw := float(pl["yaw"])
					var axis := Vector2(sin(yaw), cos(yaw))
					var zb := minf(180.0, L / 2.0 - W / 2.0 - 70.0)
					var mid := (-160.0 + zb) / 2.0
					var c2: Vector2 = (pl["centre"] as Vector2) + axis * mid
					xf.basis = Basis(Vector3.UP, yaw - PI / 2.0)
					xf.origin = Vector3(c2.x, float(pl["y"]) + 0.1, c2.y)
					var tw := 79.0
					params["width"] = tw
					params["length"] = (zb + 160.0 + 6.0) + tw
					# the stands: the flanks from 30 m inside the carceres to the curved end
					var z0 := -L / 2.0 + 30.0
					var z1 := L / 2.0 - W / 2.0
					params["crowd_half"] = (z1 - z0) / 2.0
					params["crowd_x"] = (z0 + z1) / 2.0 - mid
					# the stone stands of roman.gd _circus_segment (10 kit units, scaled to the 19.5 m
					# banks): a 2 m podium, then ten steps of 1.09 m rising 0.85 m from 42.6 m off
					# the axis. Seated figures have their feet 0.45 m below the step they sit on.
					params["crowd_r0"] = 43.15
					params["crowd_depth"] = 1.09
					params["crowd_rise"] = 0.85
					params["crowd_base"] = 2.85 - 0.45
					params["spacing"] = 1.1
					params["rows"] = 10
				elif placed is Dictionary and (placed as Dictionary).has(id):
					var pl: Dictionary = placed[id]
					xf.basis = Basis(Vector3.UP, float(pl["yaw"]) - PI / 2.0)
					xf.origin = Vector3((pl["centre"] as Vector2).x, float(pl["y"]), (pl["centre"] as Vector2).y)
					params["length"] = float(pl["length"])
					params["width"] = float(pl["width"])
				else:
					if box.size.z > box.size.x:
						xf.basis = Basis(Vector3.UP, PI / 2.0)
					params["length"] = maxf(box.size.x, box.size.z)
					params["width"] = minf(box.size.x, box.size.z)
			"munus":
				params["rx"] = clampf(box.size.x * 0.25, 14.0, 40.0)
				params["rz"] = clampf(box.size.z * 0.18, 10.0, 28.0)
			"sacrifice", "senate":
				var e: Transform3D = urbs.monuments.entrance(id)
				var inward := -e.basis.z
				inward.y = 0.0
				if kind == "sacrifice":
					# F2 play: the altar stands in the open before the temple's steps, clear of the
					# porch roof (the doorway of a deep pronaos, like the Capitoline's, is far back
					# under it): out from the door past the front of the monument's box, then 7 m on.
					# The great altar of Jupiter stood in the Area Capitolina (Platner-Ashby s.v.
					# Area Capitolina, read: "the great altar of Jupiter" among its altars; where in
					# the area it stood is not said, so before the steps is the modeller's choice).
					var outward := -inward.normalized() if inward.length() > 0.01 else Vector3(0, 0, 1)
					var front := 0.0
					for i in 8:
						front = maxf(front, (box.get_endpoint(i) - e.origin).dot(outward))
					var at: Vector3 = e.origin + outward * (front + 7.0)
					xf = Transform3D(Basis.looking_at(inward, Vector3.UP), Vector3(at.x, floor_at(urbs, at.x, at.z), at.z))
				else:
					xf = Transform3D(Basis.looking_at(inward, Vector3.UP), Vector3(c.x, y, c.z))
			"triumph":
				xf = Transform3D()
				params["route"] = triumph_route(urbs, height)
	elif kind == "triumph":
		params["route"] = triumph_route(urbs, height)
	if kind == "triumph":   # F2 play: a walking pace on the long way, and the ground for its cameras
		var r: PackedVector3Array = params["route"]
		var total := 0.0
		for i in range(1, r.size()):
			total += r[i].distance_to(r[i - 1])
		params["march_seconds"] = clampf(total / 6.0, 110.0, 700.0)
		params["height"] = height
		if urbs.has_method("push_out"):
			params["push"] = Callable(urbs, "push_out")
	if kind == "sacrifice" and not params.has("prayer") and id != "":
		# the prayer names the temple's own god (sacrifice.gd prayer_for)
		var mi: Dictionary = urbs.monuments.info(id)
		params["prayer"] = load(PATHS["sacrifice"]).prayer_for(str(mi.get("latin", "")) + " " + str(mi.get("english", "")))
	var sp := play(kind, params, urbs)
	if sp == null:
		return null
	sp.transform = xf
	return sp


## F2 play: the floor a spectacle stands on at (x, z): the ground, or the top of a platform built
## on it (the Area Capitolina's terrace stands above the hill): the highest solid box of a
## monument under the point that is broad (15 m or more) and less than 30 m above the ground (the
## terrace stands up to ~20 m over the modelled hill's slope there), so a statue base does not
## count; the ray starts 31 m up, under any roof.
static func floor_at(urbs: Node3D, x: float, z: float) -> float:
	var y := float(urbs.terrain.height_at(x, z))
	var mon: Variant = urbs.get("monuments")
	var frames: Variant = mon.get("_xf") if mon != null else null
	if not (frames is Dictionary):
		return y
	var best := y
	# the solids, and the open courts and terraces walked on (monuments.gd _opens)
	for table_name in ["_solids", "_opens"]:
		var table: Variant = mon.get(table_name)
		if table is Dictionary:
			best = maxf(best, _top_under(table, frames, x, y, z))
	return best


static func _top_under(table: Dictionary, frames: Dictionary, x: float, y: float, z: float) -> float:
	var best := y
	for id in table:
		if not frames.has(id):
			continue
		var inv: Transform3D = (frames[id] as Transform3D).affine_inverse()
		var o := inv * Vector3(x, y + 31.0, z)
		var d := inv.basis * Vector3.DOWN
		for b in table[id]:
			var box: AABB = b
			if maxf(box.size.x, box.size.z) < 15.0:
				continue
			var hit: Variant = box.intersects_ray(o, d)
			if hit != null:
				var top := ((frames[id] as Transform3D) * (hit as Vector3)).y
				if top > best and top < y + 30.0:
					best = top
	return best


## F2 play: the triumph's way (Platner-Ashby s.v. Porta Triumphalis, read: the general passed
## the gate "at the beginning of his march", a gate or arch in the Campus Martius near the
## Circus Flaminius and the Villa Publica, the accepted view resting on Josephus BJ 7.5.4
## [7.123-157], the one source with topographical indications; Plutarch Aem. 32.1, read: stands
## in the circuses, round the Forum and wherever the procession could be seen). Josephus and
## Plutarch describe later triumphs; the order of places is the standard reconstruction:
##   the Campus Martius at the Villa Publica - the Porta Triumphalis by the Circus Flaminius -
##   through the Circus Flaminius (from 220 BC) - into the city by the Porta Carmentalis (the
##   gate's site is disputed: P-A's first view puts it between the Flumentana and the
##   Carmentalis) - by the Forum Holitorium to the Forum Boarium (the Via Flumentana's line
##   under the Capitol, from the streets data; the Velabrum valley opens beside it) - the length of
##   the Circus Maximus from the carceres to the curved end - north round the Palatine in the
##   valley under the Caelian (the line of the modern Via di San Gregorio, not in the streets
##   data: the modeller's line, kept on the valley floor) - the Sacra Via from the Velia down
##   through the Forum - the Clivus Capitolinus up to the Area Capitolina before Jupiter's temple.
## The Via Flumentana, the Sacra Via and the Clivus Capitolinus follow the streets data; the
## Circus Maximus its own track; the others (the Campus, the valley under the Caelian) run
## between the places' own footprints. Every point lies on the ground (steps of 12 m).
static func triumph_route(urbs: Node3D, height: Callable) -> PackedVector3Array:
	var ids: Array = urbs.monuments.ids()
	var placed: Variant = urbs.monuments.get("_placed")
	var centre := func(id: String) -> Vector2:
		var c: Vector3 = (urbs.monuments.bounds(id) as AABB).get_center()
		return Vector2(c.x, c.z)
	var legs: Array = []   # [Vector2 point, bool keep to the valley floor]
	var add := func(p: Vector2, valley := false) -> void: legs.append([p, valley])
	var streets: Variant = urbs.get("streets")
	var has_street := func(sid: String) -> bool:
		return streets != null and (streets.street_ids() as Array).has(sid)
	# walk a whole street, starting from the end nearer where the procession is (F2 accuracy:
	# the triumph streets via_triumphi_campi and via_inter_palatium_caelium in streets.yaml)
	var follow := func(sid: String, samples: int) -> void:
		var here: Vector2 = legs[legs.size() - 1][0] if not legs.is_empty() else Vector2.ZERO
		var a3: Vector3 = streets.along(sid, 0.0)
		var b3: Vector3 = streets.along(sid, 1.0)
		var forward := legs.is_empty() or Vector2(a3.x, a3.z).distance_to(here) <= Vector2(b3.x, b3.z).distance_to(here)
		for k in samples + 1:
			var t := float(k) / samples
			var q: Vector3 = streets.along(sid, t if forward else 1.0 - t)
			legs.append([Vector2(q.x, q.z), false])
	for id in ["villa_publica", "campus_martius"]:
		if ids.has(id):
			add.call(centre.call(id))
			break
	var campus_street: bool = has_street.call("via_triumphi_campi")
	if campus_street:
		# Villa Publica, past the Circus Flaminius, round the north of the Porticus Octaviae
		follow.call("via_triumphi_campi", 40)
	elif ids.has("circus_flaminius") and placed is Dictionary and (placed as Dictionary).has("circus_flaminius"):
		var pl: Dictionary = placed["circus_flaminius"]
		var ax := Vector2(sin(float(pl["yaw"])), cos(float(pl["yaw"])))
		var c: Vector2 = pl["centre"]
		var half := float(pl["length"]) * 0.5 - 15.0
		# in at the end nearer the Campus, out at the end nearer the city
		var a := c - ax * half
		var b := c + ax * half
		if a.distance_to(Vector2(-381, 78)) < b.distance_to(Vector2(-381, 78)):
			var t := a
			a = b
			b = t
		add.call(a)
		add.call(b)
	if ids.has("porta_carmentalis") and not campus_street:
		add.call(centre.call("porta_carmentalis"))
	# by the Forum Holitorium to the Forum Boarium on the Via Flumentana's streets data (its
	# stretch under the Capitol by the river), so the way keeps to a street, not through houses
	var streets_v: Variant = urbs.get("streets")
	var flum := streets_v != null and (streets_v.street_ids() as Array).has("via_flumentana") and ids.has("forum_boarium")
	if flum:
		var from_p: Vector2 = legs[legs.size() - 1][0] if not legs.is_empty() else Vector2.ZERO
		var to_p: Vector2 = centre.call("forum_boarium")
		var pts: Array[Vector2] = []
		for k in 61:
			var q: Vector3 = streets_v.along("via_flumentana", k / 60.0)
			pts.append(Vector2(q.x, q.z))
		var i0 := 0
		var i1 := 0
		for k in pts.size():
			if pts[k].distance_to(from_p) < pts[i0].distance_to(from_p):
				i0 = k
			if pts[k].distance_to(to_p) < pts[i1].distance_to(to_p):
				i1 = k
		var step := 1 if i1 >= i0 else -1
		var k := i0
		while k != i1 + step:
			add.call(pts[k])
			k += step
		add.call(to_p)
	else:
		for id in ["forum_holitorium", "forum_boarium"]:
			if ids.has(id):
				add.call(centre.call(id))
	if ids.has("circus_maximus") and placed is Dictionary and (placed as Dictionary).has("circus_maximus"):
		var pl: Dictionary = placed["circus_maximus"]
		var ax := Vector2(sin(float(pl["yaw"])), cos(float(pl["yaw"])))
		var side := Vector2(-ax.y, ax.x)
		var c: Vector2 = pl["centre"]
		var half := float(pl["length"]) * 0.5
		var w := float(pl["width"])
		# the carceres at -L/2 (spectacles.gd place: race); along the track beside the spina
		var lane := side * w * 0.2
		if (c - ax * half).distance_to(Vector2(-368, 410)) > (c + ax * half).distance_to(Vector2(-368, 410)):
			ax = -ax
			lane = -lane
		add.call(c - ax * (half - 25.0) + lane)
		add.call(c + ax * (half - w * 0.5 - 10.0) + lane)
		add.call(c + ax * (half - 20.0) + side * w * 0.6 * signf(lane.dot(side) + 0.0001), true)
	# round the Palatine under the Caelian, to the top of the Sacra Via on the Velia
	if has_street.call("via_inter_palatium_caelium"):
		follow.call("via_inter_palatium_caelium", 30)
	else:
		for p in [Vector2(318, 760), Vector2(335, 560), Vector2(342, 380), Vector2(318, 262)]:
			add.call(p, true)
	if has_street.call("via_sacra"):
		for k in 21:
			var q: Vector3 = streets.along("via_sacra", k / 20.0)
			add.call(Vector2(q.x, q.z))
	elif ids.has("forum_romanum"):
		add.call(centre.call("forum_romanum"))
	if has_street.call("clivus_capitolinus"):
		for k in 13:
			var q: Vector3 = streets.along("clivus_capitolinus", k / 12.0)
			add.call(Vector2(q.x, q.z))
	# the end: in the Area Capitolina, 13 m before the steps (the sacrifice is 6 m on, at the
	# altar sacrifice placement uses: 7 m out from the front of the temple's box)
	if ids.has("aedes_iovis_capitolini"):
		var door: Transform3D = urbs.monuments.entrance("aedes_iovis_capitolini")
		var outward := door.basis.z
		outward.y = 0.0
		outward = outward.normalized() if outward.length() > 0.01 else Vector3(0, 0, 1)
		var box: AABB = urbs.monuments.bounds("aedes_iovis_capitolini")
		var front := 0.0
		for i in 8:
			front = maxf(front, (box.get_endpoint(i) - door.origin).dot(outward))
		var end := door.origin + outward * (front + 13.0)
		add.call(Vector2(end.x, end.z))
	# sample every 12 m; on the valley stretches each sample moves to the lowest ground within
	# 30 m across the way, then the line is smoothed so it does not zigzag
	var flat: Array[Vector2] = []
	var vals: Array[bool] = []
	for i in range(legs.size() - 1):
		var a: Vector2 = legs[i][0]
		var b: Vector2 = legs[i + 1][0]
		var valley: bool = legs[i][1] or legs[i + 1][1]
		var n := maxi(1, int(a.distance_to(b) / 12.0))
		var side := (b - a).normalized()
		side = Vector2(-side.y, side.x)
		for k in n:
			var p := a.lerp(b, float(k) / n)
			if valley:
				var best := p
				var lo := float(height.call(p.x, p.y))
				for off in [-30.0, -20.0, -10.0, 10.0, 20.0, 30.0]:
					var q: Vector2 = p + side * off
					var hq := float(height.call(q.x, q.y))
					if hq < lo - 0.5:
						lo = hq
						best = q
				p = best
			flat.append(p)
			vals.append(valley)
	if not legs.is_empty():
		flat.append(legs[legs.size() - 1][0])
		vals.append(false)
	for round_i in 3:
		var smoothed := flat.duplicate()
		for i in range(1, flat.size() - 1):
			if vals[i]:
				smoothed[i] = (flat[i - 1] + flat[i] * 2.0 + flat[i + 1]) * 0.25
		flat = smoothed
	var out := PackedVector3Array()
	var last: Vector2 = flat[flat.size() - 1] if not flat.is_empty() else Vector2.ZERO
	for p in flat:
		# the last stretch is on the Area Capitolina's terrace, above the hill's ground
		var y := floor_at(urbs, p.x, p.y) if p.distance_to(last) < 70.0 else float(height.call(p.x, p.y))
		out.append(Vector3(p.x, y, p.y))
	return out
