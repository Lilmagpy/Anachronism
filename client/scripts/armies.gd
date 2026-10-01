## Armies on the map (brief §5.8): where two states are at war, a little army in each
## side's colours stands on each side of the border, under its banner, with crossed swords
## between them. Built from simple shapes, like the settlements (D-058).
class_name Armies
extends RefCounted

const S := 8.0
const SHOW_WITHIN := 1400.0


## One army: a block of soldiers with spears around a banner, facing `facing` (radians).
static func make(colour: Color, facing: float) -> Node3D:
	var army := Node3D.new()
	army.rotation.y = facing
	var coat := _material(colour)
	var skin := _material(Color(0.9, 0.75, 0.6))
	var steel := _material(Color(0.75, 0.75, 0.78))
	var wood := _material(Color(0.45, 0.3, 0.15))
	var body := CapsuleMesh.new()
	body.radius = 0.07 * S
	body.height = 0.3 * S
	var head := SphereMesh.new()
	head.radius = 0.06 * S
	head.height = 0.12 * S
	var spear := CylinderMesh.new()
	spear.top_radius = 0.008 * S
	spear.bottom_radius = 0.008 * S
	spear.height = 0.55 * S
	for row in 2:
		for k in 4:
			var x := (k - 1.5) * 0.2 * S
			var z := (row - 0.5) * 0.22 * S
			_part(army, body, coat, Vector3(x, 0.15 * S, z))
			_part(army, head, skin, Vector3(x, 0.36 * S, z))
			var shaft := _part(army, spear, wood, Vector3(x + 0.08 * S, 0.3 * S, z))
			shaft.rotation.x = -0.25
			_part(army, _cone(0.02 * S, 0.07 * S), steel, Vector3(x + 0.08 * S, 0.6 * S, z - 0.07 * S))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.012 * S
	pole.bottom_radius = 0.012 * S
	pole.height = 0.9 * S
	_part(army, pole, wood, Vector3(0, 0.45 * S, -0.35 * S))
	var flag := BoxMesh.new()
	flag.size = Vector3(0.36, 0.22, 0.02) * S
	_part(army, flag, coat, Vector3(0.18 * S, 0.78 * S, -0.35 * S))
	for child in army.get_children():
		(child as GeometryInstance3D).visibility_range_end = SHOW_WITHIN
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return army


static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	return material


static func _cone(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh


static func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	parent.add_child(part)
	return part
