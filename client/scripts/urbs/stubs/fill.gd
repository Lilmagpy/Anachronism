## STUB (Urbs U4): scattered boxes standing for houses, ~90 a chunk, as one MultiMesh per
## chunk, so the chunk loader and the 10k-buildings budget can be tested. The real class
## replaces this file.
class_name UrbsFill
extends RefCounted

var year := -300


func build(_urbs: Node3D, new_year: int, _height: Callable) -> void:
	year = new_year


## Houses for the chunk `rect`; `lod` 0 = best, 2 = coarsest (fewer, merged).
func build_chunk(rect: Rect2, lod: int, height: Callable) -> Node3D:
	var count := 90 if lod < 2 else 30
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	var seed_value := int(rect.position.x * 73856093) ^ int(rect.position.y * 19349663)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value)
	for i in count:
		var p := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		var w := rng.randf_range(8.0, 16.0)
		var d := rng.randf_range(8.0, 16.0)
		var h := rng.randf_range(5.0, 16.0)
		var y: float = height.call(p.x, p.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, h, d))
		multi.set_instance_transform(i, Transform3D(basis, Vector3(p.x, y + h / 2.0, p.y)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.52, 0.38)
	mat.roughness = 1.0
	node.material_override = mat
	return node
