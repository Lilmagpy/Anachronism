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
	"sailing": "harbour", "compass": "harbour", "sternpost_rudder": "harbour", "caravel": "harbour",
	"printing_press": "press", "newspapers": "press", "telescope": "observatory",
	"universities": "school", "scientific_method": "school", "hospitals": "school",
	"cannon": "powder_tower", "musket": "powder_tower", "star_fort": "watchtower",
	"banking": "mint", "joint_stock_company": "mint", "double_entry": "mint",
	"steam_engine": "furnace", "coke_smelting": "furnace", "railways": "milestone",
	"mechanical_clock": "clock_tower", "glassmaking": "kiln", "spinning_machine": "workshop",
	"telegraph": "milestone", "steamship": "harbour", "bessemer_steel": "furnace", "battery": "workshop",
	"photography": "workshop", "dynamite": "powder_tower",
}

## how tall each kit-built landmark stands, in settlement units
## Landmark kinds drawn with the model kit's public buildings (D-280), and their size.
const CIVIC := {"aqueduct": "aqueduct", "windmill": "windmill", "water_wheel": "water_wheel",
	"observatory": "observatory", "school": "school", "workshop": "workshop", "press": "workshop",
	"forge": "forge", "furnace": "factory", "kiln": "workshop", "watchtower": "watchtower",
	"mint": "bank", "harbour": "harbour", "clock_tower": "clock_tower", "academy": "academy",
	"hospital": "hospital", "station": "station", "market": "market", "temple": "temple",
	"granary": "granary", "mine": "mine", "factory": "factory"}
const CIVIC_UNIT := Settlements.CIVIC_UNIT * 1.2   ## a touch larger than the city's own, as a showpiece (D-281)
const KIT_HEIGHT := {"windmill": 1.0, "water_wheel": 0.5, "clock_tower": 1.0, "watchtower": 0.8,
	"powder_tower": 0.8, "observatory": 0.8, "school": 0.6, "workshop": 0.42, "press": 0.42,
	"kiln": 0.42, "forge": 0.45, "furnace": 0.45, "mint": 0.6, "harbour": 0.55}

var map: ProvinceMap
var earth: EarthBuilder
var _built := {}   ## kind -> true
var _halos: Array[Node3D] = []   ## golden rings under landmarks from the future, turning


func setup(province_map: ProvinceMap) -> void:
	map = province_map
	earth = province_map.earth
	name = "Landmarks"


