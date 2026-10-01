## Cartoon mountain peaks over the real ranges (step 2.11b): low-poly rocky cones, capped
## with snow where the land is high, placed where the terrain is both high and rugged. The
## real elevation is still the ground; the peaks exaggerate it so ranges read at a glance,
## the way painted strategy maps draw them.
class_name Peaks
extends RefCounted

const STEP := 11                ## sample every STEP height-map pixels
const MIN_METRES := 1500.0
const MIN_RELIEF := 600.0       ## height difference within the neighbourhood
const SHOW_WITHIN := 900.0
const TILE := 300.0             ## batched by tile: Godot hides a batch by its centre's distance

var earth: EarthBuilder
var rng := RandomNumberGenerator.new()


func _init(earth_builder: EarthBuilder) -> void:
	earth = earth_builder
	rng.seed = hash(earth.region + "peaks")


func build(parent: Node3D) -> void:
	var tiles := {}   # Vector2i -> [snowy transforms, bare transforms]
	var w := int(earth.size().x)
	var h := int(earth.size().y)
	for y in range(STEP, h - STEP, STEP):
		for x in range(STEP, w - STEP, STEP):
			var pixel := Vector2(x, y) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			var metres := earth.metres_at(pixel)
			if metres < MIN_METRES or earth.is_ocean_at(pixel):
				continue
			var low := metres
			for d in [Vector2(-6, 0), Vector2(6, 0), Vector2(0, -6), Vector2(0, 6)]:
				low = minf(low, earth.metres_at(pixel + d))
			var relief := metres - low
			if relief < MIN_RELIEF or rng.randf() > 0.55:
				continue
			# a main peak with smaller ones crowding round it: a range, not a cone
			var key := Vector2i(int(x / TILE), int(y / TILE))
			if not tiles.has(key):
				tiles[key] = [[], []]
			var main := clampf(relief / 60.0, 11.0, 36.0)
			for k in rng.randi_range(2, 4):
				var height := main * (1.0 if k == 0 else rng.randf_range(0.45, 0.75))
				var width := height * rng.randf_range(1.2, 1.6)
				var spot := pixel + (Vector2.ZERO if k == 0 else Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5)))
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(width, height, width))
				var at := earth.ground_at_pixel(spot) - Vector3(0, height * 0.12, 0)
				var snowy := metres > 2600.0 and (k == 0 or metres > 3400.0)
				tiles[key][0 if snowy else 1].append(Transform3D(basis, at))
	var holder := Node3D.new()
	holder.name = "Peaks"
	parent.add_child(holder)
	var meshes := [_peak(true), _peak(false)]
	for key in tiles:
		for kind in 2:
			if not tiles[key][kind].is_empty():
				holder.add_child(_multimesh(meshes[kind], tiles[key][kind]))


## A unit peak (height 1, radius 0.5): a lumpy cone, rock below and snow (or rock) above.
func _peak(snow: bool) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	var rock := Color(0.58, 0.55, 0.52)
	var dark := Color(0.44, 0.42, 0.42)
	var cap := Color(0.98, 0.99, 1.0) if snow else Color(0.66, 0.62, 0.56)
	var ring: Array[Vector3] = []
	var mid: Array[Vector3] = []
	for i in sides:
		var a := TAU * i / sides
		var r := 0.5 * (0.85 + 0.3 * sin(i * 2.7))
		ring.append(Vector3(cos(a) * r, 0, sin(a) * r))
		mid.append(Vector3(cos(a + 0.3) * r * 0.5, 0.5 if snow else 0.62, sin(a + 0.3) * r * 0.5))
	var top := Vector3(0.04, 1.0, -0.03)
	for i in sides:
		var j := (i + 1) % sides
		var shade := rock if i % 2 == 0 else dark
		_tri(st, ring[i], ring[j], mid[j], shade)
		_tri(st, ring[i], mid[j], mid[i], shade)
		_tri(st, mid[i], mid[j], top, cap)
	st.generate_normals()
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	for v in [a, b, c]:
		st.set_color(colour)
		st.add_vertex(v)


func _multimesh(mesh: Mesh, transforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	instance.visibility_range_end = SHOW_WITHIN
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
