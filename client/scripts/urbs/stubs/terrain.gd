## STUB (Urbs U4): flat ground at y = 10 so the city scene runs before the real terrain
## lands. The real class replaces this file and keeps the same names (see urbs.gd header).
class_name UrbsTerrain
extends RefCounted

const FLOOR_Y := 10.0
var _mat := StandardMaterial3D.new()


func _init() -> void:
	_mat.albedo_color = Color(0.46, 0.42, 0.30)
	_mat.roughness = 1.0


## Whole-scene parts (river, sea, walls). The stub has none.
func build(_urbs: Node3D) -> void:
	pass


## Ground height at local (x, z), metres.
func height_at(_x: float, _z: float) -> float:
	return FLOOR_Y


## One ground chunk covering `rect` (local x, z metres); `lod` 0 = best, 2 = coarsest.
func build_chunk(rect: Rect2, _lod: int) -> Node3D:
	var node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = rect.size
	node.mesh = plane
	node.material_override = _mat
	node.position = Vector3(rect.get_center().x, FLOOR_Y, rect.get_center().y)
	return node
