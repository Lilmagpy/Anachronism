## Your ideas made visible: around your capital, a landmark appears for each advancement
## your state has adopted - an aqueduct striding over the fields, a windmill, a water wheel,
## an observatory, a school hall, smoking forges. Zoom in on the capital (or click your
## emblem in the top bar) to see what your ideas have built.
##
## Built from simple shapes in the owner's colours, so any civilisation's adoptions show
## without new art; real models can replace them later (D-051).
class_name Landmarks
extends Node3D

const S := Settlements.S
const SHOW_WITHIN := 320.0
## advancement -> landmark; the first one a state adopts in each pair of lines claims a spot
const KINDS := {
	"aqueduct": "aqueduct", "concrete": "aqueduct",
	"windmill": "windmill",
	"water_wheel": "water_wheel",
	"astronomy_calendar": "observatory",
	"schools": "school", "civil_service": "school",
	"paper": "workshop", "woodblock_printing": "workshop", "movable_type": "press",
	"iron_working": "forge", "blast_furnace": "furnace", "crucible_steel": "furnace", "coal_mining": "furnace",
	"fortification": "watchtower",
	"canals": "canal", "irrigation": "canal",
	"roads": "milestone", "postal_relay": "milestone",
	"coinage": "mint", "paper_money": "mint",
	"pottery_kiln": "kiln",
	"gunpowder": "powder_tower",
	"sailing": "harbour", "compass": "harbour", "sternpost_rudder": "harbour",
}

var map: ProvinceMap
var earth: EarthBuilder
var _built := {}   ## kind -> true


func setup(province_map: ProvinceMap) -> void:
	map = province_map
	earth = province_map.earth
	name = "Landmarks"


