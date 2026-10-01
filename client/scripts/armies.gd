## Armies on the map (brief §5.8): where two states are at war, a little army in each
## side's colours stands on each side of the border, under its banner, with crossed swords
## between them. Built from simple shapes, like the settlements (D-058).
class_name Armies
extends RefCounted

const S := 8.0
const SHOW_WITHIN := 1400.0


## One army (G1): a commander on horseback under a tall banner at the front, and ranks of
## soldiers behind with shields and tunics in the owner's colour, spears raised; a siege
## train brings a trebuchet. Faces `facing` (radians).
static func make(colour: Color, facing: float, siege := false) -> Node3D:
	var army := Node3D.new()
	army.rotation.y = facing
	var coat := _material(colour)
	var trim := _material(colour.lightened(0.35))
	var skin := _material(Color(0.93, 0.76, 0.6))
	var steel := _material(Color(0.78, 0.79, 0.82))
	var wood := _material(Color(0.45, 0.3, 0.15))
	var horse := _material(Color(0.42, 0.28, 0.18))
	var dark := _material(Color(0.22, 0.18, 0.16))
	var body := BoxMesh.new()
	body.size = Vector3(0.11, 0.17, 0.08) * S
	var legs := BoxMesh.new()
	legs.size = Vector3(0.1, 0.1, 0.07) * S
	var head := SphereMesh.new()
	head.radius = 0.045 * S
	head.height = 0.09 * S
	var helmet := SphereMesh.new()
	helmet.radius = 0.05 * S
	helmet.height = 0.05 * S
	helmet.is_hemisphere = true
	var shield := CylinderMesh.new()
	shield.top_radius = 0.065 * S
	shield.bottom_radius = 0.065 * S
	shield.height = 0.015 * S
	shield.radial_segments = 10
	var boss := SphereMesh.new()
	boss.radius = 0.02 * S
	boss.height = 0.02 * S
	var spear := CylinderMesh.new()
	spear.top_radius = 0.006 * S
	spear.bottom_radius = 0.006 * S
	spear.height = 0.5 * S
	spear.radial_segments = 4
	# three ranks of five
	for row in 3:
		for k in 5:
			var x := (k - 2.0) * 0.16 * S + (0.05 * S if row % 2 == 1 else 0.0)
			var z := 0.12 * S + row * 0.17 * S
			_part(army, legs, dark, Vector3(x, 0.05 * S, z))
			_part(army, body, coat, Vector3(x, 0.185 * S, z))
			_part(army, head, skin, Vector3(x, 0.315 * S, z))
			_part(army, helmet, steel, Vector3(x, 0.33 * S, z))
			var guard := _part(army, shield, coat, Vector3(x - 0.055 * S, 0.19 * S, z - 0.035 * S))
			guard.rotation.x = PI / 2.0
			_part(army, boss, trim, Vector3(x - 0.055 * S, 0.19 * S, z - 0.045 * S))
			_part(army, spear, wood, Vector3(x + 0.06 * S, 0.3 * S, z))
			_part(army, _cone(0.014 * S, 0.05 * S), steel, Vector3(x + 0.06 * S, 0.57 * S, z))
	# the commander on horseback
	var barrel := BoxMesh.new()
	barrel.size = Vector3(0.11, 0.11, 0.28) * S
	var leg := BoxMesh.new()
	leg.size = Vector3(0.03, 0.14, 0.03) * S
	var neck := BoxMesh.new()
	neck.size = Vector3(0.06, 0.14, 0.06) * S
	var muzzle := BoxMesh.new()
	muzzle.size = Vector3(0.06, 0.06, 0.12) * S
	var cz := -0.22 * S
	_part(army, barrel, horse, Vector3(0, 0.2 * S, cz))
	for lx in [-0.04, 0.04]:
		for lz in [-0.1, 0.1]:
			_part(army, leg, horse, Vector3(lx * S, 0.07 * S, cz + lz * S))
	var n := _part(army, neck, horse, Vector3(0, 0.3 * S, cz - 0.13 * S))
	n.rotation.x = 0.5
	_part(army, muzzle, horse, Vector3(0, 0.37 * S, cz - 0.19 * S))
	_part(army, body, coat, Vector3(0, 0.34 * S, cz))
	_part(army, head, skin, Vector3(0, 0.47 * S, cz))
	_part(army, helmet, trim, Vector3(0, 0.49 * S, cz))
	var cape := BoxMesh.new()
	cape.size = Vector3(0.12, 0.16, 0.02) * S
	var c := _part(army, cape, trim, Vector3(0, 0.33 * S, cz + 0.06 * S))
	c.rotation.x = -0.3
	# the standard: a tall pole and a long banner in the owner's colours
	var pole := CylinderMesh.new()
	pole.top_radius = 0.012 * S
	pole.bottom_radius = 0.012 * S
	pole.height = 1.1 * S
	_part(army, pole, wood, Vector3(0.12 * S, 0.55 * S, cz))
	var banner := BoxMesh.new()
	banner.size = Vector3(0.3, 0.42, 0.015) * S
	_part(army, banner, coat, Vector3(0.28 * S, 0.86 * S, cz))
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.3, 0.05, 0.02) * S
	_part(army, stripe, trim, Vector3(0.28 * S, 0.72 * S, cz))
	_part(army, _cone(0.03 * S, 0.08 * S), _material(Color(0.95, 0.8, 0.3)), Vector3(0.12 * S, 1.14 * S, cz))
	if siege:
		var engine := MeshInstance3D.new()
		engine.mesh = KenneyKit.mesh("castle/siege-trebuchet", 0.75 * S, "accents")
		engine.position = Vector3(0.62 * S, 0, 0.3 * S)
		army.add_child(engine)
	for child in army.get_children():
		(child as GeometryInstance3D).visibility_range_end = SHOW_WITHIN
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return army


## A fleet (D-107, G1): one to three sailing warships (Kenney pirate kit, CC0) with their
## flags in the owner's colours, facing `facing` (radians); `hulls` grows with the ships.
static func make_fleet(colour: Color, facing: float, hulls: int) -> Node3D:
	var fleet := Node3D.new()
	fleet.rotation.y = facing
	var spots: Array[Vector3] = [Vector3.ZERO, Vector3(-0.55, 0, 0.7), Vector3(0.55, 0, 0.7)]
	for h in clampi(hulls, 1, 3):
		var ship := MeshInstance3D.new()
		ship.mesh = KenneyKit.mesh("pirate/ship-large" if h == 0 else "pirate/ship-medium", (0.9 if h == 0 else 0.7) * S, "accents")
		ship.position = spots[h] * S
		ship.rotation.y = PI   # the models face +z
		fleet.add_child(ship)
		var flag := MeshInstance3D.new()
		var cloth := BoxMesh.new()
		cloth.size = Vector3(0.22, 0.14, 0.01) * S
		flag.mesh = cloth
		flag.material_override = _material(colour)
		flag.position = spots[h] * S + Vector3(0.11 * S, (0.98 if h == 0 else 0.78) * S, 0)
		fleet.add_child(flag)
	for child in fleet.get_children():
		(child as GeometryInstance3D).visibility_range_end = SHOW_WITHIN
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
