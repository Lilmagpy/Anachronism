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
	var node := Interiors.build_node(m, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.y)), year)
	if node == null:
		return null
	node.name = "Interior_" + id
	var holder := Holder.new()
	holder.name = node.name
	holder.xf = node.transform
	holder.result = node.get_meta("result")
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
