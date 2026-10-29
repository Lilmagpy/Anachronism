## Entry point of the spectacles (U6): UrbsSpectacles.play(kind, params, parent) -> Node3D.
## kind is "race", "munus", "senate", "sacrifice" or "triumph"; params are the engine's view of
## the event plus the venue's geometry (see each script's header). The returned node is a
## spectacle (base.gd): it plays by itself in _process, can be seeked (seek(t)), exposes
## seat_views() camera presets and emits `finished`. stop() frees the current one.
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


## The handler for `--spectacle=race|munus|senate|sacrifice|triumph [--t=seconds] [--at=<monument>]`
## (flags as main.gd passes them to Urbs.open). Places the spectacle on the monument (its bounds
## and entrance from `urbs.monuments`, ground from `urbs.terrain`), plays it, and with --t holds
## it still at that second. Returns the spectacle, or null if the flag is absent.
static func handle_flags(flags: Dictionary, urbs: Node3D) -> Node3D:
	if not flags.has("spectacle"):
		return null
	var kind := str(flags["spectacle"])
	var id := str(flags.get("at", DEFAULT_MONUMENT.get(kind, "")))
	if not urbs.monuments.ids().has(id):
		id = str(DEFAULT_MONUMENT.get(kind, ""))
	var params := {}
	var xf := Transform3D()
	var height := func(x: float, z: float) -> float: return urbs.terrain.height_at(x, z)
	if id != "" and urbs.monuments.ids().has(id):
		var box: AABB = urbs.monuments.bounds(id)
		var c := box.get_center()
		var y: float = height.call(c.x, c.z)
		xf = Transform3D(Basis(), Vector3(c.x, y, c.z))
		match kind:
			"race":
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
	if flags.has("seed"):
		params["seed"] = int(flags["seed"])
	var sp := play(kind, params, urbs)
	if sp == null:
		return null
	sp.transform = xf
	if flags.has("t"):
		sp.playing = false
		sp.seek(float(flags["t"]))
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
