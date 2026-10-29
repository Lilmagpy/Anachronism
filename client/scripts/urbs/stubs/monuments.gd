## STUB (Urbs U4): every monument of the year as a plain box at its coordinates, read from
## client/data/city/monuments.json, with `info`, `bounds` and `entrance`. The real class
## replaces this file and keeps the interface (see urbs.gd header).
class_name UrbsMonuments
extends RefCounted

var _data: Dictionary = {}     ## id -> monument dictionary
var _bounds: Dictionary = {}   ## id -> AABB in local metres
var _height: Callable


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/city/monuments.json"))
	if parsed is Dictionary:
		for m in parsed["monuments"]:
			_data[str(m["id"])] = m


## Builds the monuments standing in `year` under `urbs`. `height` is (x, z) -> y.
func build(urbs: Node3D, year: int, height: Callable) -> void:
	_height = height
	_bounds.clear()
	var root := Node3D.new()
	root.name = "Monuments"
	urbs.add_child(root)
	var ids := _data.keys()
	ids.sort()
	for id in ids:
		var m: Dictionary = _data[id]
		var built: Variant = m.get("built")
		if built == null or built.get("year") == null or int(built["year"]) > year:
			continue
		var p := UrbsGeo.to_local(float(m["lat"]), float(m["lon"]))
		var size := _size_for(str(m.get("type", "")))
		var y: float = height.call(p.x, p.y)
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		box.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.86, 0.82, 0.72)
		box.material_override = mat
		box.position = Vector3(p.x, y + size.y / 2.0, p.y)
		root.add_child(box)
		_bounds[id] = AABB(box.position - size / 2.0, size)


func _size_for(kind: String) -> Vector3:
	match kind:
		"temple": return Vector3(20, 14, 32)
		"basilica": return Vector3(30, 18, 70)
		"circus": return Vector3(120, 20, 400)
		"theatre", "amphitheatre": return Vector3(100, 30, 100)
		"wall", "gate": return Vector3(10, 12, 10)
	return Vector3(16, 10, 16)


## Ids of the monuments standing now.
func ids() -> Array:
	return _bounds.keys()


## Where the monument stands, local metres.
func bounds(id: String) -> AABB:
	return _bounds.get(id, AABB())


## Card text: latin, english, date (human text), builder, form, sources (Array of String).
func info(id: String) -> Dictionary:
	var m: Dictionary = _data.get(id, {})
	if m.is_empty():
		return {}
	var built: Dictionary = m.get("built", {})
	return {"id": id, "latin": str(m.get("latin", "")), "english": str(m.get("english", id)),
		"year": int(built.get("year", 0)), "by": str(built.get("by", "")),
		"form": str(m.get("form", "")), "sources": m.get("sources", []),
		"enterable": true}


## A transform at the door looking inwards (local metres).
func entrance(id: String) -> Transform3D:
	var b := bounds(id)
	var door := Vector3(b.get_center().x, b.position.y + 1.7, b.end.z + 2.0)
	return Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), door)
