## STUB (Urbs U4): an empty lit hall. The interiors agent's class replaces this file.
class_name UrbsInterior
extends RefCounted


## The interior of monument `id` as it stood in `year`. The returned node may define
## `spawn() -> Transform3D` (where the visitor starts); otherwise the camera starts at 1.7 m
## above the origin facing -z.
func build(_urbs: Node3D, id: String, _year: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Interior_" + id
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 60)
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)
	for i in 6:
		var column := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.6
		cyl.bottom_radius = 0.7
		cyl.height = 9.0
		column.mesh = cyl
		column.position = Vector3(-8 if i % 2 == 0 else 8, 4.5, -20.0 + (i / 2) * 15.0)
		root.add_child(column)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 8, 0)
	lamp.omni_range = 40.0
	lamp.light_energy = 2.0
	root.add_child(lamp)
	return root
