## The "living map" detail layer (D-052): forests, farms, towns, capitals and banners.
##
## Detail is grouped per province so it fades in only when the camera is close to that area,
## the way Rise of Kingdoms reveals cities as you zoom in. Zoomed out, only the strategic
## layer (territory colours, names and banners) shows. Placement is seeded, so the same game
## always looks the same.
class_name PropsBuilder
extends RefCounted

const DETAIL_RANGE := 430.0   ## camera distance at which a province's detail appears
const BANNER_FROM := 380.0    ## banners show from this distance outward
const FADE := 80.0

var world: WorldBuilder
var rng := RandomNumberGenerator.new()
var owner_colours := {}
var _materials := {}


func _init(world_builder: WorldBuilder, view: Dictionary) -> void:
	world = world_builder
	rng.seed = int(view.get("seed", 1)) * 7919
	for civ in view["civs"]:
		owner_colours[civ["id"]] = Color(civ["colour"])


func build(parent: Node3D, view: Dictionary) -> void:
	for index in world.sites.size():
		var site: Dictionary = world.sites[index]
		if site["sea"]:
			continue
		var province: Dictionary = site["province"]
		var holder := Node3D.new()
		holder.name = "Detail_" + str(province["id"])
		parent.add_child(holder)
		var town := _town_spots(province, site["pos"], index)
		_forest(holder, province, site["pos"], index, town)
		_fields(holder, province, site["pos"], index, town)
		_buildings(holder, province, town)
		if province["owner"] != null:
			_banner(parent, province, site["pos"])


# --- placement helpers ------------------------------------------------------------------

func _belongs(map_pos: Vector2, index: int) -> bool:
	var near: Array = world._nearest(map_pos)
	return near[0] == index and world.height_at(map_pos) > 0.6


func _scatter(centre: Vector2, radius: float) -> Vector2:
	var angle := rng.randf() * TAU
	return centre + Vector2(cos(angle), sin(angle)) * radius * sqrt(rng.randf())


func _ground(map_pos: Vector2) -> Vector3:
	return world.to_world(map_pos) + Vector3(0, world.height_at(map_pos), 0)


func _material(key: String) -> StandardMaterial3D:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		_materials[key] = m
	return _materials[key]


func _multimesh(mesh: Mesh, transforms: Array, colours: Array, range_end: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colours[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = _material("props")
	instance.visibility_range_end = range_end
	instance.visibility_range_end_margin = FADE
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return instance


# --- towns --------------------------------------------------------------------------------

## House positions for a province's town, sized by population. Capitals are bigger.
func _town_spots(province: Dictionary, centre: Vector2, index: int) -> Array:
	var count := clampi(int(province["population"]) / 2500, 3, 70)
	if province["capital"]:
		count = int(count * 1.4)
	var radius := 5.0 + sqrt(count) * 2.6
	var spots := []
	var tries := 0
	while spots.size() < count and tries < count * 12:
		tries += 1
		var p := _scatter(centre, radius)
		if _belongs(p, index):
			spots.append(p)
	return spots


func _buildings(holder: Node3D, province: Dictionary, spots: Array) -> void:
	if spots.is_empty():
		return
	var wall_colour := Color(0.80, 0.76, 0.66)
	var roof_colours := [Color(0.62, 0.24, 0.16), Color(0.52, 0.30, 0.18), Color(0.45, 0.20, 0.14)]
	if province["owner"] != null:
		roof_colours.append(owner_colours[province["owner"]].darkened(0.2))
	var house_t := []
	var house_c := []
	var roof_t := []
	var roof_c := []
	for p in spots:
		var ground := _ground(p)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3))
		house_t.append(Transform3D(basis, ground + Vector3(0, 0.8, 0)))
		house_c.append(wall_colour.darkened(rng.randf() * 0.15))
		roof_t.append(Transform3D(basis, ground + Vector3(0, 2.3, 0)))
		roof_c.append(roof_colours[rng.randi() % roof_colours.size()])
	var house := BoxMesh.new()
	house.size = Vector3(2.2, 1.6, 2.8)
	var roof := PrismMesh.new()
	roof.size = Vector3(2.7, 1.4, 3.1)
	holder.add_child(_multimesh(house, house_t, house_c, DETAIL_RANGE))
	holder.add_child(_multimesh(roof, roof_t, roof_c, DETAIL_RANGE))
	if province["capital"]:
		_capital(holder, province, spots)


func _capital(holder: Node3D, province: Dictionary, spots: Array) -> void:
	var centre := Vector2.ZERO
	var farthest := 0.0
	for p in spots:
		centre += p
	centre /= spots.size()
	for p in spots:
		farthest = maxf(farthest, centre.distance_to(p))
	var radius := farthest + 3.0
	var stone := Color(0.72, 0.70, 0.64)
	var walls_t := []
	var walls_c := []
	var segments := int(TAU * radius / 3.6)
	for i in segments:
		var angle := TAU * i / segments
		var p := centre + Vector2(cos(angle), sin(angle)) * radius
		var basis := Basis(Vector3.UP, -angle)
		walls_t.append(Transform3D(basis, _ground(p) + Vector3(0, 1.0, 0)))
		walls_c.append(stone.darkened(rng.randf() * 0.1))
	var wall := BoxMesh.new()
	wall.size = Vector3(0.9, 2.4, 3.9)
	holder.add_child(_multimesh(wall, walls_t, walls_c, DETAIL_RANGE))
	var keep := BoxMesh.new()
	keep.size = Vector3(5.5, 7.0, 5.5)
	var tower := CylinderMesh.new()
	tower.top_radius = 1.6
	tower.bottom_radius = 1.9
	tower.height = 11.0
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 2.3
	cap.height = 3.0
	var ground := _ground(centre)
	var roof: Color = owner_colours.get(province["owner"], Color(0.5, 0.2, 0.15))
	holder.add_child(_multimesh(keep, [Transform3D(Basis(), ground + Vector3(0, 3.5, 0))], [stone], DETAIL_RANGE))
	holder.add_child(_multimesh(tower, [Transform3D(Basis(), ground + Vector3(3.2, 5.5, 3.2))], [stone.darkened(0.08)], DETAIL_RANGE))
	holder.add_child(_multimesh(cap, [Transform3D(Basis(), ground + Vector3(3.2, 12.5, 3.2))], [roof], DETAIL_RANGE))


