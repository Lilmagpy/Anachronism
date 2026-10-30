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
##   triumph / battle | capital        triumph     the route Campus Martius - Circus Maximus -
##                                                 Via Sacra - Capitol (triumph_route)
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
					# the altar stands before the doorway; local -z points into the temple
					var at: Vector3 = e.origin - inward * 12.0
					xf = Transform3D(Basis.looking_at(inward, Vector3.UP), Vector3(at.x, height.call(at.x, at.z), at.z))
				else:
					xf = Transform3D(Basis.looking_at(inward, Vector3.UP), Vector3(c.x, y, c.z))
			"triumph":
				xf = Transform3D()
				params["route"] = triumph_route(urbs, height)
	elif kind == "triumph":
		params["route"] = triumph_route(urbs, height)
	var sp := play(kind, params, urbs)
	if sp == null:
		return null
	sp.transform = xf
	return sp


## The triumph's way through the dataset: Campus Martius, the Forum, the Via Sacra, the Capitol,
## as a polyline in local metres with the ground height under each point (steps of 15 m).
static func triumph_route(urbs: Node3D, height: Callable) -> PackedVector3Array:
	var ids := ["campus_martius", "circus_flaminius", "circus_maximus", "via_sacra", "forum_romanum", "aedes_iovis_capitolini"]
	var pts: Array[Vector2] = []
	for id in ids:
		if urbs.monuments.ids().has(id):
			var c: Vector3 = (urbs.monuments.bounds(id) as AABB).get_center()
			pts.append(Vector2(c.x, c.z))
	var out := PackedVector3Array()
	for i in range(pts.size() - 1):
		var n := maxi(1, int(pts[i].distance_to(pts[i + 1]) / 15.0))
		for k in n:
			var p := pts[i].lerp(pts[i + 1], float(k) / n)
			out.append(Vector3(p.x, height.call(p.x, p.y), p.y))
	if pts.size() > 0:
		var q: Vector2 = pts[pts.size() - 1]
		out.append(Vector3(q.x, height.call(q.x, q.y), q.y))
	return out
