## The Urbs scene's adapter (U5): `build(urbs, id, year)` gives the interior of monument `id`
## as it stood in `year`, in world coordinates, as a node with `spawn() -> Transform3D`.
## The builders are in scripts/models/roman_interiors.gd (RomanInteriors) and the placement
## helpers in scripts/urbs/interiors.gd (UrbsInteriors). Urbs hides the city and the sun while
## inside, so the interior lights itself: openings, lamps, braziers.
##
## The interior is placed at the monument's coordinates and turned so that its door (local +z)
## is on the side `urbs.monuments.entrance(id)` puts the visitor's glide.
class_name UrbsInterior
extends RefCounted

const Interiors := preload("res://scripts/urbs/interiors.gd")
const Roman := preload("res://scripts/models/roman_interiors.gd")

static var _records: Dictionary = {}


## The node the scene adds; has `spawn()`, `seat(section)`, `anchor(name)`, `set_cutaway(on)`.
func build(urbs: Node3D, id: String, year: int) -> Node3D:
	var m := _record(urbs, id)
	if m.is_empty():
		push_warning("UrbsInterior: unknown monument %s" % id)
		return null
	var p := UrbsGeo.to_local(float(m.get("lat", UrbsGeo.ORIGIN_LAT)), float(m.get("lon", UrbsGeo.ORIGIN_LON)))
	var y := float(m.get("floor_y", 10.0))
	if urbs != null and urbs.has_method("height_at"):
		y = float(urbs.call("height_at", p.x, p.y))
	var yaw := UrbsGeo.yaw_from_bearing(float(m.get("bearing", 180.0)))
	if urbs != null and urbs.get("monuments") != null and urbs.monuments.has_method("entrance"):
		var door: Transform3D = urbs.monuments.entrance(id)
		var out := door.basis.z
		yaw = atan2(out.x, out.z)
	# F3 monuments: the inside is as big as the building drawn outside (every temple without a
	# size in its record had the same default inside, whatever its footprint)
	if urbs != null and urbs.get("monuments") != null and not m.has("size"):
		var pl: Dictionary = urbs.monuments._placed.get(id, {})
		var hf: Vector2 = pl.get("half", Vector2.ZERO)
		if hf.x >= 4.0 and hf.y >= 5.0:   # a shrine smaller than this keeps the walk-in default
			m = m.duplicate()
			m["size"] = [hf.y * 2.0, hf.x * 2.0]
	var node := Interiors.build_node(m, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.y)), year)
	if node == null:
		return null
	node.name = "Interior_" + id
	var holder := Holder.new()
	holder.name = node.name
	holder.xf = node.transform
	holder.result = node.get_meta("result")
	holder.kind = str(Interiors.kind_of(m)[0])   # F2 play: where its action panel stands
	node.transform = Transform3D.IDENTITY
	holder.transform = holder.xf
	for c in node.get_children():
		node.remove_child(c)
		holder.add_child(c)
	node.free()
	return holder


func _record(urbs: Node3D, id: String) -> Dictionary:
	if urbs != null and urbs.get("monuments") != null and urbs.monuments.has_method("entry"):
		var e: Variant = urbs.monuments.entry(id)
		if e is Dictionary and not (e as Dictionary).is_empty():
			return e
	if _records.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/city/monuments.json"))
		if parsed is Dictionary:
			for r in parsed["monuments"]:
				_records[str(r["id"])] = r
	return _records.get(id, {})


## The visitor's node: remembers the build result for spawn, seats and anchors.
class Holder extends Node3D:
	var xf := Transform3D.IDENTITY
	var result: Dictionary = {}
	var kind := ""   # F2 play: the interior kind (interiors.gd kind_of)

	## Where the camera starts (world).
	func spawn() -> Transform3D:
		return xf * (result["spawn"] as Transform3D)

	## Camera transform for a seat section (circus: carceres, finish, pulvinar...).
	func seat(section: String) -> Transform3D:
		var seats: Dictionary = result.get("seats", {})
		return xf * (seats.get(section, result["spawn"]) as Transform3D)

	func seat_names() -> Array:
		return (result.get("seats", {}) as Dictionary).keys()

	## A named place (altar, statue, tribunal, door...) in world space.
	func anchor(anchor_name: String) -> Vector3:
		var a: Dictionary = result.get("anchors", {})
		return xf * (a[anchor_name] as Vector3) if a.has(anchor_name) else xf.origin

	## True for interiors under the open sky (circus, arena, theatre): the scene may keep its sky.
	func open_sky() -> bool:
		return bool(result.get("open_sky", false))

	func set_cutaway(on: bool) -> void:
		if has_node("Cover"):
			(get_node("Cover") as Node3D).visible = not on

	func notes() -> Array:
		return result.get("notes", [])

	# --- F2 play (begin): the spot where the place's action panel stands -----------------------
	## The world point of the action panel inside: the Curia's floor before the tribunal, the
	## temple's altar, the Circus' magistrates' box (pulvinar), the Rostra in the Forum, the
	## domus' tablinum, a basilica's tribunal; else a few metres ahead of where you come in.
	## `spot` overrides the kind's default (a name of UrbsPlaces.SPOTS).
	func action_spot(spot := "") -> Vector3:
		var a: Dictionary = result.get("anchors", {})
		var seats: Dictionary = result.get("seats", {})
		var want := spot if spot != "" else str(UrbsPlaces.SPOTS.get(kind, ""))
		match want:
			"floor":
				if a.has("tribunal") and a.has("door"):
					var t: Vector3 = a["tribunal"]
					var d: Vector3 = a["door"]
					var p := t.lerp(d, 0.3)
					return xf * Vector3(p.x, d.y + 1.3, p.z)
			"pulvinar":
				if seats.has("pulvinar"):
					return xf * ((seats["pulvinar"] as Transform3D).origin + Vector3(0, -0.4, 0))
			"altar":
				if a.has("altar"):
					return xf * ((a["altar"] as Vector3) + Vector3(0, 0.6, 0))
			_:
				if want != "" and a.has(want):
					return xf * ((a[want] as Vector3) + Vector3(0, 1.2, 0))
		var s: Transform3D = result.get("spawn", Transform3D.IDENTITY)
		return xf * (s.origin - s.basis.z * 5.0)
	# --- F2 play (end) -----------------------------------------------------------------------