## Rebuild for the player's adopted ideas (cheap: a handful of shapes).
func update(view: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_built.clear()
	_halos.clear()
	var capital: Dictionary = {}
	for site in map.sites:
		if site["owner"] == view["player"] and site["capital"]:
			capital = site
	if capital.is_empty():
		return
	var colour := Color(map.civ_colours.get(view["player"], Color(0.6, 0.2, 0.15)))
	var kinds: Array[String] = []
	var future := {}   ## kind -> [idea name, years early]: built from an idea brought early (D-126)
	for idea in view["ideas"]:
		if idea["stage"] in ["adopted", "widespread"] and KINDS.has(idea["id"]):
			var kind: String = KINDS[idea["id"]]
			if not kind in kinds:
				kinds.append(kind)
			var since = idea.get("adopted_year")
			if since != null and int(idea["year"]) > int(since):
				var early := int(idea["year"]) - int(since)
				if not future.has(kind) or early > int(future[kind][1]):
					future[kind] = [str(idea["name"]), early]
	kinds.sort()
	var centre: Vector2 = capital["pixel"]
	var taken: Array[Vector2] = []
	for i in kinds.size():
		var angle := TAU * i / maxf(kinds.size(), 1.0) + 0.4
		var radius := (2.6 + (i % 2) * 0.9) * S
		var spot := _find_spot(centre, angle, radius, kinds[i] == "harbour", taken)
		if kinds[i] == "harbour" and not earth.is_wet(spot):
			continue   # an inland capital has no harbour to show
		taken.append(spot)
		var piece := _make(kinds[i], colour, spot, centre)
		if piece != null:
			add_child(piece)
			if future.has(kinds[i]):
				_from_the_future(earth.ground_at_pixel(spot), str(future[kinds[i]][0]), int(future[kinds[i]][1]))


## A landmark built from an idea brought from the future: a golden halo turns on the ground
## beneath it, a soft light and rising sparkles mark it, and up close its name says how
## early it came.
func _from_the_future(at: Vector3, idea: String, early: int) -> void:
	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.62 * S
	ring.outer_radius = 0.72 * S
	ring.rings = 32
	halo.mesh = ring
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color(1.0, 0.82, 0.3)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.75, 0.25)
	halo.material_override = gold
	halo.position = at + Vector3(0, 0.08 * S, 0)
	halo.scale = Vector3(1, 0.15, 1)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Lod.near(halo, SHOW_WITHIN)
	add_child(halo)
	_halos.append(halo)
	var sparkle := Settlements.smoke_at(at + Vector3(0, 0.2 * S, 0), Color(1.0, 0.86, 0.4, 0.8))
	sparkle.amount = 10
	sparkle.lifetime = 2.5
	sparkle.scale_amount_min = 0.3
	sparkle.scale_amount_max = 0.5
	add_child(sparkle)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.4)
	glow.light_energy = 1.2
	glow.omni_range = 1.6 * S
	glow.position = at + Vector3(0, 0.6 * S, 0)
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = SHOW_WITHIN * 0.7
	glow.distance_fade_length = SHOW_WITHIN * 0.3
	add_child(glow)
	var label := Label3D.new()
	label.text = "✦ %s · %s yrs early" % [idea, GameHud.number(early)]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0006
	label.font_size = 24
	label.outline_size = 10
	label.modulate = Color(1.0, 0.88, 0.45)
	label.outline_modulate = Color(0.25, 0.12, 0.02, 0.9)
	label.no_depth_test = true
	label.render_priority = 12
	label.position = at + Vector3(0, 1.4 * S, 0)
	Lod.near(label, 160.0)
	add_child(label)


func _process(delta: float) -> void:
	for halo in _halos:
		if is_instance_valid(halo):
			halo.rotate_y(delta * 0.6)


## A place for a landmark near the capital: on land (a harbour wants the water's edge),
## turning around the city from its own angle until one is found, and not on another.
func _find_spot(centre: Vector2, angle: float, radius: float, wet: bool, taken: Array[Vector2]) -> Vector2:
	var fallback := centre + Vector2(cos(angle), sin(angle)) * radius
	for step in 24:
		var a := angle + step * TAU / 24.0 * (1.0 if step % 2 == 0 else -1.0) * 0.5
		for r in [radius, radius * 1.4, radius * 0.75]:
			var spot: Vector2 = centre + Vector2(cos(a), sin(a)) * float(r)
			if earth.is_wet(spot) != wet:
				continue
			var clear := true
			for other in taken:
				if other.distance_to(spot) < 1.2 * S:
					clear = false
			if clear:
				return spot
	return fallback