## Rebuild for the player's adopted ideas (cheap: a handful of shapes).
func update(view: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_built.clear()
	var capital: Dictionary = {}
	for site in map.sites:
		if site["owner"] == view["player"] and site["capital"]:
			capital = site
	if capital.is_empty():
		return
	var colour := Color(map.civ_colours.get(view["player"], Color(0.6, 0.2, 0.15)))
	var kinds: Array[String] = []
	for idea in view["ideas"]:
		if idea["stage"] in ["adopted", "widespread"] and KINDS.has(idea["id"]):
			var kind: String = KINDS[idea["id"]]
			if not kind in kinds:
				kinds.append(kind)
	kinds.sort()
	var centre: Vector2 = capital["pixel"]
	for i in kinds.size():
		var angle := TAU * i / maxf(kinds.size(), 1.0) + 0.4
		var radius := (2.6 + (i % 2) * 0.9) * S
		var spot := centre + Vector2(cos(angle), sin(angle)) * radius
		var piece := _make(kinds[i], colour, spot, centre)
		if piece != null:
			add_child(piece)


func _make(kind: String, colour: Color, spot: Vector2, centre: Vector2) -> Node3D:
	var node := Node3D.new()
	node.name = kind
	node.position = earth.ground_at_pixel(spot)
	var stone := Color(0.80, 0.76, 0.66)
	var wood := Color(0.50, 0.33, 0.18)
	var roof := colour.darkened(0.25)
	match kind:
		"aqueduct":
			# a line of arches from the hills into the city
			var dir := (centre - spot).normalized()
			node.rotation.y = -dir.angle()
			for k in 6:
				_box(node, Vector3(k * 0.32 * S, 0.22 * S, 0), Vector3(0.08, 0.44, 0.12) * S, stone)
			_box(node, Vector3(0.8 * S, 0.47 * S, 0), Vector3(1.9, 0.07, 0.14) * S, stone.darkened(0.1))
		"windmill":
			_cylinder(node, Vector3(0, 0.3 * S, 0), 0.12 * S, 0.6 * S, stone)
			_cone(node, Vector3(0, 0.66 * S, 0), 0.15 * S, 0.14 * S, roof)
			for k in 4:
				var sail := _box(node, Vector3(0, 0.55 * S, 0.14 * S), Vector3(0.05, 0.42, 0.01) * S, Color(0.95, 0.92, 0.85))
				sail.rotation.z = k * PI / 2.0
				sail.position += Vector3(sin(k * PI / 2.0), cos(k * PI / 2.0), 0) * 0.2 * S
		"water_wheel":
			_box(node, Vector3(0, 0.14 * S, 0), Vector3(0.3, 0.28, 0.24) * S, wood)
			_cone(node, Vector3(0, 0.34 * S, 0), 0.24 * S, 0.12 * S, roof)
			var wheel := _cylinder(node, Vector3(0.2 * S, 0.16 * S, 0), 0.16 * S, 0.05 * S, wood.darkened(0.2))
			wheel.rotation.x = PI / 2.0
		"observatory":
			for k in 3:
				_box(node, Vector3(0, (0.1 + k * 0.18) * S, 0), Vector3(0.5 - k * 0.13, 0.18, 0.5 - k * 0.13) * S, stone.darkened(k * 0.05))
			_sphere(node, Vector3(0, 0.62 * S, 0), 0.08 * S, Color(0.95, 0.8, 0.3))
		"school":
			_box(node, Vector3(0, 0.12 * S, 0), Vector3(0.6, 0.24, 0.34) * S, Color(0.93, 0.88, 0.76))
			_prism(node, Vector3(0, 0.32 * S, 0), Vector3(0.7, 0.16, 0.42) * S, roof)
		"workshop", "press", "kiln", "mint":
			_box(node, Vector3(0, 0.1 * S, 0), Vector3(0.4, 0.2, 0.3) * S, Color(0.86, 0.78, 0.62))
			_prism(node, Vector3(0, 0.26 * S, 0), Vector3(0.48, 0.12, 0.36) * S, roof)
			_cylinder(node, Vector3(0.12 * S, 0.34 * S, 0), 0.04 * S, 0.3 * S, stone.darkened(0.3))
			if kind == "mint":
				_sphere(node, Vector3(-0.1 * S, 0.4 * S, 0), 0.07 * S, Color(0.98, 0.78, 0.25))
		"forge", "furnace":
			_cylinder(node, Vector3(0, 0.2 * S, 0), 0.16 * S, 0.4 * S, Color(0.35, 0.30, 0.28))
			_sphere(node, Vector3(0, 0.46 * S, 0), 0.1 * S, Color(1.0, 0.55, 0.15))   # glow
			_sphere(node, Vector3(0.05 * S, 0.75 * S, 0), 0.14 * S, Color(0.55, 0.55, 0.55, 0.8))   # smoke
		"watchtower", "powder_tower":
			_box(node, Vector3(0, 0.3 * S, 0), Vector3(0.18, 0.6, 0.18) * S, stone.darkened(0.1))
			_cone(node, Vector3(0, 0.68 * S, 0), 0.16 * S, 0.16 * S, roof)
		"canal":
			var dir := (centre - spot).normalized()
			node.rotation.y = -dir.angle()
			_box(node, Vector3(0.6 * S, 0.01 * S, 0), Vector3(1.4, 0.02, 0.12) * S, Color(0.25, 0.55, 0.85))
		"milestone":
			_box(node, Vector3(0, 0.08 * S, 0), Vector3(0.08, 0.16, 0.08) * S, stone)
			_box(node, Vector3(0.3 * S, 0.12 * S, 0), Vector3(0.16, 0.24, 0.12) * S, roof)
		"harbour":
			_box(node, Vector3(0, 0.03 * S, 0), Vector3(0.7, 0.06, 0.14) * S, wood)
			_cylinder(node, Vector3(0.2 * S, 0.3 * S, 0.1 * S), 0.015 * S, 0.5 * S, wood)
			_prism(node, Vector3(0.2 * S, 0.3 * S, 0.1 * S), Vector3(0.25, 0.3, 0.02) * S, Color(0.95, 0.92, 0.85))
		_:
			return null
	# a pennant in the owner's colour marks each of your ideas
	_cylinder(node, Vector3(-0.25 * S, 0.35 * S, 0), 0.01 * S, 0.7 * S, wood)
	_box(node, Vector3(-0.17 * S, 0.62 * S, 0), Vector3(0.16, 0.1, 0.01) * S, colour)
	for child in node.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).visibility_range_end = SHOW_WITHIN
	return node


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.85
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add(parent: Node3D, mesh: Mesh, at: Vector3, colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material(colour)
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, at: Vector3, size: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, at, colour)


func _prism(parent: Node3D, at: Vector3, size: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _add(parent, mesh, at, colour)


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, colour: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _add(parent, mesh, at, colour)


func _cone(parent: Node3D, at: Vector3, radius: float, height: float, colour: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _add(parent, mesh, at, colour)


func _sphere(parent: Node3D, at: Vector3, radius: float, colour: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _add(parent, mesh, at, colour)
