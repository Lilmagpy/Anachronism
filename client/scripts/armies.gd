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


## A fleet (D-107): one to three oared warships under sails in the owner's colours, facing
## `facing` (radians); `hulls` grows with the number of ships.
static func make_fleet(colour: Color, facing: float, hulls: int) -> Node3D:
	var fleet := Node3D.new()
	fleet.rotation.y = facing
	var wood := _material(Color(0.42, 0.27, 0.14))
	var dark := _material(Color(0.28, 0.18, 0.1))
	var sailcloth := _material(colour.lightened(0.15))
	var hull := BoxMesh.new()
	hull.size = Vector3(0.22, 0.14, 0.9) * S
	var prow := BoxMesh.new()
	prow.size = Vector3(0.16, 0.14, 0.16) * S
	var stern := BoxMesh.new()
	stern.size = Vector3(0.18, 0.12, 0.14) * S
	var mast := CylinderMesh.new()
	mast.top_radius = 0.012 * S
	mast.bottom_radius = 0.016 * S
	mast.height = 0.75 * S
	var sail := BoxMesh.new()
	sail.size = Vector3(0.5, 0.36, 0.025) * S
	var oar := BoxMesh.new()
	oar.size = Vector3(0.26, 0.012, 0.02) * S
	var spots: Array[Vector3] = [Vector3.ZERO, Vector3(-0.42, 0, 0.55), Vector3(0.42, 0, 0.55)]
	for h in clampi(hulls, 1, 3):
		var at := spots[h] * S
		_part(fleet, hull, wood, at + Vector3(0, 0.05 * S, 0))
		var bow := _part(fleet, prow, wood, at + Vector3(0, 0.07 * S, -0.48 * S))
		bow.rotation.y = PI / 4.0
		_part(fleet, stern, dark, at + Vector3(0, 0.16 * S, 0.42 * S))
		_part(fleet, mast, dark, at + Vector3(0, 0.45 * S, -0.05 * S))
		_part(fleet, sail, sailcloth, at + Vector3(0, 0.52 * S, -0.03 * S))
		for k in 5:
			for side in [-1.0, 1.0]:
				var stroke := _part(fleet, oar, dark, at + Vector3(side * 0.2 * S, 0.03 * S, (k - 2) * 0.14 * S))
				stroke.rotation.z = side * 0.35
	for child in fleet.get_children():
		(child as GeometryInstance3D).visibility_range_end = SHOW_WITHIN
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return fleet


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