func _make(kind: String, colour: Color, spot: Vector2, centre: Vector2) -> Node3D:
	var node := Node3D.new()
	node.name = kind
	node.position = earth.ground_at_pixel(spot)
	var stone := Color(0.80, 0.76, 0.66)
	var wood := Color(0.50, 0.33, 0.18)
	var roof := colour.darkened(0.25)
	# the model kit's public buildings first (D-280): detailed, in the owner's colours
	var civic := str(CIVIC.get(kind, ""))
	if civic != "" and Settlements.MODULES.has("civic"):
		var mesh: ArrayMesh = Settlements._scaled_model(Settlements.MODULES["civic"], civic, CIVIC_UNIT)
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_custom_data = true
		batch.mesh = mesh
		batch.instance_count = 1
		batch.set_instance_transform(0, Transform3D())
		batch.set_instance_custom_data(0, colour)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = batch
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/models.gdshader")
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(instance)
		if kind == "harbour":
			node.position.y = earth.ground_at_pixel(spot).y + 0.05
		node.rotation.y = -(centre - spot).angle() + PI / 2.0   # facing the city
		if kind in ["forge", "furnace", "kiln"]:
			node.add_child(Settlements.smoke_at(Vector3(0, CIVIC_UNIT * 1.4, 0), Color(0.45, 0.45, 0.48, 0.4)))
		Lod.near(instance, SHOW_WITHIN)
		return node
	# buildings from the Kenney kits where there is one (G1); the rest from simple shapes
	var built := Buildings.landmark(kind, KIT_HEIGHT.get(kind, 1.0) * S)
	if built != null:
		_kit(node, built, colour.lerp(Color(0.88, 0.55, 0.38), 0.45))   # softened toward terracotta
		if kind in ["forge", "furnace", "workshop", "kiln"]:
			node.add_child(Settlements.smoke_at(Vector3(0, KIT_HEIGHT[kind] * S, 0), Color(0.45, 0.45, 0.48, 0.4)))
		if kind == "harbour":
			node.position.y = earth.ground_at_pixel(spot).y + 0.1
		node.rotation.y = -(centre - spot).angle() + PI / 2.0   # facing the city
		for child in node.get_children():
			if child is GeometryInstance3D:
				Lod.near(child as GeometryInstance3D, SHOW_WITHIN)
		return node
	match kind:
		"aqueduct":
			# a line of stone arches from the hills into the city
			var dir := (centre - spot).normalized()
			node.rotation.y = -dir.angle()
			for k in 9:
				_box(node, Vector3(k * 0.2 * S, 0.15 * S, 0), Vector3(0.07, 0.3, 0.1) * S, stone)
				if k < 8:
					_box(node, Vector3((k + 0.5) * 0.2 * S, 0.27 * S, 0), Vector3(0.14, 0.06, 0.1) * S, stone.darkened(0.06))
			_box(node, Vector3(0.8 * S, 0.33 * S, 0), Vector3(1.72, 0.06, 0.12) * S, stone.darkened(0.12))
			_box(node, Vector3(0.8 * S, 0.365 * S, 0), Vector3(1.72, 0.012, 0.06) * S, Color(0.35, 0.62, 0.85))
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
		"clock_tower":
			_box(node, Vector3(0, 0.4 * S, 0), Vector3(0.2, 0.8, 0.2) * S, stone)
			_cylinder(node, Vector3(0, 0.65 * S, 0.105 * S), 0.07 * S, 0.01 * S, Color(0.98, 0.95, 0.85)).rotation.x = PI / 2.0
			_cone(node, Vector3(0, 0.88 * S, 0), 0.16 * S, 0.18 * S, roof)
		"watchtower", "powder_tower":
			_box(node, Vector3(0, 0.3 * S, 0), Vector3(0.18, 0.6, 0.18) * S, stone.darkened(0.1))
			_cone(node, Vector3(0, 0.68 * S, 0), 0.16 * S, 0.16 * S, roof)
		"canal":
			# a cut of water between stone banks, toward the city
			var dir := (centre - spot).normalized()
			node.rotation.y = -dir.angle()
			_box(node, Vector3(0.6 * S, 0.012 * S, 0), Vector3(1.4, 0.02, 0.07) * S, Color(0.22, 0.52, 0.78))
			for side in [-1, 1]:
				_box(node, Vector3(0.6 * S, 0.02 * S, side * 0.045 * S), Vector3(1.4, 0.04, 0.02) * S, stone)
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
			Lod.near(child as GeometryInstance3D, SHOW_WITHIN)
	return node


## A kit building in the owner's colour (a one-instance batch, so the kit shader gets it).
func _kit(node: Node3D, mesh: ArrayMesh, colour: Color) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = 1
	batch.set_instance_transform(0, Transform3D())
	batch.set_instance_color(0, colour)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	node.add_child(instance)


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