# --- land ---------------------------------------------------------------------------------

const TREES := {
	"forest": 1100, "hills": 260, "river_plains": 35, "plains": 45, "coast": 30,
	"steppe": 20, "mountains": 140, "marsh": 90, "desert": 0,
}


func _near_town(p: Vector2, town: Array, gap: float) -> bool:
	for t in town:
		if p.distance_to(t) < gap:
			return true
	return false


func _forest(holder: Node3D, province: Dictionary, centre: Vector2, index: int, town: Array) -> void:
	var wanted: int = TREES.get(province["terrain"], 50)
	var transforms := []
	var colours := []
	var groves := []
	for g in maxi(3, wanted / 40):
		groves.append(_scatter(centre, 80.0))
	for i in wanted * 2:
		if transforms.size() >= wanted:
			break
		var dense: bool = province["terrain"] in ["forest", "mountains"]
		var p := _scatter(centre, 80.0) if dense and rng.randf() < 0.5 else _scatter(groves[rng.randi() % groves.size()], 16.0)
		if not _belongs(p, index) or _near_town(p, town, 7.0):
			continue
		var h := world.height_at(p)
		if h > 30.0:
			continue
		var size := rng.randf_range(0.7, 1.4) * (0.8 if province["terrain"] == "marsh" else 1.0)
		transforms.append(Transform3D(Basis().scaled(Vector3(size, size * rng.randf_range(0.9, 1.3), size)), _ground(p) + Vector3(0, 2.6 * size, 0)))
		colours.append(Color(0.10, 0.30, 0.12).lerp(Color(0.25, 0.42, 0.16), rng.randf()))
	if transforms.is_empty():
		return
	var tree := CylinderMesh.new()
	tree.top_radius = 0.0
	tree.bottom_radius = 1.7
	tree.height = 5.5
	tree.radial_segments = 7
	holder.add_child(_multimesh(tree, transforms, colours, DETAIL_RANGE))


func _fields(holder: Node3D, province: Dictionary, centre: Vector2, index: int, town: Array) -> void:
	if not province["terrain"] in ["plains", "river_plains", "coast", "hills"] or town.is_empty():
		return
	var crops := [Color(0.66, 0.58, 0.30), Color(0.42, 0.50, 0.20), Color(0.45, 0.36, 0.22), Color(0.56, 0.58, 0.28)]
	var transforms := []
	var colours := []
	var count := town.size() * 2
	var town_centre := Vector2.ZERO
	for t in town:
		town_centre += t
	town_centre /= town.size()
	var inner := 6.0 + sqrt(town.size()) * 2.8
	for i in count * 4:
		if transforms.size() >= count:
			break
		var angle := rng.randf() * TAU
		var ring := inner + 3.0 + rng.randf() * (10.0 + sqrt(town.size()) * 3.0)
		var p := town_centre + Vector2(cos(angle), sin(angle)) * ring
		if not _belongs(p, index) or _near_town(p, town, 4.0):
			continue
		var basis := Basis(Vector3.UP, -angle).scaled(Vector3(rng.randf_range(0.8, 1.2), 1, rng.randf_range(0.9, 1.3)))
		transforms.append(Transform3D(basis, _ground(p) + Vector3(0, 0.12, 0)))
		colours.append(crops[rng.randi() % crops.size()])
	if transforms.is_empty():
		return
	var field := BoxMesh.new()
	field.size = Vector3(6.0, 0.2, 4.5)
	holder.add_child(_multimesh(field, transforms, colours, DETAIL_RANGE))


# --- strategic layer ----------------------------------------------------------------------

func _banner(parent: Node3D, province: Dictionary, centre: Vector2) -> void:
	var colour: Color = owner_colours[province["owner"]]
	var ground := _ground(centre) + Vector3(0, 0, 0)
	var size := 1.6 if province["capital"] else 1.0
	var pole := CylinderMesh.new()
	pole.top_radius = 0.5 * size
	pole.bottom_radius = 0.5 * size
	pole.height = 26.0 * size
	var flag := BoxMesh.new()
	flag.size = Vector3(11.0, 7.0, 0.6) * size
	var node := Node3D.new()
	node.name = "Banner_" + str(province["id"])
	parent.add_child(node)
	for part in [[pole, Color(0.25, 0.2, 0.15), Vector3(0, 13.0 * size, 0)], [flag, colour, Vector3(5.6 * size, 22.0 * size, 0)]]:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = part[0]
		var m := StandardMaterial3D.new()
		m.albedo_color = part[1]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.material_override = m
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.position = ground + part[2]
		mesh_instance.visibility_range_begin = BANNER_FROM
		node.add_child(mesh_instance)
